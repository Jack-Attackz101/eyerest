#!/usr/bin/env python3
"""
Generate the Iris DMG background.

Output: installer/dmg_background.png  (540 x 340)

The layout matches the create-dmg window geometry used by
installer/build_dmg.sh:

    --window-size 540 340
    --icon "Iris.app"  135 150
    --app-drop-link    405 150
    --background installer/dmg_background.png

The background is a flat vertical gradient (#F6F7F9 top -> #E9EDF2 bottom)
with a single white chalk-style arrow arcing from the app-icon slot toward
the Applications alias, and exactly one line of instruction text. No
photograph, no numpy.
"""

import math
import os

from PIL import Image, ImageDraw, ImageFont

# ---- Canvas ---------------------------------------------------------------
WIDTH, HEIGHT = 540, 340

# ---- Gradient -------------------------------------------------------------
TOP_COLOR = (0xF6, 0xF7, 0xF9)      # #F6F7F9
BOTTOM_COLOR = (0xE9, 0xED, 0xF2)   # #E9EDF2

# ---- Arrow ----------------------------------------------------------------
ARROW_START = (190.0, 150.0)
ARROW_PEAK = (270.0, 118.0)
ARROW_END = (350.0, 150.0)
ARROW_WIDTH = 6                          # 6px stroke, round cap / round join
ARROW_ALPHA = int(round(0.92 * 255))     # 92% opacity white -> 235
ARROW_HEAD_LEN = 22.0                    # 22px arrowhead legs
ARROW_HEAD_ANGLE = math.radians(28.0)    # +/-28 deg from horizontal

# Quadratic Bezier control point chosen so the curve passes through the peak
# at t = 0.5:  B(0.5) = 0.25*P0 + 0.5*C + 0.25*P2 = PEAK
CONTROL = (
    2 * ARROW_PEAK[0] - 0.5 * (ARROW_START[0] + ARROW_END[0]),
    2 * ARROW_PEAK[1] - 0.5 * (ARROW_START[1] + ARROW_END[1]),
)

# ---- Text -----------------------------------------------------------------
TEXT = "Drag Iris into Applications"
TEXT_COLOR = (0x4B, 0x55, 0x63)   # #4B5563
TEXT_SIZE = 18                    # semibold 18px
TEXT_BASELINE_Y = 292

FONT_CANDIDATES = [
    "/System/Library/Fonts/SFNSDisplay-Semibold.otf",
    "/System/Library/Fonts/SFNSText-Semibold.otf",
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial Bold.ttf",
    "DejaVuSans-Bold.ttf",
]


def load_font(size):
    for path in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def make_gradient(width, height, top, bottom):
    base = Image.new("RGB", (width, height), top)
    draw = ImageDraw.Draw(base)
    denom = max(height - 1, 1)
    for y in range(height):
        t = y / denom
        color = (
            round(top[0] + (bottom[0] - top[0]) * t),
            round(top[1] + (bottom[1] - top[1]) * t),
            round(top[2] + (bottom[2] - top[2]) * t),
        )
        draw.line([(0, y), (width, y)], fill=color)
    return base


def quad_bezier(p0, c, p2, steps=140):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1.0 - t
        x = mt * mt * p0[0] + 2 * mt * t * c[0] + t * t * p2[0]
        y = mt * mt * p0[1] + 2 * mt * t * c[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def draw_round_polyline(draw, pts, width, color):
    """Stroke a polyline with round caps and round joins."""
    draw.line(pts, fill=color, width=width, joint="curve")
    r = width / 2.0
    for (x, y) in pts:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def main():
    canvas = make_gradient(WIDTH, HEIGHT, TOP_COLOR, BOTTOM_COLOR).convert("RGBA")

    # Arrow on its own layer so the 92% opacity blends over the gradient.
    arrow_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    adraw = ImageDraw.Draw(arrow_layer)
    color = (255, 255, 255, ARROW_ALPHA)

    curve = quad_bezier(ARROW_START, CONTROL, ARROW_END)
    draw_round_polyline(adraw, curve, ARROW_WIDTH, color)

    # Open-V arrowhead at the tip, legs 22px at +/-28 deg from horizontal.
    for signed in (ARROW_HEAD_ANGLE, -ARROW_HEAD_ANGLE):
        ang = math.pi - signed
        ex = ARROW_END[0] + ARROW_HEAD_LEN * math.cos(ang)
        ey = ARROW_END[1] + ARROW_HEAD_LEN * math.sin(ang)
        draw_round_polyline(adraw, [ARROW_END, (ex, ey)], ARROW_WIDTH, color)

    canvas = Image.alpha_composite(canvas, arrow_layer)

    # Exactly one line of instruction text, centred, baseline at y=292.
    draw = ImageDraw.Draw(canvas)
    font = load_font(TEXT_SIZE)
    ascent, _ = font.getmetrics()
    bbox = draw.textbbox((0, 0), TEXT, font=font)
    text_w = bbox[2] - bbox[0]
    text_x = (WIDTH - text_w) / 2.0 - bbox[0]
    text_y = TEXT_BASELINE_Y - ascent
    draw.text((text_x, text_y), TEXT, font=font, fill=TEXT_COLOR)

    out = canvas.convert("RGB")
    out_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "dmg_background.png"
    )
    out.save(out_path, "PNG")
    print("wrote", out_path)


if __name__ == "__main__":
    main()
