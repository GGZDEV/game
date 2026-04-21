import h2d.Graphics;

class Pickup {
    public var x : Float;
    public var y : Float;
    public var vx : Float;
    public var vy : Float;
    public var kind : String; // "cell" | "flask"
    public var life : Float;
    public var collected : Bool = false;
    public var gfx : Graphics;
    public var game : Game;

    public function new(game:Game, x:Float, y:Float, kind:String, vx:Float, vy:Float) {
        this.game = game;
        this.x = x; this.y = y;
        this.kind = kind;
        this.vx = vx; this.vy = vy;
        life = 20;
        gfx = new Graphics(game.world);
    }

    public function update(dt:Float) {
        if (collected) return;
        life -= dt;
        if (life <= 0) { collected = true; return; }

        var body : Level.PhysBody = { x: x - 6, y: y - 6, w: 12, h: 12 };
        game.level.moveX(body, vx * dt);
        var hitY = game.level.moveY(body, vy * dt, false);
        if (hitY == 1) {
            if (vy > 60) vy = -vy * 0.35;
            else vy = 0;
            vx *= 0.6;
        } else if (hitY == -1) vy = 0;
        x = body.x + 6;
        y = body.y + 6;

        vy += 900 * dt;
        vx *= 0.97;
        if (vy > 600) vy = 600;

        var p = game.player;
        var dx = (p.x + p.w / 2) - x;
        var dy = (p.y + p.h / 2) - y;
        var d = Math.sqrt(dx * dx + dy * dy);
        if (d < 90 && d > 0) {
            vx += (dx / d) * 900 * dt;
            vy += (dy / d) * 900 * dt;
        }

        if (x - 6 < p.x + p.w && x + 6 > p.x && y - 6 < p.y + p.h && y + 6 > p.y) {
            collected = true;
            if (kind == "cell") {
                p.cellsGained++;
                game.particles.pickup(x, y, 0xffcc44);
            } else if (kind == "flask") {
                if (p.flasks < p.flaskMax) p.flasks++;
                else p.heal(15);
                game.particles.pickup(x, y, 0x88ffaa);
            }
        }
    }

    public function render() {
        gfx.clear();
        gfx.x = 0; gfx.y = 0;
        var pulse = Math.sin(game.time * 8 + x) * 2;
        if (kind == "cell") {
            gfx.beginFill(0xffcc44);
            gfx.moveTo(x, y - 6 + pulse);
            gfx.lineTo(x + 5, y + pulse);
            gfx.lineTo(x, y + 6 + pulse);
            gfx.lineTo(x - 5, y + pulse);
            gfx.lineTo(x, y - 6 + pulse);
            gfx.endFill();
            gfx.beginFill(0xffdc50, 0.3);
            gfx.drawCircle(x, y + pulse, 10);
            gfx.endFill();
        } else if (kind == "flask") {
            gfx.beginFill(0x88ffaa);
            gfx.drawRect(x - 4, y - 6, 8, 10);
            gfx.endFill();
            gfx.beginFill(0x3a5a3a);
            gfx.drawRect(x - 2, y - 8, 4, 2);
            gfx.endFill();
        }
    }

    public function destroy() gfx.remove();
}
