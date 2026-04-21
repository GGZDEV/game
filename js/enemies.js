import { Projectile } from './weapon.js';
import { aabb, clamp, distSq } from './utils.js';

class Enemy {
    constructor(x, y) {
        this.x = x - 12; this.y = y - 28;
        this.w = 24; this.h = 28;
        this.vx = 0; this.vy = 0;
        this.hp = 20;
        this.maxHp = 20;
        this.damage = 10;
        this.gravity = 1400;
        this.facing = -1;
        this.dead = false;
        this.invuln = 0;
        this.hitFlash = 0;
        this.knockback = 0;
        this.team = 'enemy';
        this.cellsOnDeath = 2;
        this.hpBarTimer = 0;
    }

    hitbox() { return { x: this.x, y: this.y, w: this.w, h: this.h }; }

    takeDamage(amount, dirX, particles, from) {
        if (from === 'enemy') return;
        this.hp -= amount;
        this.invuln = 0.1;
        this.hitFlash = 0.12;
        this.vx += dirX * 240;
        this.vy -= 120;
        this.knockback = 0.1;
        this.hpBarTimer = 2.5;
        particles.blood(this.x + this.w/2, this.y + this.h/2, Math.atan2(0, dirX));
        if (this.hp <= 0) {
            this.dead = true;
            particles.blood(this.x + this.w/2, this.y + this.h/2);
            particles.blood(this.x + this.w/2, this.y + this.h/2);
        }
    }

    applyPhysics(dt, level) {
        this.vy += this.gravity * dt;
        if (this.vy > 620) this.vy = 620;
        level.moveX(this, this.vx * dt);
        const hit = level.moveY(this, this.vy * dt);
        if (hit === 'bottom') { this.vy = 0; this.grounded = true; }
        else if (hit === 'top') { this.vy = 0; }
        else this.grounded = false;
        // Friction
        if (this.grounded) {
            if (this.vx > 0) this.vx = Math.max(0, this.vx - 1000 * dt);
            else if (this.vx < 0) this.vx = Math.min(0, this.vx + 1000 * dt);
        }

        if (level.touchesSpike(this)) this.hp = 0;
        if (this.y > level.pixelHeight) this.dead = true;
    }

    // Damage player on contact for melee enemies
    touchPlayer(player, particles) {
        if (this.dead || player.dead) return;
        if (aabb(this.hitbox(), player.hitbox())) {
            const dir = Math.sign((player.x + player.w/2) - (this.x + this.w/2)) || 1;
            player.takeDamage(this.damage, dir, particles, 'enemy');
        }
    }

    update(dt, level, player, entities, particles) {
        this.invuln = Math.max(0, this.invuln - dt);
        this.hitFlash = Math.max(0, this.hitFlash - dt);
        this.knockback = Math.max(0, this.knockback - dt);
        this.hpBarTimer = Math.max(0, this.hpBarTimer - dt);
    }

    drawHpBar(ctx, cameraX, cameraY) {
        if (this.hpBarTimer <= 0 || this.hp >= this.maxHp) return;
        const sx = Math.floor(this.x - cameraX);
        const sy = Math.floor(this.y - cameraY);
        ctx.fillStyle = '#220011';
        ctx.fillRect(sx, sy - 8, this.w, 4);
        ctx.fillStyle = '#ff3355';
        ctx.fillRect(sx, sy - 8, (this.hp / this.maxHp) * this.w, 4);
    }
}

/* ---------- Grunt: walker that chases and headbutts ---------- */
export class Grunt extends Enemy {
    constructor(x, y) {
        super(x, y);
        this.hp = this.maxHp = 30;
        this.damage = 10;
        this.speed = 90;
        this.cellsOnDeath = 2;
        this.alert = false;
        this.patrolDir = Math.random() < 0.5 ? -1 : 1;
    }

    update(dt, level, player, entities, particles) {
        super.update(dt, level, player, entities, particles);
        const cx = this.x + this.w/2;
        const dx = (player.x + player.w/2) - cx;
        const dist = Math.hypot(dx, (player.y + player.h/2) - (this.y + this.h/2));

        if (!this.alert && dist < 260 && Math.abs(player.y - this.y) < 140) this.alert = true;

        if (this.knockback <= 0) {
            if (this.alert) {
                this.facing = Math.sign(dx) || this.facing;
                // Don't walk off edge
                const aheadX = this.facing > 0 ? this.x + this.w + 4 : this.x - 4;
                const footY = this.y + this.h + 4;
                const safe = level.isSolid(Math.floor(aheadX / 32), Math.floor(footY / 32)) ||
                             level.isPlatform(Math.floor(aheadX / 32), Math.floor(footY / 32));
                if (safe || !this.grounded) this.vx = this.facing * this.speed;
                else this.vx = 0;
            } else {
                this.vx = this.patrolDir * 40;
                this.facing = this.patrolDir;
                const aheadX = this.facing > 0 ? this.x + this.w + 4 : this.x - 4;
                const footY = this.y + this.h + 4;
                const safe = level.isSolid(Math.floor(aheadX / 32), Math.floor(footY / 32)) ||
                             level.isPlatform(Math.floor(aheadX / 32), Math.floor(footY / 32));
                const wall = level.isSolid(Math.floor((this.facing > 0 ? this.x + this.w + 1 : this.x - 1) / 32),
                                           Math.floor((this.y + this.h / 2) / 32));
                if (!safe || wall) this.patrolDir *= -1;
            }
        }

        this.applyPhysics(dt, level);
        this.touchPlayer(player, particles);
    }

    draw(ctx, cameraX, cameraY, time) {
        const sx = Math.floor(this.x - cameraX);
        const sy = Math.floor(this.y - cameraY);
        const body = this.hitFlash > 0 ? '#ffffff' : '#4a3a22';
        const skin = this.hitFlash > 0 ? '#ffffff' : '#8a7c5a';
        const eye = this.alert ? '#ff3355' : '#ffaa44';
        const phase = Math.abs(this.vx) > 20 ? Math.sin(time * 12) * 2 : 0;

        ctx.fillStyle = body;
        ctx.fillRect(sx + 2, sy + 10, this.w - 4, this.h - 14);
        ctx.fillRect(sx + 4, sy + this.h - 6, 6, 6 + phase);
        ctx.fillRect(sx + this.w - 10, sy + this.h - 6, 6, 6 - phase);
        ctx.fillStyle = skin;
        ctx.fillRect(sx + 6, sy, 12, 12);
        // Eye
        ctx.fillStyle = eye;
        const ex = this.facing > 0 ? sx + 14 : sx + 6;
        ctx.fillRect(ex, sy + 5, 2, 3);
        // Weapon (cleaver)
        ctx.fillStyle = '#aabbcc';
        const wx = this.facing > 0 ? sx + this.w : sx - 6;
        ctx.fillRect(wx, sy + 14, 6, 3);
        this.drawHpBar(ctx, cameraX, cameraY);
    }
}

/* ---------- Slasher: fast dasher with wind-up then lunge ---------- */
export class Slasher extends Enemy {
    constructor(x, y) {
        super(x, y);
        this.hp = this.maxHp = 40;
        this.damage = 14;
        this.speed = 140;
        this.cellsOnDeath = 3;
        this.state = 'idle';
        this.timer = 0;
        this.alert = false;
    }

    update(dt, level, player, entities, particles) {
        super.update(dt, level, player, entities, particles);
        this.timer -= dt;
        const cx = this.x + this.w/2;
        const cy = this.y + this.h/2;
        const px = player.x + player.w/2;
        const dx = px - cx;
        const dy = (player.y + player.h/2) - cy;
        const dist = Math.hypot(dx, dy);

        if (!this.alert && dist < 320 && Math.abs(dy) < 120) { this.alert = true; this.state = 'chase'; }

        if (this.knockback <= 0 && !player.dead) {
            if (this.state === 'chase') {
                this.facing = Math.sign(dx) || this.facing;
                this.vx = this.facing * this.speed;
                if (dist < 140 && Math.abs(dy) < 40 && this.grounded) {
                    this.state = 'windup';
                    this.timer = 0.35;
                    this.vx = 0;
                }
            } else if (this.state === 'windup') {
                this.vx *= 0.5;
                if (this.timer <= 0) {
                    this.state = 'dash';
                    this.timer = 0.35;
                    this.vx = this.facing * 480;
                    this.vy = -60;
                    particles.dust(this.x + this.w/2, this.y + this.h);
                }
            } else if (this.state === 'dash') {
                this.invuln = 0.05;
                if (this.timer <= 0) {
                    this.state = 'chase';
                    this.vx *= 0.3;
                }
            } else {
                this.vx = 0;
            }
        }

        this.applyPhysics(dt, level);
        if (this.state === 'dash') this.touchPlayer(player, particles);
        else this.touchPlayer(player, particles);
    }

    draw(ctx, cameraX, cameraY, time) {
        const sx = Math.floor(this.x - cameraX);
        const sy = Math.floor(this.y - cameraY);
        const body = this.hitFlash > 0 ? '#ffffff' : '#2a4050';
        const skin = this.hitFlash > 0 ? '#ffffff' : '#90a0b8';
        const eye = this.state === 'windup' ? '#ffff44' : '#ff3355';
        ctx.fillStyle = body;
        ctx.fillRect(sx + 2, sy + 8, this.w - 4, this.h - 12);
        // Legs
        ctx.fillRect(sx + 3, sy + this.h - 6, 6, 6);
        ctx.fillRect(sx + this.w - 9, sy + this.h - 6, 6, 6);
        // Head
        ctx.fillStyle = skin;
        ctx.fillRect(sx + 6, sy, 12, 10);
        // Horns
        ctx.fillStyle = body;
        ctx.fillRect(sx + 5, sy - 3, 3, 3);
        ctx.fillRect(sx + this.w - 8, sy - 3, 3, 3);
        // Eye
        ctx.fillStyle = eye;
        const ex = this.facing > 0 ? sx + 14 : sx + 6;
        ctx.fillRect(ex, sy + 4, 3, 3);
        // Blades
        ctx.fillStyle = '#ddddee';
        const bx = this.facing > 0 ? sx + this.w : sx - 10;
        ctx.fillRect(bx, sy + 14, 10, 3);
        if (this.state === 'windup') {
            // glow
            const flicker = Math.sin(time * 40) * 0.3 + 0.7;
            ctx.fillStyle = `rgba(255, 255, 80, ${flicker})`;
            ctx.fillRect(bx - 1, sy + 13, 12, 5);
        }
        this.drawHpBar(ctx, cameraX, cameraY);
    }
}

/* ---------- Archer: shoots arrows when player in LOS ---------- */
export class Archer extends Enemy {
    constructor(x, y) {
        super(x, y);
        this.hp = this.maxHp = 22;
        this.damage = 12;
        this.cellsOnDeath = 3;
        this.aimTime = 0;
        this.cooldown = 1.2;
        this.w = 20; this.h = 30;
    }

    hasLOS(level, px, py) {
        const cx = this.x + this.w/2, cy = this.y + this.h/2;
        const dx = px - cx, dy = py - cy;
        const steps = Math.max(1, Math.floor(Math.hypot(dx, dy) / 12));
        for (let i = 1; i < steps; i++) {
            const t = i / steps;
            const tx = Math.floor((cx + dx * t) / 32);
            const ty = Math.floor((cy + dy * t) / 32);
            if (level.isSolid(tx, ty)) return false;
        }
        return true;
    }

    update(dt, level, player, entities, particles) {
        super.update(dt, level, player, entities, particles);
        this.cooldown -= dt;
        const px = player.x + player.w/2;
        const py = player.y + player.h/2;
        const cx = this.x + this.w/2, cy = this.y + this.h/2;
        const dx = px - cx, dy = py - cy;
        const dist = Math.hypot(dx, dy);

        this.facing = Math.sign(dx) || this.facing;
        this.vx = 0;

        if (!player.dead && dist < 420 && this.hasLOS(level, px, py) && Math.abs(dy) < 140) {
            if (this.aimTime === 0 && this.cooldown <= 0) this.aimTime = 0.001;
            if (this.aimTime > 0) {
                this.aimTime += dt;
                if (this.aimTime > 0.6) {
                    // Fire
                    const angle = Math.atan2(dy, dx);
                    const speed = 360;
                    const p = new Projectile(
                        cx + Math.cos(angle) * 16,
                        cy + Math.sin(angle) * 16,
                        Math.cos(angle) * speed,
                        Math.sin(angle) * speed,
                        {
                            damage: this.damage,
                            owner: 'enemy',
                            color: '#ff9944', trail: '#aa4422',
                            w: 12, h: 3, life: 1.5,
                        }
                    );
                    entities.projectiles.push(p);
                    this.aimTime = 0;
                    this.cooldown = 1.6;
                }
            }
        } else {
            this.aimTime = 0;
        }

        this.applyPhysics(dt, level);
    }

    draw(ctx, cameraX, cameraY, time) {
        const sx = Math.floor(this.x - cameraX);
        const sy = Math.floor(this.y - cameraY);
        const body = this.hitFlash > 0 ? '#ffffff' : '#3a3028';
        const skin = this.hitFlash > 0 ? '#ffffff' : '#b09a72';
        // Body
        ctx.fillStyle = body;
        ctx.fillRect(sx + 3, sy + 10, this.w - 6, this.h - 14);
        ctx.fillRect(sx + 4, sy + this.h - 6, 5, 6);
        ctx.fillRect(sx + this.w - 9, sy + this.h - 6, 5, 6);
        // Head/hood
        ctx.fillStyle = body;
        ctx.fillRect(sx + 4, sy, 12, 8);
        ctx.fillStyle = skin;
        ctx.fillRect(sx + 6, sy + 4, 8, 6);
        // Bow line
        ctx.strokeStyle = '#886633';
        ctx.lineWidth = 2;
        const bx = this.facing > 0 ? sx + this.w : sx;
        ctx.beginPath();
        ctx.moveTo(bx, sy + 10);
        ctx.quadraticCurveTo(bx + this.facing * 10, sy + 16, bx, sy + 22);
        ctx.stroke();
        // Aim indicator
        if (this.aimTime > 0) {
            const t = Math.min(1, this.aimTime / 0.6);
            ctx.strokeStyle = `rgba(255, 60, 60, ${t})`;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(sx + this.w/2, sy + this.h/2);
            ctx.lineTo(sx + this.w/2 + this.facing * 200, sy + this.h/2);
            ctx.stroke();
        }
        this.drawHpBar(ctx, cameraX, cameraY);
    }
}

/* ---------- Bat: floats and swoops ---------- */
export class Bat extends Enemy {
    constructor(x, y) {
        super(x, y);
        this.w = 22; this.h = 16;
        this.hp = this.maxHp = 14;
        this.damage = 8;
        this.cellsOnDeath = 1;
        this.gravity = 0;
        this.baseY = this.y;
        this.flyT = Math.random() * Math.PI * 2;
        this.state = 'idle';
        this.swoopCD = 1.5;
    }

    update(dt, level, player, entities, particles) {
        super.update(dt, level, player, entities, particles);
        this.flyT += dt;
        this.swoopCD -= dt;
        const cx = this.x + this.w/2;
        const cy = this.y + this.h/2;
        const px = player.x + player.w/2;
        const py = player.y + player.h/2;
        const dx = px - cx, dy = py - cy;
        const dist = Math.hypot(dx, dy);

        if (this.knockback <= 0) {
            if (this.state === 'swoop') {
                // keep velocity, end swoop when cooldown resets
                if (this.swoopCD <= 0) {
                    this.state = 'idle';
                    this.swoopCD = 2.5;
                }
            } else {
                if (dist < 220 && !player.dead && this.swoopCD <= 0) {
                    this.state = 'swoop';
                    this.vx = Math.sign(dx) * 220;
                    this.vy = Math.sign(dy) * 180;
                    this.swoopCD = 0.5;
                } else {
                    // Hover towards player slowly
                    this.vx = clamp(dx * 0.6, -70, 70);
                    this.vy = Math.sin(this.flyT * 3) * 40 + clamp(dy * 0.3, -40, 40);
                    this.facing = Math.sign(dx) || this.facing;
                }
            }
        }

        // Simple non-solid movement with tile collision (no gravity)
        level.moveX(this, this.vx * dt);
        level.moveY(this, this.vy * dt);
        if (level.touchesSpike(this)) this.hp = 0;
        this.touchPlayer(player, particles);
    }

    draw(ctx, cameraX, cameraY, time) {
        const sx = Math.floor(this.x - cameraX);
        const sy = Math.floor(this.y - cameraY);
        const body = this.hitFlash > 0 ? '#ffffff' : '#2a1a2a';
        const wing = this.hitFlash > 0 ? '#ffffff' : '#4a2a4a';
        const flap = Math.sin(time * 22) * 4;

        // Wings
        ctx.fillStyle = wing;
        ctx.beginPath();
        ctx.moveTo(sx + 2, sy + 8);
        ctx.lineTo(sx - 4, sy + 4 - flap);
        ctx.lineTo(sx + 2, sy + 12);
        ctx.closePath();
        ctx.fill();
        ctx.beginPath();
        ctx.moveTo(sx + this.w - 2, sy + 8);
        ctx.lineTo(sx + this.w + 4, sy + 4 - flap);
        ctx.lineTo(sx + this.w - 2, sy + 12);
        ctx.closePath();
        ctx.fill();
        // Body
        ctx.fillStyle = body;
        ctx.fillRect(sx + 4, sy + 4, this.w - 8, this.h - 6);
        // Eyes
        ctx.fillStyle = '#ff4466';
        ctx.fillRect(sx + 7, sy + 7, 2, 2);
        ctx.fillRect(sx + this.w - 9, sy + 7, 2, 2);
        // Fangs
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(sx + 8, sy + 11, 2, 3);
        ctx.fillRect(sx + this.w - 10, sy + 11, 2, 3);
        this.drawHpBar(ctx, cameraX, cameraY);
    }
}

export function makeEnemy(type, x, y) {
    switch (type) {
        case 'grunt':   return new Grunt(x, y);
        case 'slasher': return new Slasher(x, y);
        case 'archer':  return new Archer(x, y);
        case 'bat':     return new Bat(x, y);
        default: return new Grunt(x, y);
    }
}
