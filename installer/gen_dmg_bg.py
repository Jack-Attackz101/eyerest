#!/usr/bin/env python3
"""Generate the Iris DMG background (380x720).

Layout with icon-size 215 (matches video thumbnail height exactly):
  Applications   (190,  65)  — create-dmg (42px clip at top; folder clearly visible)
  arrow UP       (190, 205)  — background art (midpoint of 65 and 345, rotated UP)
  Iris.app       (190, 345)  — create-dmg
  pointing hand  (-15, 100)  — background art (finger tip at y≈163, 300px above video)
  video art      (190, 575)  — 370x215 thumbnail (same height as 215px icon)
  Download Instructions.mp4 (190, 575) — create-dmg
"""
import glob
import os
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 380, 720
CX = 190


def key_white(im, thr=245):
    im = im.convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


def contain(im, box_w, box_h):
    w, h = im.size
    s = min(box_w / w, box_h / h)
    return im.resize((round(w * s), round(h * s)), Image.LANCZOS)


def video_thumb(mp4_path, w, h):
    """Extract a frame at 2s via ffmpeg; returns RGBA Image or None."""
    out = '/tmp/_iris_dmg_frame.png'
    try:
        r = subprocess.run(
            ['ffmpeg', '-y', '-ss', '2', '-i', mp4_path,
             '-vframes', '1', '-update', '1', '-q:v', '2', out],
            capture_output=True, timeout=15,
        )
        if os.path.exists(out) and os.path.getsize(out) > 0:
            img = Image.open(out).copy()
            return img.convert('RGBA').resize((w, h), Image.LANCZOS)
    except Exception as e:
        print(f'ffmpeg: {e}')
    return None


# ── backdrop ──────────────────────────────────────────────────────────────────
bg = Image.open(os.path.join(A, 'dmg-reference.jpg')).convert('RGBA').resize((W, H), Image.LANCZOS)

# ── chalk arrow (between Applications y=65 and Iris y=345, midpoint=205) ─────
# Rotated 180° so it points UP — indicating drag from Iris.app toward Applications.
arrow = key_white(Image.open(os.path.join(A, 'arrow.png')))
arrow = contain(arrow, 45, 58)
arrow = arrow.rotate(180)
bg.alpha_composite(arrow, (CX - arrow.width // 2, 205 - arrow.height // 2))

# ── pointing hand (finger tip at y≈163, 300px above video top) ───────────────
finger = Image.open(os.path.join(A, 'point.png')).convert('RGBA')
finger = contain(finger, 160, 107)
bg.alpha_composite(finger, (-15, 100))

# ── large video thumbnail (370×215, centered at 190,575) ─────────────────────
# VH=215 matches icon-size=215 exactly — thumbnail and clickable icon same height.
VW, VH = 370, 215
VCX, VCY = CX, 575
vx0, vy0 = VCX - VW // 2, VCY - VH // 2   # 30, 370
vx1, vy1 = vx0 + VW, vy0 + VH              # 350, 530
R = 14  # corner radius

mp4 = os.path.join(A, 'How to Install Iris.mp4')
thumb = video_thumb(mp4, VW, VH)

overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)

if thumb:
    # Rounded-corner mask
    cmask = Image.new('L', (VW, VH), 0)
    ImageDraw.Draw(cmask).rounded_rectangle([0, 0, VW - 1, VH - 1], radius=R, fill=255)
    thumb.putalpha(cmask)
    bg.alpha_composite(thumb, (vx0, vy0))
    # Subtle dark scrim so the play button reads clearly
    scrim = Image.new('RGBA', (VW, VH), (0, 0, 0, 0))
    ImageDraw.Draw(scrim).rounded_rectangle([0, 0, VW - 1, VH - 1], radius=R, fill=(0, 0, 0, 90))
    bg.alpha_composite(scrim, (vx0, vy0))
else:
    # Fallback: solid dark button
    od.rounded_rectangle([vx0, vy0, vx1, vy1], radius=R,
                         fill=(10, 10, 10, 240), outline=(255, 255, 255, 180), width=2)

# White border around the thumbnail
od.rounded_rectangle([vx0, vy0, vx1, vy1], radius=R,
                     outline=(255, 255, 255, 200), width=2)

# Play button: dark circle + white triangle
cr = 30
od.ellipse([VCX - cr, VCY - cr, VCX + cr, VCY + cr], fill=(0, 0, 0, 170))
# Triangle (pointing right)
tw = 22
th = 26
pts = [
    (VCX - tw // 3 + 3, VCY - th // 2),
    (VCX - tw // 3 + 3, VCY + th // 2),
    (VCX + tw + 3,       VCY),
]
od.polygon(pts, fill=(255, 255, 255, 240))

bg = Image.alpha_composite(bg, overlay)

bg.convert('RGB').save(OUT)
print('wrote', OUT, bg.size)
