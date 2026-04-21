import hxd.Key;

class Player extends Entity {
    public var jumpsLeft : Int = 2;
    public var coyoteTime : Float = 0;
    public var jumpBuffer : Float = 0;
    public var wallSlideSide : Int = 0;
    public var wallJumpLock : Float = 0;
    public var dashTime : Float = 0;
    public var dashCooldown : Float = 0;
    public var dashDir : Int = 1;
    public var attackCooldown : Float = 0;
    public var rangedCooldown : Float = 0;
    public var animTime : Float = 0;

    public var flasks : Int;
    public var flaskMax : Int;
    public var flaskHealRatio : Float;
    public var damageBonus : Int;
    public var cellsGained : Int = 0;
    public var kills : Int = 0;

    public function new(game:Game, x:Float, y:Float) {
        super(game, 20, 36);
        this.x = x; this.y = y;
        team = "player";
        var meta = game.meta;
        maxHp = 100 + meta.maxHp * 10;
        hp = maxHp;
        damageBonus = meta.damage;
        flaskMax = 3 + meta.flasks;
        flasks = flaskMax;
        flaskHealRatio = 0.5 + meta.flaskHeal * 0.1;
    }

    public function heal(amount:Float) {
        hp = Math.min(maxHp, hp + amount);
    }

    public function useFlask() : Bool {
        if (flasks <= 0 || hp >= maxHp) return false;
        flasks--;
        heal(maxHp * flaskHealRatio);
        return true;
    }

    override public function takeDamage(amount:Float, dirX:Float, from:String) {
        if (invuln > 0 || dashTime > 0 || dead) return;
        hp -= amount;
        invuln = Const.INVULN_AFTER_HIT;
        hitFlash = 0.2;
        vx = dirX * 280;
        vy = -260;
        game.particles.blood(x + w/2, y + h/2, Math.atan2(0, dirX));
        game.flashOverlay = 0.35;
        game.shake += 6;
        if (hp <= 0) { hp = 0; dead = true; }
    }

    function checkWall(dir:Int) : Bool {
        var probeX = dir > 0 ? x + w + 1 : x - 1;
        var tx = Std.int(Math.floor(probeX / Const.TILE));
        var top = Std.int(Math.floor(y / Const.TILE));
        var bot = Std.int(Math.floor((y + h - 1) / Const.TILE));
        for (ty in top...bot + 1) if (game.level.isSolid(tx, ty)) return true;
        return false;
    }

    override public function update(dt:Float) {
        super.update(dt);
        if (dead) return;

        animTime += dt;
        attackCooldown = Math.max(0, attackCooldown - dt);
        rangedCooldown = Math.max(0, rangedCooldown - dt);
        dashCooldown = Math.max(0, dashCooldown - dt);
        wallJumpLock = Math.max(0, wallJumpLock - dt);
        coyoteTime = Math.max(0, coyoteTime - dt);
        jumpBuffer = Math.max(0, jumpBuffer - dt);

        var left = Key.isDown(Key.LEFT) || Key.isDown(Key.A) || Key.isDown(Key.Q);
        var right = Key.isDown(Key.RIGHT) || Key.isDown(Key.D);
        var jumpKey = Key.isPressed(Key.SPACE) || Key.isPressed(Key.UP) || Key.isPressed(Key.W) || Key.isPressed(Key.Z);
        var jumpHeld = Key.isDown(Key.SPACE) || Key.isDown(Key.UP) || Key.isDown(Key.W) || Key.isDown(Key.Z);
        var dashKey = Key.isPressed(Key.SHIFT) || Key.isPressed(Key.CTRL);
        var down = Key.isDown(Key.DOWN) || Key.isDown(Key.S);
        var attack = Key.isPressed(Key.X) || Key.isPressed(Key.J);
        var ranged = Key.isPressed(Key.C) || Key.isPressed(Key.K);
        var flask = Key.isPressed(Key.E);

        if (dashTime > 0) {
            dashTime -= dt;
            vx = dashDir * Const.DASH_SPEED;
            vy = 0;
            if (Math.random() < 0.5) game.particles.dust(x + w/2, y + h);
        } else {
            var target = 0.0;
            if (left && !right) { target = -Const.PLAYER_SPEED; facing = -1; }
            else if (right && !left) { target = Const.PLAYER_SPEED; facing = 1; }

            if (wallJumpLock <= 0) {
                var a = grounded ? Const.PLAYER_ACCEL : Const.PLAYER_AIR_ACCEL;
                if (target != 0) {
                    var s = target > 0 ? 1 : -1;
                    if (s != (vx > 0 ? 1 : (vx < 0 ? -1 : s)) && vx != 0) {
                        vx += s * a * 1.4 * dt;
                    } else {
                        vx += s * a * dt;
                        if (vx > Const.PLAYER_SPEED) vx = Const.PLAYER_SPEED;
                        if (vx < -Const.PLAYER_SPEED) vx = -Const.PLAYER_SPEED;
                    }
                } else {
                    var fr = grounded ? Const.PLAYER_FRICTION : Const.PLAYER_AIR_FRICTION;
                    if (vx > 0) vx = Math.max(0, vx - fr * dt);
                    else if (vx < 0) vx = Math.min(0, vx + fr * dt);
                }
            }

            if (jumpKey) jumpBuffer = Const.JUMP_BUFFER;

            // Wall slide detection
            wallSlideSide = 0;
            if (!grounded && vy > 0) {
                if (checkWall(-1) && left) wallSlideSide = -1;
                else if (checkWall(1) && right) wallSlideSide = 1;
            }
            if (wallSlideSide != 0) {
                if (vy > 120) vy = 120;
                if (jumpsLeft < 1) jumpsLeft = 1;
            }

            if (jumpBuffer > 0) {
                if (grounded || coyoteTime > 0) {
                    vy = Const.JUMP_VEL;
                    jumpsLeft = 1;
                    grounded = false;
                    coyoteTime = 0;
                    jumpBuffer = 0;
                    game.particles.dust(x + w/2, y + h);
                } else if (wallSlideSide != 0) {
                    vy = Const.JUMP_VEL * 0.95;
                    vx = -wallSlideSide * Const.PLAYER_SPEED * 1.1;
                    facing = -wallSlideSide;
                    wallJumpLock = 0.15;
                    jumpsLeft = 1;
                    jumpBuffer = 0;
                    game.particles.dust(x + w/2, y + h/2);
                } else if (jumpsLeft > 0) {
                    vy = Const.JUMP_VEL * 0.9;
                    jumpsLeft--;
                    jumpBuffer = 0;
                    game.particles.puff(x + w/2, y + h, 0xc8a8ff);
                }
            }

            if (!jumpHeld && vy < -180) vy = -180;

            if (dashKey && dashCooldown <= 0) {
                dashTime = Const.DASH_TIME;
                dashCooldown = Const.DASH_COOLDOWN;
                dashDir = facing;
                invuln = Math.max(invuln, 0.2);
                game.particles.flash(x + w/2, y + h/2, 0xffee88);
            }

            vy += Const.GRAVITY * dt;
            if (vy > Const.MAX_FALL) vy = Const.MAX_FALL;
        }

        if (flask) useFlask();

        if (attack && attackCooldown <= 0) {
            attackCooldown = Const.ATTACK_CD;
            var swing = new SwordSwing(game, this, facing, 18 + damageBonus, 56, 28, 0.2);
            game.swings.push(swing);
            vx += facing * 80;
        }

        if (ranged && rangedCooldown <= 0) {
            rangedCooldown = Const.RANGED_CD;
            var vyy = down ? 180.0 : (jumpHeld ? -180.0 : 0.0);
            var p = new Projectile(
                game, x + w/2 + facing * 12, y + h/2,
                facing * 520, vyy,
                14 + damageBonus, "player", 0xffee88, 0xffaa44, 12, 3, 1.2, 0
            );
            game.projectiles.push(p);
            vx -= facing * 30;
        }

        // Physics step (custom so we can detect landing for particles)
        var wasGrounded = grounded;
        var b = body();
        game.level.moveX(b, vx * dt);
        x = b.x;
        var hitY = game.level.moveY(b, vy * dt, down);
        y = b.y;
        if (hitY == 1) {
            if (!wasGrounded && vy > 300) {
                game.particles.dust(x + w/2, y + h);
                game.particles.dust(x + w/2 - 8, y + h);
                game.particles.dust(x + w/2 + 8, y + h);
            }
            vy = 0;
            grounded = true;
            jumpsLeft = 2;
            coyoteTime = Const.COYOTE;
        } else if (hitY == -1) {
            vy = 0;
            grounded = false;
        } else {
            if (wasGrounded && vy > 0) coyoteTime = 0.1;
            grounded = false;
        }

        if (game.level.touchesSpike(body())) takeDamage(15, 0, "spike");
        if (y > game.level.pixelHeight - 10) takeDamage(200, 0, "pit");
    }

    override public function render() {
        gfx.clear();
        gfx.x = x;
        gfx.y = y;

        if (invuln > 0 && Std.int(animTime * 30) % 2 == 0) return;

        var bodyCol = hitFlash > 0 ? 0xffffff : 0xe8d8ff;
        var cloakCol = hitFlash > 0 ? 0xffffff : 0x3a2a5a;
        var accent = 0xc8a8ff;
        var walking = Math.abs(vx) > 20 && grounded;
        var legPhase = walking ? Math.sin(animTime * 18) * 3 : 0;

        gfx.beginFill(cloakCol);
        gfx.drawRect(3, h - 10 + legPhase, 5, 10);
        gfx.drawRect(w - 8, h - 10 - legPhase, 5, 10);
        gfx.drawRect(2, 10, w - 4, h - 18);
        gfx.endFill();
        gfx.beginFill(accent);
        gfx.drawRect(2, 10, w - 4, 2);
        gfx.endFill();
        gfx.beginFill(bodyCol);
        gfx.drawRect(5, 0, 10, 10);
        gfx.endFill();
        gfx.beginFill(accent);
        var eyeX = facing > 0 ? 11 : 6;
        gfx.drawRect(eyeX, 4, 3, 2);
        gfx.endFill();

        if (dashTime > 0) {
            gfx.beginFill(0xc8a8ff, 0.4);
            gfx.drawRect(-dashDir * 8, 0, w, h);
            gfx.endFill();
            gfx.beginFill(0xc8a8ff, 0.2);
            gfx.drawRect(-dashDir * 16, 0, w, h);
            gfx.endFill();
        }

        if (wallSlideSide != 0) {
            gfx.beginFill(0xffffff, 0.4);
            for (i in 0...3) {
                var yy = h / 2 + i * 6 - 6;
                gfx.drawRect(wallSlideSide > 0 ? w : -4, yy, 4, 2);
            }
            gfx.endFill();
        }
    }
}
