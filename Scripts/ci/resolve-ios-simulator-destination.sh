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

# Deterministic ordering. Sorting by runtime alone leaves every device on the
# newest runtime tied, and the tie was broken by simctl's emission order — so CI
# silently picked a different iPhone model between runs. Accessibility audits are
# device-sensitive (Apple's contrast/Dynamic Type samplers differ by model), so a
# nondeterministic device makes those gates flaky and impossible to reproduce
# locally. Break ties on an explicit model preference, then on name, so the same
# device set always yields the same choice.
MODEL_PREFERENCE = ["iPhone 17 Pro Max", "iPhone 17 Pro", "iPhone 17", "iPhone 16 Pro", "iPhone 16"]

def rank(item):
    runtime, name, _ = item
    try:
        preference = MODEL_PREFERENCE.index(name)
    except ValueError:
        preference = len(MODEL_PREFERENCE)
    # newest runtime first, then preferred model, then name for full determinism
    return (tuple(-part for part in runtime), preference, name)

candidates.sort(key=rank)
(_, _, _), name, udid = candidates[0]
print(f"platform=iOS Simulator,id={udid}", end="")
sys.stderr.write(f"Selected simulator: {name} ({udid})\n")
PY
