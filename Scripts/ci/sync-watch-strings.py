#!/usr/bin/env python3
"""Generate VittoraWatch/Localizable.xcstrings from the app's catalogue.

Why this exists
---------------
The watch app had NO localizations in its bundle — the built VittoraWatch.app
contained no `.lproj` at all, while Vittora.app carried `hi.lproj` and
`es.lproj`. Every one of the watch's user-facing strings was already translated
in `Vittora/Localizable.xcstrings`; the catalogue simply was not a resource of
the watch target, so at runtime the watch fell back to English for Hindi and
Spanish users. Shipped that way in 1.4.0.

`Vittora/` and `VittoraWatch/` are separate file-system synchronized groups, so
a single shared catalogue cannot be a member of both without hand-editing the
project. A per-target String Catalog is Apple's own answer to that, and this
script derives the watch one instead of leaving it to drift by hand.

Keys come from the compiler's `.stringsdata`, never from grepping source — a
regex cannot see interpolated keys (`"Updated \\(relative)"` compiles to
`Updated %@`), which is the same trap that made the 1.4.0 localization audit
report 131 keys against a true 185.

Usage
-----
    Scripts/ci/sync-watch-strings.py                 # regenerate
    Scripts/ci/sync-watch-strings.py --check         # fail if out of date
    DERIVED=.build-ios Scripts/ci/sync-watch-strings.py
"""
import glob
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAIN = os.path.join(ROOT, "Vittora", "Localizable.xcstrings")
WATCH = os.path.join(ROOT, "VittoraWatch", "Localizable.xcstrings")
DERIVED = os.environ.get("DERIVED", ".build-run")


def watch_keys():
    pattern = os.path.join(
        ROOT, DERIVED, "Build", "Intermediates.noindex", "Vittora.build",
        # Debug-watchos from `make build-ios` (the watch app is embedded), or
        # Debug-watchsimulator from a simulator build. Match both.
        "*watch*", "VittoraWatch.build", "**", "*.stringsdata",
    )
    files = glob.glob(pattern, recursive=True)
    if not files:
        sys.exit(
            f"no .stringsdata for the watch target under {DERIVED}.\n"
            "Build VittoraWatch for a watchOS simulator first — this reads the\n"
            "compiler's own extraction, not the source."
        )
    keys = set()
    for path in files:
        try:
            data = json.load(open(path))
        except (json.JSONDecodeError, OSError):
            continue
        for entries in data.get("tables", {}).values():
            for entry in entries:
                key = entry.get("key")
                if key:
                    keys.add(key)
    return keys


def build_catalogue(keys):
    main = json.load(open(MAIN))
    strings = {}
    missing = []
    for key in sorted(keys):
        entry = main["strings"].get(key)
        if entry is None:
            missing.append(key)
            continue
        strings[key] = entry
    if missing:
        sys.exit(
            "these watch strings are not in the app catalogue:\n  "
            + "\n  ".join(repr(k) for k in missing)
            + "\nAdd and translate them there first; this script only copies."
        )
    return {
        "sourceLanguage": main.get("sourceLanguage", "en"),
        "strings": strings,
        "version": main.get("version", "1.0"),
    }


def main():
    check = "--check" in sys.argv
    generated = build_catalogue(watch_keys())
    rendered = json.dumps(generated, ensure_ascii=False, indent=2, sort_keys=True) + "\n"

    if check:
        current = open(WATCH).read() if os.path.exists(WATCH) else ""
        if current != rendered:
            sys.exit(
                "VittoraWatch/Localizable.xcstrings is out of date.\n"
                "Run Scripts/ci/sync-watch-strings.py and commit the result."
            )
        print(f"watch catalogue up to date ({len(generated['strings'])} keys)")
        return

    with open(WATCH, "w") as handle:
        handle.write(rendered)
    langs = set()
    for entry in generated["strings"].values():
        langs |= set(entry.get("localizations", {}))
    print(f"wrote {WATCH} — {len(generated['strings'])} keys, languages: {sorted(langs)}")


if __name__ == "__main__":
    main()
