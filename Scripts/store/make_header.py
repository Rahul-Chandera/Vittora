#!/usr/bin/env python3
"""App Store product page header / search results creative, one per locale.

One UNIVERSAL 16:9 asset (5244 x 2950 PNG, no alpha) serves both placements —
Apple's creative-assets spec accepts 16:9 for the header and for search
results, and its best practices recommend one universal asset. The header
crops it to 21:9 and search results to 3:2, so everything that matters sits in
the region both keep: 4425 x 2247, centred (SAFE below), with margin.

Apple's rules this follows (developer.apple.com/app-store/asset-best-practices):
one clear idea for a first-time visitor; a short localized phrase that
enhances the visual; the interface visible so the purpose is obvious in search;
no prices, URLs, (c), other platforms or Apple recognitions.

Reuses make_marketing.py's ground, device frames and CoreText headlines, so
the header and the screenshot gallery read as one set. Reads raw captures from
<STORE_ROOT>/raw and writes <STORE_ROOT>/header/<locale>.png, plus one per
custom product page localization into <STORE_ROOT>/cpp/<page>/<locale>/header.png
(Docs/Store/CUSTOM_PRODUCT_PAGES.md).
"""
import os
from PIL import Image

import make_marketing as mm

W, H = 5244, 2950
# What survives both crops: 21:9 keeps a 2247 px band, 3:2 keeps 4425 px.
SAFE_W, SAFE_H = int(H * 3 / 2), int(W * 9 / 21)
SAFE = ((W - SAFE_W) // 2, (H - SAFE_H) // 2, (W + SAFE_W) // 2, (H + SAFE_H) // 2)

SUFFIX = {"en-US": "", "en-IN": "-in", "es": "-es", "hi": "-hi"}
SHOTS = os.path.join(os.path.dirname(mm.STORE_ROOT), "Screenshots")


def raw(kind, locale, slot):
    """A store-gallery raw capture: kind is iphone-69, ipad-13 or watch."""
    folder = os.path.join(mm.RAW, kind + SUFFIX[locale])
    if kind == "watch":  # watch raws are named NN-<screen>.png
        slot = next(f[:-4] for f in sorted(os.listdir(folder)) if f.endswith(f"-{slot}.png"))
    return os.path.join(folder, slot + ".png")


def shot(device, name):
    """A Marketing/Screenshots capture, e.g. ("iphone", "86-tax-estimator-india")."""
    folder = "iPad/Light" if device == "ipad" else "iPhone/Light"
    return os.path.join(SHOTS, folder, f"{device}-light-{name}.png")


def spec(locale, title, sub, pad, phone, right=None, palette="01-dashboard"):
    """right: ("watch", path) or ("phone", path), in front of the iPad's lower right."""
    return dict(locale=locale, title=title, sub=sub, pad=pad, phone=phone,
                right=right, palette=palette)


def main_page(locale, title, sub):
    return spec(locale, title, sub, raw("ipad-13", locale, "01-dashboard"),
                raw("iphone-69", locale, "07-networth"),
                ("watch", raw("watch", locale, "dashboard")))


def gallery(locale, title, sub, pad_slot, phone_slot, palette):
    return spec(locale, title, sub, raw("ipad-13", locale, pad_slot),
                raw("iphone-69", locale, phone_slot), palette=palette)


# Output path relative to STORE_ROOT -> spec. Headlines match each custom page's
# lead slide and promotional text; the en-IN tax page uses the English rupee
# captures because the en-IN gallery is in dollars (owner's choice).
def headers():
    out = {
        f"header/{loc}.png": main_page(loc, t, s) for loc, (t, s) in {
            "en-US": ("Private money, every device", "No bank linking. No ads. Nothing sold."),
            "en-IN": ("Private money, every device", "No bank linking. No ads. Nothing sold."),
            "es": ("Tu dinero, privado y en todos tus dispositivos", "Sin conectar tu banco. Sin anuncios."),
            "hi": ("आपका पैसा, निजी — हर डिवाइस पर", "कोई बैंक लिंकिंग नहीं। कोई विज्ञापन नहीं।"),
        }.items()
    }
    out["cpp/tax-india/en-IN/header.png"] = spec(
        "en-IN", "Old vs New Regime", "FY 2026-27 estimate, calculated on your device",
        shot("ipad", "86-tax-estimator-india"), shot("iphone", "86-tax-estimator-india"),
        palette="05-tax")
    out["cpp/tax-india/hi/header.png"] = gallery(
        "hi", "पुरानी बनाम नई टैक्स व्यवस्था", "FY 2026-27 का अनुमान, आपके डिवाइस पर",
        "05-tax", "05-tax", "05-tax")
    out["cpp/tax-uk-ca-au/en-US/header.png"] = spec(
        "en-US", "UK, Canada and Australia tax", "Educational estimates, calculated on your device",
        shot("ipad", "83-tax-estimator-united-kingdom"), shot("iphone", "84-tax-estimator-canada"),
        ("phone", shot("iphone", "85-tax-estimator-australia")), palette="05-tax")
    for loc in SUFFIX:
        title, sub = mm.COPY_WIDE_BY_LOCALE[loc[:2]]["04-household"]
        out[f"cpp/household/{loc}/header.png"] = gallery(
            loc, title, sub, "03-budgets", "04-household", "04-household")
    for loc, (title, sub) in {
        "en-US": ("No bank login. Ever.", "Your data stays on your devices and in your iCloud"),
        "en-IN": ("No bank login. Ever.", "Your data stays on your devices and in your iCloud"),
        "es": ("Sin conectar tu banco", "Tus datos se quedan en tus dispositivos y en tu iCloud"),
        "hi": ("बैंक लॉगिन की ज़रूरत नहीं", "आपका डेटा आपके डिवाइस और आपके iCloud में ही रहता है"),
    }.items():
        out[f"cpp/private/{loc}/header.png"] = spec(
            loc, title, sub, raw("ipad-13", loc, "01-dashboard"),
            raw("iphone-69", loc, "02-transactions"), ("watch", raw("watch", loc, "dashboard")))
    return out


def compose(s, out):
    title, sub = s["title"], s["sub"]
    pal = mm.PALETTE[s["palette"]]
    img = mm.background(W, H, pal)
    left, top, right, bottom = SAFE
    pad_y = int(SAFE_H * 0.04)

    # Headline block near the top of the safe band.
    title_px, sub_px = int(W * 0.036), int(W * 0.0155)
    text_bottom = mm.draw_copy(img, title, sub, top + pad_y + int(title_px * 0.9),
                               title_px, sub_px, int(W * 0.006), accent=pal["glow"])

    # iPad, centred, filling the space under the headline.
    pad = Image.open(s["pad"]).convert("RGB")
    bezel = int(W * 0.0055)
    avail_h = bottom - pad_y - text_bottom - int(SAFE_H * 0.02)
    screen_h = avail_h - 2 * bezel
    screen_w = int(screen_h * pad.width / pad.height)
    pad_dev, pad_m = mm.device(pad, screen_w, corner=int(screen_h * 0.045), bezel=bezel)
    pad_x = (W - pad_dev.width) // 2
    pad_y0 = bottom - pad_y - (pad_dev.height - pad_m)
    img.alpha_composite(pad_dev, (pad_x, pad_y0))

    # iPhone in front, overlapping the iPad's lower-left corner.
    p_bezel = int(W * 0.0045)
    p_screen_h = int(avail_h * 0.92) - 2 * p_bezel

    def phone_device(path):
        phone = Image.open(path).convert("RGB")
        p_screen_w = int(p_screen_h * phone.width / phone.height)
        return mm.device(phone, p_screen_w, corner=int(p_screen_w * 0.13), bezel=p_bezel)

    ph_dev, ph_m = phone_device(s["phone"])
    ph_x = pad_x + pad_m - int(ph_dev.width * 0.42)
    ph_x = max(left + int(SAFE_W * 0.03) - ph_m, ph_x)
    ph_y = bottom - pad_y - (ph_dev.height - ph_m)
    img.alpha_composite(ph_dev, (ph_x, ph_y))

    # Watch or a second phone in front, overlapping the iPad's lower-right corner.
    if s["right"]:
        kind, path = s["right"]
        if kind == "watch":
            w_dev, w_m = mm.watch_device(Image.open(path).convert("RGB"), int(avail_h * 0.30))
            overlap = 0.62
        else:
            w_dev, w_m = phone_device(path)
            overlap = 0.58
        w_x = pad_x + pad_dev.width - pad_m - int(w_dev.width * overlap)
        w_x = min(right - int(SAFE_W * 0.03) - w_dev.width + w_m, w_x)
        w_y = bottom - pad_y - (w_dev.height - w_m)
        img.alpha_composite(w_dev, (w_x, w_y))

    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.convert("RGB").save(out, "PNG")   # no alpha channel, per the spec


def main():
    jobs = headers()
    only = os.environ.get("ONLY")  # substring of the output path, e.g. ONLY=cpp/
    jobs = {k: v for k, v in jobs.items() if not only or only in k}
    mm.prerender_text([t for s in jobs.values()
                       for t in ((s["title"], "bold", mm.INK), (s["sub"], "medium", mm.MUTED))])
    for rel, s in jobs.items():
        out = os.path.join(mm.STORE_ROOT, rel)
        compose(s, out)
        print(out)


if __name__ == "__main__":
    main()
