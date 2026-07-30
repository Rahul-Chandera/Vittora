#!/bin/bash
# Fail when a user-facing string is missing from Localizable.xcstrings, or is in
# it but untranslated.
#
# Why this exists: `SWIFT_EMIT_LOC_STRINGS = YES` is already set on every
# shipping target, so the compiler *does* extract strings — but only Xcode's IDE
# writes the updated catalogue back to disk. `xcodebuild` does not. So a feature
# built and merged from the command line ships with its strings absent from the
# catalogue, while the catalogue still reports 100% translated, because it only
# knows about the keys it already has. That is how 50/30/20, Emergency Fund,
# quiet hours, appearance and Year in Review shipped English-only under hi/es.
#
# The source of truth is the compiler's own `.stringsdata`, not a grep. A regex
# over `String(localized: "…")` cannot see interpolated strings (they become
# %@/%lld keys) or bare SwiftUI `Text("literal")`, and both were a large part of
# the original gap.
#
# Usage: check-localization-coverage.sh [--list]
#   Requires a prior build. Set DERIVED to point at its derived data;
#   defaults to the same path `make build-ios` uses.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DERIVED="${DERIVED:-$ROOT/.build-ci}"
LIST="${1:-}"

if ! find "$DERIVED" -name '*.stringsdata' -print -quit 2>/dev/null | grep -q .; then
  echo "no .stringsdata under $DERIVED — build first (make build-ios), or set DERIVED" >&2
  exit 2
fi

python3 - "$ROOT" "$DERIVED" "$LIST" <<'PY'
import glob, json, os, sys

root, derived, list_flag = sys.argv[1], sys.argv[2], (len(sys.argv) > 3 and sys.argv[3] == "--list")

extracted = {}
for path in glob.glob(os.path.join(derived, "**", "*.stringsdata"), recursive=True):
    try:
        data = json.load(open(path))
    except Exception:
        continue
    for table, entries in (data.get("tables") or {}).items():
        if table != "Localizable":
            continue
        for entry in entries:
            extracted.setdefault(entry["key"], set()).add(
                os.path.basename(path)[: -len(".stringsdata")]
            )

catalog = json.load(open(os.path.join(root, "Vittora", "Localizable.xcstrings")))["strings"]
LANGS = ("hi", "es")

missing = sorted(set(extracted) - set(catalog))
untranslated = {
    lang: sorted(
        k for k, v in catalog.items()
        # shouldTranslate:false is the catalogue's own "don't translate this"
        # marker — #Preview and test-fixture strings carry it.
        if v.get("shouldTranslate", True) and lang not in v.get("localizations", {})
    )
    for lang in LANGS
}

print(f"extracted keys                 : {len(extracted)}")
print(f"catalogue keys                 : {len(catalog)}")
print(f"extracted but not in catalogue : {len(missing)}")
for lang in LANGS:
    print(f"in catalogue, no {lang} translation : {len(untranslated[lang])}")

if list_flag:
    for key in missing:
        print(f"  MISSING  {key!r}   [{', '.join(sorted(extracted[key]))}]")
    for lang in LANGS:
        for key in untranslated[lang]:
            print(f"  NO-{lang.upper()}   {key!r}")

if missing or any(untranslated[l] for l in LANGS):
    print(
        "\nFAIL: build the app, then add the new keys to Localizable.xcstrings\n"
        "and translate them. Opening the project in Xcode and building once will\n"
        "add the keys for you; `xcodebuild` alone will NOT update the catalogue.\n"
        "Mark preview/fixture strings with \"shouldTranslate\": false instead of\n"
        "translating them. Re-run with --list to see every key."
    )
    sys.exit(1)
PY
