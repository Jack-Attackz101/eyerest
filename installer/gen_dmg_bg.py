#!/usr/bin/env python3
"""Generate the Iris DMG background (540x340).

Scene only — no UI chrome. Crops the willow-woodblock art to canvas size,
keeping the upper canopy so both icon drop zones (x≈135,y≈150 and x≈405,y≈150)
land on calm leafy background.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 540, 340

# Scale reference to fill 540 wide, then take top 340px.
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size
scale = W / sw
new_h = round(sh * scale)
src = src.resize((W, new_h), Image.LANCZOS)
bg = src.crop((0, 0, W, H))

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
