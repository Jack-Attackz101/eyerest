#!/usr/bin/env python3
"""Generate the DMG background: a zen willow-and-water woodblock scene (660x400).

Deep green gradient with impressionistic hanging-willow drip lines, a still-water
reflection with ripples and shoreline figures, the Iris app icon on the left, a
simplified Applications folder on the right, and a soft-blue install arrow.

Outputs installer/dmg_background.png.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

random.seed(7)
np.random.seed(7)

W, H = 660, 400
HERE = os.path.dirname(os.path.abspath(__file__))
ICON = os.path.join(HERE, "icon_1024.png")
OUT = os.path.join(HERE, "dmg_background.png")
WATERLINE = 260


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def load_font(size):
    for path in ("/System/Library/Fonts/Helvetica.ttc",
                 "/System/Library/Fonts/HelveticaNeue.ttc"):
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def centered(d, cx, y, text, font, fill):
    box = d.textbbox((0, 0), text, font=font)
    d.text((cx - (box[2] - box[0]) / 2, y), text, font=font, fill=fill)


# ---- base: deep green gradient, lighter below the waterline ----
top, bot = np.array(hx("1a2e1a")), np.array(hx("0f1a0f"))
water = np.array(hx("1f351f"))
arr = np.zeros((H, W, 3), dtype=np.float64)
for y in range(H):
    if y < WATERLINE:
        arr[y, :, :] = top + (bot - top) * (y / WATERLINE)
    else:
        arr[y, :, :] = water
img = Image.fromarray(arr.astype(np.uint8)).convert("RGBA")

# ---- willow drip lines (hanging branches) ----
drips = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dd = ImageDraw.Draw(drips)
drip_color = hx("2d4a2d")
for _ in range(260):
    x = random.randint(0, W)
    y0 = random.randint(0, 60)
    length = random.randint(60, 140)
    width = random.randint(1, 2)
    alpha = random.randint(51, 128)   # 20–50%
    pts = [(x + math.sin(y / 20) * 3, y) for y in range(y0, min(y0 + length, WATERLINE))]
    if len(pts) > 1:
        dd.line(pts, fill=drip_color + (alpha,), width=width)
img = Image.alpha_composite(img, drips)

# ---- waterline + ripples ----
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
od.line([(0, WATERLINE), (W, WATERLINE)], fill=hx("3d6b3d") + (76,), width=1)  # 30%
ripple_color = hx("4a7a4a")
for _ in range(24):
    ry = random.randint(WATERLINE + 10, 380)
    alpha = random.randint(20, 38)   # 8–15%
    pts = [(x, ry + math.sin(x / 30) * 1.5) for x in range(0, W, 4)]
    od.line(pts, fill=ripple_color + (alpha,), width=1)
img = Image.alpha_composite(img, overlay)

draw = ImageDraw.Draw(img)

# ---- shoreline silhouette figures at the waterline ----
fig = hx("0a1a0a")
xs = sorted(random.sample(range(80, 320), 6))
for x in xs:
    drop = random.randint(0, 4)   # some sitting slightly lower
    top_y = WATERLINE - 12 + drop
    draw.rectangle([x, top_y, x + 4, top_y + 12], fill=fig)          # body
    draw.ellipse([x - 1, top_y - 7, x + 5, top_y - 1], fill=fig)     # head

# ---- app icon (left), with a soft drop shadow ----
if os.path.exists(ICON):
    icon = Image.open(ICON).convert("RGBA").resize((120, 120), Image.LANCZOS)
    shadow = ImageEnhance.Brightness(icon).enhance(0.15)
    shadow.putalpha(102)   # 40%
    img.alpha_composite(shadow, (50 + 2, 80 + 3))
    img.alpha_composite(icon, (50, 80))   # center ~ (110,140)
draw = ImageDraw.Draw(img)
centered(draw, 110, 210, "Iris", load_font(18), hx("e8f0e8"))
centered(draw, 110, 234, "Version 2.0", load_font(12), hx("7a9a7a"))

# ---- vertical divider ----
draw.line([(330, 80), (330, 320)], fill=hx("3d6b3d") + (102,), width=1)

# ---- Applications folder (right), center ~ (440,140) ----
fx0, fy0 = 390, 100
draw.rounded_rectangle([fx0, fy0 - 10, fx0 + 45, fy0 + 6], radius=4, fill=hx("2d5a3d"))          # tab
draw.rounded_rectangle([fx0, fy0, fx0 + 100, fy0 + 80], radius=10, fill=hx("2d5a3d"))            # body
draw.rounded_rectangle([fx0, fy0, fx0 + 100, fy0 + 80], radius=10, outline=hx("4a7a5a"), width=1)
centered(draw, 440, 192, "Applications", load_font(14), hx("e8f0e8"))

# ---- soft-blue install arrow ----
blue = hx("7BAFD4")
draw.line([(280, 190), (340, 190)], fill=blue, width=2)
for sign in (-1, 1):
    ex = 340 - 12 * math.cos(math.radians(35))
    ey = 190 + sign * 12 * math.sin(math.radians(35))
    draw.line([(340, 190), (ex, ey)], fill=blue, width=2)

# ---- text marks ----
centered(draw, 330, 40, "iris", load_font(16), hx("3d6b3d"))
centered(draw, 330, 360, "Drag Iris to Applications to install", load_font(13), hx("a0c0a0"))

img.convert("RGB").save(OUT)
print("wrote", OUT)
