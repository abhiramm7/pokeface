module SceneEngine {

    // Default daily active-calorie goal — used when ActivityMonitor doesn't expose one.
    const CALORIE_GOAL_DEFAULT = 500;

    class Scene {
        public var spriteId;
        public var frameIndex = 0;
        public var weatherText = "";
        public var iconKind = :unknown;
        public var lineColor = 0x7BCB6E;

        function initialize() {}
    }

    function compose(hour, calories, goal) {
        var s = new Scene();

        var w = WeatherAdapter.classify();
        s.weatherText = w[:text];
        s.iconKind = w[:icon];
        s.lineColor = w[:lineColor];

        var line = w[:line];

        // Calorie progress picks evolution stage 0..2.
        var stage = 0;
        if (goal > 0) {
            stage = (calories * 3) / goal;
            if (stage > 2) { stage = 2; }
            if (stage < 0) { stage = 0; }
        }
        s.spriteId = line[stage];

        var bob = 0;
        if (goal > 0) {
            bob = (calories * 12) / goal;
            bob = bob - stage * 4;
            if (bob > 3) { bob = 3; }
            if (bob < 0) { bob = 0; }
        }
        s.frameIndex = bob;

        return s;
    }
}
