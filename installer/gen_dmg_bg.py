#!/usr/bin/env python3
"""Generate the Iris DMG background — premium, spacious layout (440x850).

Composition (top to bottom), matching the create-dmg icon/link positions:
  Applications (220,110) -> arrow (220,290) -> Iris.app (220,430)
  -> pointing hand, lower-left -> DOWNLOAD INSTRUCTIONS pill (220,670)

The window is taller than the visible composition needs (850, not ~700)
specifically because the invisible clickable .webloc placed over the pill
inherits the window's global --icon-size (128) plus its Finder label
reservation — its real footprint extends ~115px below the pill's visual
center. Undersizing the window here is what caused the earlier "scroll down
and see white" bug: Finder expanded the scrollable canvas past the bottom of
the background image. The extra height keeps that footprint (and the visual
pill's own bottom margin) safely inside the frame.

Just the backdrop plus three pasted elements: the chalk arrow, the pointing
hand, and the pill. No text labels, no dark plates — Finder draws the
Applications/Iris labels itself (see create-dmg call for --text-size).

The app icon and Applications alias are placed by create-dmg, NOT drawn here.
Outputs installer/dmg_background.png.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 440, 850
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

# ---- chalk arrow: points up (confirmed from the source asset), between the
# Applications icon (110) and the Iris icon (430) ----
arrow = key_white(Image.open(os.path.join(A, "arrow.png")))
arrow = contain(arrow, 70, 130)
bg.alpha_composite(arrow, (CX - arrow.width // 2, 290 - arrow.height // 2))

# ---- pointing hand: lower-left. Moved up from y=555 so its opaque pixels
# (verified via alpha bbox, not eyeballed) clear the pill by ~37px instead
# of overlapping it by 13px. ----
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 175, 118)
bg.alpha_composite(finger, (-25, 515))

# ---- DOWNLOAD INSTRUCTIONS pill, center (220,670) ----
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
pw, ph, py = 300, 46, 670
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
