#!/usr/bin/env python3
"""Generate the Iris DMG background (540x540).

icon-size=60 (half=30) — compact app icons, large 500x220 video player frame.
  Iris logo    80x80   centered at (270, 40)   top=0  bottom=80
  app-drop-link y=150  icon top=120 bottom=180  label≈198
  Arrow        45x55   centered at (270, 190)   top=163  bottom=218
  Iris.app     y=260   icon top=230 bottom=290  label≈308
  Video frame  500x220 (20,300)→(520,520)
  Hand         140x91  top-left (10, 395)  tip x≈150
  Text         centered at (270, 530)  window=540  margin 10px
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")
W, H = 540, 540


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


# ── 1. Background: willow canopy, 540x540 ────────────────────────────────────
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size                                    # 736 × 1308
src = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg  = src.crop((0, 0, W, H)).convert("RGBA")

# ── 2. Iris logo: 80x80, centered at (270, 40) ───────────────────────────────
logo = Image.open(os.path.join(A, "iris-logo-white-transparent.png")).convert("RGBA")
logo = contain(logo, 80, 80)
lw, lh = logo.size
bg.alpha_composite(logo, (270 - lw // 2, 40 - lh // 2))

# ── 3. Arrow: 45x55, centered at (270, 190) ──────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((45, 55), Image.LANCZOS)
bg.alpha_composite(arrow, (270 - 22, 190 - 27))     # top-left (248, 163)

# ── 4. Video player frame: 500x220, top-left (20, 300) ───────────────────────
VPW, VPH = 500, 220
player = Image.new("RGBA", (VPW, VPH), (0, 0, 0, 0))
pd     = ImageDraw.Draw(player)
pd.rounded_rectangle(
    [(0, 0), (VPW - 1, VPH - 1)],
    radius=12,
    fill=(0, 0, 0, 190),
    outline=(255, 255, 255, 180),
    width=2,
)
pcx, pcy = VPW // 2, VPH // 2
pts = [(pcx - 22, pcy - 30), (pcx - 22, pcy + 30), (pcx + 35, pcy)]
pd.polygon(pts, fill=(255, 255, 255, 210))
bg.alpha_composite(player, (20, 300))

# ── 5. Pointing hand: 140x100, top-left (10, 395) ────────────────────────────
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 140, 100)                   # → 140x91
bg.alpha_composite(finger, (10, 395))

# ── 6. Instruction text centered at (270, 530) ───────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font12  = load_font(12)
draw_centered(od, "Drag Iris to Applications to install", 270, 530, font12, (255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
