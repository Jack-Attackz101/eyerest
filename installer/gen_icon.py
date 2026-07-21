#!/usr/bin/env python3
"""Generate the Iris app icon: a minimal Japanese brush-stroke eye mark.

Muji-meets-Hiroshige — a single almond eye outline, a sage iris ring, a dark
pupil, a few lash strokes and calligraphic corner dots on warm parchment.

Outputs installer/icon_1024.png.
"""
import math
import os

from PIL import Image, ImageDraw

SIZE = 1024
CX = CY = 512
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "icon_1024.png")


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


BEIGE = hex_rgb("F5F0E8")       # warm off-white background
DARK = hex_rgb("2C3B2D")        # dark forest green (almost black)
SAGE = hex_rgb("4A6741")        # sage green


def quad_bezier(p0, c, p2, steps=150):
    """Points along a quadratic bezier from p0 to p2 with control c."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1 - t
        x = mt * mt * p0[0] + 2 * mt * t * c[0] + t * t * p2[0]
        y = mt * mt * p0[1] + 2 * mt * t * c[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


img = Image.new("RGBA", (SIZE, SIZE), BEIGE + (255,))
draw = ImageDraw.Draw(img)

LEFT = (256, 512)
RIGHT = (768, 512)

# 1. OUTER EYE SHAPE — two quadratic arcs meeting at the corners.
#    Control-point y solved so the arcs peak at 380 (top) and 644 (bottom):
#    midpoint_y = 256 + 0.5 * Cy  ->  Cy = 2 * (peak - 256)
top_arc = quad_bezier(LEFT, (512, 248), RIGHT)     # peak at y=380
bottom_arc = quad_bezier(LEFT, (512, 776), RIGHT)  # dip at y=644
draw.line(top_arc, fill=DARK + (255,), width=8, joint="curve")
draw.line(bottom_arc, fill=DARK + (255,), width=8, joint="curve")

# 2. IRIS RING — sage circle, stroke only.
draw.ellipse([CX - 88, CY - 88, CX + 88, CY + 88], outline=SAGE + (255,), width=5)

# 3. PUPIL — filled dark circle.
draw.ellipse([CX - 38, CY - 38, CX + 38, CY + 38], fill=DARK + (255,))

# 4. LASH MARKS — short strokes fanning up-right from the right corner (60% opacity).
lashes = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ld = ImageDraw.Draw(lashes)
for i, angle in enumerate((310, 320, 330, 340, 350)):
    length = 22 + i * 3
    rad = math.radians(angle)
    x2 = RIGHT[0] + length * math.cos(rad)
    y2 = RIGHT[1] + length * math.sin(rad)
    ld.line([RIGHT, (x2, y2)], fill=DARK + (153,), width=2)  # 153/255 ≈ 60%
img = Image.alpha_composite(img, lashes)
draw = ImageDraw.Draw(img)

# 5. CORNER DOTS — calligraphic brush ends.
for corner in (LEFT, RIGHT):
    draw.ellipse([corner[0] - 4, corner[1] - 4, corner[0] + 4, corner[1] + 4], fill=SAGE + (255,))

img.convert("RGB").save(OUT)
print("wrote", OUT)
