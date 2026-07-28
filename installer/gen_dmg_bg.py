#!/usr/bin/env python3
"""
gen_dmg_bg.py — generate the Iris DMG background.

Minimal chalkboard design (ship this, stop iterating):
  * 540 x 340 canvas
  * a chalk-style arrow pointing from the app icon toward the Applications alias
  * exactly ONE line of instruction text
  * nothing else

Finder icon layout is set by create-dmg and MUST match this canvas:
  * Iris.app icon       : x=135  y=150
  * Applications alias  : x=405  y=150

Build the DMG with ../build_dmg.sh, which runs create-dmg:
  create-dmg \
    --volname "Iris" \
    --window-size 540 340 \
    --icon-size 128 \
    --background installer/dmg_background.png \
    --icon "Iris.app" 135 150 \
    --app-drop-link 405 150 \
    Iris.dmg build/export
"""

import os
import random

from PIL import Image, ImageDraw, ImageFont

W, H = 540, 340
BG = (38, 46, 43)        # dark chalkboard slate
CHALK = (238, 240, 235)  # soft chalk white

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "dmg_background.png")

random.seed(7)  # reproducible chalk texture


def load_font(size):
    for path in (
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/Library/Fonts/Arial.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def chalk_line(draw, p0, p1, width):
    """One rough chalk stroke: jittered overlapping segments plus speckle."""
    x0, y0 = p0
    x1, y1 = p1
    dist = ((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5
    steps = max(2, int(dist / 6))
    prev = (x0, y0)
    for i in range(1, steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t + random.uniform(-1.2, 1.2)
        y = y0 + (y1 - y0) * t + random.uniform(-1.2, 1.2)
        a = random.randint(140, 235)
        w = max(1, int(round(width + random.uniform(-1, 1))))
        draw.line([prev, (x, y)], fill=CHALK + (a,), width=w)
        prev = (x, y)
    for _ in range(steps):
        t = random.random()
        x = x0 + (x1 - x0) * t + random.uniform(-3, 3)
        y = y0 + (y1 - y0) * t + random.uniform(-3, 3)
        r = random.uniform(0.5, 1.5)
        draw.ellipse(
            [x - r, y - r, x + r, y + r],
            fill=CHALK + (random.randint(60, 160),),
        )


def main():
    img = Image.new("RGBA", (W, H), BG + (255,))

    # faint chalk dust so the slate is not flat
    dust = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dust)
    for _ in range(900):
        x = random.uniform(0, W)
        y = random.uniform(0, H)
        r = random.uniform(0.3, 0.9)
        dd.ellipse(
            [x - r, y - r, x + r, y + r],
            fill=CHALK + (random.randint(6, 16),),
        )
    img = Image.alpha_composite(img, dust)

    # chalk arrow, horizontal, centred on the icon row (y=150), between the icons
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    y = 150
    shaft_x0, shaft_x1 = 205, 335
    for _ in range(3):
        chalk_line(od, (shaft_x0, y), (shaft_x1, y), 4)
    for _ in range(2):
        chalk_line(od, (shaft_x1, y), (shaft_x1 - 20, y - 12), 4)
        chalk_line(od, (shaft_x1, y), (shaft_x1 - 20, y + 12), 4)
    img = Image.alpha_composite(img, overlay)

    # exactly one line of instruction text
    draw = ImageDraw.Draw(img)
    font = load_font(20)
    text = "drag iris into applications"
    tb = draw.textbbox((0, 0), text, font=font)
    tw = tb[2] - tb[0]
    draw.text(((W - tw) / 2, 292), text, font=font, fill=CHALK + (235,))

    img.convert("RGB").save(OUT)
    print(f"wrote {OUT} ({W}x{H})")


if __name__ == "__main__":
    main()
