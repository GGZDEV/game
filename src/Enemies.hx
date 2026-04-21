class EnemyBase extends Entity {
    public function new(game:Game, x:Float, y:Float, w:Float, h:Float) {
        super(game, w, h);
        this.x = x - w / 2; this.y = y - h;
        team = "enemy";
        facing = Math.random() < 0.5 ? -1 : 1;
    }
    override public function takeDamage(amount:Float, dirX:Float, from:String) {
        if (from == "enemy") return;
        super.takeDamage(amount, dirX, from);
        vx += dirX * 240;
        vy -= 120;
        knockback = 0.1;
    }
    public function touchPlayer() {
        if (dead || game.player.dead) return;
        var p = game.player;
        if (x < p.x + p.w && x + w > p.x && y < p.y + p.h && y + h > p.y) {
            var dir : Float = (p.x + p.w / 2 - (x + w / 2)) > 0 ? 1 : -1;
            p.takeDamage(damage, dir, "enemy");
        }
    }
}

class Grunt extends EnemyBase {
    public var speed : Float = 90;
    public var alert : Bool = false;
    public var patrolDir : Int;
    public function new(game:Game, x:Float, y:Float) {
        super(game, x, y, 24, 28);
        maxHp = 30; hp = 30;
        damage = 10;
        cellsOnDeath = 2;
        patrolDir = Math.random() < 0.5 ? -1 : 1;
    }
    override public function update(dt:Float) {
        super.update(dt);
        if (dead) return;
        var cx = x + w/2;
        var p = game.player;
        var dx = (p.x + p.w/2) - cx;
        var dist = Math.sqrt(dx * dx + ((p.y + p.h/2) - (y + h/2)) * ((p.y + p.h/2) - (y + h/2)));
        if (!alert && dist < 260 && Math.abs(p.y - y) < 140) alert = true;

        if (knockback <= 0) {
            if (alert) {
                facing = dx > 0 ? 1 : (dx < 0 ? -1 : facing);
                var aheadX = facing > 0 ? x + w + 4 : x - 4;
                var footY = y + h + 4;
                var tx = Std.int(Math.floor(aheadX / Const.TILE));
                var ty = Std.int(Math.floor(footY / Const.TILE));
                var safe = game.level.isSolid(tx, ty) || game.level.isPlatform(tx, ty);
                if (safe || !grounded) vx = facing * speed;
                else vx = 0;
            } else {
                vx = patrolDir * 40;
                facing = patrolDir;
                var aheadX = facing > 0 ? x + w + 4 : x - 4;
                var footY = y + h + 4;
                var tx = Std.int(Math.floor(aheadX / Const.TILE));
                var ty = Std.int(Math.floor(footY / Const.TILE));
                var safe = game.level.isSolid(tx, ty) || game.level.isPlatform(tx, ty);
                var wx = Std.int(Math.floor((facing > 0 ? x + w + 1 : x - 1) / Const.TILE));
                var wy = Std.int(Math.floor((y + h / 2) / Const.TILE));
                var wall = game.level.isSolid(wx, wy);
                if (!safe || wall) patrolDir *= -1;
            }
        }
        applyPhysics(dt);
        touchPlayer();
    }
    override public function render() {
        gfx.clear();
        gfx.x = x; gfx.y = y;
        var bodyCol = hitFlash > 0 ? 0xffffff : 0x4a3a22;
        var skinCol = hitFlash > 0 ? 0xffffff : 0x8a7c5a;
        var eye = alert ? 0xff3355 : 0xffaa44;
        var phase = Math.abs(vx) > 20 ? Math.sin(game.time * 12) * 2 : 0;
        gfx.beginFill(bodyCol);
        gfx.drawRect(2, 10, w - 4, h - 14);
        gfx.drawRect(4, h - 6, 6, 6 + phase);
        gfx.drawRect(w - 10, h - 6, 6, 6 - phase);
        gfx.endFill();
        gfx.beginFill(skinCol);
        gfx.drawRect(6, 0, 12, 12);
        gfx.endFill();
        gfx.beginFill(eye);
        var ex = facing > 0 ? 14 : 6;
        gfx.drawRect(ex, 5, 2, 3);
        gfx.endFill();
        gfx.beginFill(0xaabbcc);
        var wx = facing > 0 ? w : -6;
        gfx.drawRect(wx, 14, 6, 3);
        gfx.endFill();
        renderHpBar();
    }
}

class Slasher extends EnemyBase {
    public var speed : Float = 140;
    public var state : String = "idle";
    public var timer : Float = 0;
    public var alert : Bool = false;
    public function new(game:Game, x:Float, y:Float) {
        super(game, x, y, 24, 28);
        maxHp = 40; hp = 40;
        damage = 14;
        cellsOnDeath = 3;
    }
    override public function update(dt:Float) {
        super.update(dt);
        if (dead) return;
        timer -= dt;
        var cx = x + w/2, cy = y + h/2;
        var p = game.player;
        var px = p.x + p.w/2, py = p.y + p.h/2;
        var dx = px - cx, dy = py - cy;
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (!alert && dist < 320 && Math.abs(dy) < 120) { alert = true; state = "chase"; }

        if (knockback <= 0 && !p.dead) {
            if (state == "chase") {
                facing = dx > 0 ? 1 : (dx < 0 ? -1 : facing);
                vx = facing * speed;
                if (dist < 140 && Math.abs(dy) < 40 && grounded) {
                    state = "windup";
                    timer = 0.35;
                    vx = 0;
                }
            } else if (state == "windup") {
                vx *= 0.5;
                if (timer <= 0) {
                    state = "dash";
                    timer = 0.35;
                    vx = facing * 480;
                    vy = -60;
                    game.particles.dust(cx, y + h);
                }
            } else if (state == "dash") {
                if (timer <= 0) { state = "chase"; vx *= 0.3; }
            } else vx = 0;
        }
        applyPhysics(dt);
        touchPlayer();
    }
    override public function render() {
        gfx.clear();
        gfx.x = x; gfx.y = y;
        var bodyCol = hitFlash > 0 ? 0xffffff : 0x2a4050;
        var skinCol = hitFlash > 0 ? 0xffffff : 0x90a0b8;
        var eye = state == "windup" ? 0xffff44 : 0xff3355;
        gfx.beginFill(bodyCol);
        gfx.drawRect(2, 8, w - 4, h - 12);
        gfx.drawRect(3, h - 6, 6, 6);
        gfx.drawRect(w - 9, h - 6, 6, 6);
        gfx.endFill();
        gfx.beginFill(skinCol);
        gfx.drawRect(6, 0, 12, 10);
        gfx.endFill();
        gfx.beginFill(bodyCol);
        gfx.drawRect(5, -3, 3, 3);
        gfx.drawRect(w - 8, -3, 3, 3);
        gfx.endFill();
        gfx.beginFill(eye);
        var ex = facing > 0 ? 14 : 6;
        gfx.drawRect(ex, 4, 3, 3);
        gfx.endFill();
        gfx.beginFill(0xddddee);
        var bx = facing > 0 ? w : -10;
        gfx.drawRect(bx, 14, 10, 3);
        gfx.endFill();
        if (state == "windup") {
            var flicker = Math.sin(game.time * 40) * 0.3 + 0.7;
            gfx.beginFill(0xffff50, flicker);
            gfx.drawRect(bx - 1, 13, 12, 5);
            gfx.endFill();
        }
        renderHpBar();
    }
}

class Archer extends EnemyBase {
    public var aimTime : Float = 0;
    public var cooldown : Float = 1.2;
    public function new(game:Game, x:Float, y:Float) {
        super(game, x, y, 20, 30);
        maxHp = 22; hp = 22;
        damage = 12;
        cellsOnDeath = 3;
    }
    public function hasLOS(px:Float, py:Float) : Bool {
        var cx = x + w/2, cy = y + h/2;
        var dx = px - cx, dy = py - cy;
        var d = Math.sqrt(dx * dx + dy * dy);
        var steps = Std.int(Math.max(1, d / 12));
        for (i in 1...steps) {
            var t = i / steps;
            var tx = Std.int(Math.floor((cx + dx * t) / Const.TILE));
            var ty = Std.int(Math.floor((cy + dy * t) / Const.TILE));
            if (game.level.isSolid(tx, ty)) return false;
        }
        return true;
    }
    override public function update(dt:Float) {
        super.update(dt);
        if (dead) return;
        cooldown -= dt;
        var p = game.player;
        var px = p.x + p.w/2, py = p.y + p.h/2;
        var cx = x + w/2, cy = y + h/2;
        var dx = px - cx, dy = py - cy;
        var dist = Math.sqrt(dx * dx + dy * dy);
        facing = dx > 0 ? 1 : (dx < 0 ? -1 : facing);
        vx = 0;
        if (!p.dead && dist < 420 && hasLOS(px, py) && Math.abs(dy) < 140) {
            if (aimTime == 0 && cooldown <= 0) aimTime = 0.001;
            if (aimTime > 0) {
                aimTime += dt;
                if (aimTime > 0.6) {
                    var ang = Math.atan2(dy, dx);
                    var speed = 360.0;
                    var pr = new Projectile(
                        game, cx + Math.cos(ang) * 16, cy + Math.sin(ang) * 16,
                        Math.cos(ang) * speed, Math.sin(ang) * speed,
                        damage, "enemy",
                        0xff9944, 0xaa4422,
                        12, 3, 1.5, 0
                    );
                    game.projectiles.push(pr);
                    aimTime = 0;
                    cooldown = 1.6;
                }
            }
        } else aimTime = 0;
        applyPhysics(dt);
    }
    override public function render() {
        gfx.clear();
        gfx.x = x; gfx.y = y;
        var bodyCol = hitFlash > 0 ? 0xffffff : 0x3a3028;
        var skinCol = hitFlash > 0 ? 0xffffff : 0xb09a72;
        gfx.beginFill(bodyCol);
        gfx.drawRect(3, 10, w - 6, h - 14);
        gfx.drawRect(4, h - 6, 5, 6);
        gfx.drawRect(w - 9, h - 6, 5, 6);
        gfx.drawRect(4, 0, 12, 8);
        gfx.endFill();
        gfx.beginFill(skinCol);
        gfx.drawRect(6, 4, 8, 6);
        gfx.endFill();
        // Bow curve
        gfx.lineStyle(2, 0x886633);
        var bx = facing > 0 ? w : 0;
        gfx.moveTo(bx, 10);
        gfx.curveTo(bx + facing * 10, 16, bx, 22);
        gfx.lineStyle();
        // Aim line
        if (aimTime > 0) {
            var t = aimTime / 0.6;
            if (t > 1) t = 1;
            gfx.lineStyle(1, 0xff3030, t);
            gfx.moveTo(w/2, h/2);
            gfx.lineTo(w/2 + facing * 200, h/2);
            gfx.lineStyle();
        }
        renderHpBar();
    }
}

class Bat extends EnemyBase {
    public var flyT : Float = 0;
    public var state : String = "idle";
    public var swoopCD : Float = 1.5;
    public function new(game:Game, x:Float, y:Float) {
        super(game, x, y, 22, 16);
        maxHp = 14; hp = 14;
        damage = 8;
        cellsOnDeath = 1;
        flyT = Math.random() * Math.PI * 2;
    }
    override public function update(dt:Float) {
        super.update(dt);
        if (dead) return;
        flyT += dt;
        swoopCD -= dt;
        var p = game.player;
        var cx = x + w/2, cy = y + h/2;
        var px = p.x + p.w/2, py = p.y + p.h/2;
        var dx = px - cx, dy = py - cy;
        var dist = Math.sqrt(dx * dx + dy * dy);

        if (knockback <= 0) {
            if (state == "swoop") {
                if (swoopCD <= 0) { state = "idle"; swoopCD = 2.5; }
            } else {
                if (dist < 220 && !p.dead && swoopCD <= 0) {
                    state = "swoop";
                    vx = (dx > 0 ? 1.0 : -1.0) * 220;
                    vy = (dy > 0 ? 1.0 : -1.0) * 180;
                    swoopCD = 0.5;
                } else {
                    vx = dx * 0.6;
                    if (vx > 70) vx = 70;
                    if (vx < -70) vx = -70;
                    var tvy = dy * 0.3;
                    if (tvy > 40) tvy = 40;
                    if (tvy < -40) tvy = -40;
                    vy = Math.sin(flyT * 3) * 40 + tvy;
                    facing = dx > 0 ? 1 : (dx < 0 ? -1 : facing);
                }
            }
        }

        var b = body();
        game.level.moveX(b, vx * dt);
        x = b.x;
        game.level.moveY(b, vy * dt, false);
        y = b.y;
        if (game.level.touchesSpike(b)) hp = 0;
        touchPlayer();
    }
    override public function render() {
        gfx.clear();
        gfx.x = x; gfx.y = y;
        var bodyCol = hitFlash > 0 ? 0xffffff : 0x2a1a2a;
        var wingCol = hitFlash > 0 ? 0xffffff : 0x4a2a4a;
        var flap = Math.sin(game.time * 22) * 4;
        gfx.beginFill(wingCol);
        gfx.moveTo(2, 8);
        gfx.lineTo(-4, 4 - flap);
        gfx.lineTo(2, 12);
        gfx.lineTo(2, 8);
        gfx.moveTo(w - 2, 8);
        gfx.lineTo(w + 4, 4 - flap);
        gfx.lineTo(w - 2, 12);
        gfx.lineTo(w - 2, 8);
        gfx.endFill();
        gfx.beginFill(bodyCol);
        gfx.drawRect(4, 4, w - 8, h - 6);
        gfx.endFill();
        gfx.beginFill(0xff4466);
        gfx.drawRect(7, 7, 2, 2);
        gfx.drawRect(w - 9, 7, 2, 2);
        gfx.endFill();
        gfx.beginFill(0xffffff);
        gfx.drawRect(8, 11, 2, 3);
        gfx.drawRect(w - 10, 11, 2, 3);
        gfx.endFill();
        renderHpBar();
    }
}

class Enemies {
    public static function make(game:Game, type:String, x:Float, y:Float) : EnemyBase {
        return switch(type) {
            case "grunt":   new Grunt(game, x, y);
            case "slasher": new Slasher(game, x, y);
            case "archer":  new Archer(game, x, y);
            case "bat":     new Bat(game, x, y);
            default:        new Grunt(game, x, y);
        }
    }
}
