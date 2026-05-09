using Toybox.Graphics as Gfx;

// Tiny programmatic icons. Center-anchored at (cx, cy); `r` is the half-size.
// Kinds: :sun, :moon, :cloud, :rain, :snow, :storm, :fog, :unknown.
module WeatherIcons {

    function draw(dc, cx, cy, kind, r) {
        if (kind == :sun)        { sun(dc, cx, cy, r); return; }
        if (kind == :moon)       { moon(dc, cx, cy, r); return; }
        if (kind == :cloud)      { cloud(dc, cx, cy, r, Gfx.COLOR_LT_GRAY); return; }
        if (kind == :rain)       { rain(dc, cx, cy, r); return; }
        if (kind == :snow)       { snow(dc, cx, cy, r); return; }
        if (kind == :storm)      { storm(dc, cx, cy, r); return; }
        if (kind == :fog)        { fog(dc, cx, cy, r); return; }
        if (kind == :steps)      { steps(dc, cx, cy, r); return; }
        if (kind == :battery)    { battery(dc, cx, cy, r); return; }
        if (kind == :flame)      { flame(dc, cx, cy, r); return; }
        // Fallback dot
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r / 3);
    }

    function steps(dc, cx, cy, r) {
        // Two little footprints.
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 2, cy - r / 3, r / 3);
        dc.fillCircle(cx + r / 2, cy + r / 3, r / 3);
        dc.fillRectangle(cx - r * 7 / 10, cy - r / 6, r / 2, r / 2);
        dc.fillRectangle(cx + r / 5,      cy + r / 6, r / 2, r / 2);
    }

    function flame(dc, cx, cy, r) {
        // Outer flame body — orange teardrop.
        dc.setColor(0xFF8C42, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy + r / 4, r * 7 / 10);
        dc.fillPolygon([
            [cx, cy - r * 8 / 10],
            [cx - r * 6 / 10, cy + r / 4],
            [cx + r * 6 / 10, cy + r / 4]
        ]);
        // Inner highlight — yellow.
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy + r / 3, r * 3 / 10);
    }

    function battery(dc, cx, cy, r) {
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(cx - r, cy - r * 6 / 10, 2 * r - 2, r * 12 / 10, 2);
        dc.fillRectangle(cx + r - 2, cy - r / 4, 3, r / 2);
        dc.fillRectangle(cx - r + 2, cy - r * 4 / 10, r * 8 / 10, r * 8 / 10);
        dc.setPenWidth(1);
    }

    function sun(dc, cx, cy, r) {
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 6 / 10);
        dc.setPenWidth(2);
        // Eight rays.
        var rays = [
            [-r, 0, -r * 7 / 10, 0],
            [ r, 0,  r * 7 / 10, 0],
            [0, -r, 0, -r * 7 / 10],
            [0,  r, 0,  r * 7 / 10],
            [-r * 7 / 10, -r * 7 / 10, -r * 5 / 10, -r * 5 / 10],
            [ r * 7 / 10, -r * 7 / 10,  r * 5 / 10, -r * 5 / 10],
            [-r * 7 / 10,  r * 7 / 10, -r * 5 / 10,  r * 5 / 10],
            [ r * 7 / 10,  r * 7 / 10,  r * 5 / 10,  r * 5 / 10]
        ];
        for (var i = 0; i < rays.size(); i++) {
            var s = rays[i];
            dc.drawLine(cx + s[0], cy + s[1], cx + s[2], cy + s[3]);
        }
        dc.setPenWidth(1);
    }

    function moon(dc, cx, cy, r) {
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillCircle(cx + r / 3, cy - r / 6, r);
    }

    function cloud(dc, cx, cy, r, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 2, cy + r / 4, r * 5 / 10);
        dc.fillCircle(cx + r / 2, cy + r / 4, r * 5 / 10);
        dc.fillCircle(cx,         cy - r / 5, r * 7 / 10);
        dc.fillRectangle(cx - r, cy + r / 4 - 2, 2 * r, r * 5 / 10);
    }

    function rain(dc, cx, cy, r) {
        cloud(dc, cx, cy - r / 4, r, Gfx.COLOR_LT_GRAY);
        dc.setColor(Gfx.COLOR_BLUE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = -1; i <= 1; i++) {
            var x = cx + i * r / 2;
            dc.drawLine(x, cy + r / 2, x - 3, cy + r);
        }
        dc.setPenWidth(1);
    }

    function snow(dc, cx, cy, r) {
        cloud(dc, cx, cy - r / 4, r, Gfx.COLOR_LT_GRAY);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        for (var i = -1; i <= 1; i++) {
            var x = cx + i * r / 2;
            var y = cy + r * 7 / 10;
            dc.fillCircle(x, y, 2);
        }
    }

    function storm(dc, cx, cy, r) {
        cloud(dc, cx, cy - r / 4, r, Gfx.COLOR_DK_GRAY);
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(cx - r / 4, cy + r / 3, cx + r / 4, cy + r * 8 / 10);
        dc.setPenWidth(1);
    }

    function fog(dc, cx, cy, r) {
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        for (var i = -2; i <= 2; i++) {
            dc.drawLine(cx - r, cy + i * 5, cx + r, cy + i * 5);
        }
        dc.setPenWidth(1);
    }
}
