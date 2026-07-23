#!/usr/bin/env python3
"""Generate the Iris DMG background (380x460).

Composition (top to bottom):
  Applications (190,55) -> arrow (190,140) -> Iris.app (190,225)
  -> pointing hand, lower-left
  -> "Download Instructions.mp4" video file placed by create-dmg at (190,390)

Pill is no longer drawn here — the video file's own thumbnail + Finder label
serves as the clickable "Download Instructions" element.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 380, 460
CX = 190


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

# ---- pointing hand: lower-left, fingertip toward the video icon area ----
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 135, 90)
bg.alpha_composite(finger, (-15, 270))

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
