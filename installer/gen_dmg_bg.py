#!/usr/bin/env python3
"""Generate the Iris DMG background — premium, spacious layout (440x720).

Composition (top to bottom), matching the create-dmg icon/link positions:
  Applications (220,160) -> arrow (220,325) -> Iris.app (220,460)
  -> pointing hand, lower-left -> DOWNLOAD INSTRUCTIONS pill (220,660)

Just the backdrop plus three pasted elements: the chalk arrow, the pointing
hand, and the pill. No text labels, no dark plates — Finder draws the
Applications/Iris labels itself (see create-dmg call for --text-size / hide
tricks used to keep those unobtrusive).

The app icon and Applications alias are placed by create-dmg, NOT drawn here.
Outputs installer/dmg_background.png.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 440, 720
CX = 220


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

# ---- chalk arrow: centered between the two icon slots, y=325 ----
arrow = key_white(Image.open(os.path.join(A, "arrow.png")))
arrow = contain(arrow, 70, 130)
bg.alpha_composite(arrow, (CX - arrow.width // 2, 325 - arrow.height // 2))

# ---- pointing hand: lower-left, pointing right toward the pill ----
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 175, 118)
bg.alpha_composite(finger, (-25, 555))

# ---- DOWNLOAD INSTRUCTIONS pill, center (220,660), larger + breathing room below ----
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
pw, ph, py = 300, 46, 660
x0, y0 = CX - pw // 2, py - ph // 2
od.rounded_rectangle([x0, y0, x0 + pw, y0 + ph], radius=23,
                     fill=hx("0a0a0a") + (255,),
                     outline=(255, 255, 255, 153), width=1)
f = font(11)
box = od.textbbox((0, 0), "DOWNLOAD INSTRUCTIONS", font=f)
od.text((CX - (box[2] - box[0]) / 2, py - (box[3] - box[1]) / 2 - box[1]),
        "DOWNLOAD INSTRUCTIONS", font=f, fill=(255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
