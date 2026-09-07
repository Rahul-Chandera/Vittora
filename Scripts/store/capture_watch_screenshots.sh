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
# Seeding a year of history before the phone can push anything to the watch.
sleep "${PHONE_SEED_SETTLE:-30}"

first=1
for screen in dashboard recent quick-expense; do
  shot="$OUT/watch-$NAME-$screen.png"
  # dashboard and recent render data pushed from the phone; until the WCSession
  # handshake lands they show "Waiting for iPhone…" / "No recent transactions"
  # instead. That empty state is a much smaller PNG — 14-17KB measured, against
  # 28-39KB once the data arrives — so size is a good enough liveness check.
  # quick-expense is a local form and renders the same either way, so it has no
  # floor. 1.6.0 shipped two empty galleries because this script only ever
  # checked simctl's exit code, which is 0 for a screenshot of a blank screen.
  case "$screen" in
    dashboard|recent) floor=22000 ;;
    *)                floor=0 ;;
  esac

  for attempt in 1 2 3; do
    # Terminate and let it settle before relaunching. `simctl launch` on a
    # process that is still alive just foregrounds it and silently DISCARDS the
    # new arguments, which is why every screen came out as the dashboard.
    xcrun simctl terminate "$PAIR_WATCH" "$WATCH_APP_ID" 2>/dev/null || true
    sleep 4
    xcrun simctl launch "$PAIR_WATCH" "$WATCH_APP_ID" "--ui-test-watch-screen=$screen" \
      -AppleLanguages "($LOCALE)" -AppleLocale "$APPLE_LOCALE" >/dev/null
    # The first launch of a run also waits on the initial WCSession handshake,
    # which is slower than the cached-context replay every later launch gets;
    # a retry is by definition waiting on that same handshake, so it gets the
    # long wait too. Overridable so a slow host can go higher without editing.
    if [ "$first" = 1 ] || [ "$attempt" != 1 ]; then
      sleep "${WATCH_FIRST_SETTLE:-45}"
    else
      sleep "${WATCH_SETTLE:-24}"
    fi
    first=0
    xcrun simctl io "$PAIR_WATCH" screenshot --type=png "$shot"

    size=$(stat -f%z "$shot")
    if [ "$size" -ge "$floor" ]; then
      echo "    watch-$NAME-$screen.png (${size}B)"
      break
    fi
    echo "    watch-$NAME-$screen.png looks empty (${size}B < ${floor}B) — attempt $attempt/3"
    if [ "$attempt" = 3 ]; then
      echo "!!! $screen never received phone data after 3 attempts." >&2
      echo "!!! Not shipping a blank gallery; re-run, or raise WATCH_FIRST_SETTLE." >&2
      exit 1
    fi
  done
done

xcrun simctl status_bar "$PAIR_WATCH" clear 2>/dev/null || true
echo "==> raw watch capture in $OUT"
