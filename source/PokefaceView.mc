using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Cal;
using Toybox.ActivityMonitor as Act;
using Toybox.Application as App;
using Toybox.Math as Math;
using Toybox.Lang;

class PokefaceView extends Ui.WatchFace {

    private var _scene;
    private var _isLowPower = false;

    private const SCREEN_W = 360;

    private const POKE_CX = 110;
    private const POKE_CY = 220;

    private const PILL_R = 348;
    private const PILL_W = 130;
    private const PILL_H = 32;
    private const TIME_Y = 18;
    private const DATE_Y = 95;
    private const PILL_Y0 = 122;
    private const PILL_DY = 40;

    private const COLOR_PILL_BG = 0x222222;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        SpriteAtlas.preload();
    }

    function onShow() {}

    function onUpdate(dc) {
        var clock = Sys.getClockTime();
        var now = Cal.info(Time.now(), Time.FORMAT_MEDIUM);
        var act = Act.getInfo();

        var calories = (act != null && act.calories != null) ? act.calories : 0;
        var calGoal = SceneEngine.CALORIE_GOAL_DEFAULT;

        _scene = SceneEngine.compose(clock.hour, calories, calGoal);

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        drawPokemon(dc);

        drawTime(dc, clock);
        drawDate(dc, now);
        drawWeatherPill(dc, PILL_Y0);
        drawCaloriesPill(dc, PILL_Y0 + PILL_DY, calories, calGoal);
        drawProgressArc(dc, calories, calGoal);
    }

    function onPartialUpdate(dc) {
        var clock = Sys.getClockTime();
        var hour = clock.hour;
        var use24 = Sys.getDeviceSettings().is24Hour;
        if (!use24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var timeStr = Lang.format("$1$:$2$",
            [hour.format("%02d"), clock.min.format("%02d")]);

        dc.setClip(80, TIME_Y - 10, 280, 70);
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(SCREEN_W / 2, TIME_Y, Gfx.FONT_NUMBER_MILD, timeStr,
            Gfx.TEXT_JUSTIFY_CENTER);
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

    private function drawPokemon(dc) {
        if (_scene == null || _scene.spriteId == null) { return; }
        var sprite = SpriteAtlas.getSprite(_scene.spriteId);
        if (sprite == null) { return; }

        var w = sprite.getWidth();
        var h = sprite.getHeight();

        var bobs = [0, -2, -5, -9];
        var dy = bobs[_scene.frameIndex];

        var dstX = POKE_CX - w / 2;
        var dstY = POKE_CY - h / 2 + dy;
        dc.drawBitmap(dstX, dstY, sprite);
    }

    private function drawTime(dc, clock) {
        var hour = clock.hour;
        var use24 = Sys.getDeviceSettings().is24Hour;
        if (!use24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var s = Lang.format("$1$:$2$",
            [hour.format("%02d"), clock.min.format("%02d")]);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(SCREEN_W / 2, TIME_Y, Gfx.FONT_NUMBER_MILD, s,
            Gfx.TEXT_JUSTIFY_CENTER);
    }

    private function drawDate(dc, now) {
        var s = Lang.format("$1$ $2$ $3$",
            [now.day_of_week, now.month, now.day]);
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(SCREEN_W / 2, DATE_Y, Gfx.FONT_XTINY, s,
            Gfx.TEXT_JUSTIFY_CENTER);
    }

    // ─── Pills ────────────────────────────────────────────────────────────

    private function pillBox(dc, y) {
        var x = PILL_R - PILL_W;
        dc.setColor(COLOR_PILL_BG, COLOR_PILL_BG);
        dc.fillRoundedRectangle(x, y, PILL_W, PILL_H, PILL_H / 2);
    }

    private function drawPill(dc, y, iconKind, label, color) {
        pillBox(dc, y);
        var iconR = 9;
        var iconCx = PILL_R - PILL_W + PILL_H / 2;
        var iconCy = y + PILL_H / 2;
        WeatherIcons.draw(dc, iconCx, iconCy, iconKind, iconR);
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(PILL_R - 12, y + 5, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_RIGHT);
    }

    private function drawWeatherPill(dc, y) {
        if (_scene == null) { return; }
        drawPill(dc, y, _scene.iconKind, _scene.weatherText, Gfx.COLOR_WHITE);
    }

    private function drawCaloriesPill(dc, y, calories, goal) {
        var pct = goal > 0 ? (calories * 100) / goal : 0;
        drawPill(dc, y, :flame, calories.toString() + "  " + pct.toString() + "%",
            Gfx.COLOR_WHITE);
    }

    // ─── Progress arc ─────────────────────────────────────────────────────

    private function drawProgressArc(dc, value, goal) {
        var cx = SCREEN_W / 2;
        var cy = SCREEN_W / 2;
        var r = 168;
        var startDeg = 215;
        var endDeg   = 325;
        var span = endDeg - startDeg;
        var capR = 4;

        dc.setPenWidth(6);
        var bgColor = 0x333333;
        dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, r, Gfx.ARC_COUNTER_CLOCKWISE, startDeg, endDeg);
        capAt(dc, cx, cy, r, startDeg, capR, bgColor);
        capAt(dc, cx, cy, r, endDeg, capR, bgColor);

        if (goal > 0 && value > 0) {
            var pct = (value * 100) / goal;
            if (pct > 100) { pct = 100; }
            var fillEnd = startDeg + (pct * span) / 100;
            var color = (_scene != null) ? _scene.lineColor : 0x7BCB6E;
            dc.setColor(color, Gfx.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Gfx.ARC_COUNTER_CLOCKWISE, startDeg, fillEnd);
            capAt(dc, cx, cy, r, startDeg, capR, color);
            capAt(dc, cx, cy, r, fillEnd, capR, color);
        }

        drawEvolutionTick(dc, cx, cy, r, startDeg + span / 3);
        drawEvolutionTick(dc, cx, cy, r, startDeg + 2 * span / 3);

        dc.setPenWidth(1);
    }

    private function capAt(dc, cx, cy, r, deg, capR, color) {
        var rad = deg * Math.PI / 180.0;
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(
            (cx + r * Math.cos(rad)).toNumber(),
            (cy - r * Math.sin(rad)).toNumber(),
            capR
        );
    }

    private function drawEvolutionTick(dc, cx, cy, r, deg) {
        var rad = deg * Math.PI / 180.0;
        var ux = Math.cos(rad);
        var uy = -Math.sin(rad);
        var inner = r - 9;
        var outer = r + 6;
        dc.setPenWidth(2);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(
            (cx + inner * ux).toNumber(), (cy + inner * uy).toNumber(),
            (cx + outer * ux).toNumber(), (cy + outer * uy).toNumber()
        );
    }
}
