# Pokéface — Garmin Watch Face

A Pokémon-Sleep-inspired watch face for the **Forerunner 265S**. The scene
reacts to your context:

- **Weather** picks the biome and featured Pokémon (sunny meadow + Bulbasaur,
  rain + Squirtle, snow + Articuno, thunderstorm + Pikachu, hot day + Charmander).
- **Time of day** tints the palette (dawn / day / dusk / night).
- **Steps** advance the Pokémon's animation frame across the day (idle → bouncing).
- **Night** (21:00–05:00) brings out Gengar.

Art is original pixel-art placeholders rendered for the FR 265S's 360×360 round
AMOLED. Replace the PNGs in `resources-round-360x360/drawables/` with your own
to customize.

## One-time setup

1. Install the **Connect IQ SDK** from
   <https://developer.garmin.com/connect-iq/sdk/> (use the SDK Manager — pick the
   latest SDK and the `fr265s` device).
2. Install the **Monkey C** VS Code extension (`garmin.monkey-c`).
3. Generate a developer key once:
   ```
   monkeyc -k path/to/developer_key.der --keygen
   ```

## Build & test in the simulator

```bash
cd /Users/pluto/garmin/pokeface

# Java 17 is required by the SDK; put it on PATH.
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
export SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"

# 1. (Re)generate the placeholder art if you haven't already.
uv run --with pillow python art/build_art.py

# 2. Compile.
"$SDK/bin/monkeyc" \
    -d fr265s \
    -f monkey.jungle \
    -o bin/Pokeface.prg \
    -y /Users/pluto/garmin/developer_key.der

# 3. Open the simulator + run.
open "$SDK/bin/ConnectIQ.app"
"$SDK/bin/monkeydo" bin/Pokeface.prg fr265s
```

In the simulator, exercise each input:

- **Simulation → Time → Custom** — scrub through 06:00, 12:00, 19:00, 23:00 to
  watch the palette tint and confirm Gengar takes over at night.
- **Simulation → Weather → Set Conditions** — pick CLEAR, RAIN, SNOW,
  THUNDERSTORMS to confirm biome + Pokémon swap.
- **Simulation → Sensors → Activity Monitor** — set steps to 0, 2,500, 5,000,
  7,500, 10,000 to walk through the 4 sprite frames.
- **Simulation → Settings → Low-Power Mode** — confirms only the time + outline
  draw in the always-on state (`onPartialUpdate`).

## Sideload to the watch

```bash
# Plug the FR 265S in via USB, mount as "GARMIN".
cp bin/Pokeface.prg /Volumes/GARMIN/GARMIN/Apps/
diskutil eject /Volumes/GARMIN

# On the watch: long-press up → Watch Face → Pokéface.
```

## Project layout

```
pokeface/
├── manifest.xml                manifest (fr265s, Weather + Sensor permissions)
├── monkey.jungle               build config
├── source/
│   ├── PokefaceApp.mc          AppBase entrypoint
│   ├── PokefaceView.mc         WatchFace: onUpdate / onPartialUpdate
│   ├── SceneEngine.mc          composes {biome, palette, sprite, frame}
│   ├── WeatherAdapter.mc       Weather.getCurrentConditions() → 6-bucket classifier
│   └── SpriteAtlas.mc          lazy bitmap loader
├── resources/                  base layer (strings, settings, drawables.xml)
├── resources-round-360x360/
│   └── drawables/              360x360-tuned PNG resources (the actual art)
└── art/
    └── build_art.py            placeholder-art generator (Pillow)
```

## Customizing

- **Swap a Pokémon's art:** replace
  `resources-round-360x360/drawables/sprite_<name>.png` (must be a 256×64
  4-frame horizontal strip — frames 0..3 from idle to bounce).
- **Change the biome backgrounds:** edit
  `resources-round-360x360/drawables/biome_*.png` (must be 360×360, ideally
  pre-clipped to a circle since the FR 265S is round).
- **Change a weather → Pokémon mapping:** edit `WeatherAdapter.classify()`.
- **Change palette tint times:** edit the hour bands in
  `SceneEngine.compose()`.
- **Pick a favorite Pokémon (override weather):** Garmin Connect IQ →
  Pokéface → Settings → Favorite Pokémon.

## Notes

- The face fires `onUpdate` once per minute to conserve battery; sub-second
  animation isn't permitted in the always-on state. Visual motion comes from
  step progress and minute-to-minute frame changes.
- Pokémon are Nintendo IP — this is a personal-use, sideloaded face. Do not
  publish to the Connect IQ Store.
