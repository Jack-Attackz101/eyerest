#!/usr/bin/env python3
"""Generate the Iris DMG background (600x800).

No logo, no drawn video. icon-size=170 makes the mp4 file icon 2x the
previous 85px. All drawn elements verified clear of real Finder icons.

Background art (drawn only):
  Arrow  80x100, center (300, 250) — clear of Apps label (+10px) and Iris icon top (+15px)
  Hand   point.png as-is (RGBA, no bg removal), contain(180,117), top-left (0, 570)
  Text   12pt white, center (300, 770)

Real icons placed by create-dmg (icon-size 170):
  app-drop-link at (300, 85)    top=0, bottom=170, label≈190
  Iris.app      at (300, 400)   top=315, bottom=485, label≈505
  mp4           at (300, 630)   top=545, bottom=715, label≈735  bottom gap 65px
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")
W, H = 600, 800


def contain(im, box_w, box_h):
    w, h = im.size
    s = min(box_w / w, box_h / h)
    return im.resize((round(w * s), round(h * s)), Image.LANCZOS)


def remove_white_bg(im, thr=245):
    im = im.convert("RGBA")
    a  = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


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


# ── 1. Background: willow canopy, 600x800 ─────────────────────────────────────
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size                                     # 736 × 1308
src = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg  = src.crop((0, 0, W, H)).convert("RGBA")

# ── 2. Arrow: 80x100, center (300, 250) ──────────────────────────────────────
#    top=200  clear of Apps label bottom (~190) by 10px
#    bottom=300  clear of Iris icon top (315) by 15px
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((80, 100), Image.LANCZOS)
bg.alpha_composite(arrow, (300 - 40, 250 - 50))      # top-left (260, 200)

# ── 3. Pointing hand: point.png (already RGBA), tip at x≈180, mp4 left=215 (+35px gap)
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 180, 117)
bg.alpha_composite(finger, (0, 570))

# ── 4. Instruction text ────────────────────────────────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font12  = load_font(12)
draw_centered(od, "Drag Iris to Applications to install", 300, 770, font12, (255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
