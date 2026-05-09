using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class MinimalApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}
    function onStop(state) {}

    function getInitialView() {
        return [ new MinimalView() ];
    }

    function onSettingsChanged() {
        Ui.requestUpdate();
    }
}
