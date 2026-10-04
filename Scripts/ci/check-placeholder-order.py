#!/usr/bin/env python3
"""Fail when a translation's format placeholders do not match the source key's.

Why this exists: #257 crashed on Hindi. The translation had reordered `%@` and
`%lld` relative to the English key, so `String(format:)` read a pointer as an
integer. The existing localization gate cannot see this — it checks that a key
is *present* and *translated*, not that the translation is format-compatible.

Two distinct failures are caught:

  count    a placeholder was dropped or invented. Always a crash or a literal
           "%@" on screen.

  order    the same placeholders appear in a different sequence. This is the
           #257 case and the dangerous one, because it is invisible to review:
           the translation reads naturally and has the right number of slots.
           The fix is positional specifiers (%1$@, %2$lld), which this check
           then treats as equivalent to the source order.

Deliberately NOT checked: whether a translation uses positional specifiers when
the source does not. A translation that keeps the natural order needs none, and
requiring them flagged 40+ correct strings on the first run.

Usage: check-placeholder-order.py [--list | --self-test]
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOGUES = [
    ROOT / "Vittora" / "Localizable.xcstrings",
    ROOT / "VittoraWatch" / "Localizable.xcstrings",
]
SOURCE = "en"

# %[positional$][flags][width][.precision][length]conversion, plus xcstrings'
# own `%#@name@` substitution token, which stands in for a plural or device
# variation declared in the entry's "substitutions" table.
SUBSTITUTION = re.compile(r"%(?:(\d+)\$)?#@([^@]+)@")
# No space in the flag class, and a closed set of conversions. Both narrow the
# match away from a LITERAL percent: keys like "50% CGT discount" and "(% a
# year)" are not format strings at all, and a permissive pattern read "% C" and
# "% a" in them as specifiers — 12 false positives on the first run. A real
# specifier here is never separated from its conversion by a space.
SPEC = re.compile(r"%(?:(\d+)\$)?[-+#0]*[\d*]*(?:\.[\d*]+)?(?:hh|h|ll|l|q|L|z|j|t)?([@diufFeEgGsSxXocp%])")


def placeholders(text, substitutions=None):
    """Ordered list of conversions, with positional specifiers applied.

    `%%` is a literal percent, not a placeholder, and is dropped. Note the
    compiler rewrites a literal `%` to `%%` in keys that also carry a
    placeholder, so this is not a rare case.

    A `%#@name@` token resolves to the conversion its substitution declares, so
    a locale that expresses a count as a plural variation still compares equal
    to a source that writes `%lld` inline.
    """
    substitutions = substitutions or {}
    found = []
    index = 0
    # Blank the substitution tokens out before scanning for plain specifiers, or
    # the `@` that closes `%#@name@` is itself read as a conversion.
    def take_substitution(match):
        nonlocal index
        position, name = match.group(1), match.group(2)
        declared = substitutions.get(name, {})
        conversion = str(declared.get("formatSpecifier", "lld"))[-1:] or "d"
        slot = int(position) - 1 if position else declared.get("argNum")
        found.append(((slot - 1 if isinstance(slot, int) and not position else index)
                      if slot is not None else index, conversion))
        index += 1
        return " "

    text = SUBSTITUTION.sub(take_substitution, text)
    for match in SPEC.finditer(text):
        position, conversion = match.group(1), match.group(2)
        if conversion == "%":
            continue
        found.append((int(position) - 1 if position else index, conversion))
        index += 1
    # A positional specifier means the argument order is explicit; sort by it so
    # a reordered-but-positional translation compares equal to the source.
    return [conversion for _, conversion in sorted(found, key=lambda pair: pair[0])]


def value_of(localisation):
    unit = localisation.get("stringUnit")
    if unit:
        return unit.get("value")
    # Plural and device variations hold their forms one level down; check each.
    variations = localisation.get("variations", {})
    forms = []
    for kind in variations.values():
        for form in kind.values():
            nested = value_of(form)
            if isinstance(nested, list):
                forms.extend(nested)
            elif nested is not None:
                forms.append(nested)
    return forms or None


def forms(value):
    return value if isinstance(value, list) else [value]


def self_test():
    """Assert the check fails on the bugs it exists for, and passes on the fixes.

    A gate nobody has seen fail is not evidence. #257 shipped because the
    catalogue looked complete; this asserts the detector itself works.
    """
    cases = [
        # (name, source, translation, substitutions, expected verdict)
        ("#257: %lld reordered ahead of %@",
         "%@ spent over %lld of %lld days.",
         "%lld में से %lld दिनों में %@ खर्च हुआ।", {}, "order"),
        ("#257 fixed with positional specifiers",
         "%@ spent over %lld of %lld days.",
         "%3$lld में से %2$lld दिनों में %1$@ खर्च हुआ।", {}, "ok"),
        ("dropped placeholder",
         "%@ of %@ budgets", "%@ presupuestos", {}, "count"),
        ("invented placeholder",
         "%@ budgets", "%@ de %@ presupuestos", {}, "count"),
        ("same order needs no positional specifiers",
         "%@ of %@ budgets", "%@ de %@ presupuestos", {}, "ok"),
        ("literal percent is not a placeholder",
         "50% CGT discount applied.", "Se aplicó el descuento del 50%.", {}, "ok"),
        ("escaped percent alongside a placeholder",
         "%@. Effective rate %@%%", "%@. Tasa efectiva %@%%", {}, "ok"),
        ("plural substitution matches an inline %lld",
         "%lld overdue debts", "%#@debts@ deudas vencidas",
         {"debts": {"argNum": 1, "formatSpecifier": "lld"}}, "ok"),
    ]

    failures = 0
    for name, source, translation, substitutions, expected in cases:
        want = placeholders(source, substitutions)
        got = placeholders(translation, substitutions)
        if sorted(got) != sorted(want):
            verdict = "count"
        elif got != want:
            verdict = "order"
        else:
            verdict = "ok"
        ok = verdict == expected
        failures += not ok
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")
        if not ok:
            print(f"        expected {expected}, got {verdict}")
            print(f"        source={want} translation={got}")

    print(f"\nself-test: {len(cases) - failures}/{len(cases)} passed")
    return 1 if failures else 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    listing = "--list" in sys.argv
    problems = []
    checked = 0

    for catalogue in CATALOGUES:
        if not catalogue.exists():
            continue
        data = json.loads(catalogue.read_text())
        for key, entry in data.get("strings", {}).items():
            localisations = entry.get("localizations", {})
            source_value = value_of(localisations.get(SOURCE, {})) or key
            source_subs = entry.get("substitutions", {})
            expected = placeholders(forms(source_value)[0], source_subs)
            if not expected:
                continue

            for locale, localisation in localisations.items():
                if locale == SOURCE:
                    continue
                value = value_of(localisation)
                if value is None:
                    continue
                for form in forms(value):
                    checked += 1
                    actual = placeholders(form, source_subs)
                    if sorted(actual) != sorted(expected):
                        problems.append((catalogue.name, locale, key, "count", form))
                    elif actual != expected:
                        problems.append((catalogue.name, locale, key, "order", form))

    print(f"translations checked : {checked}")
    print(f"problems             : {len(problems)}")
    if problems:
        print()
        for catalogue, locale, key, kind, form in problems if listing else problems[:20]:
            print(f"  [{kind}] {catalogue} {locale}")
            print(f"      key: {key}")
            print(f"      got: {form}")
        if not listing and len(problems) > 20:
            print(f"  … and {len(problems) - 20} more (--list for all)")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
