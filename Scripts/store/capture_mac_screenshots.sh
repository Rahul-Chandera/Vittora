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

SET_NAME="${1:-mac}"
LOCALE="${2:-en}"
APPLE_LOCALE="${3:-en_US}"
REGION="${4:-US}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/Docs/Store/screenshots/$SET_NAME"
DERIVED="${DERIVED_DIR:-$ROOT/.build/screenshots-mac}"
APP="$DERIVED/Build/Products/Debug/Vittora.app"
BIN="$APP/Contents/MacOS/Vittora"

mkdir -p "$OUT"

if [ ! -d "$APP" ]; then
  echo "==> building macOS app"
  xcodebuild -project "$ROOT/Vittora.xcodeproj" -scheme Vittora \
    -destination "platform=macOS" -derivedDataPath "$DERIVED" \
    -configuration Debug build >/dev/null
fi

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

SHOTS=(
  "dashboard|-|01-dashboard"
  "transactions|-|02-transactions"
  "budgets|-|03-budgets"
  # Savings is NOT capturable: AppTabView routes overflow tabs (savings/debt/
  # splits/tax/settings) to the More hub root by design, so the capture would
  # show a menu under a "savings goals" headline. 50/30/20 deep-links properly.
  "reports|vittora://report/fiftyThirtyTwenty|04-fiftythirtytwenty"
  "reports|-|05-reports"
  "reports|vittora://report/yearInReview|06-yearinreview"
)

echo "==> $SET_NAME on this Mac, locale=$LOCALE region=$REGION"

for entry in "${SHOTS[@]}"; do
  IFS='|' read -r tab url name <<< "$entry"
  # ONLY=04-fiftythirtytwenty re-shoots a single slot without a full pass.
  if [ -n "${ONLY:-}" ] && [ "$name" != "$ONLY" ]; then continue; fi

  route_arg=""
  [ "$url" != "-" ] && route_arg="--ui-test-open-url=$url"

  pkill -x Vittora >/dev/null 2>&1 || true
  sleep 2

  UITEST_INITIAL_TAB="$tab" \
  UITEST_DEMO_REGION="$REGION" \
  UITEST_DEMO_MONTHS="${DEMO_MONTHS:-12}" \
    "$BIN" --uitesting --ui-test-seed-demo $route_arg \
      -AppleLanguages "($LOCALE)" -AppleLocale "$APPLE_LOCALE" \
      >/dev/null 2>&1 &

  sleep 14   # launch + async seeding + report aggregate reload

  WIN_ID="$(resolve_window_id)"
  if [ -z "$WIN_ID" ]; then
    echo "    !! no window found for $name — skipping"
    continue
  fi
  # -o drops the drop shadow so the corners stay transparent; compose_mac
  # composites its own shadow.
  screencapture -x -o -l"$WIN_ID" -t png "$OUT/$name.png"
  echo "    $name.png"
done

pkill -x Vittora >/dev/null 2>&1 || true
rm -f "$WINDOW_ID_SWIFT"
echo "==> raw captures in $OUT"
