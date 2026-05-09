# Minimal Watch Face

A text-only, brutalist-modernist micro-graphics watch face for the
**Garmin Forerunner 265S**, inspired by the
[micro-graphics aesthetic](https://www.openallhours.co/p/how-micro-graphics-went-from-an-afterthought-to-an-aesthetic):
small grotesque type, dense data, mathematical placement.

![watch face](docs/screenshot.png)

Built around four ideas:

1. **Grotesque typography** — Inter (open-source Akzidenz-Grotesk successor)
   baked into bitmap fonts at four hand-picked sizes.
2. **LaTeX-style layout** — every text row is positioned by a Python solver
   ([`art/build_layout.py`](art/build_layout.py)) that reads real glyph widths
   from the `.fnt` atlases and verifies each row fits inside the round-display
   chord at its y. Overflow = compile failure.
3. **Day / night palette inversion** — white-on-black during daylight,
   black-on-white after sunset, decided live from
   `Toybox.Weather.getSunrise/getSunset`.
4. **Honest data, lowercase** — weather (live), date, time, calories,
   compact step count, body battery, heart rate, watch battery, sun times.

## Layout

```
                    cloudy 55f                   ← live weather (header)
              tue · 09 may 26 · wk19             ← date

                       10:42                     ← time

      342kc        6.4k       73%       72bpm    ← cal · steps · bb · hr

              wb 78% · sun 6:24a 8:42p           ← watch battery + sun
```

## One-time setup

1. Install the **Connect IQ SDK** from <https://developer.garmin.com/connect-iq/sdk/>
   via SDK Manager. Pick the latest SDK + the `fr265s` device package.
2. Java 17: `brew install openjdk@17`.
3. Install the **Monkey C** VS Code extension (`garmin.monkey-c`).
4. Generate a developer key once:
   ```
   openssl genrsa -out key.pem 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in key.pem \
       -out developer_key.der -nocrypt
   ```

## Build, test, sideload

The bundled [`run.sh`](run.sh) wraps the whole loop:

```bash
./run.sh             # build + sideload to simulator once
./run.sh --watch     # rebuild + reload on every save
./run.sh --release   # release (-r) build, no debug symbols
./run.sh --build     # build only, don't launch simulator
```

To install on the actual watch over USB:

```bash
# Plug the FR 265S in. On the watch: Settings → System → USB Mode → Mass Storage.
cp bin/Minimal.prg /Volumes/GARMIN/GARMIN/Apps/
diskutil eject /Volumes/GARMIN
# On the watch: long-press LIGHT → Watch Face → Minimal Watch Face.
```

## Publish to the Connect IQ Store

1. Build the store-distribution `.iq` package:
   ```bash
   monkeyc -e -f monkey.jungle -o dist/Minimal.iq \
       -y /path/to/developer_key.der -r
   ```
2. Sign in (or register) at <https://apps.garmin.com> with the same Garmin
   account that holds the developer key.
3. Open the **Developer Dashboard** → **Submit a new app**.
4. Upload `dist/Minimal.iq`. The portal extracts metadata from the manifest
   (app id, supported products, permissions).
5. Fill in store metadata:
   - **Name:** Minimal Watch Face
   - **Category:** Watch Face
   - **Description:** see `docs/store-description.md`
   - **Icon:** the launcher icon is auto-extracted; replace if you want a
     1024×1024 store icon.
   - **Screenshots:** at least one 360×360 PNG of the face on each supported
     device. `docs/screenshot.png` is captured straight from the simulator.
6. Submit for review. Garmin's review usually takes 1–3 days.

## Project layout

```
.
├── manifest.xml             fr265s + SensorHistory permission, app UUID
├── monkey.jungle            build config
├── run.sh                   build / reload / watch helper
├── source/
│   ├── MinimalApp.mc        AppBase entrypoint
│   └── MinimalView.mc       WatchFace — drawing, day/night, helpers
├── resources/
│   ├── strings/strings.xml
│   ├── settings/properties.xml
│   ├── drawables/drawables.xml + launcher_icon.png
│   └── fonts/inter_*.fnt + .png      Inter @ 11/14/22/64 px
├── art/
│   ├── build_fonts.py       TTF → Garmin BMFont .fnt + bitmap atlas
│   ├── build_layout.py      LaTeX-style solver: chord math + row widths
│   └── build_art.py         launcher icon
├── bin/                     built .prg (debug)
└── dist/                    built .iq (store distribution)
```

## How the layout solver works

[`art/build_layout.py`](art/build_layout.py) declares each row as
`(y, font, alignment, content)` and runs three checks before any build:

1. Reads the per-glyph `xadvance` from the `.fnt` files so widths match what
   Garmin will actually render.
2. Computes the available chord at every y on the round display:
   `2·√(r² − (y − cy)²)`, with a 10 px bezel margin.
3. For `spread:N` rows, splits the chord into N evenly-spaced columns and
   verifies the longest item fits its column.

If any row overflows, the solver exits non-zero — push the row up/down,
shrink the font, or shorten the text. When all rows fit, transcribe the
emitted y-coordinates into [`MinimalView.mc`](source/MinimalView.mc).

## Notes

- `onUpdate` fires roughly once per minute; the face is intentionally
  static within a minute to keep AMOLED battery drain low.
- Body battery and heart rate require the `SensorHistory` permission
  (declared in [`manifest.xml`](manifest.xml)).
- The screenshot is captured directly from the Connect IQ Simulator
  running on macOS.
