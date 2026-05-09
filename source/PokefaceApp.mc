using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class PokefaceApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}
    function onStop(state) {}

    function getInitialView() {
        return [ new PokefaceView() ];
    }

    function onSettingsChanged() {
        Ui.requestUpdate();
    }
}
