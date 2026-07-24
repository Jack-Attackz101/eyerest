#!/usr/bin/env python3
"""Generate the Iris DMG background (540×725).

Video 1108×720  →  placeholder 500×325, canvas 540×725
  scaled_h = round((720/1108)*500) = 325
  H = 380 + 325 + 20 = 725

Layout (icon-size=60 in Finder, half=30):
  Iris logo      80×80   centered (270, 40)
  app-drop-link  y=150   Finder icon top=120 bottom=180 label≈198
  Arrow          45×55   centered (270, 190)  top=163
  Iris.app       y=260   Finder icon top=230 bottom=290 label≈308
  Video rect     500×325 at (20, 380) → (520, 705)
  mp4 Finder icon        center (270, 655)  — set by create-dmg
  Hand           140×91  top-left (10, 512) tip≈x150  video cx≈x270
  Text           11pt #CCC  centered (270, 710)
"""
import os, json, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")

W          = 540
SCALED_H   = 325          # round((720/1108)*500)
H          = 380 + SCALED_H + 20   # 725
RECT_X     = 20
RECT_Y     = 380
HAND_Y     = 350 + SCALED_H // 2  # 512


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


# ── 1. Background: willow canopy, 540×725 ────────────────────────────────────
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size
src = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg  = src.crop((0, 0, W, H)).convert("RGBA")

# ── 2. Video placeholder: solid black 500×325, saved separately ──────────────
placeholder = Image.new("RGBA", (500, SCALED_H), (0, 0, 0, 255))
placeholder_path = os.path.join(A, "dmg_video_placeholder.png")
placeholder.save(placeholder_path)
bg.alpha_composite(placeholder, (RECT_X, RECT_Y))

# ── 3. Iris logo: 80×80, centered at (270, 40) ───────────────────────────────
logo = Image.open(os.path.join(A, "iris-logo-white-transparent.png")).convert("RGBA")
logo = contain(logo, 80, 80)
lw, lh = logo.size
bg.alpha_composite(logo, (270 - lw // 2, 40 - lh // 2))

# ── 4. Arrow: 45×55, centered at (270, 190) ──────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((45, 55), Image.LANCZOS)
bg.alpha_composite(arrow, (270 - 22, 190 - 27))      # top-left (248, 163)

# ── 5. Pointing hand: 140×100 box → 140×91, top-left (10, 512) ──────────────
#    point.png is already RGBA — do NOT remove_white_bg (causes artifacts)
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 140, 100)                    # → 140×91
bg.alpha_composite(finger, (10, HAND_Y))

# ── 6. Instruction text: 11pt #CCC, centered at (270, 710) ──────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font11  = load_font(11)
draw_centered(od, "Drag Iris to Applications to install", 270, H - 15,
              font11, (204, 204, 204, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print(f"wrote {OUT}  size={bg.size}")
