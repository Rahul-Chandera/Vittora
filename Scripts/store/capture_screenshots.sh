#!/bin/bash
# Capture raw App Store gallery screenshots, one set (device + locale) at a time.
#
# Drives VittoraUITests/StoreGalleryUITests, which launches the app per slot on
# flags it already has for UI testing — no production code exists just to make
# screenshots:
#   --uitesting --ui-test-seed-demo   seed the showcase dataset
#   UITEST_DEMO_REGION=US|IN          currency + payee set
#   UITEST_INITIAL_TAB=<AppTab raw>   open straight to a tab
#   --ui-test-open-url=vittora://…    deep-link into a specific report
# iPhone sets are portrait, iPad sets landscape (the test rotates iPads).
#
# Usage: capture_screenshots.sh <set-name> <device-name> [locale] [apple-locale] [region]
#   capture_screenshots.sh iphone-69    "iPhone 17 Pro Max"
#   capture_screenshots.sh iphone-69-in "iPhone 17 Pro Max" en en_IN US
#   capture_screenshots.sh iphone-69-hi "iPhone 17 Pro Max" hi hi_IN IN
#   capture_screenshots.sh ipad-13      "iPad Pro 13-inch (M5)"
#
# Raw captures land in $STORE_ROOT/raw/<set>; make_marketing.py frames them
# into $STORE_ROOT/<set>. STORE_ROOT defaults to Marketing/AppStore beside the repo.
set -euo pipefail

SET_NAME="${1:?set name, e.g. iphone-69}"
DEVICE="${2:?simulator device name}"
LOCALE="${3:-en}"
APPLE_LOCALE="${4:-en_US}"
REGION="${5:-US}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORE_ROOT="${STORE_ROOT:-$(cd "$ROOT/.." && pwd)/Marketing/AppStore}"
OUT="$STORE_ROOT/raw/$SET_NAME"
DERIVED="${DERIVED_DIR:-$ROOT/.build/screenshots}"
mkdir -p "$OUT" "$ROOT/.build"

UDID=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
name=sys.argv[1]
best=None
for runtime, devs in json.load(sys.stdin)['devices'].items():
    if 'iOS' not in runtime: continue
    for d in devs:
        if d['name']==name and (best is None or runtime>best[0]): best=(runtime,d['udid'])
if not best: sys.exit('no available simulator named '+name)
print(best[1])" "$DEVICE")

echo "==> $SET_NAME on $DEVICE ($UDID), locale=$LOCALE region=$REGION -> $OUT"

# Erase, don't just boot. SpringBoard state outlives the app: a stray system
# alert, a previous locale, or a half-seeded store survives terminate and
# relaunch and lands in the middle of a capture.
if [ "${KEEP_DEVICE:-0}" != "1" ]; then
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID"
fi
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
# A clean status bar. Real captures show carrier text and a 63% battery, which
# reads as a screenshot of someone's phone rather than a product shot.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

cat > "$ROOT/.build/store-shot-config.json" <<JSON
{
  "outputDirectory": "$OUT",
  "locale": "$LOCALE",
  "appleLocale": "$APPLE_LOCALE",
  "region": "$REGION",
  "demoMonths": "${DEMO_MONTHS:-12}",
  "only": "${ONLY:-}"
}
JSON

# Always builds (incrementally), so the captures match the working tree.
# ONLY=<slot> re-shoots a single slot.
xcodebuild test \
  -project "$ROOT/Vittora.xcodeproj" -scheme Vittora \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" \
  -parallel-testing-enabled NO \
  -only-testing:VittoraUITests/StoreGalleryUITests \
  2>&1 | grep -E "^    [0-9]{2}-|error:|Test case .*(passed|failed)|\*\* TEST" || true

rm -f "$ROOT/.build/store-shot-config.json"
xcrun simctl status_bar "$UDID" clear

# XCUIScreen.main.screenshot() returns the display's NATIVE buffer, which on
# iPad is portrait whatever the interface orientation. The layout in it is
# correctly landscape, just stored rotated, so turn the pixels to match.
# ROTATE_90 is counter-clockwise in Pillow, which puts the sidebar back on the
# left where it renders. iPhone sets stay portrait.
case "$SET_NAME" in
  ipad*) python3 - "$OUT" <<'PYEOF'
import sys, glob, os
from PIL import Image
turned = 0
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.png"))):
    im = Image.open(f)
    if im.height > im.width:
        im.transpose(Image.ROTATE_90).save(f, "PNG")
        turned += 1
print(f"    rotated {turned} capture(s) to landscape")
PYEOF
  ;;
esac

echo "==> raw captures in $OUT — look at every one before framing"
