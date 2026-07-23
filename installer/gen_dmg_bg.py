#!/usr/bin/env python3
"""Generate the Iris DMG background (380x800) — tall layout for large video icon.

Icon positions (icon-size 150, all centers):
  Applications  (190, 100)
  arrow         (190, 240)   <- background art only
  Iris.app      (190, 370)
  pointing hand              <- background art, lower-left
  Download Instructions.mp4 (190, 660)
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 380, 800
CX = 190


def key_white(im, thr=245):
    im = im.convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


def contain(im, box_w, box_h):
    w, h = im.size
    s = min(box_w / w, box_h / h)
    return im.resize((round(w * s), round(h * s)), Image.LANCZOS)


# ---- backdrop ----
bg = Image.open(os.path.join(A, "dmg-reference.jpg")).convert("RGBA").resize((W, H), Image.LANCZOS)

# ---- chalk arrow: centered between Applications (100) and Iris.app (370) ----
arrow = key_white(Image.open(os.path.join(A, "arrow.png")))
arrow = contain(arrow, 55, 70)
bg.alpha_composite(arrow, (CX - arrow.width // 2, 240 - arrow.height // 2))

# ---- pointing hand: lower-left, fingertip toward the video icon ----
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 160, 107)
bg.alpha_composite(finger, (-15, 490))

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
