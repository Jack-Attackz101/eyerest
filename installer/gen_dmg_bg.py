#!/usr/bin/env python3
"""Generate the Iris DMG background (540x400).

Matches the reference image exactly per spec:
  Background     dmg-reference.jpg resized to 540x400
  Iris logo      iris-logo-black.png, 80x80, centered (270, 40)
  Arrow          arrow.png, 65x80 exact, centered (270, 200)
  Hand           point.png, contain(140,100), top-left (0, 310)
  "Applications" white 13pt, centered (270, 130)
  "Iris"         white 13pt, centered (270, 280)
  Pill           260x34 r=17, fill #111111, border white, "DOWNLOAD INSTRUCTIONS" 10pt
  Instruction    "Drag Iris to Applications to install" #CCCCCC 11pt, centered (270, 376)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 540, 400


def remove_white_bg(im, thr=245):
    im = im.convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


def contain(im, box_w, box_h):
    w, h = im.size
    s = min(box_w / w, box_h / h)
    return im.resize((round(w * s), round(h * s)), Image.LANCZOS)


def load_font(size):
    for path in [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
    ]:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_centered(draw, text, cx, cy, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2, cy - th // 2), text, font=font, fill=fill)


# ── 1. Background ─────────────────────────────────────────────────────────────
bg = (
    Image.open(os.path.join(A, "dmg-reference.jpg"))
    .convert("RGBA")
    .resize((W, H), Image.LANCZOS)
)

# ── 2. Iris logo: 80×80 exact, centered at (270, 40) ─────────────────────────
logo = remove_white_bg(Image.open(os.path.join(A, "iris-logo-black.png")))
logo = logo.resize((80, 80), Image.LANCZOS)
bg.alpha_composite(logo, (270 - 40, 40 - 40))   # top-left = (230, 0)

# ── 3. Chalk arrow: 65×80 exact, centered at (270, 200) ──────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((65, 80), Image.LANCZOS)
bg.alpha_composite(arrow, (270 - 32, 200 - 40))  # top-left = (238, 160)

# ── 4. Pointing hand: contain(140,100), top-left at (0, 310) ─────────────────
finger = remove_white_bg(Image.open(os.path.join(A, "point.png")))
finger = contain(finger, 140, 100)
bg.alpha_composite(finger, (0, 310))

# ── 5–8. Text overlay and pill ────────────────────────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)

font13 = load_font(13)
font11 = load_font(11)
font10 = load_font(10)

# "Applications" label
draw_centered(od, "Applications", 270, 130, font13, (255, 255, 255, 255))

# "Iris" label
draw_centered(od, "Iris", 270, 280, font13, (255, 255, 255, 255))

# DOWNLOAD INSTRUCTIONS pill: 260×34, radius 17, fill #111111, border white 1px
PW, PH, PR = 260, 34, 17
px0 = 270 - PW // 2
py0 = 340 - PH // 2
px1 = px0 + PW
py1 = py0 + PH
od.rounded_rectangle(
    [px0, py0, px1, py1],
    radius=PR,
    fill=(17, 17, 17, 255),
    outline=(255, 255, 255, 255),
    width=1,
)
draw_centered(od, "DOWNLOAD INSTRUCTIONS", 270, 340, font10, (255, 255, 255, 255))

# Instruction text
draw_centered(
    od, "Drag Iris to Applications to install", 270, 376, font11, (204, 204, 204, 255)
)

bg = Image.alpha_composite(bg, overlay)
bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
