#!/usr/bin/env python3
"""Build the Iris app icon from the provided white logo.

Pastes iris-logo-white.png (as-is) centered on a 1024x1024 pure-black canvas,
fit within a ~700px box (aspect preserved — the logo is landscape), then applies
Apple-standard rounded corners (radius 224) via an alpha mask.

Outputs installer/icon_1024.png.
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
LOGO = os.path.join(HERE, "assets", "iris-logo-white.png")
OUT = os.path.join(HERE, "icon_1024.png")

SIZE = 1024
BOX = 680          # target region for the logo
RADIUS = 224       # Apple-standard corner radius

canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))

logo = Image.open(LOGO).convert("RGBA")
lw, lh = logo.size
scale = min(BOX / lw, BOX / lh)          # contain within 700x700, keep aspect
nw, nh = round(lw * scale), round(lh * scale)
logo = logo.resize((nw, nh), Image.LANCZOS)
canvas.alpha_composite(logo, ((SIZE - nw) // 2, (SIZE - nh) // 2))

# Rounded-corner alpha mask.
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE, SIZE], radius=RADIUS, fill=255)
canvas.putalpha(mask)

canvas.save(OUT)
print("wrote", OUT)
