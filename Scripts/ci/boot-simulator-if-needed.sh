#!/usr/bin/env bash
# Boot the simulator referenced by an xcodebuild destination (id=UUID).
set -euo pipefail

DEST="${1:?destination string required}"
UDID="${DEST#*id=}"
UDID="${UDID%%,*}"

if [[ -z "$UDID" || "$UDID" == "$DEST" ]]; then
  echo "error: could not parse simulator UDID from: $DEST" >&2
  exit 1
fi

state="$(xcrun simctl list devices | grep "$UDID" | grep -Eo '\([^)]+\)' | tail -1 | tr -d '()')"
if [[ "$state" == "Booted" ]]; then
  echo "Simulator $UDID already booted"
  exit 0
fi

echo "Booting simulator $UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
