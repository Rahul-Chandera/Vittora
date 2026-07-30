#!/bin/bash
# Fail when a user-facing string never made it into Localizable.xcstrings.
#
# Why this exists: `SWIFT_EMIT_LOC_STRINGS = YES` is already set on every
# shipping target, so Xcode *does* extract strings — but only the IDE writes the
# updated catalogue back to disk. `xcodebuild` does not. So a feature built and
# merged via CLI/CI ships with its strings absent from the catalogue, and every
# non-English user sees that screen in English while the catalogue still reports
# 100% translated. That is exactly how 50/30/20, Emergency Fund and Year in
# Review shipped English-only under hi and es.
#
# Interpolated literals (String(localized: "Year \(y)")) become %@/%lld keys in
# the catalogue and cannot be matched against raw source, so they are counted
# and reported but never failed on.
#
# Usage: check-localization-coverage.sh [--list]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIST="${1:-}"

python3 - "$ROOT" "$LIST" <<'PY'
import json, os, re, sys

root, list_flag = sys.argv[1], (len(sys.argv) > 2 and sys.argv[2] == "--list")
catalog_path = os.path.join(root, "Vittora", "Localizable.xcstrings")
data = json.load(open(catalog_path))["strings"]
catalog = set(data)

# Only targets that ship. Test targets set SWIFT_EMIT_LOC_STRINGS = NO on purpose.
ROOTS = ["Vittora", "VittoraWidgets", "VittoraWatch", "Packages/VittoraCore/Sources"]
SKIP_DIRS = {"VittoraTests", "VittoraUITests", "UITesting"}
LITERAL = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"')

missing, interpolated = {}, 0
for r in ROOTS:
    for dirpath, dirnames, files in os.walk(os.path.join(root, r)):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in files:
            if not f.endswith(".swift"):
                continue
            path = os.path.join(dirpath, f)
            for lit in LITERAL.findall(open(path, encoding="utf-8").read()):
                if "\\(" in lit:
                    interpolated += 1
                elif lit not in catalog:
                    missing.setdefault(lit, set()).add(os.path.relpath(path, root))

# Every key that IS in the catalogue should carry every shipping language.
LANGS = ["hi", "es"]
untranslated = {
    lang: [k for k, v in data.items() if lang not in v.get("localizations", {})]
    for lang in LANGS
}

print(f"catalogue keys                 : {len(catalog)}")
print(f"interpolated literals (skipped): {interpolated}")
print(f"literals missing from catalogue: {len(missing)}")
for lang in LANGS:
    print(f"keys with no {lang} translation    : {len(untranslated[lang])}")

if list_flag:
    by_file = {}
    for lit, paths in missing.items():
        for p in paths:
            by_file.setdefault(p, []).append(lit)
    for p in sorted(by_file, key=lambda k: -len(by_file[k])):
        print(f"\n{p}  ({len(by_file[p])})")
        for lit in sorted(by_file[p]):
            print(f"    {lit}")

failed = bool(missing) or any(untranslated[l] for l in LANGS)
if failed:
    print(
        "\nFAIL: open the project in Xcode and build once — the IDE writes newly\n"
        "extracted strings back into Localizable.xcstrings — then translate the\n"
        "new entries. `xcodebuild` alone will NOT update the catalogue.\n"
        "Re-run with --list to see every missing string."
    )
sys.exit(1 if failed else 0)
PY
