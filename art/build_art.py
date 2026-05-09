"""
Build art for the Pokéface watch face.

Sprites are pulled from pokemondb.net (Gen 1 Red/Blue — authentic 56x56 4-color
Game Boy art), recolored to the DMG green palette, padded to 64x64, then
expanded to a 4-frame bob-animation strip and 2x-upscaled to 512x128.

Biomes are still procedurally drawn locally.

Run with:
  uv run --with pillow python art/build_art.py
"""

from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw
from urllib.request import Request, urlopen
import io
import random

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "resources" / "drawables"
OUT.mkdir(parents=True, exist_ok=True)

# Gen-1 inspired palette (chunky, high contrast).
PAL = {
    "sky_day":      (135, 206, 235),
    "sky_overcast": (160, 168, 178),
    "sky_storm":    (40, 44, 60),
    "sky_night":    (10, 14, 40),
    "sky_dusk":     (220, 130, 90),
    "grass":        (74, 156, 76),
    "grass_dark":   (44, 112, 56),
    "snow":         (236, 240, 245),
    "snow_dark":    (176, 188, 200),
    "puddle":       (60, 110, 160),
    "rain":         (140, 180, 220),
    "lightning":    (255, 230, 120),
    "moon":         (240, 240, 220),
    "star":         (255, 255, 255),
    "white":        (255, 255, 255),
    "black":        (16, 16, 16),
    "outline":      (32, 32, 40),
}

# Gen 1 starter trios: grass, fire, water.
POKEMON = [
    "bulbasaur",  "ivysaur",    "venusaur",    # grass
    "charmander", "charmeleon", "charizard",   # fire
    "squirtle",   "wartortle",  "blastoise",   # water
]

# Scarlet/Violet in-game sprites — 256x256 PNG, transparent background.
SPRITE_URL = "https://img.pokemondb.net/sprites/scarlet-violet/normal/{name}.png"

# A single big sprite per Pokémon — bob animation is done in code via a
# vertical translation, so we don't need a 4-frame strip and we can spend
# the saved bytes on resolution.
CELL_W = 170
CELL_H = 170

# Game Boy DMG (Pocket) green palette — the iconic 4-color "2-bit" look.
# Mapped from grayscale (darkest → lightest).
DMG_PALETTE = [
    (15, 56, 15),     # darkest  — outline
    (48, 98, 48),     # dark     — shadow
    (139, 172, 15),   # light    — body fill
    (155, 188, 15),   # lightest — highlight (transparent in our output)
]

# Cache downloaded raw sprites here so re-runs don't re-fetch.
CACHE = Path(__file__).resolve().parent / "_sprite_cache"


# ─── Sprite pipeline ────────────────────────────────────────────────────────

def fetch_sprite(name: str) -> Image.Image:
    """Fetch the SV in-game sprite PNG, caching to disk."""
    CACHE.mkdir(exist_ok=True)
    cached = CACHE / f"{name}.png"
    if not cached.exists():
        url = SPRITE_URL.format(name=name)
        print(f"  ↓ {url}")
        req = Request(url, headers={"User-Agent": "Mozilla/5.0 pokeface-build"})
        with urlopen(req) as r:
            cached.write_bytes(r.read())
    return Image.open(cached)


def matte_white(img: Image.Image, tol: int = 14) -> Image.Image:
    """Flood-fill from each edge replacing near-white pixels with transparent.

    This safely strips the artwork's white background without nuking white
    pixels inside the character (eyes, fur highlights), because the fill only
    propagates through connected near-white regions reachable from the border.
    """
    from collections import deque
    rgba = img.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size

    def is_white(p):
        r, g, b, _ = p
        return r >= 255 - tol and g >= 255 - tol and b >= 255 - tol

    visited = [[False] * h for _ in range(w)]
    q = deque()
    # Seed every border pixel.
    for x in range(w):
        for y in (0, h - 1):
            if is_white(px[x, y]) and not visited[x][y]:
                q.append((x, y)); visited[x][y] = True
    for y in range(h):
        for x in (0, w - 1):
            if is_white(px[x, y]) and not visited[x][y]:
                q.append((x, y)); visited[x][y] = True

    while q:
        x, y = q.popleft()
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[nx][ny] and is_white(px[nx, ny]):
                visited[nx][ny] = True
                q.append((nx, ny))
    return rgba


def to_dmg_green(src: Image.Image) -> Image.Image:
    """Map a 4-level grayscale GB sprite onto the DMG green palette.

    The brightest level (background) becomes transparent; the other 3 are mapped
    to the dark/light/lightest greens. Outline gets the deepest green.
    """
    gray = src.convert("L")
    rgba = Image.new("RGBA", gray.size, (0, 0, 0, 0))
    px = rgba.load()
    src_px = gray.load()
    w, h = gray.size

    # Pokémon Red/Blue sprites use only 4 gray levels: 0 (black), 80, 160, 255.
    # Anything in [240, 255] is background → transparent.
    for y in range(h):
        for x in range(w):
            v = src_px[x, y]
            if v >= 240:
                px[x, y] = (0, 0, 0, 0)
            elif v >= 200:
                px[x, y] = DMG_PALETTE[2] + (255,)
            elif v >= 120:
                px[x, y] = DMG_PALETTE[1] + (255,)
            else:
                px[x, y] = DMG_PALETTE[0] + (255,)
    return rgba


def fit_sprite(src: Image.Image, max_w: int, max_h: int) -> Image.Image:
    """Auto-crop transparent border, then resize to fit (max_w, max_h)."""
    src = src.convert("RGBA")
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    w, h = src.size
    scale = min(max_w / w, max_h / h)
    return src.resize((int(w * scale), int(h * scale)), Image.LANCZOS)


def build_sprite(name: str) -> Image.Image:
    """Pull Gen 9 sprite (full color), output a single CELL_W x CELL_H frame.

    Bob animation is now done in Monkey C (vertical translation), so we no
    longer expand the sprite into a 4-frame strip — same memory budget yields
    a much bigger Pokémon.
    """
    raw = fetch_sprite(name)
    fitted = fit_sprite(raw, CELL_W - 8, CELL_H - 16)

    cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))

    pad_x = (CELL_W - fitted.width) // 2
    base_y = CELL_H - fitted.height - 8

    # Soft shadow under the feet.
    sh = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    cx = pad_x + fitted.width // 2
    ImageDraw.Draw(sh).ellipse(
        [cx - fitted.width // 3, CELL_H - 12,
         cx + fitted.width // 3, CELL_H - 4],
        fill=(0, 0, 0, 110),
    )
    cell.paste(sh, (0, 0), sh)
    cell.paste(fitted, (pad_x, base_y), fitted)
    return cell


# ─── Biome generation ───────────────────────────────────────────────────────

def make_circle_mask(size: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size, size], fill=255)
    return m


def biome_meadow(daytime: bool) -> Image.Image:
    sky = PAL["sky_day"] if daytime else PAL["sky_overcast"]
    img = Image.new("RGB", (360, 360), sky)
    d = ImageDraw.Draw(img)
    # Distant hills
    d.ellipse([-60, 200, 220, 360], fill=PAL["grass_dark"])
    d.ellipse([140, 220, 420, 380], fill=PAL["grass_dark"])
    # Foreground grass
    d.rectangle([0, 280, 360, 360], fill=PAL["grass"])
    # Tufts
    for x in range(10, 360, 22):
        d.rectangle([x, 286, x + 2, 292], fill=PAL["grass_dark"])
        d.rectangle([x + 6, 290, x + 8, 296], fill=PAL["grass_dark"])
    if daytime:
        d.ellipse([280, 30, 330, 80], fill=(255, 230, 120), outline=(240, 200, 80))
    else:
        # Cloud blobs
        for cy_, cx_ in [(60, 80), (90, 200), (50, 280)]:
            d.ellipse([cx_ - 30, cy_ - 12, cx_ + 30, cy_ + 12], fill=(200, 208, 218))
    return img.convert("RGB")


def biome_rain() -> Image.Image:
    img = Image.new("RGB", (360, 360), (90, 100, 120))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 250, 360, 360], fill=(46, 80, 110))
    rng = random.Random(42)
    for _ in range(120):
        x = rng.randint(0, 360)
        y = rng.randint(0, 250)
        d.line([(x, y), (x - 4, y + 12)], fill=PAL["rain"], width=2)
    # Puddles
    for cy_, cx_, w_ in [(310, 60, 50), (330, 200, 70), (320, 290, 40)]:
        d.ellipse([cx_ - w_, cy_ - 6, cx_ + w_, cy_ + 6], fill=PAL["puddle"])
    return img


def biome_snow() -> Image.Image:
    img = Image.new("RGB", (360, 360), (180, 198, 218))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 260, 360, 360], fill=PAL["snow"])
    # Drifts
    d.ellipse([-40, 240, 200, 320], fill=PAL["snow"])
    d.ellipse([180, 250, 420, 330], fill=PAL["snow"])
    rng = random.Random(7)
    for _ in range(80):
        x = rng.randint(0, 360)
        y = rng.randint(0, 260)
        d.rectangle([x, y, x + 3, y + 3], fill=PAL["white"])
    return img


def biome_thunderstorm() -> Image.Image:
    img = Image.new("RGB", (360, 360), PAL["sky_storm"])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 270, 360, 360], fill=(28, 32, 44))
    # Lightning bolt (zig-zag)
    bolt = [(260, 30), (240, 110), (260, 110), (220, 220)]
    d.line(bolt, fill=PAL["lightning"], width=8)
    rng = random.Random(99)
    for _ in range(80):
        x = rng.randint(0, 360)
        y = rng.randint(0, 260)
        d.line([(x, y), (x - 3, y + 10)], fill=PAL["rain"], width=1)
    return img


def biome_night() -> Image.Image:
    img = Image.new("RGB", (360, 360), PAL["sky_night"])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 280, 360, 360], fill=(20, 28, 50))
    # Moon
    d.ellipse([60, 50, 120, 110], fill=PAL["moon"])
    d.ellipse([78, 50, 130, 100], fill=PAL["sky_night"])  # crescent cutout
    # Stars
    rng = random.Random(13)
    for _ in range(60):
        x = rng.randint(0, 360)
        y = rng.randint(0, 270)
        d.point((x, y), fill=PAL["star"])
        if rng.random() < 0.2:
            d.rectangle([x - 1, y, x + 1, y], fill=PAL["star"])
            d.rectangle([x, y - 1, x, y + 1], fill=PAL["star"])
    return img


def apply_round_mask(img: Image.Image) -> Image.Image:
    """Clip a 360x360 image to a circle so it matches the round watch."""
    mask = make_circle_mask(360)
    out = Image.new("RGBA", (360, 360), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def launcher_icon() -> Image.Image:
    img = Image.new("RGBA", (60, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, 58, 58], fill=(220, 60, 40), outline=PAL["black"], width=3)
    d.rectangle([2, 28, 58, 32], fill=PAL["black"])
    d.ellipse([22, 22, 38, 38], fill=PAL["white"], outline=PAL["black"], width=2)
    d.ellipse([26, 26, 34, 34], fill=PAL["black"])
    return img


# ─── Driver ─────────────────────────────────────────────────────────────────

def main():
    print(f"Writing to {OUT}")
    for name in POKEMON:
        path = OUT / f"sprite_{name}.png"
        build_sprite(name).save(path)
        print(f"  ✓ {path.name}")

    icon_path = OUT / "launcher_icon.png"
    launcher_icon().save(icon_path)
    print(f"  ✓ {icon_path.name}")

    print("Done.")


if __name__ == "__main__":
    main()
