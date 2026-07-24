#!/usr/bin/env python3
"""Generate the Iris DMG background (600x800).

icon-size=160 (half=80) — all icons same size, mp4 shows real video thumbnail.
  app-drop-link  y=80   icon top=0    bottom=160  label bottom≈180
  Arrow          y=245  top=205  gap=25px  bottom=285
  Iris.app       y=380  top=300  gap=15px  label bottom≈480
  mp4            y=580  top=500  gap=20px  label bottom≈680
  Hand           (0, 530) tip x≈120  mp4 left edge x=220  gap=100px
  Text           y=755  window=800  bottom margin 45px
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
sw, sh = src.size                                    # 736 × 1308
src = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg  = src.crop((0, 0, W, H)).convert("RGBA")

# ── 2. Arrow: 65x80, center (300, 245) ───────────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((65, 80), Image.LANCZOS)
bg.alpha_composite(arrow, (300 - 32, 245 - 40))     # top-left (268, 205)

# ── 3. Pointing hand: point.png RGBA, tip x≈120, mp4 left edge x=220, gap≈100px
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 130, 85)                    # 130x85 from 196x128
bg.alpha_composite(finger, (0, 530))

# ── 4. Instruction text ────────────────────────────────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font12  = load_font(12)
draw_centered(od, "Drag Iris to Applications to install", 300, 755, font12, (255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
