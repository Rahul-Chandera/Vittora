#!/usr/bin/env bash
# Capture the paywall for the App Store Connect subscription review screenshot.
#
#   Scripts/store/capture_paywall_shot.sh [device-udid] [out-dir]
#
# Unlike the gallery captures, this cannot go through simctl: simctl has no way to
# apply a StoreKit configuration, and xcodebuild ignores the scheme's, so the paywall
# would render its "products unavailable" state. PaywallShotUITests builds an
# SKTestSession instead, which is why this is a UI test rather than a shell loop.
#
# Pass a UDID, not a device name — duplicate simulator names make -destination ambiguous.
set -euo pipefail

cd "$(dirname "$0")/../.."

DEVICE="${1:-}"
OUT_DIR="${2:-$PWD/Docs/Store/screenshots/paywall/iphone-69}"

if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available -j \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)["devices"]
for rt,ds in d.items():
    if "iOS" not in rt: continue
    for x in ds:
        if x["name"]=="iPhone 17 Pro Max":
            print(x["udid"]); raise SystemExit')
fi

[ -n "$DEVICE" ] || { echo "No iPhone 17 Pro Max simulator found; pass a UDID." >&2; exit 1; }

mkdir -p .build
cat > .build/paywall-shot-config.json <<JSON
{"outputDirectory":"$OUT_DIR","locale":"en","appleLocale":"en_US","region":"US"}
JSON

echo "==> capturing paywall on $DEVICE -> $OUT_DIR"
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build-ci/DerivedData \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -only-testing:VittoraUITests/PaywallShotUITests \
  test

rm -f .build/paywall-shot-config.json
echo "==> wrote $OUT_DIR/paywall.png"
