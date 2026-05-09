using Toybox.Weather as W;

// Weather → starter LINE (3-stage evolution array). Step progress picks the stage.
module WeatherAdapter {

    // Three Gen 1 starter lines.
    var GRASS = [:sprite_bulbasaur,  :sprite_ivysaur,    :sprite_venusaur];
    var FIRE  = [:sprite_charmander, :sprite_charmeleon, :sprite_charizard];
    var WATER = [:sprite_squirtle,   :sprite_wartortle,  :sprite_blastoise];

    function classify() {
        var line = GRASS;
        var icon = :cloud;
        var text = "—";

        var cur = null;
        if (W has :getCurrentConditions) {
            cur = W.getCurrentConditions();
        }

        if (cur == null) {
            return { :line => line, :icon => icon, :text => text, :lineColor => colorFor(line) };
        }

        var cond = cur.condition;
        var tempC = cur.temperature;

        if (isRain(cond) || isSnow(cond)) {
            line = WATER;
            icon = isSnow(cond) ? :snow : :rain;
        } else if (isStorm(cond) || (tempC != null && tempC > 28)) {
            line = FIRE;
            icon = isStorm(cond) ? :storm
                 : isClear(cond) ? :sun
                 : :cloud;
        } else if (isClear(cond)) {
            line = GRASS;
            icon = :sun;
        } else if (isFog(cond)) {
            line = GRASS;
            icon = :fog;
        } else {
            line = GRASS;
            icon = :cloud;
        }

        text = formatTemp(tempC);

        return { :line => line, :icon => icon, :text => text, :lineColor => colorFor(line) };
    }

    function colorFor(line) {
        if (line == FIRE)  { return 0xFF8C42; }   // warm orange
        if (line == WATER) { return 0x4FB8E0; }   // cyan
        return 0x7BCB6E;                           // grass green
    }

    function isClear(c) {
        return c == W.CONDITION_CLEAR
            || c == W.CONDITION_MOSTLY_CLEAR
            || c == W.CONDITION_PARTLY_CLEAR
            || c == W.CONDITION_FAIR
            || c == W.CONDITION_PARTLY_CLOUDY;
    }

    function isRain(c) {
        return c == W.CONDITION_RAIN
            || c == W.CONDITION_LIGHT_RAIN
            || c == W.CONDITION_HEAVY_RAIN
            || c == W.CONDITION_SHOWERS
            || c == W.CONDITION_LIGHT_SHOWERS
            || c == W.CONDITION_HEAVY_SHOWERS
            || c == W.CONDITION_DRIZZLE
            || c == W.CONDITION_SCATTERED_SHOWERS;
    }

    function isSnow(c) {
        return c == W.CONDITION_SNOW
            || c == W.CONDITION_LIGHT_SNOW
            || c == W.CONDITION_HEAVY_SNOW
            || c == W.CONDITION_RAIN_SNOW
            || c == W.CONDITION_SLEET
            || c == W.CONDITION_FLURRIES
            || c == W.CONDITION_LIGHT_RAIN_SNOW
            || c == W.CONDITION_HEAVY_RAIN_SNOW;
    }

    function isStorm(c) {
        return c == W.CONDITION_THUNDERSTORMS
            || c == W.CONDITION_SCATTERED_THUNDERSTORMS
            || c == W.CONDITION_TROPICAL_STORM
            || c == W.CONDITION_HURRICANE
            || c == W.CONDITION_TORNADO;
    }

    function isFog(c) {
        return c == W.CONDITION_FOG
            || c == W.CONDITION_HAZY
            || c == W.CONDITION_HAZE
            || c == W.CONDITION_MIST
            || c == W.CONDITION_SMOKE;
    }

    function formatTemp(tempC) {
        if (tempC == null) { return "—"; }
        var f = (tempC * 9 / 5) + 32;
        return f.format("%d") + "°F";
    }
}
