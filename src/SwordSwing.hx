import h2d.Graphics;

class SwordSwing {
    public var owner : Entity;
    public var dir : Int;
    public var time : Float = 0;
    public var duration : Float;
    public var damage : Float;
    public var reach : Float;
    public var vReach : Float;
    public var dead : Bool = false;
    public var hitSet : Array<Entity> = [];
    public var gfx : Graphics;
    public var firstHit : Bool = false;
    public var game : Game;

    public function new(game:Game, owner:Entity, dir:Int, damage:Float, reach:Float, vReach:Float, duration:Float) {
        this.game = game;
        this.owner = owner;
        this.dir = dir;
        this.damage = damage;
        this.reach = reach;
        this.vReach = vReach;
        this.duration = duration;
        gfx = new Graphics(game.world);
    }

    public function update(dt:Float, targets:Array<Entity>) {
        time += dt;
        if (time >= duration) { dead = true; return; }
        var cx = owner.x + owner.w / 2;
        var cy = owner.y + owner.h / 2;
        var hx = dir > 0 ? cx : cx - reach;
        var hy = cy - vReach;
        for (t in targets) {
            if (t.dead || t == owner) continue;
            var already = false;
            for (h in hitSet) if (h == t) { already = true; break; }
            if (already) continue;
            if (t.x < hx + reach && t.x + t.w > hx && t.y < hy + vReach * 2 && t.y + t.h > hy) {
                hitSet.push(t);
                t.takeDamage(damage, dir, owner.team);
                if (!firstHit) {
                    firstHit = true;
                    game.hitStop = 0.04;
                    game.shake += 6;
                }
                owner.vx -= dir * 30;
            }
        }
    }

    public function render() {
        gfx.clear();
        var p = time / duration;
        var alpha = Math.sin(p * Math.PI);
        var cx = owner.x + owner.w / 2;
        var cy = owner.y + owner.h / 2;
        gfx.x = cx;
        gfx.y = cy;
        gfx.scaleX = dir;

        var arcStart = -Math.PI / 2.2;
        var arcEnd = Math.PI / 2.2;
        var arcPos = arcStart + (arcEnd - arcStart) * p;

        gfx.lineStyle(3, 0xffffff, alpha);
        var steps = 12;
        var r = reach * 0.8;
        var startAng = arcStart;
        var first = true;
        for (i in 0...steps + 1) {
            var a = startAng + (arcPos - startAng) * (i / steps);
            var px = Math.cos(a) * r;
            var py = Math.sin(a) * r;
            if (first) { gfx.moveTo(px, py); first = false; }
            else gfx.lineTo(px, py);
        }
        gfx.lineStyle(2, 0xffffff, alpha);
        gfx.moveTo(0, 0);
        gfx.lineTo(Math.cos(arcPos) * reach, Math.sin(arcPos) * reach);
    }

    public function destroy() {
        gfx.remove();
    }
}
