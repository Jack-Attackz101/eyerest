#!/usr/bin/env python3
"""
Generate the Iris DMG background (460×660 portrait) -> installer/dmg_background.png

Layout (measured off Jack's target design):
  Background   assets/dmg-reference.jpg -- willow, full-bleed
               resize to width 460 (736x1308 -> 460x818)
               centre-crop vertically to 660 (keep rows 79..739)
  Arrow        assets/arrow.png, white bg removed, resized to 83x159
               centred at (230, 271) -> pasted top-left (189, 192)
  Text         one line, white, regular weight ~19px, centred,
               baseline y=636, soft dark shadow so it stays readable over the water

Finder icons (placed by create-dmg via build_dmg.sh):
  --app-drop-link  230 100   Applications folder (TOP)
  --icon "Iris.app" 230 464  app icon (BOTTOM) -- the arrow points up to the folder
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter


def remove_white_bg(im, thr=240):
    im = im.convert("RGBA")
    a  = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")

W, H = 460, 660


def load_font(size):
    for path in [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
    ]:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


# -- 1. Background: willow fills 460 wide, centre-cropped to 660 tall ---------
src    = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size
new_h  = round(sh * W / sw)          # 736x1308 -> 460x818
src    = src.resize((W, new_h), Image.LANCZOS)
top    = max(0, (new_h - H) // 2)    # 79
bg     = src.crop((0, top, W, top + H)).convert("RGBA")


# -- 2. Arrow: 83x159, centred at (230, 271) ---------------------------------
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((83, 159), Image.LANCZOS)
bg.alpha_composite(arrow, (230 - 83 // 2, 271 - 159 // 2))   # (189, 192)


# -- 3. Instruction text: one line, white, soft dark shadow ------------------
TEXT = "Drag Iris into the Applications folder"
font = load_font(19)

shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(shadow).text(
    (230, 636), TEXT, font=font, fill=(0, 0, 0, 200), anchor="ms"
)
shadow = shadow.filter(ImageFilter.GaussianBlur(2))
bg = Image.alpha_composite(bg, shadow)

draw = ImageDraw.Draw(bg)
draw.text(
    (230, 636), TEXT, font=font, fill=(255, 255, 255, 255),
    anchor="ms", stroke_width=1, stroke_fill=(0, 0, 0, 160),
)

bg.convert("RGB").save(OUT)
print(f"wrote {OUT}  size={bg.size}")
