#!/usr/bin/env python3
"""Generate the Iris DMG background (380x460) — final clean layout.

Just the backdrop plus three pasted elements: the chalk arrow, the pointing
hand, and the DOWNLOAD INSTRUCTIONS pill. No text labels, no dark plates —
Finder draws the Applications/Iris labels itself.

The app icon and Applications alias are placed by create-dmg, NOT drawn here.
Outputs installer/dmg_background.png.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 380, 500
CX = 190


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def font(size):
    for p in ("/System/Library/Fonts/Helvetica.ttc",
              "/System/Library/Fonts/Supplemental/Times New Roman.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()


def key_white(im, thr=245):
    """alpha=0 only where R,G,B all exceed thr (near-pure-white only)."""
    im = im.convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


# ---- backdrop ----
bg = Image.open(os.path.join(A, "dmg-reference.jpg")).convert("RGBA").resize((W, H), Image.LANCZOS)

# ---- chalk arrow: rotated 90° left (CCW) to lie horizontal, centered at (190,100) ----
arrow = key_white(Image.open(os.path.join(A, "arrow.png"))).resize((55, 70), Image.LANCZOS)
arrow = arrow.rotate(90, expand=True)          # 90° left → points horizontally
bg.alpha_composite(arrow, (CX - arrow.width // 2, 100 - arrow.height // 2))

# ---- pointing hand: clean transparent PNG — load as-is, no keying, 150x100 ----
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA").resize((150, 100), Image.LANCZOS)
bg.alpha_composite(finger, (-20, 285))

# ---- DOWNLOAD INSTRUCTIONS pill on an RGBA overlay (for 60% border alpha) ----
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
pw, ph, py = 240, 32, 415
x0, y0 = CX - pw // 2, py - ph // 2
od.rounded_rectangle([x0, y0, x0 + pw, y0 + ph], radius=16,
                     fill=hx("0a0a0a") + (255,),
                     outline=(255, 255, 255, 153), width=1)
f = font(10)
box = od.textbbox((0, 0), "DOWNLOAD INSTRUCTIONS", font=f)
od.text((CX - (box[2] - box[0]) / 2, py - (box[3] - box[1]) / 2 - box[1]),
        "DOWNLOAD INSTRUCTIONS", font=f, fill=(255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
