#!/bin/bash
# Capture raw macOS App Store screenshots.
#
# Runs the real Mac app on this host (there is no macOS simulator) and captures
# its window with transparent rounded corners, which is what make_marketing.py's
# compose_mac expects. Same launch flags as the iOS capture.
#
# Steals focus while it runs — the window has to be on screen to be captured.
#
# Usage: capture_mac_screenshots.sh [set-name] [locale] [apple-locale] [region]
set -euo pipefail

MAC_APP_ID="${MAC_APP_ID:-com.enerjiktech.vittora}"
SET_NAME="${1:-mac}"
LOCALE="${2:-en}"
APPLE_LOCALE="${3:-en_US}"
REGION="${4:-US}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORE_ROOT="${STORE_ROOT:-$(cd "$ROOT/.." && pwd)/Marketing/AppStore}"
OUT="$STORE_ROOT/raw/$SET_NAME"
DERIVED="${DERIVED_DIR:-$ROOT/.build/screenshots-mac}"
APP="$DERIVED/Build/Products/Debug/Vittora.app"

mkdir -p "$OUT"

# Always build — a `[ ! -d "$APP" ]` guard here meant a re-capture after a
# code change silently reused the previous binary. xcodebuild is incremental.
echo "==> building macOS app"
xcodebuild -project "$ROOT/Vittora.xcodeproj" -scheme Vittora \
  -destination "platform=macOS" -derivedDataPath "$DERIVED" \
  -configuration Debug build >/dev/null

# Window id for `screencapture -l`. No pyobjc on this machine, so ask
# CoreGraphics directly through swift rather than adding a dependency.
WINDOW_ID_SWIFT="$(mktemp -t vittora-winid).swift"
cat > "$WINDOW_ID_SWIFT" <<'SWIFT'
import CoreGraphics
import Foundation

let owner = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Vittora"
guard let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
) as? [[String: Any]] else { exit(1) }

// Largest on-screen window owned by the app: skips menu-bar and helper windows.
let best = windows
    .filter { ($0[kCGWindowOwnerName as String] as? String) == owner }
    .compactMap { w -> (Int, Double)? in
        guard let id = w[kCGWindowNumber as String] as? Int,
              let b = w[kCGWindowBounds as String] as? [String: Any],
              let width = b["Width"] as? Double, let height = b["Height"] as? Double,
              width > 400, height > 300
        else { return nil }
        return (id, width * height)
    }
    .max { $0.1 < $1.1 }

guard let best else { exit(2) }
print(best.0)
SWIFT

resolve_window_id() {
  swift "$WINDOW_ID_SWIFT" Vittora 2>/dev/null || true
}

# Same slot names as StoreGalleryUITests, so make_marketing.py frames both with
# the same headlines. No 04-household on Mac: it is reached by a click, and this
# script cannot click (UI input needs Accessibility permission). The sidebar
# makes Tax a plain tab here, so it needs no click.
SHOTS=(
  "dashboard|-|01-dashboard"
  "transactions|-|02-transactions"
  "budgets|-|03-budgets"
  "tax|-|05-tax"
  "reports|vittora://report/healthScore|06-healthscore"
  "reports|vittora://report/netWorth|07-networth"
  "reports|vittora://report/cashFlowForecast|08-cashflowforecast"
  "reports|vittora://report/monthly|09-reports"
  "reports|vittora://report/yearInReview|10-yearinreview"
)

echo "==> $SET_NAME on this Mac, locale=$LOCALE region=$REGION"

for entry in "${SHOTS[@]}"; do
  IFS='|' read -r tab url name <<< "$entry"
  # ONLY=06-healthscore re-shoots a single slot without a full pass.
  if [ -n "${ONLY:-}" ] && [ "$name" != "$ONLY" ]; then continue; fi

  route_arg=""
  [ "$url" != "-" ] && route_arg="--ui-test-open-url=$url"

  # The locale goes FIRST in the launch arguments. macOS reads "-key value"
  # pairs from argv into the argument defaults domain, pairing from the start,
  # so any odd number of flags before -AppleLanguages shifts the pairing: the
  # language is never applied and the app launches with no window. That was
  # the long-standing "-AppleLanguages + --ui-test-open-url = no window" quirk.
  # It was worked around by writing the language into the app's defaults, but
  # the app is sandboxed and macOS now refuses writes into its container
  # ("Operation not permitted"), so that write failed silently and the first
  # 1.8.0 hi/es Mac captures came out in English.
  locale_args=""
  [ "$LOCALE" != "en" ] && locale_args="-AppleLanguages ($LOCALE) -AppleLocale $APPLE_LOCALE"

  # Wide layout is list + detail; with no selection the detail pane is an empty
  # placeholder filling half the window.
  select_arg=""
  [ "$name" = "02-transactions" ] && select_arg="--ui-test-select-first-transaction"

  pkill -f "$APP/Contents/MacOS/Vittora" >/dev/null 2>&1 || true
  sleep 2

  # Kill by this build's path, never `pkill -x Vittora`: that name also matches
  # the Vittora app inside every running iOS simulator, and killed the store
  # captures running alongside (1.8.0).

  # Launch through `open`, not by exec'ing the binary. A directly-exec'd .app
  # binary gets no proper GUI session from this shell and never creates a
  # window — CGWindowList shows the process running with zero windows, and
  # nothing is logged, which is a confusing way to fail.
  open -n \
    --env UITEST_INITIAL_TAB="$tab" \
    --env UITEST_DEMO_REGION="$REGION" \
    --env UITEST_DEMO_MONTHS="${DEMO_MONTHS:-12}" \
    -a "$APP" --args $locale_args --uitesting --ui-test-seed-demo --ui-test-appearance="${APPEARANCE:-light}" \
      --ui-test-pro --ui-test-user-name=Alex $route_arg $select_arg

  # Poll for the window rather than guessing a sleep: launch time varies a lot
  # between a plain tab and one that also resolves a deep link, and a fixed wait
  # silently produced "no window found" for exactly the deep-linked shots.
  WIN_ID=""
  for _ in $(seq 1 30); do
    WIN_ID="$(resolve_window_id)"
    [ -n "$WIN_ID" ] && break
    sleep 1
  done
  if [ -z "$WIN_ID" ]; then
    echo "    !! no window found for $name — skipping"
    continue
  fi
  sleep 12   # async seeding, then the report aggregates reload after it notifies
  WIN_ID="$(resolve_window_id)"   # re-resolve: the window can be rebuilt on navigation
  # -o drops the drop shadow so the corners stay transparent; compose_mac
  # composites its own shadow.
  screencapture -x -o -l"$WIN_ID" -t png "$OUT/$name.png"
  echo "    $name.png"
done

pkill -f "$APP/Contents/MacOS/Vittora" >/dev/null 2>&1 || true
rm -f "$WINDOW_ID_SWIFT"
echo "==> raw captures in $OUT"
