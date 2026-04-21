import h2d.Object;
import h2d.Graphics;
import hxd.Key;
import Enemies.EnemyBase;

class Game {
    public var scene : h2d.Scene;
    public var world : Object;
    public var uiLayer : Object;

    public var bgGraphics : Graphics;
    public var dynGraphics : Graphics;   // animated torches / door glyph
    public var vignette : Graphics;
    public var flashGfx : Graphics;

    public var level : Level;
    public var player : Player;
    public var particles : Particles;
    public var meta : Meta;
    public var ui : UI;

    public var enemies : Array<EnemyBase> = [];
    public var projectiles : Array<Projectile> = [];
    public var swings : Array<SwordSwing> = [];
    public var pickups : Array<Pickup> = [];

    public var cameraX : Float = 0;
    public var cameraY : Float = 0;
    public var shake : Float = 0;
    public var hitStop : Float = 0;
    public var flashOverlay : Float = 0;
    public var biomeBannerTime : Float = 0;
    public var biomeBannerText : String = "";
    public var biomeBannerSub : String = "";

    public var time : Float = 0;
    public var floorNumber : Int = 1;
    public var biomeIndex : Int = 0;

    var biomeTitle : h2d.Text;
    var biomeSubtitle : h2d.Text;

    public function new(scene:h2d.Scene) {
        this.scene = scene;
        meta = new Meta();

        // Layered containers (back-to-front).
        bgGraphics = new Graphics(scene);
        world = new Object(scene);
        dynGraphics = new Graphics(world);   // belongs to world so it scrolls
        vignette = new Graphics(scene);
        flashGfx = new Graphics(scene);
        uiLayer = new Object(scene);

        particles = new Particles(world);
        ui = new UI(this, uiLayer);

        var font = hxd.res.DefaultFont.get();
        biomeTitle = new h2d.Text(font, scene);
        biomeTitle.textColor = 0xc8a8ff;
        biomeTitle.scaleX = biomeTitle.scaleY = 2.4;
        biomeSubtitle = new h2d.Text(font, scene);
        biomeSubtitle.textColor = 0xaaaabf;
        biomeSubtitle.scaleX = biomeSubtitle.scaleY = 1.4;
        biomeTitle.visible = biomeSubtitle.visible = false;

        // First-time level so Game has a valid state for the UI.
        buildLevel(0, 1, true);

        ui.showStart();
        drawVignette();
    }

    function drawVignette() {
        vignette.clear();
        var colors = [
            { r:0.0, c:0x000000, a:0.0 },
            { r:0.5, c:0x000000, a:0.3 },
            { r:1.0, c:0x000000, a:0.55 }
        ];
        // Heaps Graphics doesn't do radial gradients natively; fake with overlapping rects.
        vignette.beginFill(0x000000, 0.5);
        vignette.drawRect(0, 0, Const.VIEW_W, 50);
        vignette.drawRect(0, Const.VIEW_H - 50, Const.VIEW_W, 50);
        vignette.drawRect(0, 0, 80, Const.VIEW_H);
        vignette.drawRect(Const.VIEW_W - 80, 0, 80, Const.VIEW_H);
        vignette.endFill();
        vignette.beginFill(0x000000, 0.25);
        vignette.drawRect(0, 0, Const.VIEW_W, 100);
        vignette.drawRect(0, Const.VIEW_H - 100, Const.VIEW_W, 100);
        vignette.drawRect(0, 0, 160, Const.VIEW_H);
        vignette.drawRect(Const.VIEW_W - 160, 0, 160, Const.VIEW_H);
        vignette.endFill();
    }

    function buildLevel(biomeIdx:Int, floorNum:Int, firstBuild:Bool) {
        if (level != null) level.destroy();
        for (e in enemies) e.destroy();
        for (p in projectiles) p.destroy();
        for (s in swings) s.destroy();
        for (p in pickups) p.destroy();
        enemies = []; projectiles = []; swings = []; pickups = [];

        biomeIndex = biomeIdx;
        floorNumber = floorNum;
        level = new Level(biomeIdx, floorNum, world);
        // Re-parent dynGraphics above level statics so torches draw on top.
        world.removeChild(dynGraphics);
        world.addChild(dynGraphics);

        // Background color override per biome
        Main.inst.engine.backgroundColor = 0xff000000 | level.biome.bg;

        if (firstBuild) {
            player = new Player(this, level.startX, level.startY);
        } else {
            player.x = level.startX;
            player.y = level.startY;
            player.vx = 0; player.vy = 0;
            if (player.flasks < player.flaskMax) player.flasks++;
        }
        // Place player's graphics on top of everything in the world
        world.removeChild(player.gfx);
        world.addChild(player.gfx);

        for (spec in level.enemySpawns) {
            enemies.push(Enemies.make(this, spec.type, spec.x, spec.y));
        }
        for (c in level.cellSpawns) {
            pickups.push(new Pickup(this, c.x, c.y,
                "cell",
                (Math.random() - 0.5) * 60,
                -(80 + Math.random() * 70)
            ));
        }

        cameraX = player.x - Const.VIEW_W / 2;
        cameraY = player.y - Const.VIEW_H / 2;

        biomeBannerTime = 1.8;
        biomeBannerText = level.biome.name;
        biomeBannerSub = "Etage " + floorNumber + " - " + level.biome.flavor;
    }

    public function startRun() {
        if (player != null) { player.destroy(); player = null; }
        buildLevel(0, 1, true);
        ui.showPlay();
    }

    public function nextFloor() {
        var maxFloorsPerBiome = 2;
        var nb = biomeIndex;
        var nf = floorNumber + 1;
        if (floorNumber >= maxFloorsPerBiome) {
            nb++; nf = 1;
            if (nb >= Biome.ALL.length) {
                meta.cells += player.cellsGained;
                meta.save();
                ui.showVictory();
                return;
            }
        }
        buildLevel(nb, nf, false);
    }

    function die() {
        meta.cells += player.cellsGained;
        meta.save();
        ui.showDeath();
    }

    public function update(dt:Float) {
        time += dt;
        ui.update(dt);

        if (ui.screen == "start" || ui.screen == "death" || ui.screen == "victory") {
            if (Key.isPressed(Key.ENTER)) {
                if (ui.screen == "victory") { ui.showStart(); return; }
                startRun();
            }
            return;
        }

        if (hitStop > 0) { hitStop -= dt; return; }
        if (biomeBannerTime > 0) biomeBannerTime -= dt;

        player.update(dt);

        for (s in swings) {
            var targets : Array<Entity> = cast enemies;
            s.update(dt, targets);
        }
        for (e in enemies) if (!e.dead) e.update(dt);

        // Dead-enemy cleanup + loot
        var i = enemies.length - 1;
        while (i >= 0) {
            var e = enemies[i];
            if (e.dead) {
                player.kills++;
                for (k in 0...e.cellsOnDeath) {
                    pickups.push(new Pickup(this, e.x + e.w/2, e.y + e.h/2,
                        "cell",
                        (Math.random() - 0.5) * 240,
                        -(80 + Math.random() * 140)
                    ));
                }
                if (Math.random() < 0.22) {
                    pickups.push(new Pickup(this, e.x + e.w/2, e.y, "flask",
                        (Math.random() - 0.5) * 80, -140));
                }
                particles.pickup(e.x + e.w/2, e.y + e.h/2, 0xffcc44);
                shake += 3;
                e.destroy();
                enemies.splice(i, 1);
            }
            i--;
        }

        // Projectiles
        for (p in projectiles) {
            var targets : Array<Entity> = if (p.owner == "player") (cast enemies) else [cast player];
            p.update(dt, targets);
        }
        i = projectiles.length - 1;
        while (i >= 0) {
            if (projectiles[i].dead) {
                projectiles[i].destroy();
                projectiles.splice(i, 1);
            }
            i--;
        }

        // Swings cleanup
        i = swings.length - 1;
        while (i >= 0) {
            if (swings[i].dead) {
                swings[i].destroy();
                swings.splice(i, 1);
            }
            i--;
        }

        // Pickups
        for (p in pickups) p.update(dt);
        i = pickups.length - 1;
        while (i >= 0) {
            if (pickups[i].collected) {
                pickups[i].destroy();
                pickups.splice(i, 1);
            }
            i--;
        }

        // Exit interaction
        var dxE = (player.x + player.w/2) - level.exitX;
        var dyE = (player.y + player.h/2) - level.exitY;
        if (Math.abs(dxE) < 24 && Math.abs(dyE) < 60 && Key.isPressed(Key.F)) {
            nextFloor();
            return;
        }

        // Camera follow + lookahead
        var tx = player.x + player.w/2 - Const.VIEW_W / 2 + player.facing * 60;
        var ty = player.y + player.h/2 - Const.VIEW_H / 2 - 40;
        cameraX += (tx - cameraX) * 0.12;
        cameraY += (ty - cameraY) * 0.12;
        if (cameraX < 0) cameraX = 0;
        if (cameraX > level.pixelWidth - Const.VIEW_W) cameraX = level.pixelWidth - Const.VIEW_W;
        if (cameraY < 0) cameraY = 0;
        if (cameraY > level.pixelHeight - Const.VIEW_H) cameraY = level.pixelHeight - Const.VIEW_H;

        shake = Math.max(0, shake - dt * 40);
        flashOverlay = Math.max(0, flashOverlay - dt * 2);
        particles.update(dt);

        // Apply camera to world
        var sx = (Math.random() - 0.5) * shake;
        var sy = (Math.random() - 0.5) * shake;
        world.x = -(cameraX + sx);
        world.y = -(cameraY + sy);

        // Render dynamic layer (torches etc.)
        level.drawDynamic(time, dynGraphics);

        // Render entities (their gfx lives in world so just set x/y/local draws)
        player.render();
        for (e in enemies) e.render();
        for (s in swings) s.render();
        for (p in projectiles) p.render();
        for (p in pickups) p.render();
        particles.render();

        // Flash overlay
        flashGfx.clear();
        if (flashOverlay > 0) {
            flashGfx.beginFill(0xff3030, flashOverlay);
            flashGfx.drawRect(0, 0, Const.VIEW_W, Const.VIEW_H);
            flashGfx.endFill();
        }

        // Biome banner
        if (biomeBannerTime > 0) {
            biomeTitle.visible = true;
            biomeSubtitle.visible = true;
            biomeTitle.text = biomeBannerText;
            biomeSubtitle.text = biomeBannerSub;
            biomeTitle.x = (Const.VIEW_W - biomeTitle.textWidth * biomeTitle.scaleX) / 2;
            biomeTitle.y = Const.VIEW_H / 2 - 50;
            biomeSubtitle.x = (Const.VIEW_W - biomeSubtitle.textWidth * biomeSubtitle.scaleX) / 2;
            biomeSubtitle.y = Const.VIEW_H / 2 + 20;
            var a = biomeBannerTime > 1.3 ? 1.0 : biomeBannerTime / 1.3;
            biomeTitle.alpha = a;
            biomeSubtitle.alpha = a;
        } else {
            biomeTitle.visible = false;
            biomeSubtitle.visible = false;
        }

        // Exit prompt
        if (Math.abs(dxE) < 40 && Math.abs(dyE) < 60) {
            // draw a hint via flashGfx (repurposing layer)
            flashGfx.beginFill(0x000000, 0.7);
            var hx = Const.VIEW_W / 2 - 60;
            flashGfx.drawRect(hx, Const.VIEW_H - 90, 120, 22);
            flashGfx.endFill();
        }

        if (player.dead && ui.screen == "play") {
            die();
        }
    }
}
