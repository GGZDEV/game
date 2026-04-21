import { rand } from './utils.js';

export class ParticleSystem {
    constructor() { this.parts = []; }

    spawn(x, y, opts = {}) {
        const count = opts.count ?? 8;
        for (let i = 0; i < count; i++) {
            const angle = opts.angle !== undefined ? opts.angle + rand(-opts.spread ?? 0, opts.spread ?? 0) : rand(0, Math.PI * 2);
            const speed = rand(opts.minSpeed ?? 40, opts.maxSpeed ?? 180);
            this.parts.push({
                x, y,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                life: rand(opts.minLife ?? 0.2, opts.maxLife ?? 0.6),
                maxLife: 0,
                size: rand(opts.minSize ?? 1, opts.maxSize ?? 3),
                color: opts.color ?? '#fff',
                gravity: opts.gravity ?? 400,
                drag: opts.drag ?? 0.92,
            });
            const last = this.parts[this.parts.length - 1];
            last.maxLife = last.life;
        }
    }

    blood(x, y, dir = 0) {
        this.spawn(x, y, {
            count: 10,
            angle: dir,
            spread: Math.PI * 0.8,
            minSpeed: 60, maxSpeed: 240,
            minLife: 0.3, maxLife: 0.7,
            minSize: 1.5, maxSize: 3,
            color: '#d22840',
            gravity: 500,
        });
    }

    hitSpark(x, y) {
        this.spawn(x, y, {
            count: 6,
            minSpeed: 100, maxSpeed: 260,
            minLife: 0.1, maxLife: 0.25,
            minSize: 1, maxSize: 2,
            color: '#ffee88',
            gravity: 0,
        });
    }

    dust(x, y) {
        this.spawn(x, y, {
            count: 4,
            angle: -Math.PI / 2,
            spread: Math.PI / 2,
            minSpeed: 20, maxSpeed: 60,
            minLife: 0.2, maxLife: 0.4,
            minSize: 1.5, maxSize: 3,
            color: '#887766',
            gravity: -100,
            drag: 0.85,
        });
    }

    pickup(x, y, color = '#ffcc44') {
        this.spawn(x, y, {
            count: 14,
            minSpeed: 80, maxSpeed: 200,
            minLife: 0.4, maxLife: 0.9,
            minSize: 1, maxSize: 2.5,
            color,
            gravity: 0,
            drag: 0.88,
        });
    }

    update(dt) {
        for (let i = this.parts.length - 1; i >= 0; i--) {
            const p = this.parts[i];
            p.life -= dt;
            if (p.life <= 0) { this.parts.splice(i, 1); continue; }
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.vy += p.gravity * dt;
            p.vx *= p.drag;
            p.vy *= p.drag;
        }
    }

    draw(ctx, cameraX, cameraY) {
        for (const p of this.parts) {
            const a = Math.max(0, p.life / p.maxLife);
            ctx.globalAlpha = a;
            ctx.fillStyle = p.color;
            const sx = Math.floor(p.x - cameraX);
            const sy = Math.floor(p.y - cameraY);
            ctx.fillRect(sx - p.size / 2, sy - p.size / 2, p.size, p.size);
        }
        ctx.globalAlpha = 1;
    }
}
