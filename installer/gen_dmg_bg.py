#!/usr/bin/env python3
"""
Generate Iris DMG background (460×360) → installer/dmg_background.png

Composites only:
  Arrow  48×60  center (230, 150)
  Text line 1   center (230, 325) — 11pt white
  Text line 2   center (230, 342) — 9pt #AADDAA

Finder icons (create-dmg):
  --app-drop-link  230  60
  --icon "Iris.app" 230 235
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def remove_white_bg(im, thr=240):
    im = im.convert("RGBA")
    a  = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")

W, H = 460, 360


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
    tw   = bbox[2] - bbox[0]
    th   = bbox[3] - bbox[1]
    draw.text((cx - tw // 2, cy - th // 2), text, font=font, fill=fill)


# ── 1. Background: willow fills 460×360, center-cropped ──────────────────────
src   = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size
scale  = W / sw
new_h  = round(sh * scale)
src    = src.resize((W, new_h), Image.LANCZOS)
top    = max(0, (new_h - H) // 2)
bg     = src.crop((0, top, W, top + H)).convert("RGBA")


# ── 2. Arrow: 48×60, centered at (230, 150) ──────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((48, 60), Image.LANCZOS)
bg.alpha_composite(arrow, (230 - 24, 150 - 30))


# ── 3. Instruction text ───────────────────────────────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)

font11 = load_font(11)
font9  = load_font(9)

draw_centered(od, "Drag the Iris app icon into the Applications folder",
              230, 300, font11, (255, 255, 255, 255))
draw_centered(od, "First launch: right-click Iris → Open",
              230, 317, font9,  (170, 221, 170, 255))

bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print(f"wrote {OUT}  size={bg.size}")
