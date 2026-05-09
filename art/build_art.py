"""
Generate the watch face's small image assets.

Currently just the launcher icon — the watch face itself is text-only and
needs no bitmap backgrounds. Run with:

    uv run --with pillow python art/build_art.py
"""

from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "resources" / "drawables"
OUT.mkdir(parents=True, exist_ok=True)


def launcher_icon() -> Image.Image:
    """60x60 launcher icon — concentric rings as a tiny graphic mark."""
    img = Image.new("RGBA", (60, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 59, 59], fill=(0, 0, 0), outline=(255, 255, 255), width=2)
    d.ellipse([14, 14, 46, 46], outline=(255, 255, 255), width=2)
    d.ellipse([24, 24, 36, 36], fill=(255, 255, 255))
    return img


def main():
    print(f"Writing to {OUT}")
    launcher_icon().save(OUT / "launcher_icon.png")
    print("  ✓ launcher_icon.png")


if __name__ == "__main__":
    main()
