#!/usr/bin/env python3
"""Screenshot sets for the App Store custom product pages (Docs/Store/CUSTOM_PRODUCT_PAGES.md).

Each page leads with the screen it is about. A lead slide is framed here with its
own headline, through make_marketing's composers, from either a store-gallery raw
capture or a Marketing/Screenshots capture; the rest of the set reuses the framed
store gallery for that localization, reordered.

Output: <STORE_ROOT>/cpp/<page>/<locale>/<device>/NN-<name>.png, ready to upload.
Headers for each page come from make_header.py, into <page>/<locale>/header.png.
Run make_marketing.py first, so the reused gallery images exist.
"""
import os
import shutil
import tempfile

import make_marketing as mm

SHOTS = os.path.join(os.path.dirname(mm.STORE_ROOT), "Screenshots")
DEVICES = {
    # device: (gallery set suffix, composer)
    "iphone-69": ("iphone-69", lambda r, o, c: mm.compose_phone(r, o, c, 1320, 2868)),
    "iphone-65": ("iphone-65", lambda r, o, c: mm.compose_phone(r, o, c, 1284, 2778)),
    "ipad-13":   ("ipad-13",   mm.compose_pad),
    # The custom page shows an iPhone Duo tab of its own. Lead slides from
    # Marketing/Screenshots are iPhone captures, framed on the Duo canvas: there
    # are no Duo captures of the UK, Canada, Australia or English-India estimators.
    "duo-outer": ("duo-outer", lambda r, o, c: mm.compose_phone(r, o, c, 1398, 2034)),
    "duo-inner": ("duo-inner", lambda r, o, c: mm.compose_phone(r, o, c, 2007, 2853)),
}
# The gallery set for a localization: "" for en-US, "-in", "-hi", "-es".
SUFFIX = {"en-US": "", "en-IN": "-in", "hi": "-hi", "es": "-es"}
COPY_LOCALE = {"en-US": "en", "en-IN": "en", "hi": "hi", "es": "es"}


def marketing(device, number_name):
    folder = "iPad/Light/ipad" if device == "ipad-13" else "iPhone/Light/iphone"
    return os.path.join(SHOTS, f"{folder}-light-{number_name}.png")


def gallery_raw(device, locale, slot):
    base = "iphone-69" if device == "iphone-65" else device  # 6.5" reuses 6.9" raws
    return os.path.join(mm.RAW, base + SUFFIX[locale], f"{slot}.png")


# A lead slide: (source, headline, subline), source = ("marketing", "86-…") or
# ("gallery", "01-dashboard"). Reused slides: gallery slot names, in order.
PAGES = {
    "tax-india": {
        "en-IN": {
            "lead": [(("marketing", "86-tax-estimator-india"),
                      "Old vs New\nRegime", "FY 2026-27 estimate, calculated on your device")],
            "reuse": [],  # the en-IN gallery is in dollars, so it stops at the rupee slide
        },
        "hi": {"lead": [], "reuse": ["05-tax", "01-dashboard", "03-budgets", "07-networth", "09-reports"]},
    },
    "tax-uk-ca-au": {
        "en-US": {
            "lead": [
                (("marketing", "83-tax-estimator-united-kingdom"),
                 "UK Tax and\nNational Insurance", "Scottish rates included"),
                (("marketing", "84-tax-estimator-canada"),
                 "Canada, Federal\nand Provincial", "All 13 provinces and territories, with CPP and EI"),
                (("marketing", "85-tax-estimator-australia"),
                 "Australia, with the\nMedicare Levy", "Low income tax offset and concessional super"),
            ],
            "reuse": [],
        },
    },
    "household": {
        loc: {"lead": [], "reuse": ["04-household", "03-budgets", "01-dashboard", "02-transactions", "07-networth"]}
        for loc in ("en-US", "en-IN", "hi", "es")
    },
    "private": {
        loc: {
            "lead": [(("gallery", "01-dashboard"),) + headline],
            "reuse": ["02-transactions", "03-budgets", "07-networth", "10-yearinreview"],
        }
        for loc, headline in {
            "en-US": ("No Bank Login.\nEver.", "Your data stays on your devices and in your iCloud"),
            "en-IN": ("No Bank Login.\nEver.", "Your data stays on your devices and in your iCloud"),
            "es": ("Sin Conectar\ntu Banco", "Tus datos se quedan en tus dispositivos y en tu iCloud"),
            "hi": ("बैंक लॉगिन की\nज़रूरत नहीं", "आपका डेटा आपके डिवाइस और आपके iCloud में ही रहता है"),
        }.items()
    },
}


def main():
    wide = {"ipad-13"}
    specs = []
    for page in PAGES.values():
        for spec in page.values():
            for _, title, sub in spec["lead"]:
                # Phone canvases break the headline; iPad canvases set it on one line.
                specs += [(line, "bold", mm.INK) for line in title.split("\n")]
                specs.append((title.replace("\n", " "), "bold", mm.INK))
                specs.append((sub, "medium", mm.MUTED))
    mm.prerender_text(specs)

    out_root = os.path.join(mm.STORE_ROOT, "cpp")
    for page, locales in PAGES.items():
        for locale, spec in locales.items():
            for device, (gallery, compose) in DEVICES.items():
                outdir = os.path.join(out_root, page, locale, device)
                if os.path.isdir(outdir):
                    shutil.rmtree(outdir)
                os.makedirs(outdir)
                n = 0
                for (kind, name), title, sub in spec["lead"]:
                    src = marketing(device, name) if kind == "marketing" else gallery_raw(device, locale, name)
                    key = f"lead-{n}"
                    if device in wide:
                        title = title.replace("\n", " ")
                    with tempfile.TemporaryDirectory() as tmp:
                        raw = os.path.join(tmp, key + ".png")
                        shutil.copy(src, raw)
                        n += 1
                        compose(raw, os.path.join(outdir, f"{n:02d}-{name}.png"), {key: (title, sub)})
                for slot in spec["reuse"]:
                    framed = os.path.join(mm.STORE_ROOT, gallery + SUFFIX[locale], f"{slot}.png")
                    n += 1
                    shutil.copy(framed, os.path.join(outdir, f"{n:02d}-{slot}.png"))
                print(f"{page}/{locale}/{device}: {n}")


if __name__ == "__main__":
    main()
