#!/usr/bin/env python3
"""
Generate Iris DMG background (500×420) → installer/dmg_background.png

Willow image fills entire canvas. NO fake video player or website screenshots.

Background-only composites:
  Arrow   50×62   center (250, 175)
  Hand    120×80  at     ( 15, 330)
  Frame   110×110 outline, 3px white stroke, r=12, center (250, 345)
  Text    10pt    center (250, 408)

Finder icons (via create-dmg):
  --app-drop-link            250  70   Applications folder
  --icon "Iris.app"          250 250
  --add-file "How to Install Iris.mp4" ... 250 345  ← inside the frame
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")

W, H = 500, 420


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


# ── 1. Background: willow fills 500×420, center-cropped ──────────────────────
src   = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size
scale  = W / sw
new_h  = round(sh * scale)
src    = src.resize((W, new_h), Image.LANCZOS)
top    = max(0, (new_h - H) // 2)
bg     = src.crop((0, top, W, top + H)).convert("RGBA")


# ── 2. Arrow: 50×62, centered at (250, 175) ──────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((50, 62), Image.LANCZOS)
bg.alpha_composite(arrow, (250 - 25, 175 - 31))


# ── 3. Pointing hand: 120×80, at (15, 330) — do NOT remove_white_bg ──────────
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = finger.resize((120, 80), Image.LANCZOS)
bg.alpha_composite(finger, (15, 330))


# ── 4. Rounded rectangle frame + caption ─────────────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)

fx1, fy1 = 250 - 55, 345 - 55   # 195, 290
fx2, fy2 = 250 + 55, 345 + 55   # 305, 400
od.rounded_rectangle([(fx1, fy1), (fx2, fy2)], radius=12,
                     outline=(255, 255, 255, 200), width=3)

font10 = load_font(10)
draw_centered(od, "double-click to watch the install guide",
              250, 408, font10, (255, 255, 255, 180))

bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print(f"wrote {OUT}  size={bg.size}")
