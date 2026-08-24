#!/usr/bin/env python3
"""Round two of the menu bar mark.

Round one tried to encode usage *and* pace positionally. At true menu bar size
the pace marker was 2-3 pixels and read as damage to the form rather than as a
target. Two findings carried forward:

  1. Fill grows as you SPEND, never as you have left. Ink must track alarm, or
     the icon shouts loudest on a Monday when nothing is wrong.
  2. Pace is BINARY here — over or not. A state change survives at 18pt; a
     position does not.

So: one value in the fill, one bit in the treatment.
"""

import math
import pathlib

SIZE = 36
CX = CY = SIZE / 2
HEADER = f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
FOOTER = "</svg>"


def polar(cx, cy, r, deg):
    a = math.radians(deg - 90)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def arc_path(cx, cy, r, start_deg, end_deg):
    x0, y0 = polar(cx, cy, r, start_deg)
    x1, y1 = polar(cx, cy, r, end_deg)
    large = 1 if (end_deg - start_deg) % 360 > 180 else 0
    return f"M {x0:.2f} {y0:.2f} A {r:.2f} {r:.2f} 0 {large} 1 {x1:.2f} {y1:.2f}"


def ring_fill(used, over):
    """F: ring fills clockwise as you spend; a centre dot marks over-pace."""
    r, w = 12.0, 4.4
    out = [f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="black" '
           f'stroke-opacity="0.28" stroke-width="{w}"/>']
    if used > 0.5:
        out.append(f'<path d="{arc_path(CX, CY, r, 0, min(used,100)/100*359.9)}" fill="none" '
                   f'stroke="black" stroke-width="{w}"/>')
    if over:
        out.append(f'<circle cx="{CX}" cy="{CY}" r="3.6" fill="black"/>')
    return "".join(out)


def disc_fill(used, over):
    """G: a disc filling clockwise — the portion you have eaten, not the one left."""
    r = 11.0
    out = []
    if over:
        # An outer ring, set off by a gap, so the alarm is a whole extra form.
        out.append(f'<circle cx="{CX}" cy="{CY}" r="{r + 4.2}" fill="none" stroke="black" stroke-width="2.2"/>')
    out.append(f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="black" stroke-width="2.0"/>')
    if used > 0.5:
        sweep = min(used, 99.9) / 100 * 360
        x1, y1 = polar(CX, CY, r, 0)
        x2, y2 = polar(CX, CY, r, sweep)
        large = 1 if sweep > 180 else 0
        out.append(f'<path d="M {CX} {CY} L {x1:.2f} {y1:.2f} '
                   f'A {r} {r} 0 {large} 1 {x2:.2f} {y2:.2f} Z" fill="black"/>')
    return "".join(out)


def jar(used, over):
    """H: a vessel filling from the bottom — the most literal reading of a ration."""
    w, h = 19.0, 22.0
    x, y = (SIZE - w) / 2, (SIZE - h) / 2
    r = 3.2
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="none" '
           f'stroke="black" stroke-width="2.4"/>']
    inset = 3.4
    ih = h - inset * 2
    fh = ih * min(used, 100) / 100
    if fh > 0.5:
        out.append(f'<rect x="{x + inset}" y="{y + inset + (ih - fh):.2f}" '
                   f'width="{w - inset * 2}" height="{fh:.2f}" rx="1.4" fill="black"/>')
    if over:
        # A lid, sitting clear of the vessel.
        out.append(f'<rect x="{x - 1.5}" y="{y - 5.6}" width="{w + 3}" height="2.6" rx="1.3" fill="black"/>')
    return "".join(out)


def bars(used, over):
    """I: three stacked bars filling bottom-up — coarse by design, so it reads instantly."""
    n = 3
    w, gap, bh = 20.0, 2.4, 6.0
    x = (SIZE - w) / 2
    total = n * bh + (n - 1) * gap
    y0 = (SIZE - total) / 2
    lit = min(n, math.ceil(min(used, 100) / 100 * n))
    out = []
    for i in range(n):
        y = y0 + (n - 1 - i) * (bh + gap)
        filled = i < lit
        out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{bh}" rx="{bh/2}" '
                   f'fill="{"black" if filled else "none"}" stroke="black" '
                   f'stroke-width="{0 if filled else 1.8}" '
                   f'stroke-opacity="{0 if filled else 0.35}"/>')
    if over:
        out.append(f'<circle cx="{x + w + 4.0}" cy="{y0 - 1.0}" r="3.0" fill="black"/>')
    return "".join(out)


CANDIDATES = {"F-ringfill": ring_fill, "G-discfill": disc_fill, "H-jar": jar, "I-bars": bars}

# Pairs chosen so the over-pace treatment can be compared at similar fill.
STATES = [
    ("monday",   3,  False),
    ("steady",  45,  False),
    ("hot",     65,  True),
    ("spent",   92,  True),
]


def main():
    out = pathlib.Path(__file__).parent / "marks2"
    out.mkdir(exist_ok=True)
    for name, fn in CANDIDATES.items():
        for state, used, over in STATES:
            (out / f"{name}--{state}.svg").write_text(HEADER + fn(used, over) + FOOTER)
    print(f"wrote {len(CANDIDATES) * len(STATES)} svgs")


if __name__ == "__main__":
    main()
