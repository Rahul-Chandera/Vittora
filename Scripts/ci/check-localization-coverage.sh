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
# Scan every platform's build, not just iOS. Strings inside `#if os(macOS)`
# are never compiled by the iOS build, so an iOS-only scan cannot see them at
# all — they are structurally invisible to the gate rather than merely missed.
# That is how "Running on macOS" sat in the catalogue untranslated, and how the
# macOS ShareSheet strings were nearly shipped the same way.
#
# Usage: check-localization-coverage.sh [--list]
#   Requires a prior build. Set DERIVED to its derived data, or to a
#   colon-separated list to span several builds:
#       DERIVED=.build-ios:.build-macos check-localization-coverage.sh
#   Defaults to the single path `make build-ios` uses.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DERIVED="${DERIVED:-$ROOT/.build-ci}"
LIST="${1:-}"

IFS=':' read -r -a DERIVED_PATHS <<< "$DERIVED"

# Every listed path must have been built. A silent skip would turn "the macOS
# build is missing" into a green run, which is the exact failure this gate is
# supposed to close.
for derived_path in "${DERIVED_PATHS[@]}"; do
  if ! find "$derived_path" -name '*.stringsdata' -print -quit 2>/dev/null | grep -q .; then
    echo "no .stringsdata under $derived_path — build it first" >&2
    echo "  .build-ios   comes from make build-ios" >&2
    echo "  .build-macos comes from make build-macos" >&2
    exit 2
  fi
done

python3 - "$ROOT" "$LIST" "${DERIVED_PATHS[@]}" <<'PY'
import glob, json, os, sys

root, list_flag, derived_paths = sys.argv[1], sys.argv[2] == "--list", sys.argv[3:]

# Union across platforms: a key only needs to be reachable from one of them.
extracted = {}
for derived in derived_paths:
    for path in glob.glob(os.path.join(derived, "**", "*.stringsdata"), recursive=True):
        try:
            data = json.load(open(path))
        except Exception:
            continue
        for table, entries in (data.get("tables") or {}).items():
            if table != "Localizable":
                continue
            # Name the platform build directory alongside the source file. One
            # derived path can hold several (a live Debug-iphoneos next to a
            # leftover Debug-iphonesimulator), and a build only refreshes the
            # one it targets. Naming it makes a stale tree obvious instead of
            # looking like a genuine missing key.
            build_dir = next(
                (c for c in path.split(os.sep) if c.startswith(("Debug-", "Release-"))),
                "?",
            )
            for entry in entries:
                extracted.setdefault(entry["key"], set()).add(
                    f"{os.path.basename(path)[: -len('.stringsdata')]} @ {build_dir}"
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

print(f"builds scanned                 : {len(derived_paths)} ({', '.join(derived_paths)})")
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
        "translating them. Re-run with --list to see every key.\n"
        "\n"
        "Seeing a key you already renamed? Check the build dir named beside it.\n"
        "A derived path can hold a stale tree from an earlier build for another\n"
        "platform, which the current build does not refresh. Delete the derived\n"
        "path and rebuild."
    )
    sys.exit(1)
PY
