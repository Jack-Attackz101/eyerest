#!/usr/bin/env python3
"""
Generate the Iris DMG background.

Output: installer/dmg_background.png  (460 x 660)

Portrait window. Willow illustration full-bleed, Applications folder at the
TOP, Iris app icon at the BOTTOM, hand-drawn arrow pointing UP between them,
one line of instruction text at the bottom.

Geometry measured from the approved design. It must match the create-dmg
window geometry in installer/build_dmg.sh:

    --window-size 460 660
    --icon-size 135
    --app-drop-link    230 100      <- Applications folder, top
    --icon "Iris.app"  230 464      <- Iris app, bottom
    --background installer/dmg_background.png
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# ---- Canvas ---------------------------------------------------------------
W, H = 460, 660

# ---- Arrow ---------------------------------------------------------------
# assets/arrow.png ships with a white background; remove_white_bg() keys it
# out to transparency, which is what the design needs.
ARROW_SIZE = (83, 159)          # scaled from the native 108x206
ARROW_CENTER = (230, 271)       # midway between the folder and the app icon

# ---- Text ---------------------------------------------------------------
TEXT = "Drag Iris into the Applications folder"
TEXT_SIZE = 19                  # regular weight, not semibold
TEXT_BASELINE_Y = 636
TEXT_COLOR = (255, 255, 255, 255)
SHADOW_COLOR = (0, 0, 0, 150)   # keeps the text readable over the water

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

# Regular-weight faces first: the design uses regular, not semibold.
FONT_CANDIDATES = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/SFNSText.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
]


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def remove_white_bg(im, thr=240):
    """Key out the white background of assets/arrow.png to transparency."""
    im = im.convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


def build_background():
    """Willow scaled to width, then centre-cropped vertically to 460x660."""
    src = Image.open(os.path.join(ASSETS, "dmg-reference.jpg"))
    scale = W / src.width
    new_h = round(src.height * scale)          # 736x1308 -> 460x818
    src = src.resize((W, new_h), Image.LANCZOS)
    top = max(0, (new_h - H) // 2)             # -> 79
    return src.crop((0, top, W, top + H)).convert("RGBA")


def paste_arrow(canvas):
    arrow = remove_white_bg(Image.open(os.path.join(ASSETS, "arrow.png")))
    arrow = arrow.resize(ARROW_SIZE, Image.LANCZOS)
    cx, cy = ARROW_CENTER
    canvas.alpha_composite(
        arrow, (cx - ARROW_SIZE[0] // 2, cy - ARROW_SIZE[1] // 2)
    )


def draw_text(canvas):
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    font = load_font(TEXT_SIZE)

    ascent, _ = font.getmetrics()
    bbox = od.textbbox((0, 0), TEXT, font=font)
    tw = bbox[2] - bbox[0]
    tx = (W - tw) / 2.0 - bbox[0]
    ty = TEXT_BASELINE_Y - ascent

    # Soft shadow so white type survives the bright water reflections.
    for dx, dy in ((-1, 1), (1, 1), (0, 2), (0, 1)):
        od.text((tx + dx, ty + dy), TEXT, font=font, fill=SHADOW_COLOR)
    od.text((tx, ty), TEXT, font=font, fill=TEXT_COLOR)

    return Image.alpha_composite(canvas, overlay)


def main():
    canvas = build_background()
    paste_arrow(canvas)
    canvas = draw_text(canvas)
    canvas.convert("RGB").save(OUT, "PNG")
    print(f"wrote {OUT}  size={canvas.size}")


if __name__ == "__main__":
    main()
