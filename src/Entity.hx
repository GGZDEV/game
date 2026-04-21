import h2d.Graphics;

class Entity {
    public var x : Float = 0;
    public var y : Float = 0;
    public var w : Float;
    public var h : Float;
    public var vx : Float = 0;
    public var vy : Float = 0;
    public var hp : Float = 1;
    public var maxHp : Float = 1;
    public var dead : Bool = false;
    public var invuln : Float = 0;
    public var hitFlash : Float = 0;
    public var knockback : Float = 0;
    public var facing : Int = 1;
    public var team : String = "neutral";
    public var grounded : Bool = false;
    public var gfx : Graphics;
    public var game : Game;
    public var cellsOnDeath : Int = 0;
    public var damage : Float = 0;
    public var hpBarTimer : Float = 0;

    public function new(game:Game, w:Float, h:Float) {
        this.game = game;
        this.w = w; this.h = h;
        gfx = new Graphics(game.world);
    }

    public inline function body() : Level.PhysBody {
        return { x:x, y:y, w:w, h:h };
    }

    public function rectOverlaps(ox:Float, oy:Float, ow:Float, oh:Float) : Bool {
        return x < ox + ow && x + w > ox && y < oy + oh && y + h > oy;
    }

    public function takeDamage(amount:Float, dirX:Float, from:String) {
        if (dead || invuln > 0) return;
        if (team == "enemy" && from == "enemy") return;
        hp -= amount;
        invuln = 0.1;
        hitFlash = 0.12;
        vx += dirX * 240;
        vy -= 120;
        knockback = 0.1;
        hpBarTimer = 2.5;
        game.particles.blood(x + w/2, y + h/2, Math.atan2(0, dirX));
        if (hp <= 0) {
            dead = true;
            game.particles.blood(x + w/2, y + h/2, 0);
        }
    }

    public function applyPhysics(dt:Float, gravity:Float = 1400.0, friction:Float = 1000.0) {
        vy += gravity * dt;
        if (vy > 620) vy = 620;
        var b = body();
        game.level.moveX(b, vx * dt);
        x = b.x;
        var hitY = game.level.moveY(b, vy * dt, false);
        y = b.y;
        if (hitY == 1) { vy = 0; grounded = true; }
        else if (hitY == -1) { vy = 0; grounded = false; }
        else grounded = false;
        if (grounded) {
            if (vx > 0) vx = Math.max(0, vx - friction * dt);
            else if (vx < 0) vx = Math.min(0, vx + friction * dt);
        }
        if (game.level.touchesSpike(b)) hp = 0;
        if (y > game.level.pixelHeight) dead = true;
    }

    public function update(dt:Float) {
        invuln = Math.max(0, invuln - dt);
        hitFlash = Math.max(0, hitFlash - dt);
        knockback = Math.max(0, knockback - dt);
        hpBarTimer = Math.max(0, hpBarTimer - dt);
    }

    public function render() {
        gfx.x = x;
        gfx.y = y;
    }

    public function renderHpBar() {
        if (hpBarTimer <= 0 || hp >= maxHp) return;
        gfx.beginFill(0x220011);
        gfx.drawRect(0, -8, w, 4);
        gfx.endFill();
        gfx.beginFill(0xff3355);
        gfx.drawRect(0, -8, (hp / maxHp) * w, 4);
        gfx.endFill();
    }

    public function destroy() {
        if (gfx != null) gfx.remove();
    }
}
