#!/bin/bash
# Marketing screenshots of the Mac app, light and dark — every sidebar section
# and every report, on the App Store showcase data (US, USD).
#
# There is no macOS simulator and XCUITest input needs an Accessibility grant, so
# screens are reached with launch flags alone (UITEST_INITIAL_TAB and
# --ui-test-open-url deep links) and each window is captured with screencapture.
# Needs an unlocked screen and a signed build (see capture_mac_screenshots.sh).
#
# Usage: capture_marketing_mac.sh <out-root> [light|dark|all]
set -euo pipefail

OUT_ROOT="$(cd "${1:?output root, e.g. ../Marketing/Screenshots}" && pwd)"
APPEARANCES="${2:-all}"
[ "$APPEARANCES" = all ] && APPEARANCES="light dark"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DERIVED="${DERIVED_DIR:-$ROOT/.build/screenshots-mac}"
APP="$DERIVED/Build/Products/Debug/Vittora.app"
MAC_APP_ID="com.enerjiktech.vittora"

echo "==> building macOS app"
xcodebuild -project "$ROOT/Vittora.xcodeproj" -scheme Vittora \
  -destination "platform=macOS" -derivedDataPath "$DERIVED" \
  -configuration Debug build >/dev/null

WINDOW_ID_SWIFT="$(mktemp -t vittora-winid).swift"
cat > "$WINDOW_ID_SWIFT" <<'SWIFT'
import CoreGraphics
import Foundation
guard let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
) as? [[String: Any]] else { exit(1) }
let best = windows
    .filter { ($0[kCGWindowOwnerName as String] as? String) == "Vittora" }
    .compactMap { w -> (Int, Double)? in
        guard let id = w[kCGWindowNumber as String] as? Int,
              let b = w[kCGWindowBounds as String] as? [String: Any],
              let width = b["Width"] as? Double, let height = b["Height"] as? Double,
              width > 400, height > 300 else { return nil }
        return (id, width * height)
    }
    .max { $0.1 < $1.1 }
guard let best else { exit(2) }
print(best.0)
SWIFT

# tab|deep-link or -|NN-area-screen|extra flag
SHOTS=(
  "dashboard|-|01-dashboard-overview|"
  "transactions|-|03-transactions-list-and-detail|--ui-test-select-first-transaction"
  "budgets|-|06-budgets-monthly-budgets|"
  "reports|-|10-reports-all-reports|"
  "reports|vittora://report/monthly|11-reports-monthly-overview|"
  "reports|vittora://report/category|12-reports-category-breakdown|"
  "reports|vittora://report/trends|13-reports-spending-trends|"
  "reports|vittora://report/cashFlow|14-reports-cash-flow|"
  "reports|vittora://report/cashFlowForecast|15-reports-cash-flow-forecast|"
  "reports|vittora://report/annual|16-reports-annual-summary|"
  "reports|vittora://report/netWorth|17-reports-net-worth-history|"
  "reports|vittora://report/subscriptionAudit|18-reports-subscription-audit|"
  "reports|vittora://report/fiftyThirtyTwenty|19-reports-50-30-20-budget-rule|"
  # Emergency Fund is left out: the seed counts no account toward the fund and
  # there is no input on the Mac to count one, so it would read "0.0 months".
  "reports|vittora://report/healthScore|21-reports-financial-health-score|"
  "reports|vittora://report/spendingOutlook|22-reports-spending-outlook-and-what-if|"
  "reports|vittora://report/yearInReview|23-reports-year-in-review|"
  "reports|vittora://report/custom|24-reports-custom-report-builder|"
  "savings|-|30-savings-goals|"
  "debt|-|32-debt-ledger|"
  "splits|-|35-splits-groups|"
  "tax|-|37-tax-estimator|"
  "settings|-|60-settings-overview|"
)

for appearance in $APPEARANCES; do
  folder="Mac/$(tr '[:lower:]' '[:upper:]' <<< "${appearance:0:1}")${appearance:1}"
  out="$OUT_ROOT/$folder"
  mkdir -p "$out"
  echo "==> mac $appearance -> $out"
  for entry in "${SHOTS[@]}"; do
    IFS='|' read -r tab url name extra <<< "$entry"
    if [ -n "${ONLY:-}" ] && [ "$name" != "$ONLY" ]; then continue; fi
    route_arg=""; [ "$url" != "-" ] && route_arg="--ui-test-open-url=$url"
    pkill -f "$APP/Contents/MacOS/Vittora" >/dev/null 2>&1 || true
    sleep 2
    # Through `open`: a directly exec'd binary gets no GUI session and no window.
    open -n \
      --env UITEST_INITIAL_TAB="$tab" --env UITEST_DEMO_REGION=US --env UITEST_DEMO_MONTHS=12 \
      -a "$APP" --args --uitesting --ui-test-seed-demo --ui-test-pro --ui-test-user-name=Alex \
      --ui-test-appearance="$appearance" $route_arg $extra
    WIN_ID=""
    for _ in $(seq 1 30); do
      WIN_ID="$(swift "$WINDOW_ID_SWIFT" 2>/dev/null || true)"
      [ -n "$WIN_ID" ] && break
      sleep 1
    done
    if [ -z "$WIN_ID" ]; then echo "    !! no window for $name — skipped"; continue; fi
    sleep 12   # async seeding, then report aggregates reload
    # Bring it forward: an inactive window renders its sidebar selection and
    # accents washed out, which is not how the app looks in use.
    osascript -e 'tell application "Vittora" to activate' >/dev/null 2>&1 || true
    sleep 1
    WIN_ID="$(swift "$WINDOW_ID_SWIFT" 2>/dev/null || true)"
    screencapture -x -o -l"$WIN_ID" -t png "$out/mac-$appearance-$name.png"
    echo "    mac-$appearance-$name.png"
  done
done
pkill -f "$APP/Contents/MacOS/Vittora" >/dev/null 2>&1 || true
rm -f "$WINDOW_ID_SWIFT"
