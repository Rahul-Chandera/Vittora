#!/bin/bash
# Capture raw Apple Watch App Store screenshots.
#
# The watch app has no data of its own — WatchSnapshotStore is fed over
# WatchConnectivity by the phone. So this boots a *paired* iPhone + Watch,
# seeds the phone app (which pushes a snapshot on activate), and only then
# captures the watch. Running the watch simulator alone yields empty state.
#
# Usage: capture_watch_screenshots.sh   (uses the first active pair)
set -euo pipefail

APP_ID="com.enerjiktech.vittora"
WATCH_APP_ID="com.enerjiktech.vittora.watchkitapp"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/Docs/Store/screenshots/watch"
DERIVED="${DERIVED_DIR:-$ROOT/.build/screenshots}"

mkdir -p "$OUT"

PAIR_INFO=$(xcrun simctl list pairs -j | python3 -c "
import json,sys
pairs=json.load(sys.stdin)['pairs']
# 'state' reads '(active, disconnected)', not 'active'. Prefer the 46mm Series
# watch so the output matches the 416x496 asset already in the listing.
cands=[p for p in pairs.values() if 'active' in p.get('state','')]
if not cands: sys.exit('no active watch/phone pair')
cands.sort(key=lambda p: 0 if '46mm' in p['watch']['name'] else 1)
p=cands[0]
print(p['watch']['udid'], p['phone']['udid'], p['watch']['name'].replace(' ','_'))
") || exit 1
read -r PAIR_WATCH PAIR_PHONE WATCH_NAME <<< "$PAIR_INFO"
echo "==> watch $WATCH_NAME ($PAIR_WATCH) paired with phone $PAIR_PHONE"

# Erase the watch: WatchSnapshotStore persists the last snapshot, so a stale
# one renders ("Updated 2 days ago") and masks a push that never arrived.
if [ "${KEEP_DEVICE:-0}" != "1" ]; then
  xcrun simctl shutdown "$PAIR_WATCH" >/dev/null 2>&1 || true
  xcrun simctl erase "$PAIR_WATCH"
fi
for udid in "$PAIR_PHONE" "$PAIR_WATCH"; do
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
done
xcrun simctl bootstatus "$PAIR_PHONE" -b
xcrun simctl bootstatus "$PAIR_WATCH" -b

PHONE_APP="$DERIVED/Build/Products/Debug-iphonesimulator/Vittora.app"
WATCH_APP="$DERIVED/Build/Products/Debug-watchsimulator/VittoraWatch.app"

# Always build — a `[ ! -d "$APP" ]` guard here meant a re-capture after a
# code change silently reused the previous binary. xcodebuild is incremental.
echo "==> building iOS app"
xcodebuild -project "$ROOT/Vittora.xcodeproj" -scheme Vittora \
  -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" \
  -configuration Debug build >/dev/null
echo "==> building watchOS app"
xcodebuild -project "$ROOT/Vittora.xcodeproj" -scheme VittoraWatch \
  -destination "generic/platform=watchOS Simulator" -derivedDataPath "$DERIVED" \
  -configuration Debug build >/dev/null

xcrun simctl install "$PAIR_PHONE" "$PHONE_APP"
xcrun simctl install "$PAIR_WATCH" "$WATCH_APP"

xcrun simctl status_bar "$PAIR_WATCH" override --time "9:41" 2>/dev/null || true

# Phone first: seeding is async and the bridge pushes a post-seed snapshot.
SIMCTL_CHILD_UITEST_DEMO_REGION="${REGION:-US}" \
SIMCTL_CHILD_UITEST_DEMO_MONTHS="${DEMO_MONTHS:-12}" \
  xcrun simctl launch "$PAIR_PHONE" "$APP_ID" --uitesting --ui-test-seed-demo >/dev/null
sleep 20

xcrun simctl launch "$PAIR_WATCH" "$WATCH_APP_ID" >/dev/null
sleep 25   # WCSession activation + first snapshot delivery

NAME=$(echo "$WATCH_NAME" | tr 'A-Z' 'a-z' | sed -E 's/apple_watch_//; s/[()]//g; s/_+/-/g')
xcrun simctl io "$PAIR_WATCH" screenshot --type=png "$OUT/watch-$NAME-dashboard.png"
echo "    watch-$NAME-dashboard.png"

xcrun simctl status_bar "$PAIR_WATCH" clear 2>/dev/null || true
echo "==> raw watch capture in $OUT"
