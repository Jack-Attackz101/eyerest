#!/usr/bin/env python3
"""Generate the DMG background: a Japanese-woodblock weeping-willow scene.

A 540x340 nocturne — deep emerald canopy hanging from the top, ink-black trunks,
a dock line with distant silhouetted figures, and still dark water with ripples
and trunk reflections. Scene only: the app icon and Applications alias are placed
by create-dmg, so they are NOT drawn here.

Outputs installer/dmg_background.png.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont

random.seed(11)
np.random.seed(11)

W, H = 540, 360   # 20px taller than the 540x340 window to fit the first-launch note
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "dmg_background.png")
GROUND = 214
WATERLINE = 220


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


LEAF_COLORS = [hx("1a3d1a"), hx("2d5c2d"), hx("3a6e3a"), hx("4a8a4a")]


def load_serif(size):
    # Times New Roman first — it carries the → glyph that Times.ttc lacks.
    for path in ("/System/Library/Fonts/Supplemental/Times New Roman.ttf",
                 "/System/Library/Fonts/Times.ttc",
                 "/System/Library/Fonts/Georgia.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def centered(d, cx, y, text, font, fill):
    box = d.textbbox((0, 0), text, font=font)
    d.text((cx - (box[2] - box[0]) / 2, y), text, font=font, fill=fill)


# ---- LAYER 1: base radial gradient ----
yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
cx, cy = W / 2, H / 2
dist = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
dist = np.clip(dist, 0, 1)
center_c, edge_c = np.array(hx("142a17")), np.array(hx("080f09"))
base = np.zeros((H, W, 3))
for i in range(3):
    base[:, :, i] = center_c[i] + (edge_c[i] - center_c[i]) * dist

# ---- LAYER 7 (prepared): atmospheric glow at (270,180) ----
glow = np.exp(-(((xx - 270) ** 2 + (yy - 180) ** 2) / (2 * 120 ** 2)))
glow_c = np.array(hx("2d5c2d"))
for i in range(3):
    base[:, :, i] += glow_c[i] * glow * 0.08

img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")

# ---- LAYER 2: willow canopy ----
canopy = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cd = ImageDraw.Draw(canopy)
origins = sorted(random.sample(range(0, W), random.randint(8, 12)))
for ox in origins:
    for _ in range(random.randint(15, 25)):
        length = random.randint(80, 180)
        drift = random.uniform(-30, 30)
        color = random.choice(LEAF_COLORS)
        alpha = random.randint(102, 204)   # 40–80%
        pts = []
        for step in range(0, length, 3):
            t = step / length
            x = ox + drift * (t ** 1.3) + math.sin(t * math.pi) * 2
            pts.append((x, step))
        if len(pts) > 1:
            cd.line(pts, fill=color + (alpha,), width=1)
        # leaf marks at the tip
        ex, ey = pts[-1]
        for _ in range(random.randint(3, 5)):
            lx = ex + random.uniform(-3, 3)
            ly = ey + random.uniform(-2, 6)
            cd.ellipse([lx - 1, ly - 2, lx + 1, ly + 2], fill=color + (alpha,))
img = Image.alpha_composite(img, canopy)
draw = ImageDraw.Draw(img)

# ---- LAYER 3: tree trunks (ink black, tapering, slight curve) ----
def draw_trunk(base_x, curve):
    ink = hx("050f06")
    for y in range(0, 221):
        t = y / 220
        width = 12 - 6 * t
        x = base_x + curve * (t ** 2)
        draw.line([(x - width / 2, y), (x + width / 2, y)], fill=ink, width=1)

draw_trunk(60, curve=18)          # left main trunk, curves rightward
draw_trunk(515, curve=-10)        # right partial trunk

# ---- LAYER 4: ground / dock line ----
draw.rectangle([0, GROUND, W, WATERLINE], fill=hx("0d1f12"))
draw.line([(0, GROUND), (W, GROUND)], fill=hx("1a3d1a"), width=1)

# ---- LAYER 5: water ----
draw.rectangle([0, WATERLINE, W, H], fill=hx("0a1a0d"))
water = Image.new("RGBA", (W, H), (0, 0, 0, 0))
wd = ImageDraw.Draw(water)
for _ in range(36):
    ry = random.randint(WATERLINE + 5, H - 5)
    phase = random.uniform(0, math.tau)
    alpha = random.randint(15, 46)   # 6–18%
    pts = [(x, ry + math.sin(x / 12 + phase) * 2) for x in range(0, W, 3)]
    wd.line(pts, fill=hx("1a3d1a") + (alpha,), width=1)
# trunk reflections below the waterline
for base_x, w in ((60, 12), (515, 10)):
    for y in range(WATERLINE, H):
        wob = random.uniform(-2, 2)
        x = base_x + wob
        wd.line([(x - w / 2, y), (x + w / 2, y)], fill=hx("050f06") + (128,), width=1)
img = Image.alpha_composite(img, water)
draw = ImageDraw.Draw(img)

# ---- LAYER 6: silhouette figures on the dock ----
fig = hx("030a04")
xs = sorted(random.sample(range(180, 370), 6))
for x in xs:
    seated = random.random() < 0.3
    body_h = 6 if seated else 10
    top_y = GROUND - body_h
    draw.rectangle([x, top_y, x + 3, GROUND], fill=fig)
    draw.ellipse([x - 1, top_y - 5, x + 4, top_y], fill=fig)

# ---- ARROW (soft blue, between the two icon slots) ----
blue = hx("7BAFD4")
draw.line([(195, 150), (345, 150)], fill=blue, width=2)
draw.line([(345, 150), (333, 142)], fill=blue, width=2)
draw.line([(345, 150), (333, 158)], fill=blue, width=2)

# ---- TYPOGRAPHY ----
centered(draw, 270, 28, "iris", load_serif(15), hx("4a7a4a"))
centered(draw, 135, 205, "Iris", load_serif(15), hx("c8dcc8"))
centered(draw, 135, 224, "Version 2.0", load_serif(11), hx("5a7a5a"))
centered(draw, 405, 205, "Applications", load_serif(15), hx("c8dcc8"))
centered(draw, 270, 300, "Drag Iris to Applications to install", load_serif(12), hx("5a8a5a"))

# First-launch (Gatekeeper) instructions.
centered(draw, 270, 322, "First launch: right-click Iris → Open → Open", load_serif(12), hx("8ab88a"))
centered(draw, 270, 338, "macOS will ask to verify the app on first open only", load_serif(10), hx("5a7a5a"))

img.convert("RGB").save(OUT)
print("wrote", OUT)
