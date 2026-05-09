"""
Mirror of SceneEngine.compose() and WeatherAdapter.classify() in Python.

Verifies the watch face will pick the right Pokémon for every combination
of weather × calorie progress. Run with:

    uv run python art/test_logic.py
"""

from __future__ import annotations
from dataclasses import dataclass

GRASS = ["bulbasaur",  "ivysaur",    "venusaur"]
FIRE  = ["charmander", "charmeleon", "charizard"]
WATER = ["squirtle",   "wartortle",  "blastoise"]


def classify(condition: str | None, temp_c: float | None) -> dict:
    """Mirror of WeatherAdapter.classify()."""
    if condition is None and temp_c is None:
        return {"line": GRASS, "icon": "cloud", "name": "GRASS"}

    is_clear = condition in {"clear", "mostly_clear", "fair", "partly_cloudy"}
    is_rain  = condition in {"rain", "light_rain", "heavy_rain", "showers", "drizzle"}
    is_snow  = condition in {"snow", "light_snow", "heavy_snow", "sleet", "flurries"}
    is_storm = condition in {"thunderstorms", "tropical_storm", "hurricane", "tornado"}
    is_fog   = condition in {"fog", "hazy", "haze", "mist"}

    if is_rain or is_snow:
        return {"line": WATER, "icon": "snow" if is_snow else "rain", "name": "WATER"}
    if is_storm or (temp_c is not None and temp_c > 28):
        icon = "storm" if is_storm else ("sun" if is_clear else "cloud")
        return {"line": FIRE, "icon": icon, "name": "FIRE"}
    if is_clear:
        return {"line": GRASS, "icon": "sun", "name": "GRASS"}
    if is_fog:
        return {"line": GRASS, "icon": "fog", "name": "GRASS"}
    return {"line": GRASS, "icon": "cloud", "name": "GRASS"}


def compose(calories: int, goal: int, condition: str | None, temp_c: float | None) -> dict:
    """Mirror of SceneEngine.compose()."""
    w = classify(condition, temp_c)
    line = w["line"]

    stage = 0
    if goal > 0:
        stage = (calories * 3) // goal
        stage = max(0, min(2, stage))

    bob = 0
    if goal > 0:
        bob = (calories * 12) // goal - stage * 4
        bob = max(0, min(3, bob))

    return {
        "sprite": line[stage],
        "stage": stage,
        "bob": bob,
        "icon": w["icon"],
        "line": w["name"],
    }


def main():
    GOAL = 500
    print(f"Goal = {GOAL} active calories\n")

    print("=== Calorie progression (weather=clear, mild) ===")
    print(f"{'cal':>5}  {'%':>4}  {'line':<5}  {'stage':<5}  {'sprite':<12}  {'bob':>3}")
    for cal in [0, 100, 165, 166, 200, 300, 333, 334, 400, 500, 600]:
        r = compose(cal, GOAL, "clear", 20)
        pct = cal * 100 // GOAL
        print(f"{cal:>5}  {pct:>3}%  {r['line']:<5}  {r['stage']:<5}  {r['sprite']:<12}  {r['bob']:>3}")

    print("\n=== Weather → line at 50% calories ===")
    cases = [
        ("clear",         20,    "clear / mild"),
        ("clear",         32,    "clear / hot >28C"),
        ("rain",          15,    "rain"),
        ("heavy_rain",    10,    "heavy rain"),
        ("snow",          -2,    "snow"),
        ("thunderstorms", 22,    "storm"),
        ("hurricane",     25,    "hurricane"),
        ("fog",           18,    "fog"),
        ("partly_cloudy", 22,    "partly cloudy"),
        ("cloudy",        18,    "cloudy default"),
        (None,            None,  "no weather data"),
    ]
    print(f"{'condition':<18}  {'temp':>4}  {'line':<5}  {'sprite':<12}  {'icon':<6}  {'desc':<15}")
    for cond, t, desc in cases:
        r = compose(GOAL // 2, GOAL, cond, t)
        cond_s = cond if cond else "(null)"
        t_s = f"{t:>3}C" if t is not None else "  --"
        print(f"{cond_s:<18}  {t_s:>4}  {r['line']:<5}  {r['sprite']:<12}  {r['icon']:<6}  {desc:<15}")

    print("\n=== Threshold sanity ===")
    for goal in [400, 500, 750]:
        b1 = goal // 3       # stage 0 → 1 boundary (calories needed)
        b2 = 2 * goal // 3
        for cal in [b1 - 1, b1, b1 + 1, b2 - 1, b2, b2 + 1]:
            r = compose(cal, goal, "clear", 20)
            print(f"goal={goal} cal={cal:>4}  stage={r['stage']}  sprite={r['sprite']}")
        print()


if __name__ == "__main__":
    main()
