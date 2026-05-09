using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Cal;
using Toybox.ActivityMonitor as Act;
using Toybox.Weather as Weather;
using Toybox.SensorHistory as SH;
using Toybox.Lang;

// Text-only micro-graphics watch face.
// Layout y/x anchors come straight from art/build_layout.py.
class MinimalView extends Ui.WatchFace {

    private var _fontBig;
    private var _fontMed;
    private var _fontSmall;
    private var _fontTiny;
    private var _isLowPower = false;

    private const SCREEN_W = 360;
    private const CX = 180;

    // Solver-emitted Y anchors.
    private const Y_WEATHER = 48;
    private const Y_DATE    = 74;
    private const Y_TIME    = 130;
    private const Y_VALUES  = 218;
    private const Y_FOOTER  = 290;

    // Spread-of-4 column centres at y=218: chord=331, inner=323, step=80.75,
    // first centre = CX - 161 + 40 ≈ 60.
    private const COL_X = [60, 140, 220, 300];

    // Day mode: white text on black.
    // Night mode: black text on white (inverse).
    private const DAY_BG    = 0x000000;
    private const DAY_TEXT  = 0xFFFFFF;
    private const DAY_DIM   = 0x808080;
    private const NIGHT_BG    = 0xFFFFFF;
    private const NIGHT_TEXT  = 0x000000;
    private const NIGHT_DIM   = 0x808080;

    private var _bg;
    private var _text;
    private var _dim;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        _fontBig   = Ui.loadResource(Rez.Fonts.InterBig);
        _fontMed   = Ui.loadResource(Rez.Fonts.InterMed);
        _fontSmall = Ui.loadResource(Rez.Fonts.InterSmall);
        _fontTiny  = Ui.loadResource(Rez.Fonts.InterTiny);
    }

    function onShow() {}

    function onUpdate(dc) {
        // Pick day/night palette based on whether the sun is up.
        applyPalette(isDayNow());

        dc.setColor(_bg, _bg);
        dc.clear();

        var clock = Sys.getClockTime();
        var now = Cal.info(Time.now(), Time.FORMAT_MEDIUM);
        var act = Act.getInfo();
        var stats = Sys.getSystemStats();

        var calories = (act != null && act.calories != null) ? act.calories : 0;
        var steps    = (act != null && act.steps != null) ? act.steps : 0;
        var battery  = stats.battery.toNumber();
        var bodyBat  = bodyBattery();

        // 1. Weather (top): condition + temp, lowercase. Dim accent colour.
        drawCenter(dc, _fontTiny, _dim, Y_WEATHER, weatherHeader());

        // 2. Date: lowercase compact form.
        drawCenter(dc, _fontTiny, _text, Y_DATE, dateString(now));

        // 3. Time: big.
        drawCenter(dc, _fontBig, _text, Y_TIME, formatTime(clock));

        // 4. Stat values — cal · steps · body battery · heart rate.
        drawCol(dc, _fontSmall, _text, Y_VALUES, 0, calories.toString() + "kc");
        drawCol(dc, _fontSmall, _text, Y_VALUES, 1, compactSteps(steps));
        drawCol(dc, _fontSmall, _text, Y_VALUES, 2, pctText(bodyBat));
        drawCol(dc, _fontSmall, _text, Y_VALUES, 3, hrText(heartRate()));

        // 5. Footer: watch battery + sunrise/sunset.
        drawCenter(dc, _fontTiny, _dim, Y_FOOTER, footerLine(battery));
    }

    function onPartialUpdate(dc) {
        var clock = Sys.getClockTime();
        var s = formatTime(clock);
        dc.setClip(20, Y_TIME - 4, SCREEN_W - 40, 80);
        dc.setColor(_bg, _bg);
        dc.clear();
        dc.setColor(_text, Gfx.COLOR_TRANSPARENT);
        dc.drawText(CX, Y_TIME, _fontBig, s, Gfx.TEXT_JUSTIFY_CENTER);
        dc.clearClip();
    }

    function onEnterSleep() {
        _isLowPower = true;
        Ui.requestUpdate();
    }

    function onExitSleep() {
        _isLowPower = false;
        Ui.requestUpdate();
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    private function applyPalette(day) {
        if (day) {
            _bg = DAY_BG;
            _text = DAY_TEXT;
            _dim = DAY_DIM;
        } else {
            _bg = NIGHT_BG;
            _text = NIGHT_TEXT;
            _dim = NIGHT_DIM;
        }
    }

    // True if the sun is currently up at the watch's last-known location.
    // Falls back to a clock-only heuristic (06:00–18:00) when weather/location
    // hasn't been synced yet.
    private function isDayNow() {
        var cur = null;
        if (Weather has :getCurrentConditions) {
            cur = Weather.getCurrentConditions();
        }
        var pos = (cur != null && (cur has :observationLocationPosition))
            ? cur.observationLocationPosition : null;
        if (pos != null) {
            var now = Time.now();
            var rise = Weather.getSunrise(pos, now);
            var set  = Weather.getSunset(pos, now);
            if (rise != null && set != null) {
                var n = now.value();
                return n >= rise.value() && n < set.value();
            }
        }
        var hour = Sys.getClockTime().hour;
        return hour >= 6 && hour < 18;
    }

    private function drawCenter(dc, font, color, y, text) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(CX, y, font, text, Gfx.TEXT_JUSTIFY_CENTER);
    }

    private function drawCol(dc, font, color, y, colIndex, text) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(COL_X[colIndex], y, font, text, Gfx.TEXT_JUSTIFY_CENTER);
    }

    private function formatTime(clock) {
        var hour = clock.hour;
        var use24 = Sys.getDeviceSettings().is24Hour;
        if (!use24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return Lang.format("$1$:$2$",
            [hour.format("%02d"), clock.min.format("%02d")]);
    }

    private function dateString(now) {
        // "tue · 09 may 26"
        var year2 = now.year % 100;
        var s = Lang.format("$1$ · $2$ $3$ $4$",
            [now.day_of_week, now.day.format("%02d"), now.month,
             year2.format("%02d")]);
        return s.toLower();
    }

    private function compactSteps(n) {
        if (n >= 10000) {
            var k = n / 1000;
            var dec = (n % 1000) / 100;
            return k.toString() + "." + dec.toString() + "k";
        } else if (n >= 1000) {
            var k = n / 1000;
            var dec = (n % 1000) / 100;
            return k.toString() + "." + dec.toString() + "k";
        }
        return n.toString();
    }

    // ─── Weather ──────────────────────────────────────────────────────────

    private function weatherHeader() {
        var cur = null;
        if (Weather has :getCurrentConditions) {
            cur = Weather.getCurrentConditions();
        }
        if (cur == null) {
            return "—";
        }
        var cond = (cur.condition != null) ? condText(cur.condition) : "";
        var temp = "";
        if (cur.temperature != null) {
            var f = (cur.temperature * 9 / 5) + 32;
            temp = f.format("%d") + "f";
        }
        if (cond.length() > 0 && temp.length() > 0) {
            return cond + " " + temp;
        }
        if (cond.length() > 0) { return cond; }
        if (temp.length() > 0) { return temp; }
        return "—";
    }

    // CONDITION_* enum → short lowercase label.
    private function condText(c) {
        if (c == Weather.CONDITION_CLEAR)                    { return "clear"; }
        if (c == Weather.CONDITION_PARTLY_CLOUDY)            { return "partly cloudy"; }
        if (c == Weather.CONDITION_MOSTLY_CLOUDY)            { return "mostly cloudy"; }
        if (c == Weather.CONDITION_RAIN)                     { return "rain"; }
        if (c == Weather.CONDITION_SNOW)                     { return "snow"; }
        if (c == Weather.CONDITION_WINDY)                    { return "windy"; }
        if (c == Weather.CONDITION_THUNDERSTORMS)            { return "storm"; }
        if (c == Weather.CONDITION_WINTRY_MIX)               { return "wintry"; }
        if (c == Weather.CONDITION_FOG)                      { return "fog"; }
        if (c == Weather.CONDITION_HAZY)                     { return "hazy"; }
        if (c == Weather.CONDITION_HAIL)                     { return "hail"; }
        if (c == Weather.CONDITION_SCATTERED_SHOWERS)        { return "showers"; }
        if (c == Weather.CONDITION_SCATTERED_THUNDERSTORMS)  { return "storms"; }
        if (c == Weather.CONDITION_UNKNOWN_PRECIPITATION)    { return "precip"; }
        if (c == Weather.CONDITION_LIGHT_RAIN)               { return "lt rain"; }
        if (c == Weather.CONDITION_HEAVY_RAIN)               { return "hvy rain"; }
        if (c == Weather.CONDITION_LIGHT_SNOW)               { return "lt snow"; }
        if (c == Weather.CONDITION_HEAVY_SNOW)               { return "hvy snow"; }
        if (c == Weather.CONDITION_LIGHT_RAIN_SNOW)          { return "rain/snow"; }
        if (c == Weather.CONDITION_HEAVY_RAIN_SNOW)          { return "rain/snow"; }
        if (c == Weather.CONDITION_CLOUDY)                   { return "cloudy"; }
        if (c == Weather.CONDITION_RAIN_SNOW)                { return "rain/snow"; }
        if (c == Weather.CONDITION_PARTLY_CLEAR)             { return "partly clear"; }
        if (c == Weather.CONDITION_MOSTLY_CLEAR)             { return "mostly clear"; }
        if (c == Weather.CONDITION_LIGHT_SHOWERS)            { return "lt showers"; }
        if (c == Weather.CONDITION_SHOWERS)                  { return "showers"; }
        if (c == Weather.CONDITION_HEAVY_SHOWERS)            { return "hvy showers"; }
        if (c == Weather.CONDITION_CHANCE_OF_SHOWERS)        { return "chance rain"; }
        if (c == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS)  { return "chance storm"; }
        if (c == Weather.CONDITION_MIST)                     { return "mist"; }
        if (c == Weather.CONDITION_DUST)                     { return "dust"; }
        if (c == Weather.CONDITION_DRIZZLE)                  { return "drizzle"; }
        if (c == Weather.CONDITION_TORNADO)                  { return "tornado"; }
        if (c == Weather.CONDITION_SMOKE)                    { return "smoke"; }
        if (c == Weather.CONDITION_ICE)                      { return "ice"; }
        if (c == Weather.CONDITION_SAND)                     { return "sand"; }
        if (c == Weather.CONDITION_SQUALL)                   { return "squall"; }
        if (c == Weather.CONDITION_SANDSTORM)                { return "sandstorm"; }
        if (c == Weather.CONDITION_VOLCANIC_ASH)             { return "ash"; }
        if (c == Weather.CONDITION_HAZE)                     { return "haze"; }
        if (c == Weather.CONDITION_FAIR)                     { return "fair"; }
        if (c == Weather.CONDITION_HURRICANE)                { return "hurricane"; }
        if (c == Weather.CONDITION_TROPICAL_STORM)           { return "tropical"; }
        if (c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN)    { return "cloudy/rain"; }
        if (c == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW)    { return "cloudy/snow"; }
        if (c == Weather.CONDITION_FLURRIES)                 { return "flurries"; }
        if (c == Weather.CONDITION_FREEZING_RAIN)            { return "frz rain"; }
        if (c == Weather.CONDITION_SLEET)                    { return "sleet"; }
        if (c == Weather.CONDITION_THIN_CLOUDS)              { return "thin cloud"; }
        return "—";
    }

    // ─── Body battery ─────────────────────────────────────────────────────

    private function bodyBattery() {
        if (!(SH has :getBodyBatteryHistory)) { return null; }
        var iter = SH.getBodyBatteryHistory({ :period => 1 });
        if (iter == null) { return null; }
        var sample = iter.next();
        if (sample == null || sample.data == null) { return null; }
        return sample.data.toNumber();
    }

    private function pctText(v) {
        return (v == null) ? "—" : v.toString() + "%";
    }

    private function hrText(v) {
        return (v == null) ? "—" : v.toString() + "bpm";
    }

    // ─── Heart rate ───────────────────────────────────────────────────────

    private function heartRate() {
        if (!(SH has :getHeartRateHistory)) { return null; }
        var iter = SH.getHeartRateHistory({ :period => 1 });
        if (iter == null) { return null; }
        var sample = iter.next();
        if (sample == null || sample.data == null) { return null; }
        return sample.data.toNumber();
    }

    private function footerLine(battery) {
        var ss = sunriseSunsetCompact();
        var batStr = "wb " + battery.toString() + "%";
        if (ss == null) { return batStr; }
        return batStr + " · " + ss;
    }

    private function sunriseSunsetCompact() {
        var cur = null;
        if (Weather has :getCurrentConditions) {
            cur = Weather.getCurrentConditions();
        }
        if (cur == null) { return null; }
        var pos = (cur has :observationLocationPosition) ? cur.observationLocationPosition : null;
        if (pos == null) { return null; }
        var rise = Weather.getSunrise(pos, Time.now());
        var set  = Weather.getSunset(pos, Time.now());
        if (rise == null || set == null) { return null; }
        return "sun " + ampmTime(rise) + " " + ampmTime(set);
    }

    // ─── Sunrise / sunset ────────────────────────────────────────────────

    private function sunriseSunset() {
        var cur = null;
        if (Weather has :getCurrentConditions) {
            cur = Weather.getCurrentConditions();
        }
        if (cur == null) { return "—"; }
        var pos = (cur has :observationLocationPosition) ? cur.observationLocationPosition : null;
        if (pos == null) { return "—"; }

        var rise = Weather.getSunrise(pos, Time.now());
        var set  = Weather.getSunset(pos, Time.now());
        if (rise == null || set == null) { return "—"; }
        return "sun " + ampmTime(rise) + " · " + ampmTime(set);
    }

    // Format a Time.Moment as "6:24a" / "8:42p".
    private function ampmTime(moment) {
        var info = Cal.info(moment, Time.FORMAT_SHORT);
        var h = info.hour;
        var m = info.min;
        var suffix = "a";
        if (h >= 12) { suffix = "p"; h = h - 12; }
        if (h == 0) { h = 12; }
        return h.toString() + ":" + m.format("%02d") + suffix;
    }
}
