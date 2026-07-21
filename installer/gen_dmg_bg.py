#!/usr/bin/env python3
"""Generate the premium DMG background: installer/dmg_background.png (1280x800).

The real Iris.app icon and the Applications drop-link are placed on top of this
background by create-dmg at (320,380) and (960,380), and Finder draws their name
labels. So this image supplies the composition around them — gradient, faint
wordmark, the iris icon + a simple Applications folder (as a fallback beneath the
real icons), the connecting arrow, a divider, a version line, and the install
hint — without duplicating the Finder-drawn "Iris" / "Applications" labels.
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ICON = os.path.join(HERE, "icon_1024.png")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 1280, 800
ICON_PX = 180
APP_XY = (320, 380)   # center of the app icon slot
FOLDER_XY = (960, 380)
ARROW_XY = (640, 380)


def load_font(size):
    for path in ("/System/Library/Fonts/SFNS.ttf",
                 "/System/Library/Fonts/Helvetica.ttc",
                 "/System/Library/Fonts/HelveticaNeue.ttc"):
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def draw_centered(d, cx, y, text, font, fill):
    box = d.textbbox((0, 0), text, font=font)
    w = box[2] - box[0]
    d.text((cx - w / 2, y), text, font=font, fill=fill)


# ---- gradient background (#080810 top -> #050508 bottom) ----
top = (8, 8, 16)
bot = (5, 5, 8)
img = Image.new("RGB", (W, H))
px = img.load()
for y in range(H):
    f = y / (H - 1)
    r = round(top[0] + (bot[0] - top[0]) * f)
    g = round(top[1] + (bot[1] - top[1]) * f)
    b = round(top[2] + (bot[2] - top[2]) * f)
    for x in range(W):
        px[x, y] = (r, g, b)
img = img.convert("RGBA")
d = ImageDraw.Draw(img)

# ---- top faint wordmark ----
draw_centered(d, W / 2, 80, "iris", load_font(18), (51, 51, 51, 255))

# ---- center divider (white 8%, y 200..600) ----
d.line([(640, 200), (640, 600)], fill=(255, 255, 255, 20), width=1)

# ---- app icon (fallback beneath the real create-dmg icon) ----
icon = Image.open(ICON).convert("RGBA").resize((ICON_PX, ICON_PX), Image.LANCZOS)
img.alpha_composite(icon, (APP_XY[0] - ICON_PX // 2, APP_XY[1] - ICON_PX // 2))

# ---- Applications folder (simplified, classic macOS blue) ----
fx, fy = FOLDER_XY
half = ICON_PX // 2
blue = (29, 110, 245, 255)
blue_light = (77, 148, 255, 255)
left, top_ = fx - half, fy - half + 24
right, bottom = fx + half, fy + half
# back tab
d.rounded_rectangle([left, top_ - 16, left + 78, top_ + 20], radius=10, fill=blue_light)
# folder body
d.rounded_rectangle([left, top_, right, bottom], radius=22, fill=blue)
# subtle lighter lip along the top of the body
d.rounded_rectangle([left, top_, right, top_ + 26], radius=22, fill=blue_light)
d.rounded_rectangle([left, top_ + 14, right, bottom], radius=22, fill=blue)

# ---- version line under the app icon (Finder draws the "Iris" label itself) ----
draw_centered(d, APP_XY[0], APP_XY[1] + half + 34, "Version 2.0", load_font(15), (140, 140, 150, 255))

# ---- connecting chevron arrow (white 30%) ----
ax, ay = ARROW_XY
s = 20
d.line([(ax - s, ay - s), (ax + s, ay), (ax - s, ay + s)],
       fill=(255, 255, 255, 76), width=4, joint="curve")

# ---- bottom instruction ----
draw_centered(d, W / 2, 672, "Drag Iris to Applications to install",
              load_font(14), (136, 136, 136, 255))

img.convert("RGB").save(OUT)
print("wrote", OUT)
