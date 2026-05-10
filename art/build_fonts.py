"""
Generate Garmin-compatible bitmap fonts (.fnt + .png atlas) from a TTF.

Renders Aldrich (a geometric-square sans, near-identical to Eurostile) into
three sizes: tiny (date / pill text), small (steps), big (time).

Output goes to resources/fonts/ — referenced from resources/fonts/fonts.xml.

Run with:
    uv run --with pillow --with freetype-py python art/build_fonts.py
"""

from __future__ import annotations
from pathlib import Path
from PIL import Image
import freetype

ROOT = Path(__file__).resolve().parent.parent
TTF = ROOT / "art" / "_font_cache" / "Inter.ttf"
FACE_NAME = "Inter"
WEIGHT = 500   # 400=Regular, 500=Medium — heavier reads better at small sizes
OUT = ROOT / "resources" / "fonts"
OUT.mkdir(parents=True, exist_ok=True)

# Glyph ranges to bake into each font.
GLYPHS = sorted(set(
    range(0x20, 0x7F)        # printable ASCII
)) + [0xB0, 0xB7, 0x2022]    # degree sign, middle dot, bullet

# (suffix, point size, atlas width). Sizes chosen for micro-graphics rhythm.
SIZES = [
    ("tiny",   13, 256),     # care-label / tech text
    ("small",  16, 256),     # row labels / data values
    ("med",    24, 256),     # date / secondary headlines
    ("big",    66, 512),     # time
]


def render_atlas(face: freetype.Face, px: int, atlas_w: int):
    """Render every glyph into a single PNG atlas, return (image, char_records).

    Each char_record is a dict with the BMFont-style fields:
      id, x, y, width, height, xoffset, yoffset, xadvance.
    """
    face.set_pixel_sizes(0, px)
    ascender = face.size.ascender >> 6
    line_height = (face.size.height >> 6) + 2
    base = ascender + 1

    pad = 2
    # FT_LOAD_TARGET_LIGHT keeps stem positions unchanged (no horizontal
    # snapping) but emits softer, more accurately-shaped glyphs. On AMOLED
    # without subpixel rendering this looks far less grainy than NORMAL.
    load_flags = freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_LIGHT

    # First pass — render every glyph.
    glyphs = []
    for code in GLYPHS:
        face.load_char(chr(code), load_flags)
        bmp = face.glyph.bitmap
        glyphs.append({
            "id": code,
            "w": bmp.width,
            "h": bmp.rows,
            "buffer": bytes(bmp.buffer),
            "pitch": bmp.pitch,
            "left": face.glyph.bitmap_left,
            "top": face.glyph.bitmap_top,
            "advance": face.glyph.advance.x >> 6,
        })

    # Second pass — pack into an RGBA atlas (glyph mask in the alpha channel,
    # RGB = white). This is the canonical BMFont layout that Garmin's renderer
    # picks up cleanly with anti-aliasing intact.
    img = Image.new("RGBA", (atlas_w, atlas_w), (255, 255, 255, 0))
    cx = pad
    cy = pad
    row_h = 0
    chars = []
    for g in glyphs:
        gw = max(g["w"], 1)
        gh = max(g["h"], 1)
        if cx + gw + pad > atlas_w:
            cx = pad
            cy += row_h + pad
            row_h = 0
        if g["w"] > 0 and g["h"] > 0:
            mask = Image.frombytes("L", (g["w"], g["h"]), g["buffer"], "raw", "L", g["pitch"])
            white = Image.new("RGBA", (g["w"], g["h"]), (255, 255, 255, 0))
            white.putalpha(mask)
            img.alpha_composite(white, (cx, cy))
        chars.append({
            "id": g["id"],
            "x": cx,
            "y": cy,
            "width": gw,
            "height": gh,
            "xoffset": g["left"],
            "yoffset": base - g["top"],
            "xadvance": g["advance"],
        })
        cx += gw + pad
        row_h = max(row_h, gh)

    final_h = cy + row_h + pad
    img = img.crop((0, 0, atlas_w, final_h))
    return img, chars, line_height, base


def write_fnt(path: Path, face_name: str, px: int, atlas_w: int, atlas_h: int,
              line_height: int, base: int, png_name: str, chars: list[dict]):
    """Write a Garmin-compatible BMFont text file."""
    lines = []
    lines.append(f'info face="{face_name}" size={px} bold=0 italic=0 charset="" '
                 'unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=2,2 outline=0')
    lines.append(f'common lineHeight={line_height} base={base} scaleW={atlas_w} '
                 f'scaleH={atlas_h} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4')
    lines.append(f'page id=0 file="{png_name}"')
    lines.append(f'chars count={len(chars)}')
    for c in chars:
        lines.append(
            f'char id={c["id"]:<5} x={c["x"]:<5} y={c["y"]:<5} '
            f'width={c["width"]:<5} height={c["height"]:<5} '
            f'xoffset={c["xoffset"]:<5} yoffset={c["yoffset"]:<5} '
            f'xadvance={c["xadvance"]:<5} page=0 chnl=15'
        )
    path.write_text("\n".join(lines) + "\n")


def main():
    if not TTF.exists():
        raise SystemExit(f"TTF not found at {TTF}")
    face = freetype.Face(str(TTF))

    # If this is a variable font, pin the weight (and optical size = px).
    if face.has_multiple_masters:
        info = face.get_variation_info()
        coords = []
        for axis in info.axes:
            if axis.tag == b"wght":
                coords.append(WEIGHT)
            elif axis.tag == b"opsz":
                coords.append(axis.default)
            else:
                coords.append(axis.default)
        face.set_var_design_coords(coords)

    # Clean out any old generated fonts first.
    for old in OUT.glob("archivo_*"):
        old.unlink()
    for old in OUT.glob("aldrich_*"):
        old.unlink()
    for old in OUT.glob("inter_*"):
        old.unlink()

    for suffix, px, atlas_w in SIZES:
        img, chars, line_h, base = render_atlas(face, px, atlas_w)
        png_name = f"inter_{suffix}.png"
        fnt_name = f"inter_{suffix}.fnt"
        img.save(OUT / png_name)
        write_fnt(
            OUT / fnt_name, face_name=FACE_NAME, px=px,
            atlas_w=img.width, atlas_h=img.height,
            line_height=line_h, base=base,
            png_name=png_name, chars=chars,
        )
        print(f"  ✓ {fnt_name}  ({img.size}, {len(chars)} chars)")


if __name__ == "__main__":
    main()
