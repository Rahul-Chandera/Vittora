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
<STORE_ROOT>/raw and writes <STORE_ROOT>/header/<locale>.png.
"""
import os
from PIL import Image

import make_marketing as mm

W, H = 5244, 2950
# What survives both crops: 21:9 keeps a 2247 px band, 3:2 keeps 4425 px.
SAFE_W, SAFE_H = int(H * 3 / 2), int(W * 9 / 21)
SAFE = ((W - SAFE_W) // 2, (H - SAFE_H) // 2, (W + SAFE_W) // 2, (H + SAFE_H) // 2)

# (raw iPhone set, raw iPad set, raw watch set, headline, supporting line)
LOCALES = {
    "en-US": ("iphone-69", "ipad-13", "watch",
              "Private money, every device", "No bank linking. No ads. Nothing sold."),
    "en-IN": ("iphone-69-in", "ipad-13-in", "watch-in",
              "Private money, every device", "No bank linking. No ads. Nothing sold."),
    "es":    ("iphone-69-es", "ipad-13-es", "watch-es",
              "Tu dinero, privado y en todos tus dispositivos", "Sin conectar tu banco. Sin anuncios."),
    "hi":    ("iphone-69-hi", "ipad-13-hi", "watch-hi",
              "आपका पैसा, निजी — हर डिवाइस पर", "कोई बैंक लिंकिंग नहीं। कोई विज्ञापन नहीं।"),
}


def compose(locale):
    phone_set, pad_set, watch_set, title, sub = LOCALES[locale]
    raw = mm.RAW
    pal = mm.PALETTE["01-dashboard"]
    img = mm.background(W, H, pal)
    left, top, right, bottom = SAFE
    pad_y = int(SAFE_H * 0.04)

    # Headline block near the top of the safe band.
    title_px, sub_px = int(W * 0.036), int(W * 0.0155)
    text_bottom = mm.draw_copy(img, title, sub, top + pad_y + int(title_px * 0.9),
                               title_px, sub_px, int(W * 0.006), accent=pal["glow"])

    # iPad, centred, filling the space under the headline.
    pad = Image.open(os.path.join(raw, pad_set, "01-dashboard.png")).convert("RGB")
    bezel = int(W * 0.0055)
    avail_h = bottom - pad_y - text_bottom - int(SAFE_H * 0.02)
    screen_h = avail_h - 2 * bezel
    screen_w = int(screen_h * pad.width / pad.height)
    pad_dev, pad_m = mm.device(pad, screen_w, corner=int(screen_h * 0.045), bezel=bezel)
    pad_x = (W - pad_dev.width) // 2
    pad_y0 = bottom - pad_y - (pad_dev.height - pad_m)
    img.alpha_composite(pad_dev, (pad_x, pad_y0))

    # iPhone in front, overlapping the iPad's lower-left corner.
    phone = Image.open(os.path.join(raw, phone_set, "07-networth.png")).convert("RGB")
    p_bezel = int(W * 0.0045)
    p_screen_h = int(avail_h * 0.92) - 2 * p_bezel
    p_screen_w = int(p_screen_h * phone.width / phone.height)
    ph_dev, ph_m = mm.device(phone, p_screen_w, corner=int(p_screen_w * 0.13), bezel=p_bezel)
    ph_x = pad_x + pad_m - int(ph_dev.width * 0.42)
    ph_x = max(left + int(SAFE_W * 0.03) - ph_m, ph_x)
    ph_y = bottom - pad_y - (ph_dev.height - ph_m)
    img.alpha_composite(ph_dev, (ph_x, ph_y))

    # Watch in front, overlapping the iPad's lower-right corner.
    watch_files = sorted(f for f in os.listdir(os.path.join(raw, watch_set)) if f.endswith("-dashboard.png"))
    watch = Image.open(os.path.join(raw, watch_set, watch_files[0])).convert("RGB")
    w_dev, w_m = mm.watch_device(watch, int(avail_h * 0.30))
    w_x = pad_x + pad_dev.width - pad_m - int(w_dev.width * 0.62)
    w_x = min(right - int(SAFE_W * 0.03) - w_dev.width + w_m, w_x)
    w_y = bottom - pad_y - (w_dev.height - w_m)
    img.alpha_composite(w_dev, (w_x, w_y))

    out_dir = os.path.join(mm.STORE_ROOT, "header")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{locale}.png")
    img.convert("RGB").save(out, "PNG")   # no alpha channel, per the spec
    return out


def main():
    specs = []
    for _, _, _, title, sub in LOCALES.values():
        specs += [(title, "bold", mm.INK), (sub, "medium", mm.MUTED)]
    mm.prerender_text(specs)
    for locale in LOCALES:
        print(compose(locale))


if __name__ == "__main__":
    main()
