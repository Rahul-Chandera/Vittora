#!/bin/bash
# Marketing screenshots (social, website, blog, ad creative) for iPhone and iPad,
# light and dark. Drives VittoraUITests/MarketingScreenshotsUITests, which walks
# every feature on the App Store showcase data (US, USD, en_US) and writes each
# screen straight to disk with an AI-readable name:
#
#   <platform>-<appearance>-<NN>-<feature-area>-<screen>.png
#
# Usage: capture_marketing_screenshots.sh <out-root> [iphone|ipad|all] [light|dark|all]
#   capture_marketing_screenshots.sh ../Marketing/Screenshots all all
#
# Mac and Watch have their own scripts (capture_marketing_mac.sh and
# capture_watch_screenshots.sh) — there is no macOS simulator, and the watch needs
# a paired phone.
set -euo pipefail

OUT_ROOT="$(cd "${1:?output root, e.g. ../Marketing/Screenshots}" && pwd)"
PLATFORMS="${2:-all}"
APPEARANCES="${3:-all}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DERIVED="${DERIVED_DIR:-$ROOT/.build/marketing}"

[ "$PLATFORMS" = all ] && PLATFORMS="iphone ipad"
[ "$APPEARANCES" = all ] && APPEARANCES="light dark"

device_for() {
  case "$1" in
    iphone) echo "${IPHONE_DEVICE:-iPhone 17 Pro Max}" ;;
    ipad)   echo "${IPAD_DEVICE:-iPad Pro 13-inch (M5)}" ;;
  esac
}

udid_for() {
  xcrun simctl list devices available -j | python3 -c "
import json,sys
name=sys.argv[1]
best=None
for runtime, devs in json.load(sys.stdin)['devices'].items():
    if 'iOS' not in runtime: continue
    for d in devs:
        if d['name']==name and (best is None or runtime>best[0]): best=(runtime,d['udid'])
if not best: sys.exit('no available simulator named '+name)
print(best[1])" "$1"
}

echo "==> building for testing (once)"
xcodebuild -project "$ROOT/Vittora.xcodeproj" -scheme Vittora \
  -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" \
  build-for-testing >/dev/null
XCTESTRUN=$(ls "$DERIVED"/Build/Products/*.xctestrun | head -1)

for platform in $PLATFORMS; do
  device="$(device_for "$platform")"
  udid="$(udid_for "$device")"
  for appearance in $APPEARANCES; do
    folder="$([ "$platform" = iphone ] && echo iPhone || echo iPad)/$(tr '[:lower:]' '[:upper:]' <<< "${appearance:0:1}")${appearance:1}"
    out="$OUT_ROOT/$folder"
    mkdir -p "$out"
    echo "==> $platform $appearance on $device ($udid) -> $out"
    # Erase per set: SpringBoard state, a stray alert or a half-seeded store all
    # survive relaunches and would land in the shots.
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$udid" -b >/dev/null
    xcrun simctl status_bar "$udid" override \
      --time "9:41" --batteryState charged --batteryLevel 100 \
      --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3
    TEST_RUNNER_MARKETING_SCREENSHOT_DIR="$out" \
    TEST_RUNNER_MARKETING_APPEARANCE="$appearance" \
      xcodebuild test-without-building -xctestrun "$XCTESTRUN" \
        -destination "id=$udid" -parallel-testing-enabled NO \
        -only-testing:VittoraUITests/MarketingScreenshotsUITests 2>&1 \
      | grep -E "screen not reached|Test Case .*(failed|skipped)" || true
    # The Dynamic Island shot is taken from the home screen, which also shows
    # the simulator's own apps (and the UI-test runner). Keep only the top band:
    # status bar and island with the live total.
    for f in "$out"/*-live-activities-*.png; do
      [ -f "$f" ] || continue
      w=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
      h=$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}')
      [ "$h" -gt 600 ] && sips --cropToHeightWidth $((h * 75 / 1000)) "$w" --cropOffset 0 0 "$f" >/dev/null
    done
    # iPad is shot in landscape, but XCUIScreen returns the device's native
    # portrait framebuffer — rotate each one upright.
    if [ "$platform" = ipad ]; then
      # PIL, not sips: `sips -r 270` turned these the wrong way.
      python3 - "$out" <<'PY'
import glob, os, sys
from PIL import Image
for f in glob.glob(os.path.join(sys.argv[1], "*.png")):
    im = Image.open(f)
    if im.height > im.width:
        im.rotate(90, expand=True).save(f)
PY
    fi
    echo "    $(ls "$out"/*.png 2>/dev/null | wc -l | tr -d ' ') screenshots"
  done
done
