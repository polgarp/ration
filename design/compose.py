#!/usr/bin/env python3
"""Builds the mark comparison sheets.

Template images carry only alpha — macOS tints them to suit the menu bar. So
the dark sheet is not a guess: it is the same silhouette, tinted white, on the
menu bar's dark grey. Both sheets show every mark at true menu bar size
alongside an enlargement, because a mark that only works at 4x is not a mark.
"""

import pathlib
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).parent
import sys
ROUND = sys.argv[1] if len(sys.argv) > 1 else "marks"
MARKS = HERE / ROUND

if ROUND == "marks2":
    CANDIDATES = [
        ("F-ringfill", "Ring (dot when over)"),
        ("G-discfill", "Disc (halo when over)"),
        ("H-jar",      "Jar (lid when over)"),
        ("I-bars",     "Bars (dot when over)"),
    ]
    STATES = [("monday", "Monday 3%"), ("steady", "Steady 45%"), ("hot", "Over pace 65%"), ("spent", "Nearly out 92%")]
    LABELS = {"monday": "97%", "steady": "55%", "hot": "35%", "spent": "8%"}
else:
    CANDIDATES = [
        ("A-ring",    "Ring + pace tick"),
        ("B-capsule", "Capsule + pace line"),
        ("C-gauge",   "Gauge + pace notch"),
        ("D-tally",   "Seven-day tally"),
        ("E-wedge",   "Wedge (no pace)"),
    ]
    STATES = [("fresh", "Monday"), ("on-pace", "On pace"), ("hot", "Ahead +15"), ("spent", "Nearly out")]
    LABELS = {"fresh": "98%", "on-pace": "52%", "hot": "16%", "spent": "3%"}

BIG = 88          # enlarged mark
TRUE = 36         # true menu bar size at 2x
SCALE = 2         # sheet is drawn at 2x for retina

PAD = 28 * SCALE
COL_W = 132 * SCALE
ROW_H = 116 * SCALE
LABEL_W = 150 * SCALE


def font(size, bold=False):
    names = ["/System/Library/Fonts/SFNSDisplay.ttf", "/System/Library/Fonts/Helvetica.ttc"]
    for n in names:
        try:
            return ImageFont.truetype(n, size, index=1 if bold and n.endswith("ttc") else 0)
        except Exception:
            continue
    return ImageFont.load_default()


def tinted(path, colour):
    """Recolour a black-on-transparent mark, exactly as a template image is tinted."""
    src = Image.open(path).convert("RGBA")
    out = Image.new("RGBA", src.size, colour + (0,))
    out.putalpha(src.getchannel("A"))
    return out


def sheet(dark: bool) -> Image.Image:
    bg      = (28, 28, 30) if dark else (250, 250, 252)
    barbg   = (52, 52, 56) if dark else (232, 232, 236)
    ink     = (245, 245, 247) if dark else (18, 18, 20)
    dim     = (150, 150, 156) if dark else (120, 120, 128)
    glyph   = (255, 255, 255) if dark else (0, 0, 0)

    W = LABEL_W + COL_W * len(STATES) + PAD * 2
    H = PAD * 3 + 34 * SCALE + ROW_H * len(CANDIDATES)
    im = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(im)

    f_head = font(15 * SCALE, bold=True)
    f_lab = font(13 * SCALE)
    f_small = font(11 * SCALE)

    d.text((PAD, PAD - 6 * SCALE), "Dark menu bar" if dark else "Light menu bar", font=f_head, fill=ink)

    y0 = PAD + 30 * SCALE
    for ci, (_, state_label) in enumerate(STATES):
        x = LABEL_W + PAD + ci * COL_W + COL_W // 2
        d.text((x, y0), state_label, font=f_small, fill=dim, anchor="ma")

    y = y0 + 22 * SCALE
    for key, label in CANDIDATES:
        d.text((PAD, y + ROW_H // 2 - 22 * SCALE), label.split(" + ")[0].split(" (")[0],
               font=f_lab, fill=ink)
        if "+" in label or "(" in label:
            tail = label.split(" ", 1)[1] if " " in label else ""
            d.text((PAD, y + ROW_H // 2 - 2 * SCALE), tail, font=f_small, fill=dim)

        for ci, (state, _) in enumerate(STATES):
            cx = LABEL_W + PAD + ci * COL_W + COL_W // 2

            big = tinted(MARKS / f"{key}--{state}--big.png", glyph).resize((BIG, BIG), Image.LANCZOS)
            im.paste(big, (cx - BIG // 2, y), big)

            # True size, sitting on a menu bar swatch so the scale is honest.
            sw_w, sw_h = 54 * SCALE, 26 * SCALE
            sx, sy = cx - sw_w // 2, y + BIG + 8 * SCALE
            d.rounded_rectangle([sx, sy, sx + sw_w, sy + sw_h], radius=4 * SCALE, fill=barbg)
            true = tinted(MARKS / f"{key}--{state}@2x.png", glyph)
            im.paste(true, (sx + 8 * SCALE, sy + (sw_h - TRUE) // 2), true)
            d.text((sx + 8 * SCALE + TRUE + 4 * SCALE, sy + sw_h // 2),
                   LABELS[state],
                   font=f_small, fill=glyph, anchor="lm")
        y += ROW_H

    return im


def main():
    for dark in (False, True):
        im = sheet(dark)
        name = f"{ROUND}-dark.png" if dark else f"{ROUND}-light.png"
        im.save(HERE / name)
        print("wrote", name, im.size)


if __name__ == "__main__":
    main()
