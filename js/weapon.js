import { aabb, rand } from './utils.js';

export class Projectile {
    constructor(x, y, vx, vy, opts = {}) {
        this.x = x; this.y = y;
        this.vx = vx; this.vy = vy;
        this.w = opts.w ?? 10;
        this.h = opts.h ?? 4;
        this.life = opts.life ?? 1.5;
        this.damage = opts.damage ?? 6;
        this.owner = opts.owner ?? 'player'; // 'player' or 'enemy'
        this.color = opts.color ?? '#ffee88';
        this.trail = opts.trail ?? '#ffaa44';
        this.gravity = opts.gravity ?? 0;
        this.dead = false;
        this.rot = Math.atan2(vy, vx);
        this.trailPts = [];
    }

    update(dt, level, targets, particles) {
        this.life -= dt;
        if (this.life <= 0) { this.dead = true; return; }

        this.trailPts.push({ x: this.x, y: this.y, life: 0.15 });
        for (let i = this.trailPts.length - 1; i >= 0; i--) {
            this.trailPts[i].life -= dt;
            if (this.trailPts[i].life <= 0) this.trailPts.splice(i, 1);
        }

        this.x += this.vx * dt;
        this.y += this.vy * dt;
        this.vy += this.gravity * dt;
        this.rot = Math.atan2(this.vy, this.vx);

        // Tile collision — kill if any overlapped tile is solid
        const body = { x: this.x - this.w/2, y: this.y - this.h/2, w: this.w, h: this.h };
        const left = Math.floor(body.x / 32);
        const right = Math.floor((body.x + body.w - 1) / 32);
        const top = Math.floor(body.y / 32);
        const bottom = Math.floor((body.y + body.h - 1) / 32);
        for (let ty = top; ty <= bottom; ty++) {
            for (let tx = left; tx <= right; tx++) {
                if (level.isSolid(tx, ty)) {
                    this.dead = true;
                    particles.hitSpark(this.x, this.y);
                    return;
                }
            }
        }

        // Target hits
        for (const t of targets) {
            if (t.dead || t.invuln > 0) continue;
            if (aabb(body, t.hitbox())) {
                t.takeDamage(this.damage, Math.sign(this.vx) || 1, particles, this.owner);
                this.dead = true;
                particles.hitSpark(this.x, this.y);
                return;
            }
        }
    }

    draw(ctx, cameraX, cameraY) {
        // Trail
        for (const t of this.trailPts) {
            const a = Math.max(0, t.life / 0.15) * 0.5;
            ctx.globalAlpha = a;
            ctx.fillStyle = this.trail;
            ctx.fillRect(
                Math.floor(t.x - cameraX) - 1,
                Math.floor(t.y - cameraY) - 1,
                3, 3
            );
        }
        ctx.globalAlpha = 1;
        ctx.save();
        ctx.translate(Math.floor(this.x - cameraX), Math.floor(this.y - cameraY));
        ctx.rotate(this.rot);
        ctx.fillStyle = this.color;
        ctx.fillRect(-this.w / 2, -this.h / 2, this.w, this.h);
        ctx.fillStyle = '#fff';
        ctx.fillRect(this.w / 2 - 3, -1, 3, 2);
        ctx.restore();
    }
}

export class SwordSwing {
    constructor(owner, dir, opts = {}) {
        this.owner = owner;
        this.dir = dir; // 1 or -1
        this.time = 0;
        this.duration = opts.duration ?? 0.22;
        this.damage = opts.damage ?? 10;
        this.reach = opts.reach ?? 50;
        this.vReach = opts.vReach ?? 26;
        this.hit = new Set();
        this.dead = false;
    }

    hitbox() {
        const cx = this.owner.x + this.owner.w / 2;
        const cy = this.owner.y + this.owner.h / 2;
        const hx = this.dir > 0 ? cx : cx - this.reach;
        return { x: hx, y: cy - this.vReach, w: this.reach, h: this.vReach * 2 };
    }

    update(dt, targets, particles) {
        this.time += dt;
        if (this.time >= this.duration) { this.dead = true; return; }
        const box = this.hitbox();
        for (const t of targets) {
            if (t.dead || this.hit.has(t)) continue;
            if (aabb(box, t.hitbox())) {
                this.hit.add(t);
                t.takeDamage(this.damage, this.dir, particles, this.owner.team ?? 'player');
                // Micro knockback on owner for feel
                this.owner.vx -= this.dir * 30;
            }
        }
    }

    draw(ctx, cameraX, cameraY) {
        const p = this.time / this.duration;
        const alpha = Math.sin(p * Math.PI);
        const cx = this.owner.x + this.owner.w / 2 - cameraX;
        const cy = this.owner.y + this.owner.h / 2 - cameraY;
        ctx.save();
        ctx.translate(cx, cy);
        ctx.scale(this.dir, 1);
        const arcStart = -Math.PI / 2.2;
        const arcEnd = Math.PI / 2.2;
        const arcPos = arcStart + (arcEnd - arcStart) * p;
        ctx.strokeStyle = `rgba(255, 255, 255, ${alpha})`;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(0, 0, this.reach * 0.8, arcStart, arcPos);
        ctx.stroke();
        ctx.strokeStyle = `rgba(200, 200, 255, ${alpha * 0.5})`;
        ctx.lineWidth = 8;
        ctx.beginPath();
        ctx.arc(0, 0, this.reach * 0.8, arcStart, arcPos);
        ctx.stroke();

        // Blade line
        ctx.strokeStyle = `rgba(255, 255, 255, ${alpha})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(Math.cos(arcPos) * this.reach, Math.sin(arcPos) * this.reach);
        ctx.stroke();
        ctx.restore();
    }
}
