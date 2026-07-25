#!/usr/bin/env python3
"""
Generate Iris DMG background (540×800) → installer/dmgbackground.png

Background elements (drawn into PNG):
  Iris logo   60×60   center (270,  40)
  Arrow       45×55   center (270, 240)
  Video frame 520×338 at     ( 10, 422)  — 40px bottom margin
  Hand        140×91  at     (  0, 545)  — tip at (132, 591)
  Text        11pt           center (270, 780)

Finder icons (set by create-dmg):
  --app-drop-link  270 120   Applications folder
  --icon "Iris.app" 270 345  Iris.app
  mp4 file icon    270 591   center of video area
"""
import os, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmgbackground.png")

W        = 540
VIDEO_W  = 520                               # 10px margin each side
VIDEO_H  = round((720 / 1108) * VIDEO_W)    # 338
H        = 800

RECT_X   = 10
RECT_Y   = H - 40 - VIDEO_H                 # 422  (40px bottom margin)
VIDEO_CENTER_Y = RECT_Y + VIDEO_H // 2      # 591

HAND_X   = 0
HAND_Y   = VIDEO_CENTER_Y - 46              # 545  tip at (132, 591)


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


# ── 1. Background: willow canopy fills 540×800, edge to edge ─────────────────
src   = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size
src   = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg    = src.crop((0, 0, W, H)).convert("RGBA")


# ── 2. Iris logo: 60×60, centered at (270, 40) ───────────────────────────────
logo = Image.open(os.path.join(A, "iris-logo-white-transparent.png")).convert("RGBA")
logo = contain(logo, 60, 60)
lw, lh = logo.size
bg.alpha_composite(logo, (270 - lw // 2, 40 - lh // 2))


# ── 3. Arrow: 45×55, centered at (270, 240) ──────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((45, 55), Image.LANCZOS)
bg.alpha_composite(arrow, (270 - 22, 240 - 27))


# ── 4. Video frame (extracted from mp4) ──────────────────────────────────────
frame_path = os.path.join(A, "dmg_video_frame.png")
mp4_path   = os.path.join(A, "How to Install Iris.mp4")
if not os.path.exists(frame_path) and os.path.exists(mp4_path):
    subprocess.run(
        ["ffmpeg", "-i", mp4_path, "-ss", "00:00:01",
         "-vframes", "1", "-update", "1", "-y", frame_path],
        capture_output=True,
    )
if os.path.exists(frame_path):
    vf = Image.open(frame_path).convert("RGBA")
    vf = vf.resize((VIDEO_W, VIDEO_H), Image.LANCZOS)
else:
    vf = Image.new("RGBA", (VIDEO_W, VIDEO_H), (20, 20, 20, 255))
bg.alpha_composite(vf, (RECT_X, RECT_Y))


# ── 5. Pointing hand: 140×100 box → 140×91, from left edge ──────────────────
#    point.png is already RGBA — do NOT remove_white_bg (causes artifacts)
finger = Image.open(os.path.join(A, "point.png")).convert("RGBA")
finger = contain(finger, 140, 100)
bg.alpha_composite(finger, (HAND_X, HAND_Y))


# ── 6. Instruction text: 11pt #CCC, centered at (270, H-20=780) ─────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font11  = load_font(11)
draw_centered(od, "Drag Iris to Applications to install", 270, H - 20,
              font11, (204, 204, 204, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print(f"wrote {OUT}  size={bg.size}")
print(f"  VIDEO: {VIDEO_W}×{VIDEO_H} at ({RECT_X},{RECT_Y})  center_y={VIDEO_CENTER_Y}")
print(f"  HAND: ({HAND_X},{HAND_Y})  tip=({HAND_X+132},{VIDEO_CENTER_Y})")
print(f"  TEXT: y={H-20}")
