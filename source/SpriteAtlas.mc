using Toybox.WatchUi as Ui;

module SpriteAtlas {

    var _sprites = null;

    function preload() {
        if (_sprites != null) { return; }
        _sprites = {};
    }

    function getSprite(sym) {
        if (_sprites == null) { preload(); }
        if (!_sprites.hasKey(sym)) {
            _sprites[sym] = loadById(sym);
        }
        return _sprites[sym];
    }

    function loadById(sym) {
        if (sym == :sprite_bulbasaur)  { return Ui.loadResource(Rez.Drawables.SpriteBulbasaur); }
        if (sym == :sprite_ivysaur)    { return Ui.loadResource(Rez.Drawables.SpriteIvysaur); }
        if (sym == :sprite_venusaur)   { return Ui.loadResource(Rez.Drawables.SpriteVenusaur); }

        if (sym == :sprite_charmander) { return Ui.loadResource(Rez.Drawables.SpriteCharmander); }
        if (sym == :sprite_charmeleon) { return Ui.loadResource(Rez.Drawables.SpriteCharmeleon); }
        if (sym == :sprite_charizard)  { return Ui.loadResource(Rez.Drawables.SpriteCharizard); }

        if (sym == :sprite_squirtle)   { return Ui.loadResource(Rez.Drawables.SpriteSquirtle); }
        if (sym == :sprite_wartortle)  { return Ui.loadResource(Rez.Drawables.SpriteWartortle); }
        if (sym == :sprite_blastoise)  { return Ui.loadResource(Rez.Drawables.SpriteBlastoise); }
        return null;
    }
}
