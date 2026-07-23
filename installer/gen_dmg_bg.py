#!/usr/bin/env python3
"""Generate the Iris DMG background (440x850).

Composition (top to bottom), matching the create-dmg icon/link positions:
  Applications (220,110) -> arrow (220,290) -> Iris.app (220,430)
  -> pointing hand, lower-left -> "How to Install Iris.mp4" (220,670)

The install-video file is a REAL, visible file placed by create-dmg (not
drawn here) — replacing an earlier invisible-webloc-over-a-drawn-pill hack
that turned out to be broken in practice: Finder requires a double-click to
open an item, but a drawn "button" visually invites a single click, and an
invisible icon gives zero feedback either way. A real file with Finder's own
icon/thumbnail and label doesn't have either problem.

The window is taller than the top composition alone needs (850, not ~700)
because that video file's Finder footprint (icon-size 128 + label) needs
room below the hand — sizing this too tight is what caused the earlier
"scroll down and see white" bug (Finder's scrollable canvas extending past
the bottom of the background image).

Just the backdrop plus two pasted elements: the chalk arrow and the pointing
hand. No text, no dark plates — Finder draws the Applications/Iris/video
labels itself (see create-dmg call for --text-size).

The app icon, Applications alias, and video file are placed by create-dmg,
NOT drawn here. Outputs installer/dmg_background.png.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 440, 850
CX = 220


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

# ---- chalk arrow: points up, between the Applications icon (110) and the
# Iris icon (430) ----
arrow = key_white(Image.open(os.path.join(A, "arrow.png")))
arrow = contain(arrow, 70, 130)
bg.alpha_composite(arrow, (CX - arrow.width // 2, 290 - arrow.height // 2))

# ---- pointing hand: lower-left, toward the video file's icon slot ----
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 175, 118)
bg.alpha_composite(finger, (-25, 515))

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
