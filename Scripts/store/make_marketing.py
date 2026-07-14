#!/usr/bin/env python3
"""Compose App Store marketing screenshots: raw capture -> device frame +
headline + soft branded background. Outputs exact ASC-accepted sizes."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/System/Library/Fonts/HelveticaNeue.ttc"
INK = (17, 24, 39, 255)          # #111827
MUTED = (75, 85, 99, 255)        # #4b5563
GREEN = (60, 215, 157)           # brand #3cd79d
BLUE = (96, 165, 250)

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Docs", "Store", "screenshots")
OUT = os.path.join(RAW, "marketing")

COPY = {
    "01-dashboard":   ("Everything at\na Glance",      "Income, spending, budgets, and goals in one place"),
    "02-transactions":("Track Every\nTransaction",     "Ten-second capture with instant search and filters"),
    "03-budgets":     ("Budgets That\nKeep Up",        "Per-category limits with overspend warnings"),
    "04-savings":     ("Achieve Your\nSavings Goals",  "Set a target and watch the progress ring fill"),
    "05-reports":     ("Reports That\nExplain",        "Category breakdowns, trends, and cash flow"),
}
# Wide canvases fit the headline on one line
COPY_WIDE = {k: (t.replace("\n", " "), s) for k, (t, s) in COPY.items()}


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
    d = ImageDraw.Draw(img)
    w = img.width
    y = top
    for line in title.split("\n"):
        tw = d.textlength(line, font=font(title_size))
        d.text(((w - tw) // 2, y), line, font=font(title_size), fill=INK)
        y += int(title_size * 1.14)
    y += gap
    tw = d.textlength(sub, font=font(sub_size, 10))
    d.text(((w - tw) // 2, y), sub, font=font(sub_size, 10), fill=MUTED)
    return y + int(sub_size * 1.3)


def compose_phone(raw_path, out_path, W, H):
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = COPY[key]
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


def compose_pad(raw_path, out_path, W=2752, H=2064):
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = COPY_WIDE[key]
    img = background(W, H)
    bottom = draw_copy(img, title, sub, int(H * 0.055), int(W * 0.042), int(W * 0.017), int(W * 0.012))
    shot = Image.open(raw_path).convert("RGB")
    avail_h = H - bottom - int(H * 0.04)
    bezel = int(W * 0.011)
    screen_h = avail_h + int(H * 0.06)
    screen_w = int(screen_h * shot.width / shot.height)
    dev, margin = device(shot, screen_w, corner=int(W * 0.028), bezel=bezel)
    img.alpha_composite(dev, ((W - dev.width) // 2, bottom + int(H * 0.02) - margin + bezel * 2))
    img = img.crop((0, 0, W, H))
    img.convert("RGB").save(out_path, "PNG")


def compose_mac(raw_path, out_path, W=1440, H=900):
    key = os.path.splitext(os.path.basename(raw_path))[0]
    title, sub = COPY_WIDE[key]
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
    jobs = [
        ("iphone-69", "iphone-69", lambda r, o: compose_phone(r, o, 1320, 2868)),
        ("iphone-69", "iphone-65", lambda r, o: compose_phone(r, o, 1284, 2778)),
        ("ipad-13", "ipad-13", compose_pad),
        ("mac", "mac", compose_mac),
    ]
    for src, dst, fn in jobs:
        outdir = os.path.join(OUT, dst)
        os.makedirs(outdir, exist_ok=True)
        for name in sorted(os.listdir(os.path.join(RAW, src))):
            if not name.endswith(".png"):
                continue
            fn(os.path.join(RAW, src, name), os.path.join(outdir, name))
            print(dst, name)


if __name__ == "__main__":
    main()
