"""
LaTeX-style layout solver for the round 360x360 watch face.

Each ROW declares its content + font + alignment. The solver:

  1. Reads the actual .fnt char widths so it knows true rendered widths.
  2. Verifies every row fits inside the round chord at its y-coordinate
     (with a configurable margin).
  3. Computes x-positions per alignment ("center", "left@x", "right@x",
     "spread:N" for evenly-spaced columns).
  4. Reports overflows and prints Monkey C-ready constants.

Run with:

    uv run python art/build_layout.py
"""

from __future__ import annotations
from pathlib import Path
import math
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
FONTS_DIR = ROOT / "resources" / "fonts"

CX, CY = 180, 180
RADIUS = 180
ROUND_MARGIN = 10        # px stay-clear from the bezel


def parse_fnt(path: Path):
    """Return ({char_id: xadvance}, line_height, base)."""
    widths, line_height, base = {}, 0, 0
    char_re = re.compile(r"(\w+)=(-?\d+)")
    for line in path.read_text().splitlines():
        if line.startswith("char id="):
            kv = dict(char_re.findall(line))
            widths[int(kv["id"])] = int(kv["xadvance"])
        elif line.startswith("common "):
            kv = dict(char_re.findall(line))
            line_height = int(kv["lineHeight"])
            base = int(kv["base"])
    return widths, line_height, base


# Load every available size up front.
FONTS = {}
for fnt in FONTS_DIR.glob("inter_*.fnt"):
    suffix = fnt.stem.replace("inter_", "")
    FONTS[suffix] = parse_fnt(fnt)


def text_width(text: str, font: str) -> int:
    widths, _, _ = FONTS[font]
    return sum(widths.get(ord(c), widths.get(ord(" "), 0)) for c in text)


def line_height(font: str) -> int:
    return FONTS[font][1]


def chord_width(y: int) -> int:
    """Horizontal pixels available inside the round display at row y."""
    dy = abs(y - CY)
    inner = RADIUS - ROUND_MARGIN
    if dy >= inner:
        return 0
    return int(2 * math.sqrt(inner * inner - dy * dy))


# ─── Content of the watch face ──────────────────────────────────────────────
# Each row: (anchor_y, font, alignment, content)
#   anchor_y is the TOP of the text bounding box.
#   alignment:
#     "center"        — centered horizontally on the screen
#     "spread:N:items"— N evenly-spaced items, content is "|"-joined
#     "left:X"        — left-justified, anchor at x=X
#     "right:X"       — right-justified, anchor at x=X

ROWS = [
    # Top: live weather condition + temp.
    (48,  "tiny",  "center",       "cloudy 55f"),
    # Date — compact, lowercase.
    (74,  "tiny",  "center",       "tue · 09 may 26 · wk19"),
    # Time — the largest element, sits in the visual centre.
    (130, "big",   "center",       "10:42"),
    # Stats — units in-line, no labels: cal · steps · body battery · heart rate.
    (218, "small", "spread:4",     "342kc|6.4k|73%|72bpm"),
    # Footer — watch battery and sunrise/sunset.
    (290, "tiny",  "center",       "wb 78% · sun 6:24a 8:42p"),
]


def solve():
    print(f"Round chord widths (margin={ROUND_MARGIN}):")
    for y in (20, 40, 80, 110, 180, 220, 280, 310, 330):
        print(f"  y={y:3d}  → {chord_width(y)}px")
    print()

    issues = 0
    print(f"{'y':>4} {'font':<6} {'align':<10} {'chord':>6} {'used':>6} content")
    print("─" * 80)
    placements = []
    for y, font, align, content in ROWS:
        chord = chord_width(y)
        if align == "center":
            w = text_width(content, font)
            x = CX - w // 2
            slot = [(x, content)]
            used = w
        elif align.startswith("spread:"):
            n = int(align.split(":")[1])
            items = content.split("|")
            assert len(items) == n
            inner = chord - 8
            step = inner // n
            slot = []
            used = 0
            for i, item in enumerate(items):
                ix = CX - inner // 2 + i * step + step // 2
                iw = text_width(item, font)
                slot.append((ix - iw // 2, item))
                used = max(used, ix + iw // 2 - (CX - inner // 2))
        elif align.startswith("left:"):
            ax = int(align.split(":")[1])
            slot = [(ax, content)]
            used = text_width(content, font)
        elif align.startswith("right:"):
            ax = int(align.split(":")[1])
            slot = [(ax - text_width(content, font), content)]
            used = text_width(content, font)
        else:
            raise ValueError(f"unknown align {align!r}")

        ok = used <= chord
        marker = " " if ok else "!"
        if not ok:
            issues += 1
        print(f"{marker}{y:>3} {font:<6} {align:<10} {chord:>6} {used:>6}  {content}")
        placements.append((y, font, align, slot))

    if issues:
        print(f"\n{issues} row(s) overflow the round mask.")
        sys.exit(1)
    return placements


if __name__ == "__main__":
    solve()
