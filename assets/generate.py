#!/usr/bin/env python3
"""Regenerate the Nexus page images from the source screenshot.

  assets/gallery-1920x1080.jpg  (refiners with mute badge, gallery slot)
  assets/header-1300x372.jpg     (wide crop + title overlay, banner)

The source is the wiki shot of all three refiners (small, medium, large)
on a dark red backdrop. Two framings come out of it:

  gallery  the whole frame, fitted to 16:9 over a blurred fill of
           itself, with a muted-speaker badge bottom-right, which is
           the point of the mod.
  header   a band cropped off the top at full source width, so all
           three refiners stay in frame and the title has the empty
           dark backdrop top-left to sit on.

Source attribution: see assets/src/ATTRIBUTION.md.

Usage: python3 assets/generate.py   (or: make assets)
Requires: Pillow (pip install Pillow). Typeface is vendored (see FONT).
"""

import os

from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src", "gallery-refiners.jpg")
GAL = os.path.join(HERE, "gallery-1920x1080.jpg")
HDR = os.path.join(HERE, "header-1300x372.jpg")

# In-game heading typeface, vendored (SIL OFL 1.1):
# https://github.com/NMSCD/No-Mans-Sky-Universal-Font
FONT = os.path.join(HERE, "fonts", "GeosansLight-NMS.ttf")

TITLE = ["SHUT UP REFINERS"]
SUBTITLE = "SMALL  \u2022  MEDIUM  \u2022  LARGE  \u2022  PERSONAL"

# Header crop, in source pixels: full source width so all three refiners
# stay in frame, band taken from below the top edge where the empty
# backdrop gives the title room. The source is 1114x449 with a dark
# few-pixel border that load() shaves off, so the crop works on the
# shaved 1108x443 frame.
HDR_X = 0
HDR_Y = 60
HDR_W = 1108

# Pixels shaved off every source edge on load. The wiki file carries a
# near-black border that would otherwise print as a hard line where the
# fitted gallery frame meets its blurred fill.
BORDER = 3

# Header size in output pixels.
HDR_OUT_W = 1300
HDR_OUT_H = 372

# Title placement in the header.
TITLE_X = 48
TITLE_Y = 48
TITLE_SIZE = 50
TITLE_GAP = 62
SUBTITLE_SIZE = 30

# Gallery size in output pixels.
GAL_W = 1920
GAL_H = 1080

# Muted-speaker badge placement in the gallery.
BADGE_CX = 1722
BADGE_CY = 900
BADGE_R = 110

X_RED = (255, 57, 0)


def text_shadowed(d, xy, s, font, fill):
    x, y = xy
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-2, -2), (2, -2), (-2, 2), (2, 2)):
        d.text((x + dx, y + dy), s, font=font, fill=(0, 0, 0))
    d.text((x, y), s, font=font, fill=fill)


def load():
    img = Image.open(SRC).convert("RGB")
    return img.crop((BORDER, BORDER, img.width - BORDER, img.height - BORDER))


def header():
    img = load()
    assert img.size[0] >= HDR_X + HDR_W, f"crop too wide for source: {img.size}"

    band_h = int(HDR_W * HDR_OUT_H / HDR_OUT_W)
    assert HDR_Y + band_h <= img.size[1], f"crop too tall for source: {img.size}"
    band = img.crop((HDR_X, HDR_Y, HDR_X + HDR_W, HDR_Y + band_h))
    band = band.resize((HDR_OUT_W, HDR_OUT_H), Image.LANCZOS)
    d = ImageDraw.Draw(band, "RGBA")
    # left-weighted gradient: title sits on the left
    for x in range(HDR_OUT_W):
        a = int(205 * max(0.0, 1 - x / (HDR_OUT_W * 0.62)) ** 1.5)
        d.rectangle([x, 0, x + 1, HDR_OUT_H], fill=(0, 0, 0, a))
    band = band.convert("RGB")
    d = ImageDraw.Draw(band)
    fb = ImageFont.truetype(FONT, TITLE_SIZE)
    fs = ImageFont.truetype(FONT, SUBTITLE_SIZE)

    for i, line in enumerate(TITLE):
        text_shadowed(d, (TITLE_X, TITLE_Y + i * TITLE_GAP), line, fb, (255, 255, 255))
    text_shadowed(
        d,
        (TITLE_X + 2, TITLE_Y + len(TITLE) * TITLE_GAP + 8),
        SUBTITLE,
        fs,
        (255, 205, 130),
    )
    band.save(HDR, quality=92)
    print(f"wrote {HDR}")


def draw_mute_badge(img):
    """Draw a muted-speaker badge: white speaker glyph with a red X
    where the sound waves would be, on a dark disc."""
    d = ImageDraw.Draw(img)
    cx, cy, r = BADGE_CX, BADGE_CY, BADGE_R
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(12, 8, 8))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255), width=6)
    # speaker cone and back box, left of center
    d.rectangle([cx - 90, cy - 28, cx - 60, cy + 28], fill=(255, 255, 255))
    d.polygon(
        [(cx - 60, cy - 28), (cx - 10, cy - 78), (cx - 10, cy + 78), (cx - 60, cy + 28)],
        fill=(255, 255, 255),
    )
    # the X, same style as the gallery cross on the sibling mods
    x0, y0, x1, y1 = cx + 8, cy - 58, cx + 88, cy + 58
    d.line([(x0, y0), (x1, y1)], fill=(0, 0, 0), width=30)
    d.line([(x1, y0), (x0, y1)], fill=(0, 0, 0), width=30)
    d.line([(x0, y0), (x1, y1)], fill=X_RED, width=22)
    d.line([(x1, y0), (x0, y1)], fill=X_RED, width=22)


def gallery():
    src = load()
    # blurred fill: cover the frame, blur it, darken it, so the fitted
    # frame below lands on its own backdrop instead of a hard edge
    scale = max(GAL_W / src.width, GAL_H / src.height)
    bg = src.resize(
        (round(src.width * scale), round(src.height * scale)), Image.LANCZOS
    )
    left = (bg.width - GAL_W) // 2
    top = (bg.height - GAL_H) // 2
    bg = bg.crop((left, top, left + GAL_W, top + GAL_H))
    bg = bg.filter(ImageFilter.GaussianBlur(40))
    bg = Image.blend(bg, Image.new("RGB", bg.size), 0.45)
    # fitted frame: full width, so all three refiners stay in frame.
    # Pasted through a mask feathered top and bottom so no hard edge
    # shows where the frame meets its blurred fill.
    fg_w = GAL_W
    fg_h = round(src.height * GAL_W / src.width)
    fg = src.resize((fg_w, fg_h), Image.LANCZOS)
    top = (GAL_H - fg_h) // 2
    layer = Image.new("RGB", (GAL_W, GAL_H))
    layer.paste(fg, (0, top))
    feather = 30
    mask_img = Image.new("L", (GAL_W, GAL_H))
    mask = ImageDraw.Draw(mask_img)
    mask.rectangle([0, top, GAL_W, top + fg_h], fill=255)
    for i in range(feather):
        a = int(255 * (i + 1) / (feather + 1))
        mask.line([(0, top + i), (GAL_W, top + i)], fill=a)
        mask.line([(0, top + fg_h - 1 - i), (GAL_W, top + fg_h - 1 - i)], fill=a)
    bg.paste(layer, (0, 0), mask_img)
    draw_mute_badge(bg)
    bg.save(GAL, quality=92)
    print(f"wrote {GAL}")


if __name__ == "__main__":
    header()
    gallery()
