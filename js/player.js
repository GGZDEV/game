import { isDown, wasPressed } from './input.js';
import { clamp } from './utils.js';
import { SwordSwing, Projectile } from './weapon.js';

export class Player {
    constructor(x, y, meta) {
        this.x = x; this.y = y;
        this.w = 20; this.h = 36;
        this.vx = 0; this.vy = 0;
        this.facing = 1;
        this.team = 'player';

        // Stats
        const maxHpBonus = meta.upgrades.maxHp * 10;
        const damageBonus = meta.upgrades.damage;
        const flaskBonus = meta.upgrades.flasks;
        const healBonus = meta.upgrades.flaskHeal * 0.1;

        this.maxHp = 100 + maxHpBonus;
        this.hp = this.maxHp;
        this.damageBonus = damageBonus;
        this.flaskMax = 3 + flaskBonus;
        this.flasks = this.flaskMax;
        this.flaskHealRatio = 0.5 + healBonus;

        // Movement
        this.speed = 220;
        this.accel = 1800;
        this.airAccel = 1200;
        this.friction = 1800;
        this.airFriction = 400;
        this.jumpVel = -430;
        this.gravity = 1400;
        this.maxFall = 620;

        // State
        this.grounded = false;
        this.jumpsLeft = 2;
        this.coyoteTime = 0;
        this.jumpBuffer = 0;
        this.wallSlideSide = 0; // -1 left wall, 1 right wall, 0 none
        this.wallJumpLock = 0;

        this.dashTime = 0;
        this.dashCooldown = 0;
        this.dashDir = 1;

        this.attackCooldown = 0;
        this.rangedCooldown = 0;

        this.invuln = 0;
        this.hitFlash = 0;
        this.dead = false;
        this.kills = 0;
        this.cellsGained = 0;

        this.animTime = 0;
    }

    hitbox() { return { x: this.x, y: this.y, w: this.w, h: this.h }; }

    heal(amount) {
        this.hp = Math.min(this.maxHp, this.hp + amount);
    }

    useFlask() {
        if (this.flasks <= 0 || this.hp >= this.maxHp) return false;
        this.flasks--;
        this.heal(this.maxHp * this.flaskHealRatio);
        return true;
    }

    takeDamage(amount, dirX, particles, from) {
        if (this.invuln > 0 || this.dashTime > 0 || this.dead) return;
        this.hp -= amount;
        this.invuln = 0.8;
        this.hitFlash = 0.2;
        this.vx = dirX * 280;
        this.vy = -260;
        particles.blood(this.x + this.w/2, this.y + this.h/2, Math.atan2(0, dirX));
        if (this.hp <= 0) {
            this.hp = 0;
            this.dead = true;
            particles.blood(this.x + this.w/2, this.y + this.h/2, 0);
        }
    }

    update(dt, level, entities, particles, audio) {
        if (this.dead) return;

        this.animTime += dt;
        this.attackCooldown = Math.max(0, this.attackCooldown - dt);
        this.rangedCooldown = Math.max(0, this.rangedCooldown - dt);
        this.dashCooldown = Math.max(0, this.dashCooldown - dt);
        this.invuln = Math.max(0, this.invuln - dt);
        this.hitFlash = Math.max(0, this.hitFlash - dt);
        this.wallJumpLock = Math.max(0, this.wallJumpLock - dt);
        this.coyoteTime = Math.max(0, this.coyoteTime - dt);
        this.jumpBuffer = Math.max(0, this.jumpBuffer - dt);

        const left = isDown('arrowleft', 'a', 'q');
        const right = isDown('arrowright', 'd');
        const jumpPressed = wasPressed('arrowup', 'w', 'z', ' ');
        const dashPressed = wasPressed('shift', 'control');
        const down = isDown('arrowdown', 's');
        const attack = wasPressed('x', 'j');
        const ranged = wasPressed('c', 'k');
        const flask = wasPressed('e');

        // Dash control
        if (this.dashTime > 0) {
            this.dashTime -= dt;
            this.vx = this.dashDir * 520;
            this.vy = 0;
            if (Math.random() < 0.5) particles.dust(this.x + this.w / 2, this.y + this.h);
        } else {
            // Horizontal acceleration
            let target = 0;
            if (left && !right) { target = -this.speed; this.facing = -1; }
            else if (right && !left) { target = this.speed; this.facing = 1; }

            if (this.wallJumpLock <= 0) {
                const a = this.grounded ? this.accel : this.airAccel;
                if (target !== 0) {
                    if (Math.sign(target) !== Math.sign(this.vx) && this.vx !== 0) {
                        this.vx += Math.sign(target) * a * 1.4 * dt;
                    } else {
                        this.vx += Math.sign(target) * a * dt;
                        this.vx = clamp(this.vx, -this.speed, this.speed);
                    }
                } else {
                    const fr = this.grounded ? this.friction : this.airFriction;
                    if (this.vx > 0) this.vx = Math.max(0, this.vx - fr * dt);
                    else if (this.vx < 0) this.vx = Math.min(0, this.vx + fr * dt);
                }
            }

            // Jump input handling
            if (jumpPressed) this.jumpBuffer = 0.12;

            // Wall slide detection: moving into wall while airborne
            this.wallSlideSide = 0;
            if (!this.grounded && this.vy > 0) {
                const touchingLeft = this.checkWall(level, -1);
                const touchingRight = this.checkWall(level, 1);
                if (touchingLeft && left) this.wallSlideSide = -1;
                else if (touchingRight && right) this.wallSlideSide = 1;
            }
            if (this.wallSlideSide !== 0) {
                this.vy = Math.min(this.vy, 120);
                this.jumpsLeft = Math.max(this.jumpsLeft, 1);
            }

            // Execute jump
            if (this.jumpBuffer > 0) {
                if (this.grounded || this.coyoteTime > 0) {
                    this.vy = this.jumpVel;
                    this.jumpsLeft = 1;
                    this.grounded = false;
                    this.coyoteTime = 0;
                    this.jumpBuffer = 0;
                    particles.dust(this.x + this.w/2, this.y + this.h);
                } else if (this.wallSlideSide !== 0) {
                    this.vy = this.jumpVel * 0.95;
                    this.vx = -this.wallSlideSide * this.speed * 1.1;
                    this.facing = -this.wallSlideSide;
                    this.wallJumpLock = 0.15;
                    this.jumpsLeft = 1;
                    this.jumpBuffer = 0;
                    particles.dust(this.x + this.w/2, this.y + this.h/2);
                } else if (this.jumpsLeft > 0) {
                    this.vy = this.jumpVel * 0.9;
                    this.jumpsLeft--;
                    this.jumpBuffer = 0;
                    // Double jump puff
                    particles.spawn(this.x + this.w/2, this.y + this.h, {
                        count: 10, minSpeed: 50, maxSpeed: 150,
                        color: '#c8a8ff', gravity: 200, minLife: 0.2, maxLife: 0.4,
                    });
                }
            }

            // Variable jump height (cut velocity on release)
            if (!isDown('arrowup', 'w', 'z', ' ') && this.vy < -180) {
                this.vy = -180;
            }

            // Dash
            if (dashPressed && this.dashCooldown <= 0) {
                this.dashTime = 0.18;
                this.dashCooldown = 0.6;
                this.dashDir = this.facing;
                this.invuln = Math.max(this.invuln, 0.2);
                particles.spawn(this.x + this.w/2, this.y + this.h/2, {
                    count: 12, minSpeed: 50, maxSpeed: 150,
                    color: '#ffee88', gravity: 0, minLife: 0.2, maxLife: 0.4,
                });
            }

            // Gravity — always applied so the grounded flag stays stable.
            this.vy += this.gravity * dt;
            if (this.vy > this.maxFall) this.vy = this.maxFall;
        }

        // Flask
        if (flask) this.useFlask();

        // Attack (sword)
        if (attack && this.attackCooldown <= 0) {
            this.attackCooldown = 0.32;
            const swing = new SwordSwing(this, this.facing, {
                damage: 18 + this.damageBonus,
                reach: 56, vReach: 28, duration: 0.2,
            });
            entities.swings.push(swing);
            // small forward lunge
            this.vx += this.facing * 80;
        }

        // Ranged (bow)
        if (ranged && this.rangedCooldown <= 0) {
            this.rangedCooldown = 0.5;
            const dir = this.facing;
            const vy = down ? 180 : (isDown('arrowup', 'w', 'z') ? -180 : 0);
            const p = new Projectile(
                this.x + this.w/2 + dir * 12,
                this.y + this.h/2,
                dir * 520, vy,
                {
                    damage: 14 + this.damageBonus,
                    color: '#ffee88', trail: '#ffaa44',
                    owner: 'player',
                    w: 12, h: 3, life: 1.2,
                }
            );
            entities.projectiles.push(p);
            // slight recoil
            this.vx -= dir * 30;
        }

        // Move with collisions
        const wasGrounded = this.grounded;
        level.moveX(this, this.vx * dt);
        const hitY = level.moveY(this, this.vy * dt, down);
        if (hitY === 'bottom') {
            if (!wasGrounded && this.vy > 300) {
                particles.dust(this.x + this.w/2, this.y + this.h);
                particles.dust(this.x + this.w/2 - 8, this.y + this.h);
                particles.dust(this.x + this.w/2 + 8, this.y + this.h);
            }
            this.vy = 0;
            this.grounded = true;
            this.jumpsLeft = 2;
            this.coyoteTime = 0.12;
        } else if (hitY === 'top') {
            this.vy = 0;
        } else {
            if (wasGrounded && this.vy > 0) this.coyoteTime = 0.1;
            this.grounded = false;
        }

        // Spike damage
        if (level.touchesSpike(this)) {
            this.takeDamage(15, 0, particles, 'spike');
        }

        // Fall into pit bottom
        if (this.y > level.pixelHeight - 10) {
            this.takeDamage(200, 0, particles, 'pit');
        }
    }

    checkWall(level, dir) {
        const probeX = dir > 0 ? this.x + this.w + 1 : this.x - 1;
        const tx = Math.floor(probeX / 32);
        const top = Math.floor(this.y / 32);
        const bot = Math.floor((this.y + this.h - 1) / 32);
        for (let y = top; y <= bot; y++) {
            if (level.isSolid(tx, y)) return true;
        }
        return false;
    }

    draw(ctx, cameraX, cameraY) {
        if (this.dead) return;
        const sx = Math.floor(this.x - cameraX);
        const sy = Math.floor(this.y - cameraY);

        // Flicker during invuln
        if (this.invuln > 0 && Math.floor(this.animTime * 30) % 2 === 0) return;

        // Body (cloaked)
        const bodyColor = this.hitFlash > 0 ? '#ffffff' : '#e8d8ff';
        const cloakColor = this.hitFlash > 0 ? '#ffffff' : '#3a2a5a';
        const accent = '#c8a8ff';

        // Legs
        const walking = Math.abs(this.vx) > 20 && this.grounded;
        const legPhase = walking ? Math.sin(this.animTime * 18) * 3 : 0;
        ctx.fillStyle = cloakColor;
        ctx.fillRect(sx + 3, sy + this.h - 10 + legPhase, 5, 10);
        ctx.fillRect(sx + this.w - 8, sy + this.h - 10 - legPhase, 5, 10);

        // Torso / cloak
        ctx.fillStyle = cloakColor;
        ctx.fillRect(sx + 2, sy + 10, this.w - 4, this.h - 18);
        // Cloak trim
        ctx.fillStyle = accent;
        ctx.fillRect(sx + 2, sy + 10, this.w - 4, 2);

        // Head
        ctx.fillStyle = bodyColor;
        ctx.fillRect(sx + 5, sy, 10, 10);
        // Glowing eye
        const glow = this.hitFlash > 0 ? '#ffffff' : accent;
        ctx.fillStyle = glow;
        const eyeX = this.facing > 0 ? sx + 11 : sx + 6;
        ctx.fillRect(eyeX, sy + 4, 3, 2);

        // Dash afterimage
        if (this.dashTime > 0) {
            ctx.globalAlpha = 0.4;
            ctx.fillStyle = '#c8a8ff';
            ctx.fillRect(sx - this.dashDir * 8, sy, this.w, this.h);
            ctx.globalAlpha = 0.2;
            ctx.fillRect(sx - this.dashDir * 16, sy, this.w, this.h);
            ctx.globalAlpha = 1;
        }

        // Wall slide indicator
        if (this.wallSlideSide !== 0) {
            ctx.fillStyle = 'rgba(255,255,255,0.4)';
            for (let i = 0; i < 3; i++) {
                const yy = sy + this.h / 2 + i * 6 - 6;
                ctx.fillRect(sx + (this.wallSlideSide > 0 ? this.w : -4), yy, 4, 2);
            }
        }
    }
}
