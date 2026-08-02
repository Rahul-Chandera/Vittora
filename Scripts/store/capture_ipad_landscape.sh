#!/bin/bash
# Capture landscape iPad App Store screenshots.
#
# Separate from capture_screenshots.sh because orientation is the one thing
# `simctl` cannot do: there is no rotate subcommand, and driving Simulator.app
# through AppleScript needs the GUI frontmost plus accessibility permission.
# `XCUIDevice.shared.orientation` works, but only inside a UI test — so this
# writes a config file and runs VittoraUITests/StoreGalleryUITests, which reads
# it and captures the same six slots in the same order as the simctl path.
#
# Usage: capture_ipad_landscape.sh <set-name> [locale] [apple-locale] [region]
#   capture_ipad_landscape.sh ipad-13
#   capture_ipad_landscape.sh ipad-13-hi hi hi_IN IN
set -euo pipefail

SET_NAME="${1:-ipad-13}"
LOCALE="${2:-en}"
APPLE_LOCALE="${3:-en_US}"
REGION="${4:-US}"
DEVICE="${DEVICE:-iPad Pro 13-inch (M5)}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/Docs/Store/screenshots/$SET_NAME"
DERIVED="${DERIVED_DIR:-$ROOT/.build/screenshots-ipad}"

mkdir -p "$OUT" "$ROOT/.build"

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

echo "==> $SET_NAME on $DEVICE (landscape), locale=$LOCALE region=$REGION"

# The UI test drives launch arguments itself, so this only needs to build and
# run. ONLY=<slot> is forwarded the same way the simctl script uses it.
xcodebuild test \
  -project "$ROOT/Vittora.xcodeproj" \
  -scheme Vittora \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  -only-testing:VittoraUITests/StoreGalleryUITests \
  2>&1 | grep -E "^    [0-9]{2}-|Test case .*(passed|failed)|\*\* TEST|error:" || true

rm -f "$ROOT/.build/store-shot-config.json"

# XCUIScreen.main.screenshot() always returns the display's NATIVE buffer, which
# on iPad is portrait no matter what the interface orientation is. The layout in
# it is correctly landscape — it is just stored rotated — so turn the pixels to
# match. ROTATE_90 is counter-clockwise in Pillow, which moves the buffer's top
# edge to the left and puts the sidebar back on the left where it renders.
python3 - "$OUT" <<'PYEOF'
import sys, glob, os
from PIL import Image
turned = 0
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.png"))):
    im = Image.open(f)
    if im.height > im.width:                      # still portrait -> rotate
        im.transpose(Image.ROTATE_90).save(f, "PNG")
        turned += 1
print(f"    rotated {turned} capture(s) to landscape")
PYEOF

echo "==> raw captures in $OUT"
