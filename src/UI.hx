import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import hxd.Key;

class UI {
    public var root : Object;

    var hudRoot : Object;
    var hpBar : Graphics;
    var hpText : Text;
    var flaskText : Text;
    var cellsText : Text;
    var biomeText : Text;
    var depthText : Text;
    var weaponsText : Text;

    var overlayRoot : Object;
    var overlayBg : Graphics;
    var overlayTitle : Text;
    var overlayBody : Text;
    var overlayHint : Text;

    public var game : Game;
    public var screen : String = "start";

    public function new(game:Game, parent:Object) {
        this.game = game;
        root = new Object(parent);
        hudRoot = new Object(root);
        overlayRoot = new Object(root);

        var font = hxd.res.DefaultFont.get();

        hpBar = new Graphics(hudRoot);
        hpText = new Text(font, hudRoot); hpText.textColor = 0xffffff;
        hpText.x = 10; hpText.y = 10;

        flaskText = new Text(font, hudRoot); flaskText.textColor = 0xa0f0c0;
        flaskText.x = 290; flaskText.y = 10;
        cellsText = new Text(font, hudRoot); cellsText.textColor = 0xffcc44;
        cellsText.x = 400; cellsText.y = 10;
        biomeText = new Text(font, hudRoot); biomeText.textColor = 0xc8a8ff;
        biomeText.x = 520; biomeText.y = 10;
        depthText = new Text(font, hudRoot); depthText.textColor = 0x888888;
        depthText.x = 800; depthText.y = 10;
        weaponsText = new Text(font, hudRoot); weaponsText.textColor = 0xcccccc;
        weaponsText.x = 10; weaponsText.y = 36;

        overlayBg = new Graphics(overlayRoot);
        overlayTitle = new Text(font, overlayRoot); overlayTitle.textColor = 0xff4477;
        overlayTitle.scaleX = overlayTitle.scaleY = 3;
        overlayBody = new Text(font, overlayRoot); overlayBody.textColor = 0xddddee;
        overlayHint = new Text(font, overlayRoot); overlayHint.textColor = 0xffcc44;
    }

    public function showStart() {
        screen = "start";
        hudRoot.visible = false;
        overlayRoot.visible = true;
        overlayBg.clear();
        overlayBg.beginFill(0x05050c, 0.92);
        overlayBg.drawRect(0, 0, Const.VIEW_W, Const.VIEW_H);
        overlayBg.endFill();
        overlayTitle.text = "HOLLOW CELLS";
        overlayTitle.scaleX = overlayTitle.scaleY = 3;
        centerX(overlayTitle, 40);
        overlayBody.text =
            "Un roguelike metroidvania nerveux  -  Haxe 4.3 + Heaps.io\n\n" +
            "DEPLACEMENT  Fleches / A D / Q D\n" +
            "SAUTER       Espace / W / Z  (double saut, wall jump)\n" +
            "ROULADE      Shift  (i-frames)\n" +
            "EPEE         X / J         ARC     C / K\n" +
            "POTION       E             PORTE   F / Entree\n\n" +
            "Cellules accumulees : " + game.meta.cells + "\n" +
            "Ameliorations : taper 1-4 pour acheter (depuis ecran mort aussi)";
        overlayBody.scaleX = overlayBody.scaleY = 1.2;
        centerX(overlayBody, 150);
        overlayHint.text = "Appuyez sur [ENTREE] pour commencer";
        overlayHint.scaleX = overlayHint.scaleY = 1.4;
        centerX(overlayHint, Const.VIEW_H - 48);
        overlayHint.visible = true;
        refreshUpgradeHint();
    }

    public function showDeath() {
        screen = "death";
        hudRoot.visible = false;
        overlayRoot.visible = true;
        overlayBg.clear();
        overlayBg.beginFill(0x05050c, 0.92);
        overlayBg.drawRect(0, 0, Const.VIEW_W, Const.VIEW_H);
        overlayBg.endFill();
        overlayTitle.text = "VOUS ETES MORT";
        overlayTitle.scaleX = overlayTitle.scaleY = 3;
        centerX(overlayTitle, 40);
        overlayBody.text =
            "Biome     : " + game.level.biome.name + "  - etage " + game.floorNumber + "\n" +
            "Ennemis   : " + game.player.kills + "\n" +
            "Cellules  : " + game.meta.cells + "  (+" + game.player.cellsGained + ")\n\n" +
            "AMELIORATIONS PERMANENTES\n";
        var lineIdx = 1;
        for (u in Meta.UPGRADES) {
            var lvl = game.meta.level(u.key);
            var costStr = lvl >= u.max ? "MAX" : "cout " + u.costAt(lvl);
            overlayBody.text += "[" + lineIdx + "] " + u.name + "  Niv " + lvl + "/" + u.max + "  - " + u.desc + "  (" + costStr + ")\n";
            lineIdx++;
        }
        overlayBody.scaleX = overlayBody.scaleY = 1.2;
        centerX(overlayBody, 150);
        overlayHint.text = "[ENTREE] Nouvelle course";
        overlayHint.scaleX = overlayHint.scaleY = 1.4;
        centerX(overlayHint, Const.VIEW_H - 48);
        overlayHint.visible = true;
    }

    public function showVictory() {
        screen = "victory";
        hudRoot.visible = false;
        overlayRoot.visible = true;
        overlayBg.clear();
        overlayBg.beginFill(0x05050c, 0.92);
        overlayBg.drawRect(0, 0, Const.VIEW_W, Const.VIEW_H);
        overlayBg.endFill();
        overlayTitle.text = "VICTOIRE";
        centerX(overlayTitle, 120);
        overlayBody.text = "Vous avez survecu aux profondeurs.\nCellules ramenees : " + game.meta.cells;
        overlayBody.scaleX = overlayBody.scaleY = 1.6;
        centerX(overlayBody, 260);
        overlayHint.text = "[ENTREE] Continuer";
        overlayHint.scaleX = overlayHint.scaleY = 1.4;
        centerX(overlayHint, Const.VIEW_H - 80);
        overlayHint.visible = true;
    }

    public function showBiomeTransition() : Void {
        // Simple fade-in text rendered ON TOP of play screen, but we use a
        // separate timer on Game. Draw via hudRoot extras.
    }

    public function showPlay() {
        screen = "play";
        hudRoot.visible = true;
        overlayRoot.visible = false;
    }

    function centerX(t:Text, y:Float) {
        t.x = (Const.VIEW_W - t.textWidth * t.scaleX) / 2;
        t.y = y;
    }

    function refreshUpgradeHint() {
        // Show first affordable upgrade as bottom hint
    }

    public function update(dt:Float) {
        if (screen == "start" || screen == "death") {
            // Number keys 1-4 buy upgrades
            if (Key.isPressed(Key.NUMBER_1)) tryBuy("maxHp");
            if (Key.isPressed(Key.NUMBER_2)) tryBuy("damage");
            if (Key.isPressed(Key.NUMBER_3)) tryBuy("flasks");
            if (Key.isPressed(Key.NUMBER_4)) tryBuy("flaskHeal");
        }
        if (screen == "play") refreshHud();
    }

    function tryBuy(key:String) {
        if (game.meta.buy(key)) {
            if (screen == "start") showStart();
            else if (screen == "death") showDeath();
        }
    }

    function refreshHud() {
        var p = game.player;
        hpBar.clear();
        hpBar.beginFill(0x1a1a2a);
        hpBar.drawRect(10, 10, 260, 20);
        hpBar.endFill();
        var pct = p.maxHp > 0 ? (p.hp / p.maxHp) : 0;
        if (pct < 0) pct = 0;
        hpBar.beginFill(0xff3355);
        hpBar.drawRect(12, 12, 256 * pct, 16);
        hpBar.endFill();
        hpBar.lineStyle(2, 0x33334a);
        hpBar.drawRect(10, 10, 260, 20);
        hpBar.lineStyle();

        hpText.text = Std.int(Math.max(0, Math.ceil(p.hp))) + " / " + Std.int(p.maxHp);
        hpText.x = 10 + (260 - hpText.textWidth) / 2;
        hpText.y = 13;

        flaskText.text = "[E] POTION " + p.flasks;
        cellsText.text = "CELLS " + p.cellsGained;
        biomeText.text = game.level.biome.name;
        depthText.text = "etage " + game.floorNumber;
        weaponsText.text = "[X] epee  [C] arc  [SHIFT] roulade";
    }
}
