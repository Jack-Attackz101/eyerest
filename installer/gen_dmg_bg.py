#!/usr/bin/env python3
"""Generate the DMG installer background image.

Produces `installer/dmg_background.png`, a 540x340 canvas with a vertical
linear gradient (top #F6F7F9 -> bottom #E9EDF2), a single chalk-style arrow
arcing from the app-icon slot to the Applications alias, and one line of
instruction text.

The Finder icon layout is driven by create-dmg. Build the DMG with:

    create-dmg \
      --volname "Iris" \
      --window-size 540 340 \
      --background installer/dmg_background.png \
      --icon "Iris.app" 135 150 \
      --app-drop-link 405 150 \
      Iris.dmg \
      build/Iris.app

The icon positions above MUST match the slot centres this script draws:
the app icon at (135, 150) and the Applications alias at (405, 150).
"""

import math
import random

from PIL import Image, ImageDraw, ImageFont

# --- Canvas -----------------------------------------------------------------
WIDTH, HEIGHT = 540, 340

# Finder icon slot centres (must match the create-dmg positions above).
APP_ICON = (135, 150)
APPLICATIONS = (405, 150)

# Gradient endpoints.
TOP_COLOR = (0xF6, 0xF7, 0xF9)
BOTTOM_COLOR = (0xE9, 0xED, 0xF2)

# Arrow geometry.
ARROW_START = (190, 150)
ARROW_END = (350, 150)
ARROW_PEAK = (270, 118)
STROKE_WIDTH = 6
ARROWHEAD_LEG = 22          # px
ARROWHEAD_ANGLE = 28        # degrees from horizontal
ARROW_ALPHA = int(round(0.92 * 255))

# Text.
TEXT = "Drag Iris into Applications"
TEXT_COLOR = (0x4B, 0x55, 0x63)
TEXT_SIZE = 18
TEXT_BASELINE_Y = 292

# Supersampling factor for a clean, antialiased arrow silhouette at 1x.
SS = 4

OUTPUT = "dmg_background.png"


def build_gradient():
    """Vertical linear gradient from TOP_COLOR to BOTTOM_COLOR."""
    base = Image.new("RGB", (WIDTH, HEIGHT))
    px = base.load()
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        r = round(TOP_COLOR[0] + (BOTTOM_COLOR[0] - TOP_COLOR[0]) * t)
        g = round(TOP_COLOR[1] + (BOTTOM_COLOR[1] - TOP_COLOR[1]) * t)
        b = round(TOP_COLOR[2] + (BOTTOM_COLOR[2] - TOP_COLOR[2]) * t)
        for x in range(WIDTH):
            px[x, y] = (r, g, b)
    return base


def quadratic_bezier(p0, p1, p2, steps=96):
    """Sample a quadratic Bezier curve into a list of points."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1 - t
        x = mt * mt * p0[0] + 2 * mt * t * p1[0] + t * t * p2[0]
        y = mt * mt * p0[1] + 2 * mt * t * p1[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def draw_arrow(canvas):
    """Draw the chalk-style arrow onto `canvas` (RGB) via a supersampled layer."""
    layer = Image.new("RGBA", (WIDTH * SS, HEIGHT * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    stroke = STROKE_WIDTH * SS
    white = (255, 255, 255, ARROW_ALPHA)

    # Control point chosen so the curve peaks at ARROW_PEAK at t=0.5:
    #   B(0.5) = 0.25*P0 + 0.5*P1 + 0.25*P2  ->  P1 = 2*peak - (P0 + P2)/2
    ctrl = (
        2 * ARROW_PEAK[0] - (ARROW_START[0] + ARROW_END[0]) / 2,
        2 * ARROW_PEAK[1] - (ARROW_START[1] + ARROW_END[1]) / 2,
    )
    curve = quadratic_bezier(ARROW_START, ctrl, ARROW_END)
    curve_ss = [(x * SS, y * SS) for x, y in curve]

    # Round-join polyline for the arc.
    draw.line(curve_ss, fill=white, width=stroke, joint="curve")

    # Open-V arrowhead at the tip, legs at +/-ARROWHEAD_ANGLE from horizontal,
    # pointing back from the tip (the arc travels left -> right).
    tip = ARROW_END
    for sign in (+1, -1):
        angle = math.radians(180 - sign * ARROWHEAD_ANGLE)
        leg = (
            tip[0] + ARROWHEAD_LEG * math.cos(angle),
            tip[1] + ARROWHEAD_LEG * math.sin(angle),
        )
        draw.line(
            [(tip[0] * SS, tip[1] * SS), (leg[0] * SS, leg[1] * SS)],
            fill=white,
            width=stroke,
            joint="curve",
        )

    # Round caps + round joins: stamp discs at every vertex the stroke touches.
    radius = stroke / 2
    cap_points = list(curve_ss)
    cap_points.append((tip[0] * SS, tip[1] * SS))
    for sign in (+1, -1):
        angle = math.radians(180 - sign * ARROWHEAD_ANGLE)
        cap_points.append(
            ((tip[0] + ARROWHEAD_LEG * math.cos(angle)) * SS,
             (tip[1] + ARROWHEAD_LEG * math.sin(angle)) * SS)
        )
    for cx, cy in cap_points:
        draw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=white,
        )

    # Slight chalk grain: faint speckles along the stroke, kept well inside the
    # silhouette so the 1x edge stays clean.
    rng = random.Random(0x1715)
    for (x, y) in curve_ss:
        for _ in range(2):
            jx = x + rng.uniform(-radius * 0.4, radius * 0.4)
            jy = y + rng.uniform(-radius * 0.4, radius * 0.4)
            a = rng.randint(40, 110)
            draw.ellipse([jx - SS, jy - SS, jx + SS, jy + SS], fill=(255, 255, 255, a))

    layer = layer.resize((WIDTH, HEIGHT), Image.LANCZOS)
    canvas.paste(layer, (0, 0), layer)


def load_semibold_font():
    """Best-effort semibold font at TEXT_SIZE; fall back gracefully."""
    candidates = [
        "/System/Library/Fonts/SFNSDisplay-Semibold.otf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/Library/Fonts/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "DejaVuSans-Bold.ttf",
        "Helvetica-Bold.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, TEXT_SIZE)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def draw_text(canvas):
    draw = ImageDraw.Draw(canvas)
    font = load_semibold_font()

    # Measure so the text is horizontally centred and sits on TEXT_BASELINE_Y.
    try:
        bbox = draw.textbbox((0, 0), TEXT, font=font)
        text_w = bbox[2] - bbox[0]
        ascent = -bbox[1]
        x = (WIDTH - text_w) / 2 - bbox[0]
    except AttributeError:  # very old Pillow
        text_w = draw.textsize(TEXT, font=font)[0]
        ascent = TEXT_SIZE
        x = (WIDTH - text_w) / 2
    y = TEXT_BASELINE_Y - ascent
    draw.text((x, y), TEXT, font=font, fill=TEXT_COLOR)


def main():
    canvas = build_gradient()
    draw_arrow(canvas)
    draw_text(canvas)
    canvas.save(OUTPUT)
    print(f"Wrote {OUTPUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
