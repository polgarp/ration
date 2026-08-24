#!/usr/bin/env python3
"""Generates menu bar mark candidates as SVG.

Every candidate is a function of (used, elapsed) percentages, because the
point of Ration's mark is to show both at once: how much of the window is
spent, and how much *should* be spent by now. A glyph that can only show one
number throws away the whole idea.

Drawn for a template image — the system tints it, so only silhouette matters.
Everything is pure black on transparent; nothing may rely on colour.

Canvas is 36x36 (18pt at 2x), artwork inset to leave optical breathing room.
"""

import math
import pathlib

SIZE = 36
CX = CY = SIZE / 2

HEADER = f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
FOOTER = "</svg>"


def polar(cx, cy, r, deg):
    a = math.radians(deg - 90)  # 0 deg = 12 o'clock
    return cx + r * math.cos(a), cy + r * math.sin(a)


def arc_path(cx, cy, r, start_deg, end_deg):
    x0, y0 = polar(cx, cy, r, start_deg)
    x1, y1 = polar(cx, cy, r, end_deg)
    large = 1 if (end_deg - start_deg) % 360 > 180 else 0
    return f"M {x0:.2f} {y0:.2f} A {r:.2f} {r:.2f} 0 {large} 1 {x1:.2f} {y1:.2f}"


# ---------------------------------------------------------------- candidates

def ring(used, elapsed):
    """A: full ring, arc filled to usage, external tick at the pace mark."""
    r, w = 12.5, 4.0
    out = [f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="black" '
           f'stroke-opacity="0.25" stroke-width="{w}"/>']
    if used > 0.5:
        sweep = min(used, 100) / 100 * 359.9
        out.append(f'<path d="{arc_path(CX, CY, r, 0, sweep)}" fill="none" stroke="black" '
                   f'stroke-width="{w}" stroke-linecap="butt"/>')
    # Pace tick sits outside the ring so it reads as a target, not as data.
    tx0, ty0 = polar(CX, CY, r + w / 2 + 0.5, elapsed / 100 * 360)
    tx1, ty1 = polar(CX, CY, r + w / 2 + 4.0, elapsed / 100 * 360)
    out.append(f'<line x1="{tx0:.2f}" y1="{ty0:.2f}" x2="{tx1:.2f}" y2="{ty1:.2f}" '
               f'stroke="black" stroke-width="2.4" stroke-linecap="round"/>')
    return "".join(out)


def capsule(used, elapsed):
    """B: horizontal capsule filling left to right, hairline at the pace mark."""
    w, h = 28.0, 13.0
    x, y = (SIZE - w) / 2, (SIZE - h) / 2
    r = h / 2
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="none" '
           f'stroke="black" stroke-width="2.2"/>']
    inset = 3.0
    inner_w = w - inset * 2
    fill = inner_w * min(used, 100) / 100
    if fill > 0.5:
        out.append(f'<rect x="{x + inset}" y="{y + inset}" width="{fill:.2f}" '
                   f'height="{h - inset * 2}" rx="{(h - inset * 2) / 2:.2f}" fill="black"/>')
    px = x + inset + inner_w * min(elapsed, 100) / 100
    out.append(f'<line x1="{px:.2f}" y1="{y - 3.5}" x2="{px:.2f}" y2="{y + h + 3.5}" '
               f'stroke="black" stroke-width="2.2" stroke-linecap="round"/>')
    return "".join(out)


def gauge(used, elapsed):
    """C: speedometer — 200-degree arc, filled to usage, notch at the pace mark."""
    r, w = 13.0, 3.8
    start, end = -100.0, 100.0
    span = end - start
    cy = CY + 4
    out = [f'<path d="{arc_path(CX, cy, r, start, end)}" fill="none" stroke="black" '
           f'stroke-opacity="0.25" stroke-width="{w}" stroke-linecap="round"/>']
    if used > 0.5:
        out.append(f'<path d="{arc_path(CX, cy, r, start, start + span * min(used,100)/100)}" '
                   f'fill="none" stroke="black" stroke-width="{w}" stroke-linecap="round"/>')
    deg = start + span * min(elapsed, 100) / 100
    tx0, ty0 = polar(CX, cy, r - w / 2 - 1.2, deg)
    tx1, ty1 = polar(CX, cy, r + w / 2 + 1.2, deg)
    out.append(f'<line x1="{tx0:.2f}" y1="{ty0:.2f}" x2="{tx1:.2f}" y2="{ty1:.2f}" '
               f'stroke="black" stroke-width="2.6" stroke-linecap="round"/>')
    return "".join(out)


def tally(used, elapsed):
    """D: seven marks for seven days — spent ones struck through. Literal to the name."""
    n = 7
    gap, bw = 4.2, 2.4
    total = n * bw + (n - 1) * (gap - bw)
    x0 = (SIZE - total) / 2
    top, bot = 8.0, 28.0
    spent = round(min(used, 100) / 100 * n)
    due = round(min(elapsed, 100) / 100 * n)
    out = []
    for i in range(n):
        x = x0 + i * gap
        op = "1" if i < spent else "0.28"
        out.append(f'<line x1="{x:.2f}" y1="{top}" x2="{x:.2f}" y2="{bot}" stroke="black" '
                   f'stroke-opacity="{op}" stroke-width="{bw}" stroke-linecap="round"/>')
    px = x0 + max(0, due - 0.5) * gap
    out.append(f'<line x1="{px:.2f}" y1="{bot + 3.0}" x2="{px:.2f}" y2="{bot + 4.6}" '
               f'stroke="black" stroke-width="2.4" stroke-linecap="round"/>')
    return "".join(out)


def wedge(used, elapsed):
    """E: a portion of a disc — the plain reading of the name. Cannot show pace."""
    r = 13.0
    remaining = max(0.0, 100 - used)
    out = [f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="black" stroke-width="2.2"/>']
    if remaining > 0.5:
        sweep = min(remaining, 99.9) / 100 * 360
        x1, y1 = polar(CX, CY, r, 0)
        x2, y2 = polar(CX, CY, r, sweep)
        large = 1 if sweep > 180 else 0
        out.append(f'<path d="M {CX} {CY} L {x1:.2f} {y1:.2f} '
                   f'A {r} {r} 0 {large} 1 {x2:.2f} {y2:.2f} Z" fill="black"/>')
    return "".join(out)


CANDIDATES = {
    "A-ring": ring,
    "B-capsule": capsule,
    "C-gauge": gauge,
    "D-tally": tally,
    "E-wedge": wedge,
}

# The states that matter, named for what they mean rather than their numbers.
STATES = [
    ("fresh",     2,  4),    # Monday morning
    ("on-pace",  48, 50),    # the unremarkable middle
    ("hot",      84, 69),    # ahead of pace, the warning case
    ("spent",    97, 72),    # nearly out, well before the reset
]


def main():
    out = pathlib.Path(__file__).parent / "marks"
    out.mkdir(exist_ok=True)
    for name, fn in CANDIDATES.items():
        for state, used, elapsed in STATES:
            svg = HEADER + fn(used, elapsed) + FOOTER
            (out / f"{name}--{state}.svg").write_text(svg)
    print(f"wrote {len(CANDIDATES) * len(STATES)} svgs to {out}")


if __name__ == "__main__":
    main()
