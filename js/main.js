import { inputFrameStart, wasPressed, isDown } from './input.js';
import { Level, BIOMES, TILE } from './level.js';
import { Player } from './player.js';
import { makeEnemy } from './enemies.js';
import { ParticleSystem } from './particles.js';
import { loadMeta, saveMeta, UPGRADES, upgradeCost, canBuy, buyUpgrade } from './meta.js';
import { clamp, aabb, rand } from './utils.js';

const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
ctx.imageSmoothingEnabled = false;

const hud = {
    root: document.getElementById('hud'),
    hpFill: document.querySelector('.hp-fill'),
    hpText: document.querySelector('.hp-text'),
    flaskCount: document.querySelector('.flask-count'),
    cellsCount: document.querySelector('.cells-count'),
    biomeName: document.querySelector('.biome-name'),
    depth: document.querySelector('.depth'),
};

const startScreen = document.getElementById('start-screen');
const deathScreen = document.getElementById('death-screen');
const victoryScreen = document.getElementById('victory-screen');
const transition = document.getElementById('biome-transition');
const biomeTitle = document.getElementById('biome-title');
const biomeFlavor = document.getElementById('biome-flavor');
const metaCellsEl = document.getElementById('meta-cells');
const deathCells = document.getElementById('death-cells');
const deathKills = document.getElementById('death-kills');
const deathDepth = document.getElementById('death-depth');
const upgradeList = document.getElementById('upgrade-list');

let meta = loadMeta();

const state = {
    screen: 'start',
    level: null,
    player: null,
    entities: {
        enemies: [],
        projectiles: [],
        swings: [],
        pickups: [],
    },
    particles: new ParticleSystem(),
    camera: { x: 0, y: 0, shake: 0 },
    time: 0,
    floorNumber: 1,
    biomeIndex: 0,
    hitStop: 0,
    totalKills: 0,
};

function refreshMetaDisplay() {
    metaCellsEl.textContent = `◆ ${meta.cells} cellules accumulées`;
    upgradeList.innerHTML = '';
    for (const u of UPGRADES) {
        const lvl = meta.upgrades[u.key];
        const btn = document.createElement('button');
        btn.className = 'upgrade-btn';
        const maxed = lvl >= u.max;
        const cost = maxed ? 0 : upgradeCost(u, lvl);
        const canAfford = !maxed && meta.cells >= cost;
        btn.innerHTML = `
            <span>
                <strong style="color:#c8a8ff">${u.name}</strong> Niv ${lvl}/${u.max}<br>
                <span style="color:#aaa;font-size:11px">${u.desc}</span>
            </span>
            <span class="upgrade-cost">${maxed ? 'MAX' : '◆ ' + cost}</span>
        `;
        btn.disabled = !canAfford;
        btn.addEventListener('click', () => {
            if (buyUpgrade(meta, u.key)) {
                refreshMetaDisplay();
                metaCellsEl.textContent = `◆ ${meta.cells} cellules accumulées`;
                deathCells.textContent = meta.cells;
            }
        });
        upgradeList.appendChild(btn);
    }
}
refreshMetaDisplay();

function startRun() {
    startScreen.classList.add('hidden');
    deathScreen.classList.add('hidden');
    victoryScreen.classList.add('hidden');
    hud.root.classList.remove('hidden');

    state.biomeIndex = 0;
    state.floorNumber = 1;
    state.totalKills = 0;

    beginLevel(state.biomeIndex, state.floorNumber);
}

function beginLevel(biomeIndex, floorNumber) {
    state.biomeIndex = biomeIndex;
    state.floorNumber = floorNumber;
    state.level = new Level(biomeIndex, floorNumber);
    const level = state.level;

    // If this is the first floor overall, make the player; otherwise keep stats carry-over
    if (!state.player || state.player.dead) {
        state.player = new Player(level.spawns.start.x, level.spawns.start.y, meta);
        state.player.cellsGained = 0;
    } else {
        state.player.x = level.spawns.start.x;
        state.player.y = level.spawns.start.y;
        state.player.vx = 0; state.player.vy = 0;
        // top up flasks partially between floors
        state.player.flasks = Math.min(state.player.flaskMax, state.player.flasks + 1);
    }
    state.player.screen = 'play';

    state.entities.enemies = [];
    state.entities.projectiles = [];
    state.entities.swings = [];
    state.entities.pickups = [];

    for (const spec of level.spawns.enemies) {
        state.entities.enemies.push(makeEnemy(spec.type, spec.x, spec.y));
    }
    for (const c of level.spawns.cells) {
        state.entities.pickups.push({ kind: 'cell', x: c.x, y: c.y, vy: -rand(80, 150), vx: rand(-30, 30), collected: false, life: 30, bounced: false });
    }

    state.camera.x = state.player.x - canvas.width / 2;
    state.camera.y = state.player.y - canvas.height / 2;

    // Biome transition banner
    biomeTitle.textContent = `${level.biome.name}`;
    biomeFlavor.textContent = `Étage ${floorNumber} — ${level.biome.flavor}`;
    transition.classList.remove('hidden');
    transition.style.opacity = '1';
    setTimeout(() => {
        transition.style.opacity = '0';
        setTimeout(() => transition.classList.add('hidden'), 500);
    }, 1400);

    state.screen = 'play';
}

function die() {
    // Bank cells
    meta.cells += state.player.cellsGained;
    saveMeta(meta);

    deathDepth.textContent = `${state.level.biome.name} — ${state.floorNumber}`;
    deathKills.textContent = state.player.kills;
    deathCells.textContent = meta.cells;
    refreshMetaDisplay();

    deathScreen.classList.remove('hidden');
    hud.root.classList.add('hidden');
    state.screen = 'death';
}

function victory() {
    meta.cells += state.player.cellsGained;
    saveMeta(meta);
    victoryScreen.classList.remove('hidden');
    hud.root.classList.add('hidden');
    state.screen = 'victory';
}

function nextFloor() {
    // Advance floor within biome or move to next biome
    const maxFloorsPerBiome = 2;
    let nextBiome = state.biomeIndex;
    let nextFloor = state.floorNumber + 1;
    if ((state.floorNumber) >= maxFloorsPerBiome) {
        nextBiome++;
        nextFloor = 1;
        if (nextBiome >= BIOMES.length) {
            victory();
            return;
        }
    }
    beginLevel(nextBiome, nextFloor);
}

function updateGame(dt) {
    state.time += dt;
    if (state.hitStop > 0) {
        state.hitStop -= dt;
        return; // Freeze on hit for juiciness
    }

    const { level, player, entities, particles } = state;

    player.update(dt, level, entities, particles);

    for (const s of entities.swings) {
        s.update(dt, entities.enemies, particles);
    }
    for (let i = entities.swings.length - 1; i >= 0; i--) {
        if (entities.swings[i].dead) entities.swings.splice(i, 1);
    }

    for (const e of entities.enemies) {
        if (e.dead) continue;
        e.update(dt, level, player, entities, particles);
    }

    // Collect dead enemies => drop cells, count kills
    for (let i = entities.enemies.length - 1; i >= 0; i--) {
        const e = entities.enemies[i];
        if (e.dead) {
            player.kills++;
            state.totalKills++;
            for (let k = 0; k < e.cellsOnDeath; k++) {
                entities.pickups.push({
                    kind: 'cell',
                    x: e.x + e.w/2,
                    y: e.y + e.h/2,
                    vx: rand(-120, 120),
                    vy: rand(-220, -80),
                    collected: false,
                    life: 15,
                });
            }
            if (Math.random() < 0.2) {
                entities.pickups.push({
                    kind: 'flask',
                    x: e.x + e.w/2, y: e.y,
                    vx: rand(-40, 40), vy: -140,
                    collected: false, life: 20,
                });
            }
            particles.pickup(e.x + e.w/2, e.y + e.h/2, '#ffcc44');
            state.camera.shake = Math.max(state.camera.shake, 4);
            entities.enemies.splice(i, 1);
        }
    }

    // Projectiles
    for (const p of entities.projectiles) {
        const targets = p.owner === 'player' ? entities.enemies : [player];
        p.update(dt, level, targets, particles);
    }
    for (let i = entities.projectiles.length - 1; i >= 0; i--) {
        if (entities.projectiles[i].dead) entities.projectiles.splice(i, 1);
    }

    // Pickups physics + collection
    for (const pu of entities.pickups) {
        if (pu.collected) continue;
        pu.life -= dt;
        if (pu.life <= 0) { pu.collected = true; continue; }
        const body = { x: pu.x - 6, y: pu.y - 6, w: 12, h: 12 };
        level.moveX(body, pu.vx * dt);
        const hitY = level.moveY(body, pu.vy * dt);
        if (hitY === 'bottom') {
            if (pu.vy > 60) pu.vy = -pu.vy * 0.35;
            else pu.vy = 0;
            pu.vx *= 0.6;
        } else if (hitY === 'top') {
            pu.vy = 0;
        }
        pu.x = body.x + 6;
        pu.y = body.y + 6;

        pu.vy += 900 * dt;
        pu.vx *= 0.97;
        if (pu.vy > 600) pu.vy = 600;

        // Attract toward player
        const dx = (player.x + player.w/2) - pu.x;
        const dy = (player.y + player.h/2) - pu.y;
        const d = Math.hypot(dx, dy);
        if (d < 90) {
            pu.vx += (dx / d) * 900 * dt;
            pu.vy += (dy / d) * 900 * dt;
        }

        if (aabb({ x: pu.x - 6, y: pu.y - 6, w: 12, h: 12 }, player.hitbox())) {
            pu.collected = true;
            if (pu.kind === 'cell') {
                player.cellsGained++;
                particles.pickup(pu.x, pu.y, '#ffcc44');
            } else if (pu.kind === 'flask') {
                if (player.flasks < player.flaskMax) {
                    player.flasks++;
                } else {
                    player.heal(15);
                }
                particles.pickup(pu.x, pu.y, '#88ffaa');
            }
        }
    }
    for (let i = entities.pickups.length - 1; i >= 0; i--) {
        if (entities.pickups[i].collected) entities.pickups.splice(i, 1);
    }

    // Exit interaction
    if (level.spawns.exit) {
        const ex = level.spawns.exit.x;
        const ey = level.spawns.exit.y;
        const dx = (player.x + player.w/2) - ex;
        const dy = (player.y + player.h/2) - ey;
        if (Math.abs(dx) < 24 && Math.abs(dy) < 40 && wasPressed('f', 'enter')) {
            nextFloor();
            return;
        }
    }

    // Camera follow with lookahead
    const targetX = player.x + player.w/2 - canvas.width / 2 + player.facing * 60;
    const targetY = player.y + player.h/2 - canvas.height / 2 - 40;
    state.camera.x += (targetX - state.camera.x) * 0.12;
    state.camera.y += (targetY - state.camera.y) * 0.12;
    state.camera.x = clamp(state.camera.x, 0, level.pixelWidth - canvas.width);
    state.camera.y = clamp(state.camera.y, 0, level.pixelHeight - canvas.height);

    if (state.camera.shake > 0) state.camera.shake = Math.max(0, state.camera.shake - dt * 40);

    particles.update(dt);

    // Death
    if (player.dead) {
        setTimeout(() => { if (state.screen === 'play') die(); }, 800);
        state.screen = 'dying';
    }

    // Hitstop on any hit (feel)
    // (We trigger it when player lands a hit - see below check)
    for (const s of entities.swings) {
        if (s.hit.size > 0 && !s._stopped) {
            s._stopped = true;
            state.hitStop = 0.04;
            state.camera.shake = 6;
        }
    }
}

function drawGame() {
    const { level, player, entities, particles, camera } = state;

    // Screen shake
    const shakeX = (Math.random() - 0.5) * camera.shake;
    const shakeY = (Math.random() - 0.5) * camera.shake;
    const cx = camera.x + shakeX;
    const cy = camera.y + shakeY;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    level.draw(ctx, cx, cy, state.time);

    // Pickups
    for (const pu of entities.pickups) {
        if (pu.collected) continue;
        const sx = Math.floor(pu.x - cx);
        const sy = Math.floor(pu.y - cy);
        const pulse = Math.sin(state.time * 8 + pu.x) * 2;
        if (pu.kind === 'cell') {
            ctx.fillStyle = '#ffcc44';
            ctx.beginPath();
            ctx.moveTo(sx, sy - 6 + pulse);
            ctx.lineTo(sx + 5, sy + pulse);
            ctx.lineTo(sx, sy + 6 + pulse);
            ctx.lineTo(sx - 5, sy + pulse);
            ctx.closePath();
            ctx.fill();
            // glow
            const glow = ctx.createRadialGradient(sx, sy + pulse, 1, sx, sy + pulse, 14);
            glow.addColorStop(0, 'rgba(255, 220, 80, 0.5)');
            glow.addColorStop(1, 'rgba(255, 220, 80, 0)');
            ctx.fillStyle = glow;
            ctx.fillRect(sx - 14, sy - 14 + pulse, 28, 28);
        } else if (pu.kind === 'flask') {
            ctx.fillStyle = '#88ffaa';
            ctx.fillRect(sx - 4, sy - 6, 8, 10);
            ctx.fillStyle = '#3a5a3a';
            ctx.fillRect(sx - 2, sy - 8, 4, 2);
        }
    }

    // Entities
    for (const e of entities.enemies) e.draw(ctx, cx, cy, state.time);
    player.draw(ctx, cx, cy);

    for (const s of entities.swings) s.draw(ctx, cx, cy);
    for (const p of entities.projectiles) p.draw(ctx, cx, cy);

    particles.draw(ctx, cx, cy);

    // Exit prompt
    if (level.spawns.exit) {
        const ex = level.spawns.exit.x;
        const ey = level.spawns.exit.y;
        const dx = (player.x + player.w/2) - ex;
        const dy = (player.y + player.h/2) - ey;
        if (Math.abs(dx) < 40 && Math.abs(dy) < 60) {
            const sx = ex - cx;
            const sy = ey - cy - 80;
            ctx.fillStyle = 'rgba(0,0,0,0.7)';
            ctx.fillRect(sx - 60, sy - 12, 120, 22);
            ctx.fillStyle = '#ffcc44';
            ctx.font = 'bold 12px Courier New';
            ctx.textAlign = 'center';
            ctx.fillText('[F] Descendre', sx, sy + 4);
        }
    }

    // Vignette
    const vg = ctx.createRadialGradient(canvas.width/2, canvas.height/2, 200, canvas.width/2, canvas.height/2, 500);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(1, 'rgba(0,0,0,0.55)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Hit flash overlay
    if (player.invuln > 0.6) {
        ctx.fillStyle = `rgba(255, 50, 50, ${(player.invuln - 0.6) * 1.5})`;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
}

function updateHUD() {
    const p = state.player;
    if (!p) return;
    hud.hpFill.style.width = `${clamp((p.hp / p.maxHp) * 100, 0, 100)}%`;
    hud.hpText.textContent = `${Math.max(0, Math.ceil(p.hp))} / ${p.maxHp}`;
    hud.flaskCount.textContent = p.flasks;
    hud.cellsCount.textContent = p.cellsGained;
    hud.biomeName.textContent = state.level.biome.name;
    hud.depth.textContent = `Étage ${state.floorNumber}`;
}

let lastT = 0;
function loop(now) {
    const dt = Math.min(0.033, (now - lastT) / 1000 || 0.016);
    lastT = now;
    inputFrameStart();

    if (state.screen === 'play' || state.screen === 'dying') {
        updateGame(dt);
        drawGame();
        updateHUD();
    }

    requestAnimationFrame(loop);
}

document.getElementById('start-btn').addEventListener('click', startRun);
document.getElementById('retry-btn').addEventListener('click', startRun);
document.getElementById('victory-btn').addEventListener('click', () => {
    victoryScreen.classList.add('hidden');
    startScreen.classList.remove('hidden');
    state.screen = 'start';
    refreshMetaDisplay();
});

requestAnimationFrame(loop);
