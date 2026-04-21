import h2d.Graphics;

class Projectile {
    public var x : Float;
    public var y : Float;
    public var vx : Float;
    public var vy : Float;
    public var w : Float;
    public var h : Float;
    public var life : Float;
    public var damage : Float;
    public var owner : String;
    public var color : Int;
    public var trailCol : Int;
    public var gravity : Float;
    public var dead : Bool = false;
    public var rot : Float = 0;
    public var trailPts : Array<{ x:Float, y:Float, life:Float }> = [];
    public var gfx : Graphics;
    public var game : Game;

    public function new(
        game:Game, x:Float, y:Float, vx:Float, vy:Float,
        damage:Float, owner:String,
        color:Int, trailCol:Int,
        w:Float, h:Float, life:Float, gravity:Float
    ) {
        this.game = game;
        this.x = x; this.y = y; this.vx = vx; this.vy = vy;
        this.w = w; this.h = h;
        this.damage = damage;
        this.owner = owner;
        this.color = color;
        this.trailCol = trailCol;
        this.life = life;
        this.gravity = gravity;
        gfx = new Graphics(game.world);
        rot = Math.atan2(vy, vx);
    }

    public function update(dt:Float, targets:Array<Entity>) {
        life -= dt;
        if (life <= 0) { dead = true; return; }

        trailPts.push({ x:x, y:y, life:0.15 });
        var i = trailPts.length - 1;
        while (i >= 0) {
            trailPts[i].life -= dt;
            if (trailPts[i].life <= 0) trailPts.splice(i, 1);
            i--;
        }

        x += vx * dt;
        y += vy * dt;
        vy += gravity * dt;
        rot = Math.atan2(vy, vx);

        var left = Std.int(Math.floor((x - w/2) / Const.TILE));
        var right = Std.int(Math.floor((x + w/2 - 0.01) / Const.TILE));
        var top = Std.int(Math.floor((y - h/2) / Const.TILE));
        var bottom = Std.int(Math.floor((y + h/2 - 0.01) / Const.TILE));
        for (ty in top...bottom + 1) for (tx in left...right + 1) {
            if (game.level.isSolid(tx, ty)) {
                dead = true;
                game.particles.hitSpark(x, y);
                return;
            }
        }

        for (t in targets) {
            if (t.dead || t.invuln > 0) continue;
            if (x - w/2 < t.x + t.w && x + w/2 > t.x && y - h/2 < t.y + t.h && y + h/2 > t.y) {
                var dir = vx > 0 ? 1.0 : -1.0;
                t.takeDamage(damage, dir, owner);
                dead = true;
                game.particles.hitSpark(x, y);
                return;
            }
        }
    }

    public function render() {
        gfx.clear();
        gfx.x = 0; gfx.y = 0; gfx.rotation = 0;
        // Trail drawn in world coords
        for (t in trailPts) {
            var a = t.life / 0.15;
            if (a < 0) a = 0;
            gfx.beginFill(trailCol, a * 0.5);
            gfx.drawRect(t.x - 1, t.y - 1, 3, 3);
            gfx.endFill();
        }
        // Body as rotated quad
        var c = Math.cos(rot), s = Math.sin(rot);
        var hw = w / 2, hh = h / 2;
        gfx.beginFill(color);
        var x0 = x + (-hw) * c - (-hh) * s, y0 = y + (-hw) * s + (-hh) * c;
        var x1 = x + ( hw) * c - (-hh) * s, y1 = y + ( hw) * s + (-hh) * c;
        var x2 = x + ( hw) * c - ( hh) * s, y2 = y + ( hw) * s + ( hh) * c;
        var x3 = x + (-hw) * c - ( hh) * s, y3 = y + (-hw) * s + ( hh) * c;
        gfx.moveTo(x0, y0);
        gfx.lineTo(x1, y1);
        gfx.lineTo(x2, y2);
        gfx.lineTo(x3, y3);
        gfx.lineTo(x0, y0);
        gfx.endFill();
        // Tip highlight
        gfx.beginFill(0xffffff);
        var tx = x + (hw) * c;
        var ty = y + (hw) * s;
        gfx.drawRect(tx - 1, ty - 1, 2, 2);
        gfx.endFill();
    }

    public function destroy() {
        gfx.remove();
    }
}
