#!/bin/bash
# Write every synced record type and field into the CloudKit DEVELOPMENT schema,
# so "Deploy Schema Changes" carries all of it to Production (RELEASE_CHECKLIST §3).
#
# Builds the macOS Debug app, signed — Debug Mac builds carry no
# icloud-container-environment entitlement, so CloudKit is Development — and runs
# it with --initialize-cloudkit-schema (Vittora/App/CloudKitSchemaInitializer.swift).
# Needs this Mac signed in to an iCloud account. Deploys nothing.
#
# Build signed: an unsigned build has no CloudKit entitlement at all.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DERIVED="${DERIVED_DIR:-$ROOT/.build/cloudkit-schema}"
APP="$DERIVED/Build/Products/Debug/Vittora.app"

echo "==> building macOS Debug app (signed)"
xcodebuild -project "$ROOT/Vittora.xcodeproj" -scheme Vittora \
  -destination "platform=macOS" -derivedDataPath "$DERIVED" \
  -configuration Debug -quiet build

OUTPUT="$(mktemp -t ckschema)"
ENTITLEMENTS="$(mktemp -t ckschema-entitlements)"
trap 'rm -f "$OUTPUT" "$ENTITLEMENTS"' EXIT

# Never write sample records into Production, and fail clearly on an unsigned build.
codesign -d --entitlements - --xml "$APP" >"$ENTITLEMENTS" 2>/dev/null || true
entitlement() { /usr/libexec/PlistBuddy -c "Print :$1" "$ENTITLEMENTS" 2>/dev/null || true; }
if [ -z "$(entitlement com.apple.developer.icloud-container-identifiers)" ]; then
  echo "error: $APP has no iCloud entitlement — it must be built signed" >&2
  exit 1
fi
environment="$(entitlement com.apple.developer.icloud-container-environment)"
if [ -n "$environment" ] && [ "$environment" != "Development" ]; then
  echo "error: $APP targets CloudKit $environment; this script only writes to Development" >&2
  exit 1
fi

echo "==> initializing the Development schema"
app_status=0
"$APP/Contents/MacOS/Vittora" --initialize-cloudkit-schema >"$OUTPUT" 2>&1 || app_status=$?
grep "^CKSCHEMA:" "$OUTPUT" || true

if [ "$app_status" -ne 0 ] \
  || ! grep -q "^CKSCHEMA: OK — SwiftData:" "$OUTPUT" \
  || ! grep -q "^CKSCHEMA: OK — household:" "$OUTPUT"; then
  echo "error: schema initialization failed (exit $app_status); full output:" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

echo "==> done. Next: CloudKit Console → Development → Deploy Schema Changes, and diff every field (RELEASE_CHECKLIST §3)."
