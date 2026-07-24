#!/usr/bin/env python3
"""Generate the Iris DMG background (600x650).

Video "4x bigger" trick: draw a large dark player frame (340x192) on the
background with a play-button chevron — no video thumbnail, just chrome.
The real mp4 sits centered inside it; double-clicking it opens QuickTime.

Spacing verified (icon centers in Finder space, icon-size=85 → half=42):
  app-drop-link  y=60   icon top≈18  bottom≈102  label bottom≈122
  Arrow          y=175  top=135 (+13 from label)  bottom=215
  Iris.app       y=305  top=263 (+48 from arrow)  label bottom≈365
  Player frame   y=394–586  (340x192, center y=490)
  mp4            y=490  (centered in player frame)
  Hand tip       x≈110  player left edge x=130  (+20px gap)
  Text           y=630  window=650  bottom margin 20px
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")
W, H = 600, 650


def contain(im, box_w, box_h):
    w, h = im.size
    s = min(box_w / w, box_h / h)
    return im.resize((round(w * s), round(h * s)), Image.LANCZOS)


def remove_white_bg(im, thr=245):
    im = im.convert("RGBA")
    a  = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


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


def draw_centered(draw, text, cx, cy, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2, cy - th // 2), text, font=font, fill=fill)


# ── 1. Background: willow canopy, 600x650 ─────────────────────────────────────
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size                                    # 736 × 1308
src = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg  = src.crop((0, 0, W, H)).convert("RGBA")

# ── 2. Arrow: 65x80, center (300, 175) ───────────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((65, 80), Image.LANCZOS)
bg.alpha_composite(arrow, (300 - 32, 175 - 40))     # top-left (268, 135)

# ── 3. Video player frame: 340x192 dark rounded rect + play chevron ───────────
#    No video thumbnail — pure chrome. mp4 file (from create-dmg) sits center.
VPW, VPH = 340, 192
vp_x = (W - VPW) // 2          # 130
vp_y = 490 - VPH // 2          # 394   bottom = 394+192 = 586

player = Image.new("RGBA", (VPW, VPH), (0, 0, 0, 0))
pd     = ImageDraw.Draw(player)
pd.rounded_rectangle(
    [(0, 0), (VPW - 1, VPH - 1)],
    radius=10,
    fill=(0, 0, 0, 190),
    outline=(255, 255, 255, 180),
    width=2,
)
# Play triangle, centered in the frame
pcx, pcy = VPW // 2, VPH // 2
pts = [(pcx - 22, pcy - 30), (pcx - 22, pcy + 30), (pcx + 35, pcy)]
pd.polygon(pts, fill=(255, 255, 255, 210))
bg.alpha_composite(player, (vp_x, vp_y))

# ── 4. Pointing hand: 2x smaller than previous 220x143 → 110x71 ──────────────
#    point.png is RGBA 196x128 (no bg removal needed)
#    tip at x≈110, player left edge x=130, gap +20px
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 110, 72)                    # 110x72 from 196x128
bg.alpha_composite(finger, (0, 440))

# ── 5. Instruction text ────────────────────────────────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font12  = load_font(12)
draw_centered(od, "Drag Iris to Applications to install", 300, 630, font12, (255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
