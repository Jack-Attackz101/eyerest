#!/usr/bin/env python3
"""Generate the Iris DMG background (380x460) — tight spacing grid.

Composition (top to bottom), matching the create-dmg icon/link positions:
  Applications (190,55) -> arrow (190,140) -> Iris.app (190,225)
  -> pointing hand, lower-left -> DOWNLOAD INSTRUCTIONS pill (190,360)
  -> ~80px clear margin below the pill to the window bottom (460)

This reverts to a purely decorative pill (no clickable overlay, no add-file)
— a compact, no-dead-space window doesn't have room for the oversized
Finder footprint a visible/invisible extra item needs (see prior git log
for that saga). If the install-video file should be back in the DMG,
that's a separate, explicit follow-up — this pass is positioning only.

Just the backdrop plus the chalk arrow, the pointing hand, and the pill.
Finder draws the Applications/Iris labels itself.

The app icon and Applications alias are placed by create-dmg, NOT drawn
here. Outputs installer/dmg_background.png.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 380, 460
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


def contain(im, box_w, box_h):
    """Resize preserving aspect ratio to fit within box_w x box_h."""
    w, h = im.size
    s = min(box_w / w, box_h / h)
    return im.resize((round(w * s), round(h * s)), Image.LANCZOS)


# ---- backdrop ----
bg = Image.open(os.path.join(A, "dmg-reference.jpg")).convert("RGBA").resize((W, H), Image.LANCZOS)

# ---- chalk arrow: points up, centered between Applications (55) and Iris (225) ----
arrow = key_white(Image.open(os.path.join(A, "arrow.png")))
arrow = contain(arrow, 45, 58)
bg.alpha_composite(arrow, (CX - arrow.width // 2, 140 - arrow.height // 2))

# ---- pointing hand: lower-left, fingertip toward the pill ----
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 135, 90)
bg.alpha_composite(finger, (-15, 310))

# ---- DOWNLOAD INSTRUCTIONS pill, center (190,360) ----
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
pw, ph, py = 220, 32, 360
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
