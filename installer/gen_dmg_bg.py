#!/usr/bin/env python3
"""
Generate Iris DMG background (460×660 portrait) → installer/dmg_background.png

Full-bleed willow illustration. The Applications folder sits at the TOP and
the Iris app icon at the BOTTOM (both placed as Finder icons by create-dmg);
a hand-drawn arrow between them points UP from the app to the folder.

Composited here:
  Background   assets/dmg-reference.jpg, width-fit to 460 then centre-cropped to 660
  Arrow        assets/arrow.png (white bg removed), 83×159, centred at (230, 271)
  Text         one white line, baseline y=636, with a soft dark shadow

Finder icons (placed by build_dmg.sh / create-dmg):
  --app-drop-link   230 100
  --icon "Iris.app" 230 464
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter


def remove_white_bg(im, thr=240):
    im = im.convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

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


# ── 1. Background: willow width-fit to 460, centre-cropped to 660 ────────────
#     dmg-reference.jpg is 736×1308 → resize to 460×818 → keep rows 79..739.
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size
scale = W / sw
new_h = round(sh * scale)
src = src.resize((W, new_h), Image.LANCZOS)
top = max(0, (new_h - H) // 2)
bg = src.crop((0, top, W, top + H)).convert("RGBA")


# ── 2. Arrow: 83×159, centred at (230, 271) → top-left (189, 192) ────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((83, 159), Image.LANCZOS)
bg.alpha_composite(arrow, (230 - 83 // 2, 271 - 159 // 2))


# ── 3. Instruction text: one regular-weight line, baseline y=636 ─────────────
TEXT = "Drag Iris into the Applications folder"
font = load_font(19)

# Soft dark shadow so the white text stays readable over the water.
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.text((230, 637), TEXT, font=font, anchor="ms", fill=(0, 0, 0, 200))
shadow = shadow.filter(ImageFilter.GaussianBlur(2))
bg = Image.alpha_composite(bg, shadow)

# White text with a thin dark outline for extra contrast.
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
od.text((230, 636), TEXT, font=font, anchor="ms",
        fill=(255, 255, 255, 255), stroke_width=1, stroke_fill=(0, 0, 0, 180))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print(f"wrote {OUT}  size={bg.size}")
