#!/usr/bin/env python3
"""Generate the Iris DMG background (540x500).

Top-to-bottom layout (background art only — real icons placed by create-dmg):
  Iris logo    80x80, center (270, 40)
  [Applications folder at y=140 — real icon]
  Arrow        65x80, center (270, 210)
  [Iris.app at y=310 — real icon]
  Video frame  380x130, center (270, 410)
  Hand         contain(140,100), top-left (0, 385)
  Instruction  11pt white, center (270, 476)
"""
import os, subprocess, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")
W, H = 540, 500


def remove_white_bg(im, thr=245):
    im = im.convert("RGBA")
    a  = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


def contain(im, box_w, box_h):
    w, h = im.size
    s = min(box_w / w, box_h / h)
    return im.resize((round(w * s), round(h * s)), Image.LANCZOS)


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


# ── 1. Background: willow canopy, scale to 540 wide, crop top 500px ──────────
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size                        # 736 x 1308
src = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg  = src.crop((0, 0, W, H)).convert("RGBA")

# ── 2. Iris logo: 80x80 (white, transparent bg), center (270, 40) ─────────────
logo = Image.open(os.path.join(A, "iris-logo-white-transparent.png")).convert("RGBA")
logo = logo.resize((80, 80), Image.LANCZOS)
bg.alpha_composite(logo, (270 - 40, 40 - 40))   # top-left (230, 0)

# ── 3. Arrow: 65x80, center (270, 210) ───────────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((65, 80), Image.LANCZOS)
bg.alpha_composite(arrow, (270 - 32, 210 - 40))  # top-left (238, 170)

# ── 4. Video thumbnail: 380x130, center (270, 410) ───────────────────────────
VW, VH = 380, 130
with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
    frame_path = f.name
subprocess.run(
    ["ffmpeg", "-y", "-ss", "1", "-i",
     os.path.join(A, "How to Install Iris.mp4"),
     "-vframes", "1", "-q:v", "2", frame_path],
    capture_output=True,
)
frame = Image.open(frame_path).convert("RGB")
os.unlink(frame_path)
# Scale to VW wide, then center-crop to VH tall
fw, fh = frame.size
frame = frame.resize((VW, round(fh * VW / fw)), Image.LANCZOS)
crop_top = (frame.height - VH) // 2
frame = frame.crop((0, crop_top, VW, crop_top + VH))
# 1px black border
framed = Image.new("RGBA", (VW + 2, VH + 2), (0, 0, 0, 255))
framed.paste(frame, (1, 1))
# Paste so center lands at (270, 410): top-left = (270 - (VW+2)//2, 410 - (VH+2)//2)
vx = 270 - (VW + 2) // 2  # = 79
vy = 410 - (VH + 2) // 2  # = 344
bg.alpha_composite(framed, (vx, vy))

# ── 5. Pointing hand: contain(140,100), top-left (0, 385) ────────────────────
finger = remove_white_bg(Image.open(os.path.join(A, "point.png")))
finger = contain(finger, 140, 100)
bg.alpha_composite(finger, (0, 385))

# ── 6. Instruction text: centered at (270, 476) ───────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font11  = load_font(11)
draw_centered(od, "Drag Iris to Applications to install", 270, 476, font11, (255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
