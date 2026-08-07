#!/bin/bash
# Capture raw Apple Watch App Store screenshots.
#
# The watch app has no data of its own — WatchSnapshotStore is fed over
# WatchConnectivity by the phone. So this boots a *paired* iPhone + Watch,
# seeds the phone app (which pushes a snapshot on activate), and only then
# captures the watch. Running the watch simulator alone yields empty state.
#
# Usage: capture_watch_screenshots.sh [set-name] [locale] [apple-locale] [region]
#   capture_watch_screenshots.sh                      (en, uses the first active pair)
#   capture_watch_screenshots.sh watch-hi hi hi_IN IN
set -euo pipefail

SET_NAME="${1:-watch}"
LOCALE="${2:-en}"
APPLE_LOCALE="${3:-en_US}"
REGION="${4:-US}"

APP_ID="com.enerjiktech.vittora"
WATCH_APP_ID="com.enerjiktech.vittora.watchkitapp"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/Docs/Store/screenshots/$SET_NAME"
DERIVED="${DERIVED_DIR:-$ROOT/.build/screenshots}"

mkdir -p "$OUT"

# WATCH_DEVICE picks which paired watch to shoot, because App Store Connect has
# a slot PER WATCH SIZE and they are not interchangeable: Ultra 3 wants
# 422x514, the Series 46mm 416x496. Uploading one into the other's slot is
# rejected outright. Defaults to Ultra 3, which is the size ASC shows first.
PAIR_INFO=$(WANT="${WATCH_DEVICE:-Ultra 3}" xcrun simctl list pairs -j | python3 -c "
import json,os,sys
want=os.environ.get('WANT','Ultra 3')
pairs=json.load(sys.stdin)['pairs']
# 'state' reads '(active, disconnected)', not 'active'.
cands=[p for p in pairs.values() if 'active' in p.get('state','')]
if not cands: sys.exit('no active watch/phone pair')
match=[p for p in cands if want.lower() in p['watch']['name'].lower()]
if not match:
    names=', '.join(sorted({p['watch']['name'] for p in cands}))
    sys.exit(f'no active pair whose watch matches {want!r}. Available: {names}')
p=match[0]
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

# One shot per screen. simctl can screenshot a watch but cannot tap it or open
# a URL on it, so the app takes --ui-test-watch-screen to launch straight into
# the screen we want. Without it the gallery could only ever show the
# dashboard, which is why all three previous watch captures were identical.
NAME=$(echo "$WATCH_NAME" | tr 'A-Z' 'a-z' | sed -E 's/apple_watch_//; s/[()]//g; s/_+/-/g')

# Phone once. The snapshot travels over WCSession as an application context,
# which the watch caches and replays on activation — so relaunching the watch
# app keeps its data and the phone does not need restarting per screen.
SIMCTL_CHILD_UITEST_DEMO_REGION="${REGION:-US}" \
SIMCTL_CHILD_UITEST_DEMO_MONTHS="${DEMO_MONTHS:-12}" \
  xcrun simctl launch "$PAIR_PHONE" "$APP_ID" --uitesting --ui-test-seed-demo \
    -AppleLanguages "($LOCALE)" -AppleLocale "$APPLE_LOCALE" >/dev/null
sleep 20

first=1
for screen in dashboard recent quick-expense; do
  # Terminate and let it settle before relaunching. `simctl launch` on a
  # process that is still alive just foregrounds it and silently DISCARDS the
  # new arguments, which is why every screen came out as the dashboard.
  xcrun simctl terminate "$PAIR_WATCH" "$WATCH_APP_ID" 2>/dev/null || true
  sleep 4
  xcrun simctl launch "$PAIR_WATCH" "$WATCH_APP_ID" "--ui-test-watch-screen=$screen" \
    -AppleLanguages "($LOCALE)" -AppleLocale "$APPLE_LOCALE" >/dev/null
  # The first launch of a run also waits on the initial WCSession handshake,
  # which is slower than the cached-context replay every later launch gets.
  # An 18s wait caught the dashboard mid-handshake and captured
  # "Waiting for iPhone…" instead of the data.
  if [ "$first" = 1 ]; then sleep 30; first=0; else sleep 18; fi
  xcrun simctl io "$PAIR_WATCH" screenshot --type=png "$OUT/watch-$NAME-$screen.png"
  echo "    watch-$NAME-$screen.png"
done

xcrun simctl status_bar "$PAIR_WATCH" clear 2>/dev/null || true
echo "==> raw watch capture in $OUT"
