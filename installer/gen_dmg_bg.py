#!/usr/bin/env python3
"""Generate the Iris DMG background (600x650).

icon-size=85 → apps 2x smaller than previous 170.
Finder enforces one icon size per window; mp4 is also 85px.

Spacing verified (all coordinates are icon centers in Finder space):
  app-drop-link  y=60   icon bottom=103, label bottom≈122
  Arrow          y=175  top=135  (+13 from Apps label) bottom=215
  Iris.app       y=305  top=262  (+47 from arrow bottom) label bottom≈365
  mp4            y=490  top=447  (+82 from Iris label)  bottom=533
  Hand tip       x≈219  mp4 left edge x=257  (+38px gap)
  Text           y=630  window=650  (+20px margin at bottom)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")
W, H = 600, 650


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


# ── 1. Background: willow canopy, 600x650 ─────────────────────────────────────
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size                                    # 736 × 1308
src = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg  = src.crop((0, 0, W, H)).convert("RGBA")

# ── 2. Arrow: 65x80, center (300, 175) ───────────────────────────────────────
#    top=135  Apps label bottom≈122  gap +13px
#    bottom=215  Iris icon top=262   gap +47px
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((65, 80), Image.LANCZOS)
bg.alpha_composite(arrow, (300 - 32, 175 - 40))     # top-left (268, 135)

# ── 3. Pointing hand: point.png RGBA, moved up, tip≈x219 vs mp4 left x257 (+38px)
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 220, 143)                   # 219x143 from 196x128
bg.alpha_composite(finger, (0, 440))                 # tip at (219, 511), mp4 center y=490

# ── 4. Instruction text ────────────────────────────────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font12  = load_font(12)
draw_centered(od, "Drag Iris to Applications to install", 300, 630, font12, (255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
