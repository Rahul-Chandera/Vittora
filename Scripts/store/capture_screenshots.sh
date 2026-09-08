#!/bin/bash
# Capture raw App Store screenshots from a simulator, one locale at a time.
#
# Everything here rides on flags the app already has for UI testing — no
# production code exists just to make screenshots:
#   --uitesting --ui-test-seed-demo   seed the showcase dataset
#   UITEST_DEMO_REGION=US|IN          currency + payee set
#   UITEST_INITIAL_TAB=<AppTab raw>   open straight to a tab, no tapping
#   vittora://report/<ReportType>     deep-link into a specific report
#
# Usage: capture_screenshots.sh <set-name> <device-name> [locale] [region]
#   capture_screenshots.sh iphone-69 "iPhone 17 Pro Max"
#   capture_screenshots.sh iphone-69-hi "iPhone 17 Pro Max" hi hi_IN IN
set -euo pipefail

SET_NAME="${1:?set name, e.g. iphone-69}"
DEVICE="${2:?simulator device name}"
LOCALE="${3:-en}"
APPLE_LOCALE="${4:-en_US}"
REGION="${5:-US}"

APP_ID="com.enerjiktech.vittora"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/Docs/Store/screenshots/$SET_NAME"
DERIVED="${DERIVED_DIR:-$ROOT/.build/screenshots}"

mkdir -p "$OUT"

# ---- resolve + boot the simulator -------------------------------------------
UDID=$(xcrun simctl list devices available -j \
  | python3 -c "
import json,sys
name=sys.argv[1]
for runtime, devs in json.load(sys.stdin)['devices'].items():
    for d in devs:
        if d['name'] == name:
            print(d['udid']); sys.exit(0)
sys.exit('no available simulator named ' + name)
" "$DEVICE")

echo "==> $SET_NAME on $DEVICE ($UDID), locale=$LOCALE region=$REGION"

# Erase, don't just boot. SpringBoard state outlives the app: a stray system
# alert (or a previous locale, or a half-seeded store) survives terminate and
# relaunch and lands in the middle of a capture.
if [ "${KEEP_DEVICE:-0}" != "1" ]; then
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID"
fi
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b

# ---- build + install --------------------------------------------------------
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Vittora.app"
# Always build. This used to be `if [ ! -d "$APP" ]`, which meant the first
# capture compiled the current source and every later one silently reused that
# binary — so re-running after a colour or layout change produced screenshots
# of the OLD build, with nothing in the output saying so. xcodebuild is
# incremental, so when nothing changed this costs a few seconds and still only
# builds once across all the sets.
echo "==> building (incremental; guarantees the captures match the working tree)"
xcodebuild -project "$ROOT/Vittora.xcodeproj" -scheme Vittora \
  -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" \
  -configuration Debug build >/dev/null
xcrun simctl install "$UDID" "$APP"

# A clean status bar. Real captures show carrier text and a 63% battery, which
# reads as a screenshot of someone's phone rather than a product shot.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

# ---- capture ---------------------------------------------------------------
# tab|url|output-name  — url is "-" when the tab alone is the screen.
# Routes go through --ui-test-open-url, not `simctl openurl`: the latter makes
# SpringBoard show an "Open in Vittora?" alert, which lands in the capture.
# A fourth field marks slots that hide the floating add button. It overlaps a
# transaction amount on the dashboard, which reads fine in use — you scroll and
# it moves — but not in a still.
SHOTS=(
  "dashboard|-|01-dashboard|hide-fab"
  "transactions|-|02-transactions"
  "budgets|-|03-budgets"
  # Savings is NOT capturable: AppTabView routes overflow tabs (savings/debt/
  # splits/tax/settings) to the More hub root by design, so the capture would
  # show a menu under a "savings goals" headline. 50/30/20 deep-links properly.
  "reports|vittora://report/fiftyThirtyTwenty|04-fiftythirtytwenty"
  "reports|-|05-reports"
  "reports|vittora://report/yearInReview|06-yearinreview"
)

for entry in "${SHOTS[@]}"; do
  IFS='|' read -r tab url name flags <<< "$entry"
  # ONLY=04-fiftythirtytwenty re-shoots a single slot without a full pass.
  if [ -n "${ONLY:-}" ] && [ "$name" != "$ONLY" ]; then continue; fi

  # A plain string, not an array: bash 3.2 with `set -u` errors on "${a[@]}"
  # when the array is empty, and these URLs never contain spaces.
  route_arg=""
  [ "$url" != "-" ] && route_arg="--ui-test-open-url=$url"

  fab_arg=""
  [ "${flags:-}" = "hide-fab" ] && fab_arg="--ui-test-hide-quick-entry"

  xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1 || true
  # Relaunching per screen costs a few seconds but removes every ordering
  # dependency — a bad capture can be re-run alone.
  SIMCTL_CHILD_UITEST_INITIAL_TAB="$tab" \
  SIMCTL_CHILD_UITEST_DEMO_REGION="$REGION" \
  SIMCTL_CHILD_UITEST_DEMO_MONTHS="${DEMO_MONTHS:-12}" \
    xcrun simctl launch "$UDID" "$APP_ID" \
      --uitesting --ui-test-seed-demo --ui-test-appearance="${APPEARANCE:-light}" $route_arg $fab_arg \
      -AppleLanguages "($LOCALE)" -AppleLocale "$APPLE_LOCALE" >/dev/null

  sleep 12  # seeding is async (a year of history), and report aggregates
            # reload only after it notifies

  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png"
  echo "    $name.png"
done

xcrun simctl status_bar "$UDID" clear
xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1 || true
echo "==> raw captures in $OUT"
