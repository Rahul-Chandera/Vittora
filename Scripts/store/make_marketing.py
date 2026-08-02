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
GREEN = (63, 207, 164)           # brand #3FCFA4 (DEC-012)
BLUE = (96, 165, 250)

# One tint per slot, so the gallery reads as a set rather than six copies of the
# same card. All six are desaturated neighbours of the brand green plus a warm
# sand — a finance app wants calm, not carnival. `glow` is the colour of the
# soft spotlight behind the device; `ink` overrides the headline colour where a
# darker ground needs it.
PALETTE = {
    "01-dashboard":         {"top": (233, 248, 242), "bottom": (207, 238, 227), "glow": (63, 207, 164)},
    "02-transactions":      {"top": (238, 245, 251), "bottom": (213, 230, 244), "glow": (96, 165, 250)},
    "03-budgets":           {"top": (248, 245, 236), "bottom": (238, 229, 210), "glow": (214, 178, 106)},
    "04-fiftythirtytwenty": {"top": (236, 246, 245), "bottom": (206, 232, 230), "glow": (72, 187, 182)},
    "05-reports":           {"top": (243, 241, 250), "bottom": (223, 217, 241), "glow": (146, 128, 220)},
    "06-yearinreview":      {"top": (232, 246, 240), "bottom": (198, 232, 219), "glow": (52, 190, 150)},
}
DEFAULT_PAL = PALETTE["01-dashboard"]

# Watch slots are keyed by the screen suffix, because the raw filename carries
# the device name ("watch-series-11-46mm-dashboard") and that changes with
# whatever pair the capture script finds.
WATCH_COPY_BY_LOCALE = {
    "en": {
        "dashboard":     ("Today at\na Glance",  "Spend and budget, on your wrist"),
        "recent":        ("Recent\nActivity",    "Your latest transactions"),
        "quick-expense": ("Add in\nSeconds",     "Turn the crown. Done."),
    },
    "hi": {
        "dashboard":     ("एक नज़र में\nआज",       "खर्च और बजट, आपकी कलाई पर"),
        "recent":        ("हाल की\nगतिविधि",       "आपके नवीनतम ट्रांज़ैक्शन"),
        "quick-expense": ("सेकंडों में\nजोड़ें",      "क्राउन घुमाएँ। हो गया।"),
    },
    "es": {
        "dashboard":     ("Tu día de\nun vistazo", "Gastos y presupuesto en tu muñeca"),
        "recent":        ("Actividad\nreciente",   "Tus últimos movimientos"),
        "quick-expense": ("Añade en\nsegundos",    "Gira la corona. Listo."),
    },
}
WATCH_COPY = WATCH_COPY_BY_LOCALE["en"]
WATCH_PALETTE = {
    "dashboard":     PALETTE["01-dashboard"],
    "recent":        PALETTE["02-transactions"],
    "quick-expense": PALETTE["06-yearinreview"],
}

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Docs", "Store", "screenshots")
OUT = os.path.join(RAW, "marketing")

COPY_BY_LOCALE = {
    "en": {
        "01-dashboard":    ("Everything at\na Glance",      "Income, spending, budgets, and goals in one place"),
        "02-transactions": ("Track Every\nTransaction",     "Ten-second capture with instant search and filters"),
        "03-budgets":      ("Budgets That\nKeep Up",        "Per-category limits with overspend warnings"),
        "04-fiftythirtytwenty": ("Needs, Wants,\nSavings",     "See your month against the 50/30/20 guideline"),
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


def _vertical_gradient(w, h, top, bottom):
    """Per-row interpolation on a 1px column, then stretched — cheap and smooth."""
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return col.resize((w, h), Image.BILINEAR)


def _grain(w, h, strength=5):
    """Faint luminance noise. Long vertical gradients band visibly on the App
    Store's own rescaling; a little grain hides it and reads as texture."""
    small = Image.effect_noise((w // 8 or 1, h // 8 or 1), strength * 12).convert("L")
    small = small.resize((w, h), Image.BILINEAR)
    layer = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    layer.putalpha(small.point(lambda v: int(abs(v - 128) * strength / 128)))
    return layer


def background(w, h, pal=None):
    """Tinted ground: vertical gradient, a soft spotlight where the device sits,
    and grain. The previous version drew three blurred blobs at alpha 30-46,
    which at this canvas size resolved to plain white — the gallery had no
    brand colour in it at all."""
    pal = pal or DEFAULT_PAL
    img = _vertical_gradient(w, h, pal["top"], pal["bottom"]).convert("RGBA")

    # Spotlight behind the device, centred on the upper third of the artwork.
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = int(w * 0.78)
    cx, cy = w // 2, int(h * 0.52)
    ImageDraw.Draw(glow).ellipse([cx - r, cy - r, cx + r, cy + r], fill=pal["glow"] + (78,))
    glow = glow.filter(ImageFilter.GaussianBlur(int(w * 0.16)))
    img.alpha_composite(glow)

    # A brighter wash at the very top keeps the headline crisp against the tint.
    top_wash = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(top_wash).rectangle([0, 0, w, int(h * 0.30)], fill=(255, 255, 255, 58))
    img.alpha_composite(top_wash.filter(ImageFilter.GaussianBlur(int(h * 0.05))))

    img.alpha_composite(_grain(w, h))
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def device(shot, screen_w, corner, bezel):
    """Screenshot inside an iPhone-like frame. Returns (RGBA, margin).

    Built rather than photographed: a titanium-toned rail, a hairline inner
    edge so the bezel does not read as a flat black slab, side buttons, and a
    two-pass shadow (tight contact + wide ambient) so it sits on the ground
    instead of floating."""
    screen_h = int(screen_w * shot.height / shot.width)
    scr = rounded(shot.resize((screen_w, screen_h), Image.LANCZOS), corner)
    fw, fh = screen_w + 2 * bezel, screen_h + 2 * bezel
    margin = int(bezel * 9)
    canvas = Image.new("RGBA", (fw + 2 * margin, fh + 2 * margin), (0, 0, 0, 0))
    outer = corner + bezel

    # Ambient shadow — wide, soft, offset down.
    amb = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(amb).rounded_rectangle(
        [margin, margin + int(bezel * 3.2), margin + fw, margin + fh + int(bezel * 3.2)],
        outer, fill=(12, 34, 27, 92))
    canvas.alpha_composite(amb.filter(ImageFilter.GaussianBlur(int(bezel * 4.5))))

    # Contact shadow — tight and darker, sells the weight.
    con = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(con).rounded_rectangle(
        [margin + bezel, margin + bezel, margin + fw - bezel, margin + fh + int(bezel * 0.9)],
        outer, fill=(10, 28, 22, 105))
    canvas.alpha_composite(con.filter(ImageFilter.GaussianBlur(int(bezel * 1.4))))

    # Side buttons, drawn under the rail so they read as part of the body.
    btn = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(btn)
    rail = (176, 182, 190, 255)
    bw = max(2, int(bezel * 0.45))
    for y0, y1 in [(0.175, 0.245), (0.275, 0.375)]:            # volume up / down
        bd.rounded_rectangle([margin - bw, margin + int(fh * y0), margin + 2,
                              margin + int(fh * y1)], bw, fill=rail)
    bd.rounded_rectangle([margin + fw - 2, margin + int(fh * 0.235), margin + fw + bw,
                          margin + int(fh * 0.365)], bw, fill=rail)   # side button
    canvas.alpha_composite(btn)

    frame = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([margin, margin, margin + fw, margin + fh], outer, fill=(28, 31, 36, 255))
    # Hairline highlight just inside the rail.
    fd.rounded_rectangle([margin + 2, margin + 2, margin + fw - 2, margin + fh - 2],
                         outer - 2, outline=(122, 130, 140, 255), width=max(2, bezel // 5))
    # Darker line where the glass meets the bezel.
    fd.rounded_rectangle([margin + bezel - 2, margin + bezel - 2,
                          margin + fw - bezel + 2, margin + fh - bezel + 2],
                         corner + 2, outline=(8, 10, 13, 255), width=max(1, bezel // 8))
    canvas.alpha_composite(frame)
    canvas.alpha_composite(scr, (margin + bezel, margin + bezel))
    return canvas, margin


def draw_copy(img, title, sub, top, title_size, sub_size, gap, accent=None):
    """Headline block. Tighter leading than before (1.06 vs 1.14) so a two-line
    headline reads as one unit, plus a short accent rule above it."""
    w = img.width
    y = top
    if accent:
        rule_w, rule_h = int(w * 0.085), max(4, int(w * 0.007))
        rule = Image.new("RGBA", (rule_w, rule_h), accent + (255,))
        img.alpha_composite(rounded(rule, rule_h // 2), ((w - rule_w) // 2, y - int(title_size * 0.62)))
        y += int(title_size * 0.20)
    for line in title.split("\n"):
        layer = text_layer(line, title_size, "bold", INK)
        img.alpha_composite(layer, ((w - layer.width) // 2, y - int(title_size * 0.5)))
        y += int(title_size * 1.06)
    y += gap
    layer = text_layer(sub, sub_size, "medium", MUTED)
    img.alpha_composite(layer, ((w - layer.width) // 2, y - int(sub_size * 0.5)))
    return y + int(sub_size * 1.3)


def compose_phone(raw_path, out_path, copy, W, H):
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = copy[key]
    pal = PALETTE.get(key, DEFAULT_PAL)
    img = background(W, H, pal)
    ts = int(W * 0.092)
    bottom = draw_copy(img, title, sub, int(H * 0.062), ts, int(W * 0.0385),
                       int(W * 0.032), accent=pal["glow"])

    shot = Image.open(raw_path).convert("RGB")
    bezel = int(W * 0.013)
    # The device now sits fully inside the canvas. It used to be scaled past the
    # bottom edge, which cut the artwork mid-row and shrank the UI to the point
    # where nothing was legible at gallery thumbnail size.
    avail_h = H - bottom - int(H * 0.042)
    screen_h = avail_h - 2 * bezel
    screen_w = int(screen_h * shot.width / shot.height)
    max_w = int(W * 0.78)
    if screen_w > max_w:
        screen_w = max_w
        screen_h = int(screen_w * shot.height / shot.width)
    dev, margin = device(shot, screen_w, corner=int(screen_w * 0.115), bezel=bezel)
    x = (W - dev.width) // 2
    y = bottom + (H - bottom - (dev.height - 2 * margin)) // 2 - margin
    img.alpha_composite(dev, (x, y))
    img.crop((0, 0, W, H)).convert("RGB").save(out_path, "PNG")


def watch_device(shot, screen_w):
    """Apple Watch frame: squircle body, thicker rail than a phone, digital
    crown and side button on the right edge."""
    screen_h = int(screen_w * shot.height / shot.width)
    corner = int(screen_w * 0.30)                       # watch glass is very round
    bezel = max(4, int(screen_w * 0.055))
    scr = rounded(shot.resize((screen_w, screen_h), Image.LANCZOS), corner)
    fw, fh = screen_w + 2 * bezel, screen_h + 2 * bezel
    margin = int(bezel * 7)
    canvas = Image.new("RGBA", (fw + 2 * margin, fh + 2 * margin), (0, 0, 0, 0))
    outer = corner + bezel

    amb = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(amb).rounded_rectangle(
        [margin, margin + int(bezel * 2.4), margin + fw, margin + fh + int(bezel * 2.4)],
        outer, fill=(12, 34, 27, 96))
    canvas.alpha_composite(amb.filter(ImageFilter.GaussianBlur(int(bezel * 3.2))))

    rail = (188, 193, 200, 255)
    side = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(side)
    cw = max(3, int(bezel * 0.85))
    # Digital crown: a short capsule with a slightly brighter cap.
    cy0, cy1 = margin + int(fh * 0.30), margin + int(fh * 0.42)
    sd.rounded_rectangle([margin + fw - 2, cy0, margin + fw + cw, cy1], cw // 2, fill=rail)
    sd.rounded_rectangle([margin + fw + cw - 2, cy0 + 2, margin + fw + cw + 2, cy1 - 2],
                         2, fill=(226, 230, 236, 255))
    # Side button.
    sd.rounded_rectangle([margin + fw - 2, margin + int(fh * 0.50),
                          margin + fw + int(cw * 0.7), margin + int(fh * 0.60)],
                         cw // 3, fill=rail)
    canvas.alpha_composite(side)

    frame = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([margin, margin, margin + fw, margin + fh], outer, fill=(26, 28, 33, 255))
    fd.rounded_rectangle([margin + 2, margin + 2, margin + fw - 2, margin + fh - 2],
                         outer - 2, outline=(126, 134, 145, 255), width=max(2, bezel // 4))
    canvas.alpha_composite(frame)
    canvas.alpha_composite(scr, (margin + bezel, margin + bezel))
    return canvas, margin


def compose_watch(raw_path, out_path, copy, W=416, H=496):
    """Apple Watch slot. 416x496 is the Series 10/11 46mm size the capture
    script produces and an ASC-accepted one, so the canvas matches the source."""
    key = os.path.splitext(os.path.basename(raw_path))[0]
    suffix = next((k for k in copy if key.endswith(k)), None)
    if suffix is None:
        print(f"skip watch/{os.path.basename(raw_path)}: no copy for this screen")
        return
    title, sub = copy[suffix]
    pal = WATCH_PALETTE[suffix]
    img = background(W, H, pal)
    bottom = draw_copy(img, title, sub, int(H * 0.085), int(W * 0.105),
                       int(W * 0.043), int(W * 0.020), accent=pal["glow"])

    shot = Image.open(raw_path).convert("RGB")
    avail_h = H - bottom - int(H * 0.035)
    bezel_guess = max(4, int(W * 0.030))
    screen_h = avail_h - 2 * bezel_guess
    screen_w = int(screen_h * shot.width / shot.height)
    max_w = int(W * 0.56)
    if screen_w > max_w:
        screen_w = max_w
        screen_h = int(screen_w * shot.height / shot.width)
    dev, margin = watch_device(shot, screen_w)
    x = (W - dev.width) // 2
    y = bottom + (H - bottom - (dev.height - 2 * margin)) // 2 - margin
    img.alpha_composite(dev, (x, y))
    img.crop((0, 0, W, H)).convert("RGB").save(out_path, "PNG")


def compose_pad(raw_path, out_path, copy, W=2752, H=2064):
    """Landscape iPad. 2752x2064 is the ASC-accepted 13" landscape size.

    Landscape rather than portrait because the wide layout is the one that
    shows what the iPad build actually does — sidebar plus a real detail pane —
    which a portrait shot renders as a single narrow column."""
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = copy[key]
    pal = PALETTE.get(key, DEFAULT_PAL)
    img = background(W, H, pal)
    bottom = draw_copy(img, title, sub, int(H * 0.085), int(W * 0.034),
                       int(W * 0.0145), int(W * 0.009), accent=pal["glow"])

    shot = Image.open(raw_path).convert("RGB")
    bezel = int(W * 0.008)
    avail_h = H - bottom - int(H * 0.055)
    screen_h = avail_h - 2 * bezel
    screen_w = int(screen_h * shot.width / shot.height)
    max_w = int(W * 0.72)
    if screen_w > max_w:
        screen_w = max_w
        screen_h = int(screen_w * shot.height / shot.width)
    dev, margin = device(shot, screen_w, corner=int(screen_h * 0.045), bezel=bezel)
    x = (W - dev.width) // 2
    y = bottom + (H - bottom - (dev.height - 2 * margin)) // 2 - margin
    img.alpha_composite(dev, (x, y))
    img.crop((0, 0, W, H)).convert("RGB").save(out_path, "PNG")


def compose_mac(raw_path, out_path, copy, W=1440, H=900):
    """Landscape Mac. The capture is already a real window with rounded corners
    and no chrome to add, so this frames it with a shadow rather than a bezel."""
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = copy[key]
    pal = PALETTE.get(key, DEFAULT_PAL)
    img = background(W, H, pal)
    bottom = draw_copy(img, title, sub, int(H * 0.085), int(W * 0.038),
                       int(W * 0.0155), int(W * 0.010), accent=pal["glow"])

    shot = Image.open(raw_path).convert("RGBA")
    avail_h = H - bottom - int(H * 0.055)
    win_h = avail_h
    win_w = int(win_h * shot.width / shot.height)
    max_w = int(W * 0.80)
    if win_w > max_w:
        win_w = max_w
        win_h = int(win_w * shot.height / shot.width)
    win = rounded(shot.resize((win_w, win_h), Image.LANCZOS), 14)

    sm = 90
    shadow = Image.new("RGBA", (win_w + 2 * sm, win_h + 2 * sm), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([sm, sm + 26, sm + win_w, sm + win_h + 26], 18, fill=(12, 34, 27, 88))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    contact = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
    ImageDraw.Draw(contact).rounded_rectangle(
        [sm + 8, sm + 6, sm + win_w - 8, sm + win_h + 8], 16, fill=(10, 28, 22, 96))
    shadow.alpha_composite(contact.filter(ImageFilter.GaussianBlur(12)))

    x = (W - win_w) // 2
    y = bottom + (H - bottom - win_h) // 2
    img.alpha_composite(shadow, (x - sm, y - sm))
    img.alpha_composite(win, (x, y))
    img.crop((0, 0, W, H)).convert("RGB").save(out_path, "PNG")


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
        # 6.5" counterparts. Apple keeps a separate 6.5" slot that will not
        # accept the 6.9" canvas, and it is per-localization — the English
        # iphone-65 set alone does not cover the hi/es/en-IN listings.
        ("iphone-69-in", "iphone-65-in", "en", lambda r, o, c: compose_phone(r, o, c, 1284, 2778)),
        ("iphone-69-hi", "iphone-65-hi", "hi", lambda r, o, c: compose_phone(r, o, c, 1284, 2778)),
        ("iphone-69-es", "iphone-65-es", "es", lambda r, o, c: compose_phone(r, o, c, 1284, 2778)),
        ("ipad-13",      "ipad-13",      "en", compose_pad),
        ("ipad-13-in",   "ipad-13-in",   "en", compose_pad),
        ("ipad-13-hi",   "ipad-13-hi",   "hi", compose_pad),
        ("ipad-13-es",   "ipad-13-es",   "es", compose_pad),
        ("mac",          "mac",          "en", compose_mac),
        ("mac-in",       "mac-in",       "en", compose_mac),
        ("mac-hi",       "mac-hi",       "hi", compose_mac),
        ("mac-es",       "mac-es",       "es", compose_mac),
        ("watch",        "watch",        "en", compose_watch),
        ("watch-in",     "watch-in",     "en", compose_watch),
        ("watch-hi",     "watch-hi",     "hi", compose_watch),
        ("watch-es",     "watch-es",     "es", compose_watch),
    ]

    # One swift invocation for every string in the run.
    wide = {"mac", "mac-in", "mac-hi", "mac-es",
            "ipad-13", "ipad-13-in", "ipad-13-hi", "ipad-13-es"}
    specs, tables = [], {}
    for src, dst, locale, _ in jobs:
        srcdir = os.path.join(RAW, src)
        if not os.path.isdir(srcdir):
            continue
        if dst.startswith("watch"):
            # Keyed by screen suffix; compose_watch resolves the filename itself.
            tables[dst] = WATCH_COPY_BY_LOCALE[locale]
            for title, sub in tables[dst].values():
                specs += [(line, "bold", INK) for line in title.split("\n")]
                specs.append((sub, "medium", MUTED))
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

    only = {x for x in os.environ.get("SETS", "").split(",") if x}
    for src, dst, locale, fn in jobs:
        if only and dst not in only:
            continue
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
            if not dst.startswith("watch") and key not in table:
                # A raw capture with no headline copy — don't guess one.
                print(f"skip {dst}/{name}: no copy for '{key}'")
                continue
            fn(os.path.join(srcdir, name), os.path.join(outdir, name), table)
            print(dst, name)


if __name__ == "__main__":
    main()
