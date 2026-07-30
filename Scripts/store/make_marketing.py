#!/usr/bin/env python3
"""Compose App Store marketing screenshots: raw capture -> device frame +
headline + soft branded background. Outputs exact ASC-accepted sizes."""
import hashlib
import json
import os
import subprocess
import tempfile
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/System/Library/Fonts/HelveticaNeue.ttc"
INK = (17, 24, 39, 255)          # #111827
MUTED = (75, 85, 99, 255)        # #4b5563
GREEN = (60, 215, 157)           # brand #3cd79d
BLUE = (96, 165, 250)

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Docs", "Store", "screenshots")
OUT = os.path.join(RAW, "marketing")

COPY_BY_LOCALE = {
    "en": {
        "01-dashboard":    ("Everything at\na Glance",      "Income, spending, budgets, and goals in one place"),
        "02-transactions": ("Track Every\nTransaction",     "Ten-second capture with instant search and filters"),
        "03-budgets":      ("Budgets That\nKeep Up",        "Per-category limits with overspend warnings"),
        "04-fiftythirtytwenty": ("Needs, Wants,\nSavings",     "See your month against the 50/30/20 guideline"),
        # Only the Mac raws still carry a savings capture (see the note in
        # capture_screenshots.sh); kept so the Mac gallery is not cut to four.
        "04-savings":      ("Achieve Your\nSavings Goals",  "Set a target and watch the progress ring fill"),
        "05-reports":      ("Reports That\nExplain",        "Category breakdowns, trends, and cash flow"),
        "06-yearinreview": ("Your Year,\nWrapped",          "Total spent, top categories, and your biggest month"),
    },
    "es": {
        "01-dashboard":    ("Todo de\nun Vistazo",          "Ingresos, gastos, presupuestos y metas en un lugar"),
        "02-transactions": ("Registra Cada\nMovimiento",    "Captura en segundos, con búsqueda y filtros"),
        "03-budgets":      ("Presupuestos\na tu Ritmo",     "Límites por categoría y avisos antes de pasarte"),
        "04-fiftythirtytwenty": ("Necesidades,\nGustos, Ahorro", "Compara tu mes con la regla 50/30/20"),
        "05-reports":      ("Reportes que\nte Explican",    "Desglose por categoría, tendencias y flujo"),
        "06-yearinreview": ("Tu Año\nen Resumen",           "Total gastado, categorías principales y tu mes más alto"),
    },
    "hi": {
        "01-dashboard":    ("एक नज़र में\nसब कुछ",            "आय, खर्च, बजट और लक्ष्य — एक ही जगह"),
        "02-transactions": ("हर ट्रांज़ैक्शन\nरिकॉर्ड करें",      "सेकंडों में एंट्री, तुरंत सर्च और फ़िल्टर"),
        "03-budgets":      ("बजट जो\nसाथ चले",              "हर कैटेगरी की सीमा, खर्च बढ़ने से पहले चेतावनी"),
        "04-fiftythirtytwenty": ("ज़रूरतें, चाहतें,\nबचत",        "50/30/20 नियम के हिसाब से अपना महीना देखें"),
        "05-reports":      ("रिपोर्ट जो\nसमझाएँ",             "कैटेगरी ब्रेकडाउन, ट्रेंड और कैश फ़्लो"),
        "06-yearinreview": ("आपका साल,\nएक झलक में",         "कुल खर्च, मुख्य कैटेगरी और सबसे बड़ा महीना"),
    },
}
COPY = COPY_BY_LOCALE["en"]
# Wide canvases fit the headline on one line
COPY_WIDE_BY_LOCALE = {
    loc: {k: (t.replace("\n", " "), sub) for k, (t, sub) in table.items()}
    for loc, table in COPY_BY_LOCALE.items()
}


# ---- text rendering ---------------------------------------------------------
# Rendered by CoreText via render_text.swift, not by PIL: Pillow here has no
# Raqm, so it mis-shapes Devanagari. Everything is rendered once at BASE_PT and
# scaled down per canvas, so one swift invocation covers the whole run.
BASE_PT = 200
TEXT_DIR = os.path.join(tempfile.gettempdir(), "vittora-marketing-text")
_TEXT_CACHE = {}


def _text_key(text, weight, rgb):
    digest = hashlib.sha1(f"{text}|{weight}|{rgb}".encode()).hexdigest()[:16]
    return digest, os.path.join(TEXT_DIR, f"{digest}.png")


def prerender_text(specs):
    """specs: iterable of (text, weight, rgb). Renders any not already cached."""
    os.makedirs(TEXT_DIR, exist_ok=True)
    manifest = []
    for text, weight, rgb in specs:
        digest, path = _text_key(text, weight, rgb)
        if digest in _TEXT_CACHE:
            continue
        _TEXT_CACHE[digest] = path
        if not os.path.exists(path):
            manifest.append({"out": path, "size": BASE_PT, "weight": weight,
                             "rgb": list(rgb[:3]), "text": text})
    if not manifest:
        return
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
        json.dump(manifest, fh)
        manifest_path = fh.name
    swift = os.path.join(os.path.dirname(os.path.abspath(__file__)), "render_text.swift")
    subprocess.run(["swift", swift, manifest_path], check=True)
    os.unlink(manifest_path)


def text_layer(text, px, weight, rgb):
    """Cached CoreText render, scaled so its point size corresponds to `px`."""
    _, path = _text_key(text, weight, rgb)
    img = Image.open(path).convert("RGBA")
    scale = px / BASE_PT
    return img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))),
                      Image.LANCZOS)


def font(size, face=1):  # 1=Bold, 0=Regular, 10=Medium
    return ImageFont.truetype(FONT, size, index=face)


def background(w, h):
    img = Image.new("RGB", (w, h), (246, 250, 248))
    grad = Image.new("L", (1, h))
    for y in range(h):
        grad.putpixel((0, y), int(255 * (y / h)))
    grad = grad.resize((w, h))
    img = Image.composite(Image.new("RGB", (w, h), (255, 255, 255)), img, grad)
    blobs = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blobs)
    r = int(w * 0.42)
    bd.ellipse([-r // 2, int(h * 0.05), r, int(h * 0.05) + int(r * 1.1)], fill=GREEN + (46,))
    bd.ellipse([w - r, int(h * 0.32), w + r // 2, int(h * 0.32) + int(r * 1.2)], fill=BLUE + (36,))
    bd.ellipse([int(w * 0.1), h - int(r * 0.9), int(w * 0.1) + r, h + r // 3], fill=GREEN + (30,))
    blobs = blobs.filter(ImageFilter.GaussianBlur(int(w * 0.09)))
    img = img.convert("RGBA")
    img.alpha_composite(blobs)
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def device(shot, screen_w, corner, bezel):
    """Screenshot inside a dark rounded frame; returns RGBA with shadow margin."""
    screen_h = int(screen_w * shot.height / shot.width)
    scr = rounded(shot.resize((screen_w, screen_h), Image.LANCZOS), corner)
    fw, fh = screen_w + 2 * bezel, screen_h + 2 * bezel
    margin = bezel * 6
    canvas = Image.new("RGBA", (fw + 2 * margin, fh + 2 * margin), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [margin, margin + bezel * 2, margin + fw, margin + fh + bezel * 2],
        corner + bezel, fill=(15, 30, 24, 110))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(bezel * 2)))
    frame = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([margin, margin, margin + fw, margin + fh],
                         corner + bezel, fill=(23, 26, 31, 255))
    fd.rounded_rectangle([margin + 3, margin + 3, margin + fw - 3, margin + fh - 3],
                         corner + bezel - 3, outline=(70, 76, 84, 255), width=3)
    canvas.alpha_composite(frame)
    canvas.alpha_composite(scr, (margin + bezel, margin + bezel))
    return canvas, margin


def draw_copy(img, title, sub, top, title_size, sub_size, gap):
    w = img.width
    y = top
    for line in title.split("\n"):
        layer = text_layer(line, title_size, "bold", INK)
        img.alpha_composite(layer, ((w - layer.width) // 2, y - int(title_size * 0.5)))
        y += int(title_size * 1.14)
    y += gap
    layer = text_layer(sub, sub_size, "medium", MUTED)
    img.alpha_composite(layer, ((w - layer.width) // 2, y - int(sub_size * 0.5)))
    return y + int(sub_size * 1.3)


def compose_phone(raw_path, out_path, copy, W, H):
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = copy[key]
    img = background(W, H)
    ts = int(W * 0.088)
    bottom = draw_copy(img, title, sub, int(H * 0.052), ts, int(W * 0.036), int(W * 0.03))
    shot = Image.open(raw_path).convert("RGB")
    avail_h = H - bottom - int(H * 0.02)
    bezel = int(W * 0.016)
    screen_h = avail_h + int(H * 0.045)          # slight bottom bleed like the samples
    screen_w = int(screen_h * shot.width / shot.height)
    dev, margin = device(shot, screen_w, corner=int(W * 0.10), bezel=bezel)
    img.alpha_composite(dev, ((W - dev.width) // 2, bottom + int(H * 0.015) - margin + bezel * 2))
    img = img.crop((0, 0, W, H))
    img.convert("RGB").save(out_path, "PNG")


def compose_pad(raw_path, out_path, copy, W=2064, H=2752):
    """Portrait iPad. 2064x2752 is an ASC-accepted 13" size and matches what the
    simulator captures, so nothing has to be rotated."""
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = copy[key]
    img = background(W, H)
    bottom = draw_copy(img, title, sub, int(H * 0.045), int(W * 0.058),
                       int(W * 0.024), int(W * 0.016))
    shot = Image.open(raw_path).convert("RGB")
    avail_h = H - bottom - int(H * 0.03)
    bezel = int(W * 0.013)
    screen_h = avail_h + int(H * 0.035)
    screen_w = int(screen_h * shot.width / shot.height)
    if screen_w > W - int(W * 0.16):            # keep clear of the canvas edges
        screen_w = W - int(W * 0.16)
        screen_h = int(screen_w * shot.height / shot.width)
    dev, margin = device(shot, screen_w, corner=int(W * 0.035), bezel=bezel)
    img.alpha_composite(dev, ((W - dev.width) // 2, bottom + int(H * 0.015) - margin + bezel * 2))
    img = img.crop((0, 0, W, H))
    img.convert("RGB").save(out_path, "PNG")


def compose_mac(raw_path, out_path, copy, W=1440, H=900):
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = copy[key]
    img = background(W, H)
    bottom = draw_copy(img, title, sub, int(H * 0.045), int(W * 0.032), int(W * 0.0135), int(W * 0.008))
    shot = Image.open(raw_path).convert("RGBA")  # window capture already has rounded corners
    avail_h = H - bottom - int(H * 0.015)
    win_h = avail_h + int(H * 0.04)              # slight bottom bleed
    win_w = int(win_h * shot.width / shot.height)
    win = shot.resize((win_w, win_h), Image.LANCZOS)
    sm = 60
    shadow = Image.new("RGBA", (win_w + 2 * sm, win_h + 2 * sm), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([sm, sm + 14, sm + win_w, sm + win_h + 14], 18,
                                             fill=(15, 30, 24, 100))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    x = (W - win_w) // 2
    y = bottom + int(H * 0.01)
    img.alpha_composite(shadow, (x - sm, y - sm))
    img.alpha_composite(win, (x, y))
    img = img.crop((0, 0, W, H))
    img.convert("RGB").save(out_path, "PNG")


def main():
    # (raw set, output set, locale, composer). The 6.5" set reuses the 6.9"
    # captures — Apple accepts one gallery scaled, and the pixel ratio is close
    # enough that the framed result is indistinguishable.
    jobs = [
        ("iphone-69",    "iphone-69",    "en", lambda r, o, c: compose_phone(r, o, c, 1320, 2868)),
        ("iphone-69",    "iphone-65",    "en", lambda r, o, c: compose_phone(r, o, c, 1284, 2778)),
        ("iphone-69-in", "iphone-69-in", "en", lambda r, o, c: compose_phone(r, o, c, 1320, 2868)),
        ("iphone-69-hi", "iphone-69-hi", "hi", lambda r, o, c: compose_phone(r, o, c, 1320, 2868)),
        ("iphone-69-es", "iphone-69-es", "es", lambda r, o, c: compose_phone(r, o, c, 1320, 2868)),
        ("ipad-13",      "ipad-13",      "en", compose_pad),
        ("mac",          "mac",          "en", compose_mac),
    ]

    # One swift invocation for every string in the run.
    wide = {"mac"}
    specs, tables = [], {}
    for src, dst, locale, _ in jobs:
        srcdir = os.path.join(RAW, src)
        if not os.path.isdir(srcdir):
            continue
        table = (COPY_WIDE_BY_LOCALE if dst in wide else COPY_BY_LOCALE)[locale]
        tables[dst] = table
        for name in sorted(os.listdir(srcdir)):
            key = os.path.splitext(name)[0]
            if not name.endswith(".png") or key not in table:
                continue
            title, sub = table[key]
            specs += [(line, "bold", INK) for line in title.split("\n")]
            specs.append((sub, "medium", MUTED))
    prerender_text(specs)

    for src, dst, locale, fn in jobs:
        srcdir = os.path.join(RAW, src)
        if not os.path.isdir(srcdir):
            print(f"skip {dst}: no raw captures in {srcdir}")
            continue
        outdir = os.path.join(OUT, dst)
        os.makedirs(outdir, exist_ok=True)
        table = tables[dst]
        for name in sorted(os.listdir(srcdir)):
            key = os.path.splitext(name)[0]
            if not name.endswith(".png"):
                continue
            if key not in table:
                # A raw capture with no headline copy — don't guess one.
                print(f"skip {dst}/{name}: no copy for '{key}'")
                continue
            fn(os.path.join(srcdir, name), os.path.join(outdir, name), table)
            print(dst, name)


if __name__ == "__main__":
    main()
