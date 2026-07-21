#!/usr/bin/env python3
"""Generate the Iris app icon: a stylized, detailed human iris at 1024x1024.

Layers are composited in the order described in the spec: base vignette, iris
body gradient (numpy per-pixel), radial fibers, collarette, crypts, pupil,
pupil glow, specular highlights, and a final outer vignette.

Outputs installer/icon_1024.png.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

random.seed(20)
np.random.seed(20)

SIZE = 1024
CX = CY = 512
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "icon_1024.png")


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


BLACK = hex_rgb("000000")
NAVY_EDGE = hex_rgb("0a0f1a")
IRIS_INNER = hex_rgb("1a2a6c")
IRIS_MID = hex_rgb("4B6BFB")
IRIS_OUTER = hex_rgb("0d3b4f")
GLOW_BLUE = hex_rgb("4B6BFB")

R_PUPIL = 155
R_IRIS_IN = 180
R_IRIS_MID = 320
R_IRIS_OUT = 460


def lerp(c1, c2, f):
    """Blend two RGB tuples/arrays by fraction f (0..1)."""
    f = np.clip(f, 0.0, 1.0)
    return [c1[i] + (c2[i] - c1[i]) * f for i in range(3)]


# ---------------------------------------------------------------- base + body
yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
dx = xx - CX
dy = yy - CY
r = np.sqrt(dx * dx + dy * dy)

img = np.zeros((SIZE, SIZE, 3), dtype=np.float64)

# 1. BASE — black center to dark navy edge.
base_f = np.clip(r / 724.0, 0, 1)
for i in range(3):
    img[:, :, i] = BLACK[i] + (NAVY_EDGE[i] - BLACK[i]) * base_f

# 2. IRIS BODY — radial gradient across the ring.
f1 = (r - R_IRIS_IN) / (R_IRIS_MID - R_IRIS_IN)   # inner -> mid
f2 = (r - R_IRIS_MID) / (R_IRIS_OUT - R_IRIS_MID)  # mid -> out
inner_mid = lerp(IRIS_INNER, IRIS_MID, f1)
mid_out = lerp(IRIS_MID, IRIS_OUTER, f2)

seg1 = (r >= R_IRIS_IN) & (r < R_IRIS_MID)
seg2 = (r >= R_IRIS_MID) & (r <= R_IRIS_OUT)
for i in range(3):
    img[:, :, i] = np.where(seg1, inner_mid[i], img[:, :, i])
    img[:, :, i] = np.where(seg2, mid_out[i], img[:, :, i])

# limbal ring — subtle deep-blue glow at the very outer edge
limbal = np.clip(1 - np.abs(r - 455) / 22.0, 0, 1) * 0.35
for i in range(3):
    img[:, :, i] = np.clip(img[:, :, i] + GLOW_BLUE[i] * limbal, 0, 255)

canvas = Image.fromarray(img.astype(np.uint8)).convert("RGBA")


def composite(overlay):
    global canvas
    canvas = Image.alpha_composite(canvas, overlay)


def new_overlay():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def polar(radius, angle_deg):
    a = math.radians(angle_deg)
    return CX + radius * math.cos(a), CY + radius * math.sin(a)


# 3. IRIS TEXTURE — radial fibers
ov = new_overlay()
d = ImageDraw.Draw(ov)
for _ in range(random.randint(180, 220)):
    angle = random.uniform(0, 360)
    wobble = random.uniform(-3, 3)
    width = random.randint(1, 2)
    alpha = int(255 * random.uniform(0.06, 0.12))
    x1, y1 = polar(190, angle)
    x2, y2 = polar(450, angle + wobble)
    d.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, alpha), width=width)
composite(ov)

# 4. COLLARETTE — jagged irregular ring near r=260
ov = new_overlay()
d = ImageDraw.Draw(ov)
bbox = [CX - 260, CY - 260, CX + 260, CY + 260]
for _ in range(random.randint(40, 50)):
    start = random.uniform(0, 360)
    end = start + random.uniform(3, 8)
    d.arc(bbox, start, end, fill=(255, 255, 255, int(255 * 0.20)), width=4)
composite(ov)

# 5. CRYPTS — small dark irregular patches within the ring
ov = new_overlay()
d = ImageDraw.Draw(ov)
for _ in range(random.randint(8, 12)):
    rad = random.uniform(R_IRIS_IN + 20, R_IRIS_OUT - 30)
    ang = random.uniform(0, 360)
    px, py = polar(rad, ang)
    w = random.uniform(5, 12)
    h = random.uniform(5, 12)
    d.ellipse([px - w, py - h, px + w, py + h], fill=(0, 0, 0, int(255 * 0.40)))
composite(ov)

# 6. PUPIL — solid black circle
ov = new_overlay()
d = ImageDraw.Draw(ov)
d.ellipse([CX - R_PUPIL, CY - R_PUPIL, CX + R_PUPIL, CY + R_PUPIL], fill=(0, 0, 0, 255))
composite(ov)

# 7. PUPIL GLOW — blue ring around the pupil edge (peak alpha at r=185)
glow = np.zeros((SIZE, SIZE, 4), dtype=np.float64)
peak = np.zeros_like(r)
rising = (r >= R_PUPIL) & (r < 185)
falling = (r >= 185) & (r <= 210)
peak = np.where(rising, (r - R_PUPIL) / (185 - R_PUPIL), peak)
peak = np.where(falling, 1 - (r - 185) / (210 - 185), peak)
alpha = np.clip(peak, 0, 1) * (255 * 0.30)
for i in range(3):
    glow[:, :, i] = GLOW_BLUE[i]
glow[:, :, 3] = alpha
composite(Image.fromarray(glow.astype(np.uint8)))

# 8. SPECULAR HIGHLIGHTS
ov = new_overlay()
d = ImageDraw.Draw(ov)
d.ellipse([580 - 18, 400 - 12, 580 + 18, 400 + 12], fill=(255, 255, 255, int(255 * 0.80)))
d.ellipse([445 - 8, 430 - 5, 445 + 8, 430 + 5], fill=(255, 255, 255, int(255 * 0.40)))
composite(ov)

# 9. OUTER VIGNETTE — darken the outer edge (r=430 unchanged .. r=500 black)
arr = np.array(canvas).astype(np.float64)
vig = np.clip((500 - r) / (500 - 430), 0, 1)   # 1 inside, 0 at/after 500
for i in range(3):
    arr[:, :, i] *= vig
canvas = Image.fromarray(arr.astype(np.uint8))

canvas.convert("RGB").save(OUT)
print("wrote", OUT)
