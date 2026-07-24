#!/usr/bin/env python3
"""Generate the Iris DMG background (1080x1000).

Window is 2x the original 540x500. App icons stay at icon-size 85;
background art and video scale up 2x.

Top-to-bottom layout (background art only — real icons placed by create-dmg):
  Iris logo    160x160, center (540, 80)
  [Applications folder at y=280 — real icon]
  Arrow        130x160, center (540, 420)
  [Iris.app at y=620 — real icon]
  Video frame  760x260, center (540, 810)
  Hand         contain(280,200), top-left (0, 770)
  Instruction  22pt white, center (540, 960)
"""
import os, subprocess, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A    = os.path.join(HERE, "assets")
OUT  = os.path.join(HERE, "dmg_background.png")
W, H = 1080, 1000


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


# ── 1. Background: willow canopy, scale to 1080 wide, crop top 1000px ─────────
src = Image.open(os.path.join(A, "dmg-reference.jpg"))
sw, sh = src.size                        # 736 x 1308
src = src.resize((W, round(sh * W / sw)), Image.LANCZOS)
bg  = src.crop((0, 0, W, H)).convert("RGBA")

# ── 2. Iris logo: 160x160, center (540, 80) ───────────────────────────────────
logo = Image.open(os.path.join(A, "iris-logo-white-transparent.png")).convert("RGBA")
logo = logo.resize((160, 160), Image.LANCZOS)
bg.alpha_composite(logo, (540 - 80, 80 - 80))   # top-left (460, 0)

# ── 3. Arrow: 130x160, center (540, 420) ─────────────────────────────────────
arrow = remove_white_bg(Image.open(os.path.join(A, "arrow.png")))
arrow = arrow.resize((130, 160), Image.LANCZOS)
bg.alpha_composite(arrow, (540 - 65, 420 - 80))  # top-left (475, 340)

# ── 4. Video thumbnail: 760x260, center (540, 810) ───────────────────────────
VW, VH = 760, 260
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
# 2px black border
framed = Image.new("RGBA", (VW + 4, VH + 4), (0, 0, 0, 255))
framed.paste(frame, (2, 2))
vx = 540 - (VW + 4) // 2  # = 158
vy = 810 - (VH + 4) // 2  # = 678
bg.alpha_composite(framed, (vx, vy))

# ── 5. Pointing hand: contain(280,200), top-left (0, 770) ────────────────────
finger = remove_white_bg(Image.open(os.path.join(A, "point.png")))
finger = contain(finger, 280, 200)
bg.alpha_composite(finger, (0, 770))

# ── 6. Instruction text: centered at (540, 960) ───────────────────────────────
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
font22  = load_font(22)
draw_centered(od, "Drag Iris to Applications to install", 540, 960, font22, (255, 255, 255, 255))
bg = Image.alpha_composite(bg, overlay)

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
