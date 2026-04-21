import { randInt, rand, chance, choice } from './utils.js';

export const TILE = 32;

export const T_EMPTY = 0;
export const T_SOLID = 1;
export const T_PLATFORM = 2; // one-way
export const T_SPIKE = 3;
export const T_DECO = 4;     // background pillar/torch (non-solid)

export const BIOMES = [
    {
        name: 'Prison des Âmes',
        flavor: 'Des murs froids et des gardes endormis...',
        bg: '#100f1a',
        fog: '#1a1830',
        wall: '#3a3450',
        wallTop: '#554a78',
        wallShadow: '#221d33',
        accent: '#c8a8ff',
        platform: '#6a5a96',
        enemies: ['grunt', 'grunt', 'archer', 'bat'],
        enemyCount: [4, 7],
    },
    {
        name: 'Égouts Toxiques',
        flavor: 'Il y a quelque chose qui bouge dans la vase...',
        bg: '#0c120c',
        fog: '#141e14',
        wall: '#2a3a28',
        wallTop: '#4a6044',
        wallShadow: '#1a241a',
        accent: '#b0ff70',
        platform: '#4a6044',
        enemies: ['grunt', 'archer', 'archer', 'bat', 'slasher'],
        enemyCount: [5, 9],
    },
    {
        name: 'Remparts Oubliés',
        flavor: 'Le vent hurle entre les créneaux fissurés...',
        bg: '#140e10',
        fog: '#241822',
        wall: '#4a2a3a',
        wallTop: '#6a4058',
        wallShadow: '#2a1522',
        accent: '#ff88aa',
        platform: '#6a4058',
        enemies: ['slasher', 'archer', 'bat', 'bat'],
        enemyCount: [6, 10],
    },
    {
        name: 'Donjon du Roi',
        flavor: 'Une présence ancienne attend...',
        bg: '#180810',
        fog: '#281020',
        wall: '#5a1830',
        wallTop: '#8a2848',
        wallShadow: '#2a0815',
        accent: '#ffcc44',
        platform: '#8a2848',
        enemies: ['slasher', 'slasher', 'archer', 'bat'],
        enemyCount: [7, 11],
        isBoss: true,
    },
];

export class Level {
    constructor(biomeIndex = 0, floorNumber = 1) {
        this.biomeIndex = biomeIndex;
        this.biome = BIOMES[biomeIndex];
        this.floorNumber = floorNumber;
        this.w = randInt(60, 90);
        this.h = 22;
        this.tiles = new Uint8Array(this.w * this.h);
        this.spawns = { enemies: [], cells: [], exit: null, start: null };
        this.generate();
    }

    idx(x, y) { return y * this.w + x; }
    get(x, y) {
        if (x < 0 || y < 0 || x >= this.w || y >= this.h) return T_SOLID;
        return this.tiles[this.idx(x, y)];
    }
    set(x, y, v) {
        if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
        this.tiles[this.idx(x, y)] = v;
    }
    isSolid(x, y) { return this.get(x, y) === T_SOLID; }
    isPlatform(x, y) { return this.get(x, y) === T_PLATFORM; }
    isSpike(x, y) { return this.get(x, y) === T_SPIKE; }

    generate() {
        const { w, h } = this;
        // Fill everything empty
        for (let i = 0; i < this.tiles.length; i++) this.tiles[i] = T_EMPTY;

        // Border walls
        for (let x = 0; x < w; x++) {
            this.set(x, 0, T_SOLID);
            this.set(x, h - 1, T_SOLID);
            this.set(x, h - 2, T_SOLID);
        }
        for (let y = 0; y < h; y++) {
            this.set(0, y, T_SOLID);
            this.set(w - 1, y, T_SOLID);
        }

        // Create a wavy floor with pits
        let floorY = h - 3;
        for (let x = 1; x < w - 1; x++) {
            // Random pit
            if (x > 5 && x < w - 6 && chance(0.04)) {
                const pitWidth = randInt(2, 4);
                for (let i = 0; i < pitWidth && x + i < w - 2; i++) {
                    // leave gap
                }
                x += pitWidth - 1;
                continue;
            }
            this.set(x, floorY, T_SOLID);
            if (chance(0.15) && floorY < h - 3) floorY++;
            if (chance(0.15) && floorY > h - 5) floorY--;
        }

        // Add spikes in some pits (small chance)
        for (let x = 2; x < w - 2; x++) {
            if (!this.isSolid(x, h - 3) && !this.isSolid(x, h - 4)) {
                if (chance(0.35)) this.set(x, h - 3, T_SPIKE);
            }
        }

        // Platforms at varying heights
        const numPlatforms = Math.floor(w * 0.35);
        for (let i = 0; i < numPlatforms; i++) {
            const px = randInt(3, w - 5);
            const py = randInt(4, h - 6);
            const len = randInt(3, 7);
            // Don't overlap solids
            let canPlace = true;
            for (let j = 0; j < len; j++) {
                if (this.get(px + j, py) !== T_EMPTY) { canPlace = false; break; }
                if (this.get(px + j, py - 1) === T_SOLID) { canPlace = false; break; }
            }
            if (canPlace) {
                for (let j = 0; j < len; j++) this.set(px + j, py, T_PLATFORM);
            }
        }

        // Add some high solid ledges
        const numLedges = Math.floor(w * 0.08);
        for (let i = 0; i < numLedges; i++) {
            const lx = randInt(3, w - 8);
            const ly = randInt(3, h - 8);
            const lw = randInt(2, 5);
            const lh = randInt(1, 2);
            for (let dx = 0; dx < lw; dx++) {
                for (let dy = 0; dy < lh; dy++) {
                    this.set(lx + dx, ly + dy, T_SOLID);
                }
            }
        }

        // Decorative torches on walls
        for (let x = 2; x < w - 2; x += randInt(5, 10)) {
            for (let y = 1; y < h - 3; y++) {
                if (!this.isSolid(x, y) && this.isSolid(x, y + 1) && chance(0.4)) {
                    // Mark as deco - we'll draw a torch here
                    this.set(x, y, T_DECO);
                    break;
                }
            }
        }

        // Start position (left side, on floor)
        for (let x = 2; x < 10; x++) {
            for (let y = 1; y < h - 1; y++) {
                if (!this.isSolid(x, y) && this.isSolid(x, y + 1)) {
                    this.spawns.start = { x: x * TILE + TILE / 2, y: y * TILE };
                    break;
                }
            }
            if (this.spawns.start) break;
        }
        if (!this.spawns.start) this.spawns.start = { x: 3 * TILE, y: (h - 4) * TILE };

        // Exit door (right side)
        for (let x = w - 3; x > w - 12; x--) {
            for (let y = 1; y < h - 1; y++) {
                if (!this.isSolid(x, y) && !this.isSolid(x, y - 1) && this.isSolid(x, y + 1)) {
                    this.spawns.exit = { x: x * TILE + TILE / 2, y: y * TILE };
                    break;
                }
            }
            if (this.spawns.exit) break;
        }
        if (!this.spawns.exit) this.spawns.exit = { x: (w - 3) * TILE, y: (h - 4) * TILE };

        // Enemies on floors/platforms
        const [minE, maxE] = this.biome.enemyCount;
        const numEnemies = randInt(minE, maxE);
        let attempts = 0;
        while (this.spawns.enemies.length < numEnemies && attempts < 200) {
            attempts++;
            const ex = randInt(12, w - 4);
            const ey = randInt(2, h - 3);
            if (this.isSolid(ex, ey) || this.isSpike(ex, ey)) continue;
            // Needs solid ground under it (or platform, for grunt/archer). Bats can spawn anywhere.
            const type = choice(this.biome.enemies);
            const worldX = ex * TILE + TILE / 2;
            const worldY = ey * TILE + TILE;
            if (type === 'bat') {
                // needs clear space
                if (!this.isSolid(ex, ey - 1)) {
                    this.spawns.enemies.push({ type, x: worldX, y: worldY - TILE / 2 });
                }
            } else {
                if (this.isSolid(ex, ey + 1) || this.isPlatform(ex, ey + 1)) {
                    // keep distance from start
                    if (worldX > (this.spawns.start.x + 200)) {
                        this.spawns.enemies.push({ type, x: worldX, y: worldY });
                    }
                }
            }
        }

        // Cell pickups scattered
        const numCells = randInt(3, 6);
        attempts = 0;
        while (this.spawns.cells.length < numCells && attempts < 100) {
            attempts++;
            const cx = randInt(6, w - 4);
            const cy = randInt(2, h - 3);
            if (this.isSolid(cx, cy) || this.isSpike(cx, cy)) continue;
            if (this.isSolid(cx, cy + 1) || this.isPlatform(cx, cy + 1)) {
                this.spawns.cells.push({ x: cx * TILE + TILE / 2, y: cy * TILE + TILE - 8 });
            }
        }

        this.pixelWidth = this.w * TILE;
        this.pixelHeight = this.h * TILE;
    }

    /** Collide a rect with solid tiles; returns resolved {x, y, hitX, hitY}. */
    moveX(body, dx) {
        body.x += dx;
        const left = Math.floor(body.x / TILE);
        const right = Math.floor((body.x + body.w - 0.01) / TILE);
        const top = Math.floor(body.y / TILE);
        const bottom = Math.floor((body.y + body.h - 0.01) / TILE);
        let hit = false;
        for (let y = top; y <= bottom; y++) {
            for (let x = left; x <= right; x++) {
                if (this.isSolid(x, y)) {
                    if (dx > 0) body.x = x * TILE - body.w;
                    else if (dx < 0) body.x = (x + 1) * TILE;
                    hit = true;
                }
            }
        }
        return hit;
    }

    moveY(body, dy, allowDrop = false) {
        const prevBottom = body.y + body.h;
        body.y += dy;
        const left = Math.floor(body.x / TILE);
        const right = Math.floor((body.x + body.w - 0.01) / TILE);
        const top = Math.floor(body.y / TILE);
        const bottom = Math.floor((body.y + body.h - 0.01) / TILE);
        let hit = false;
        for (let y = top; y <= bottom; y++) {
            for (let x = left; x <= right; x++) {
                if (this.isSolid(x, y)) {
                    if (dy > 0) { body.y = y * TILE - body.h; hit = 'bottom'; }
                    else if (dy < 0) { body.y = (y + 1) * TILE; hit = 'top'; }
                } else if (this.isPlatform(x, y) && dy > 0 && !allowDrop) {
                    const tileTop = y * TILE;
                    if (prevBottom <= tileTop + 2) {
                        body.y = tileTop - body.h;
                        hit = 'bottom';
                    }
                }
            }
        }
        return hit;
    }

    touchesSpike(body) {
        const left = Math.floor(body.x / TILE);
        const right = Math.floor((body.x + body.w - 0.01) / TILE);
        const top = Math.floor(body.y / TILE);
        const bottom = Math.floor((body.y + body.h - 0.01) / TILE);
        for (let y = top; y <= bottom; y++) {
            for (let x = left; x <= right; x++) {
                if (this.isSpike(x, y)) return true;
            }
        }
        return false;
    }

    draw(ctx, cameraX, cameraY, time) {
        const b = this.biome;

        // Background gradient
        const grd = ctx.createLinearGradient(0, 0, 0, ctx.canvas.height);
        grd.addColorStop(0, b.bg);
        grd.addColorStop(1, b.fog);
        ctx.fillStyle = grd;
        ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);

        // Parallax pillars in background
        ctx.fillStyle = b.wallShadow;
        const plx = cameraX * 0.3;
        for (let i = 0; i < 30; i++) {
            const px = (i * 140 - plx) % (this.pixelWidth + 200);
            const ppx = px < 0 ? px + this.pixelWidth + 200 : px;
            const ph = 160 + (i * 37) % 120;
            ctx.fillRect(Math.floor(ppx), ctx.canvas.height - ph - 100, 24, ph);
        }

        // Draw tiles visible in viewport
        const startX = Math.max(0, Math.floor(cameraX / TILE));
        const endX = Math.min(this.w, Math.ceil((cameraX + ctx.canvas.width) / TILE) + 1);
        const startY = Math.max(0, Math.floor(cameraY / TILE));
        const endY = Math.min(this.h, Math.ceil((cameraY + ctx.canvas.height) / TILE) + 1);

        for (let y = startY; y < endY; y++) {
            for (let x = startX; x < endX; x++) {
                const t = this.get(x, y);
                if (t === T_EMPTY) continue;
                const sx = x * TILE - cameraX;
                const sy = y * TILE - cameraY;
                if (t === T_SOLID) {
                    ctx.fillStyle = b.wall;
                    ctx.fillRect(sx, sy, TILE, TILE);
                    // top highlight if empty above
                    if (!this.isSolid(x, y - 1)) {
                        ctx.fillStyle = b.wallTop;
                        ctx.fillRect(sx, sy, TILE, 4);
                    }
                    // side shade
                    ctx.fillStyle = b.wallShadow;
                    ctx.fillRect(sx, sy + TILE - 3, TILE, 3);
                    // detail dot
                    if ((x * 31 + y * 17) % 5 === 0) {
                        ctx.fillStyle = b.wallTop;
                        ctx.fillRect(sx + 6, sy + 10, 2, 2);
                        ctx.fillRect(sx + 20, sy + 20, 2, 2);
                    }
                } else if (t === T_PLATFORM) {
                    ctx.fillStyle = b.platform;
                    ctx.fillRect(sx, sy, TILE, 6);
                    ctx.fillStyle = b.wallShadow;
                    ctx.fillRect(sx, sy + 6, TILE, 2);
                } else if (t === T_SPIKE) {
                    ctx.fillStyle = '#cccccc';
                    for (let i = 0; i < 4; i++) {
                        const px = sx + i * (TILE / 4);
                        ctx.beginPath();
                        ctx.moveTo(px, sy + TILE);
                        ctx.lineTo(px + TILE / 8, sy + TILE / 2);
                        ctx.lineTo(px + TILE / 4, sy + TILE);
                        ctx.closePath();
                        ctx.fill();
                    }
                    ctx.fillStyle = '#555';
                    ctx.fillRect(sx, sy + TILE - 3, TILE, 3);
                } else if (t === T_DECO) {
                    // Torch
                    ctx.fillStyle = '#3a2a20';
                    ctx.fillRect(sx + TILE / 2 - 2, sy + 10, 4, 16);
                    const flicker = Math.sin(time * 14 + x * 3) * 0.2 + 0.8;
                    ctx.fillStyle = `rgba(255, 180, 60, ${flicker})`;
                    ctx.beginPath();
                    ctx.arc(sx + TILE / 2, sy + 8, 6, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.fillStyle = `rgba(255, 240, 180, ${flicker * 0.9})`;
                    ctx.beginPath();
                    ctx.arc(sx + TILE / 2, sy + 8, 3, 0, Math.PI * 2);
                    ctx.fill();
                    // Light glow
                    const glowR = 80 + Math.sin(time * 10 + x) * 10;
                    const glow = ctx.createRadialGradient(sx + TILE/2, sy + 8, 4, sx + TILE/2, sy + 8, glowR);
                    glow.addColorStop(0, 'rgba(255,180,80,0.25)');
                    glow.addColorStop(1, 'rgba(255,180,80,0)');
                    ctx.fillStyle = glow;
                    ctx.fillRect(sx - glowR, sy - glowR, glowR * 2, glowR * 2);
                }
            }
        }

        // Draw exit door
        if (this.spawns.exit) {
            const ex = this.spawns.exit.x - cameraX;
            const ey = this.spawns.exit.y - cameraY;
            ctx.fillStyle = '#1a0a14';
            ctx.fillRect(ex - 20, ey - 56, 40, 56);
            ctx.fillStyle = b.accent;
            ctx.fillRect(ex - 22, ey - 58, 44, 4);
            ctx.fillRect(ex - 22, ey - 58, 4, 60);
            ctx.fillRect(ex + 18, ey - 58, 4, 60);
            // glyph
            const pulse = Math.sin(time * 4) * 0.3 + 0.7;
            ctx.fillStyle = `rgba(255, 220, 120, ${pulse})`;
            ctx.fillRect(ex - 3, ey - 38, 6, 6);
            ctx.fillRect(ex - 6, ey - 32, 12, 2);
            ctx.fillRect(ex - 3, ey - 28, 6, 6);
        }
    }
}
