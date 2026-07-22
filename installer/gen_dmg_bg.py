#!/usr/bin/env python3
"""Generate the Iris DMG background (420x560).

Layout matches the latest spec:
- dmg-reference.jpg stretched to the window size as the backdrop
- small arrow between the Applications (top) and Iris (bottom) icon slots
- engraved pointing hand emerging from the left edge, toward the pill
- semi-transparent dark plates behind each Finder label so the white text reads
- white "Applications" / "Iris" labels
- drag + Gatekeeper info lines
- outlined "DOWNLOAD INSTRUCTIONS" pill near the bottom

The app icon and Applications alias are placed by create-dmg, NOT drawn here.
Outputs installer/dmg_background.png.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
OUT = os.path.join(HERE, "dmg_background.png")

W, H = 420, 560
CX = 210


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def font(size, bold=False):
    # Arial carries the → glyph that Helvetica.ttc renders as tofu.
    for p in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
              else "/System/Library/Fonts/Supplemental/Arial.ttf",
              "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()


def centered(d, cx, y, text, f, fill):
    box = d.textbbox((0, 0), text, font=f)
    d.text((cx - (box[2] - box[0]) / 2, y), text, font=f, fill=fill)


def key_white(im, thr):
    """Set alpha=0 where R,G,B all exceed thr (near-pure-white background)."""
    im = im.convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] > thr) & (a[:, :, 1] > thr) & (a[:, :, 2] > thr)
    a[mask, 3] = 0
    return Image.fromarray(a)


# ---- backdrop ----
bg = Image.open(os.path.join(A, "dmg-reference.jpg")).convert("RGBA").resize((W, H), Image.LANCZOS)

# ---- arrow between the two icon slots (center 210,220) ----
arrow = key_white(Image.open(os.path.join(A, "arrow.png")), 230)
aw, ah = arrow.size
s = min(60 / aw, 90 / ah)                      # contain within 60x90, keep aspect
arrow = arrow.resize((round(aw * s), round(ah * s)), Image.LANCZOS)
bg.alpha_composite(arrow, (CX - arrow.width // 2, 220 - arrow.height // 2))

# ---- pointing hand from the left edge (conservative key keeps mid-tones) ----
finger = key_white(Image.open(os.path.join(A, "point.png")), 245)
finger = finger.resize((140, 95), Image.LANCZOS)
bg.alpha_composite(finger, (-10, 430))

d = ImageDraw.Draw(bg)

# ---- dark plates behind the Finder labels (#00000088) ----
# Positions reconciled to the FIX-3 icon geometry (icon-size 85):
#   Applications icon center y=80  -> Finder label ~y126-142, my text y148
#   Iris icon center y=310         -> Finder label ~y356-372, my text y368
plate = Image.new("RGBA", (W, H), (0, 0, 0, 0))
pd = ImageDraw.Draw(plate)
pd.rectangle([130, 120, 300, 164], fill=(0, 0, 0, 136))   # Applications band
pd.rectangle([130, 350, 300, 386], fill=(0, 0, 0, 136))   # Iris band
bg = Image.alpha_composite(bg, plate)
d = ImageDraw.Draw(bg)

# ---- white labels ----
centered(d, CX, 148, "Applications", font(12), hx("FFFFFF"))
centered(d, CX, 368, "Iris", font(12), hx("FFFFFF"))

# ---- info lines ----
centered(d, CX, 396, "Drag Iris to Applications to install", font(11), hx("DDDDDD"))
centered(d, CX, 414, "Blocked? System Settings → Privacy & Security → Open Anyway",
         font(9), hx("8ab88a"))

# ---- DOWNLOAD INSTRUCTIONS pill (center 210,520; 260x34, r17) ----
pw, ph, py = 260, 34, 520
x0, y0 = CX - pw // 2, py - ph // 2
d.rounded_rectangle([x0, y0, x0 + pw, y0 + ph], radius=17,
                    fill=hx("111111"), outline=hx("FFFFFF"), width=1)
centered(d, CX, py - 6, "DOWNLOAD INSTRUCTIONS", font(10), hx("FFFFFF"))

bg.convert("RGB").save(OUT)
print("wrote", OUT, bg.size)
