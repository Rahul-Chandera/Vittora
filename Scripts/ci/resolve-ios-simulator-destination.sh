#!/usr/bin/env bash
# Prints an xcodebuild -destination value for the newest available iPhone simulator
# whose runtime meets MIN_IOS_* (defaults match Vittora deployment target).
set -euo pipefail

MIN_IOS_MAJOR="${MIN_IOS_MAJOR:-26}"
MIN_IOS_MINOR="${MIN_IOS_MINOR:-0}"

python3 - "$MIN_IOS_MAJOR" "$MIN_IOS_MINOR" <<'PY'
import json
import subprocess
import sys

min_major = int(sys.argv[1])
min_minor = int(sys.argv[2])

raw = subprocess.run(
    ["xcrun", "simctl", "list", "devices", "available", "-j"],
    capture_output=True,
    text=True,
)
if raw.returncode != 0:
    print("error: xcrun simctl failed — is CoreSimulator installed and up to date?", file=sys.stderr)
    if raw.stderr:
        print(raw.stderr, file=sys.stderr)
    sys.exit(raw.returncode)

data = json.loads(raw.stdout)

candidates: list[tuple[tuple[int, int, int], str, str]] = []

for runtime_id, devices in data.get("devices", {}).items():
    if "iOS" not in runtime_id or "SimRuntime" not in runtime_id:
        continue
    suffix = runtime_id.rsplit("iOS-", 1)[-1]
    parts = suffix.split("-")
    if len(parts) < 2:
        continue
    try:
        major, minor = int(parts[0]), int(parts[1])
    except ValueError:
        continue
    patch = int(parts[2]) if len(parts) > 2 else 0
    if (major, minor) < (min_major, min_minor):
        continue
    for device in devices:
        if not device.get("isAvailable"):
            continue
        name = device.get("name", "")
        udid = device.get("udid")
        if "iPhone" not in name or not udid:
            continue
        candidates.append(((major, minor, patch), name, udid))

if not candidates:
    print(
        f"error: no iPhone simulator found for iOS >={min_major}.{min_minor}",
        file=sys.stderr,
    )
    subprocess.run(["xcrun", "simctl", "list", "devices", "available"], check=False)
    sys.exit(1)

candidates.sort(key=lambda item: item[0], reverse=True)
(_, _, _), name, udid = candidates[0]
print(f"platform=iOS Simulator,id={udid}", end="")
sys.stderr.write(f"Selected simulator: {name} ({udid})\n")
PY
