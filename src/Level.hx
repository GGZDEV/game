import h2d.Graphics;

class Level {
    public static inline var T_EMPTY = 0;
    public static inline var T_SOLID = 1;
    public static inline var T_PLATFORM = 2;
    public static inline var T_SPIKE = 3;
    public static inline var T_DECO = 4;

    public var w : Int;
    public var h : Int;
    public var tiles : haxe.ds.Vector<Int>;
    public var biome : Biome;
    public var biomeIndex : Int;
    public var floorNumber : Int;
    public var pixelWidth : Int;
    public var pixelHeight : Int;

    public var startX : Float;
    public var startY : Float;
    public var exitX : Float;
    public var exitY : Float;

    public var enemySpawns : Array<{ type:String, x:Float, y:Float }> = [];
    public var cellSpawns : Array<{ x:Float, y:Float }> = [];

    // Rendering
    public var gfx : Graphics;
    public var bgGfx : Graphics;
    public var doorGfx : Graphics;

    public function new(biomeIndex:Int, floorNumber:Int, parent:h2d.Object) {
        this.biomeIndex = biomeIndex;
        this.floorNumber = floorNumber;
        this.biome = Biome.ALL[biomeIndex];
        this.w = 60 + Std.random(30);
        this.h = 22;
        this.tiles = new haxe.ds.Vector(w * h);
        for (i in 0...tiles.length) tiles[i] = T_EMPTY;
        this.pixelWidth = w * Const.TILE;
        this.pixelHeight = h * Const.TILE;

        bgGfx = new Graphics(parent);
        gfx = new Graphics(parent);
        doorGfx = new Graphics(parent);

        generate();
        drawStaticTiles();
    }

    public inline function idx(x:Int, y:Int) return y * w + x;
    public inline function get(x:Int, y:Int) : Int {
        if (x < 0 || y < 0 || x >= w || y >= h) return T_SOLID;
        return tiles[idx(x, y)];
    }
    public inline function set(x:Int, y:Int, v:Int) {
        if (x < 0 || y < 0 || x >= w || y >= h) return;
        tiles[idx(x, y)] = v;
    }
    public inline function isSolid(x:Int, y:Int) return get(x, y) == T_SOLID;
    public inline function isPlatform(x:Int, y:Int) return get(x, y) == T_PLATFORM;
    public inline function isSpike(x:Int, y:Int) return get(x, y) == T_SPIKE;

    function generate() {
        // Borders
        for (x in 0...w) {
            set(x, 0, T_SOLID);
            set(x, h - 1, T_SOLID);
            set(x, h - 2, T_SOLID);
        }
        for (y in 0...h) {
            set(0, y, T_SOLID);
            set(w - 1, y, T_SOLID);
        }

        // Wavy floor with pits
        var floorY = h - 3;
        var x = 1;
        while (x < w - 1) {
            if (x > 5 && x < w - 6 && Math.random() < 0.06) {
                var pitW = 2 + Std.random(3);
                x += pitW;
                continue;
            }
            set(x, floorY, T_SOLID);
            if (Math.random() < 0.15 && floorY < h - 3) floorY++;
            if (Math.random() < 0.15 && floorY > h - 5) floorY--;
            x++;
        }

        // Spikes in pits
        for (x in 2...w - 2) {
            if (!isSolid(x, h - 3) && !isSolid(x, h - 4)) {
                if (Math.random() < 0.4) set(x, h - 3, T_SPIKE);
            }
        }

        // Platforms
        var numPlatforms = Std.int(w * 0.35);
        for (i in 0...numPlatforms) {
            var px = 3 + Std.random(w - 5);
            var py = 4 + Std.random(h - 10);
            var len = 3 + Std.random(5);
            var canPlace = true;
            for (j in 0...len) {
                if (get(px + j, py) != T_EMPTY) { canPlace = false; break; }
                if (isSolid(px + j, py - 1)) { canPlace = false; break; }
            }
            if (canPlace) for (j in 0...len) set(px + j, py, T_PLATFORM);
        }

        // High ledges
        var numLedges = Std.int(w * 0.08);
        for (i in 0...numLedges) {
            var lx = 3 + Std.random(w - 11);
            var ly = 5 + Std.random(h - 13);
            var lw = 2 + Std.random(4);
            var lh = 1 + Std.random(2);
            for (dx in 0...lw) for (dy in 0...lh) set(lx + dx, ly + dy, T_SOLID);
        }

        // Torches
        var tx = 2;
        while (tx < w - 2) {
            for (ty in 1...h - 3) {
                if (!isSolid(tx, ty) && isSolid(tx, ty + 1) && Math.random() < 0.4) {
                    set(tx, ty, T_DECO);
                    break;
                }
            }
            tx += 5 + Std.random(6);
        }

        // Start position
        startX = 3 * Const.TILE;
        startY = (h - 4) * Const.TILE;
        for (sx in 2...10) {
            var found = false;
            for (sy in 1...h - 1) {
                if (!isSolid(sx, sy) && isSolid(sx, sy + 1)) {
                    startX = sx * Const.TILE + Const.TILE / 2;
                    startY = sy * Const.TILE;
                    // Clear the spawn area so the player doesn't get stuck on a ledge
                    found = true;
                    break;
                }
            }
            if (found) break;
        }

        // Exit
        exitX = (w - 3) * Const.TILE;
        exitY = (h - 4) * Const.TILE;
        var ex = w - 3;
        while (ex > w - 12) {
            var found = false;
            for (ey in 1...h - 1) {
                if (!isSolid(ex, ey) && !isSolid(ex, ey - 1) && isSolid(ex, ey + 1)) {
                    exitX = ex * Const.TILE + Const.TILE / 2;
                    exitY = ey * Const.TILE;
                    found = true;
                    break;
                }
            }
            if (found) break;
            ex--;
        }

        // Enemies
        var numE = biome.enemyMin + Std.random(biome.enemyMax - biome.enemyMin + 1);
        var attempts = 0;
        while (enemySpawns.length < numE && attempts < 200) {
            attempts++;
            var ex = 12 + Std.random(w - 16);
            var ey = 2 + Std.random(h - 5);
            if (isSolid(ex, ey) || isSpike(ex, ey)) continue;
            var type = biome.enemies[Std.random(biome.enemies.length)];
            var wX = ex * Const.TILE + Const.TILE / 2;
            var wY = ey * Const.TILE + Const.TILE;
            if (type == "bat") {
                if (!isSolid(ex, ey - 1)) enemySpawns.push({ type: type, x: wX, y: wY - Const.TILE / 2 });
            } else {
                if ((isSolid(ex, ey + 1) || isPlatform(ex, ey + 1)) && wX > startX + 240) {
                    enemySpawns.push({ type: type, x: wX, y: wY });
                }
            }
        }

        // Cells
        var numC = 3 + Std.random(4);
        attempts = 0;
        while (cellSpawns.length < numC && attempts < 100) {
            attempts++;
            var cx = 6 + Std.random(w - 10);
            var cy = 2 + Std.random(h - 5);
            if (isSolid(cx, cy) || isSpike(cx, cy)) continue;
            if (isSolid(cx, cy + 1) || isPlatform(cx, cy + 1)) {
                cellSpawns.push({
                    x: cx * Const.TILE + Const.TILE / 2,
                    y: cy * Const.TILE + Const.TILE - 8
                });
            }
        }
    }

    /** Redraw only when camera changes so we don't redraw every frame. */
    function drawStaticTiles() {
        gfx.clear();
        bgGfx.clear();

        // Pre-render ALL tiles once (cheap enough). They'll be culled by the scene camera.
        for (y in 0...h) {
            for (x in 0...w) {
                var t = get(x, y);
                if (t == T_EMPTY) continue;
                var sx = x * Const.TILE;
                var sy = y * Const.TILE;
                if (t == T_SOLID) {
                    gfx.beginFill(biome.wall);
                    gfx.drawRect(sx, sy, Const.TILE, Const.TILE);
                    gfx.endFill();
                    if (!isSolid(x, y - 1)) {
                        gfx.beginFill(biome.wallTop);
                        gfx.drawRect(sx, sy, Const.TILE, 4);
                        gfx.endFill();
                    }
                    gfx.beginFill(biome.wallShadow);
                    gfx.drawRect(sx, sy + Const.TILE - 3, Const.TILE, 3);
                    gfx.endFill();
                } else if (t == T_PLATFORM) {
                    gfx.beginFill(biome.platform);
                    gfx.drawRect(sx, sy, Const.TILE, 6);
                    gfx.endFill();
                    gfx.beginFill(biome.wallShadow);
                    gfx.drawRect(sx, sy + 6, Const.TILE, 2);
                    gfx.endFill();
                } else if (t == T_SPIKE) {
                    gfx.beginFill(0xcccccc);
                    var step = Const.TILE / 4;
                    for (i in 0...4) {
                        var px = sx + i * step;
                        gfx.moveTo(px, sy + Const.TILE);
                        gfx.lineTo(px + step / 2, sy + Const.TILE / 2);
                        gfx.lineTo(px + step, sy + Const.TILE);
                        gfx.lineTo(px, sy + Const.TILE);
                    }
                    gfx.endFill();
                    gfx.beginFill(0x555555);
                    gfx.drawRect(sx, sy + Const.TILE - 3, Const.TILE, 3);
                    gfx.endFill();
                }
            }
        }

        // Exit door
        doorGfx.clear();
        var ex = exitX;
        var ey = exitY;
        doorGfx.beginFill(0x1a0a14);
        doorGfx.drawRect(ex - 20, ey - 56, 40, 56);
        doorGfx.endFill();
        doorGfx.beginFill(biome.accent);
        doorGfx.drawRect(ex - 22, ey - 58, 44, 4);
        doorGfx.drawRect(ex - 22, ey - 58, 4, 60);
        doorGfx.drawRect(ex + 18, ey - 58, 4, 60);
        doorGfx.endFill();
    }

    /** Draw animated background (torches pulse, door glyph pulses). */
    public function drawDynamic(time:Float, g:Graphics) {
        g.clear();
        for (y in 0...h) {
            for (x in 0...w) {
                if (get(x, y) != T_DECO) continue;
                var sx = x * Const.TILE;
                var sy = y * Const.TILE;
                var flicker = Math.sin(time * 14 + x * 3) * 0.2 + 0.8;
                // Torch rod
                g.beginFill(0x3a2a20);
                g.drawRect(sx + Const.TILE / 2 - 2, sy + 10, 4, 16);
                g.endFill();
                // Flame
                g.beginFill(mixColor(0xffb43c, 0x000000, 1.0 - flicker));
                g.drawCircle(sx + Const.TILE / 2, sy + 8, 6);
                g.endFill();
                g.beginFill(0xfff0b4);
                g.drawCircle(sx + Const.TILE / 2, sy + 8, 3);
                g.endFill();
            }
        }
        // Door glyph pulse
        var pulse = Math.sin(time * 4) * 0.3 + 0.7;
        var col = mixColor(0xffdc78, 0x000000, 1.0 - pulse);
        g.beginFill(col);
        g.drawRect(exitX - 3, exitY - 38, 6, 6);
        g.drawRect(exitX - 6, exitY - 32, 12, 2);
        g.drawRect(exitX - 3, exitY - 28, 6, 6);
        g.endFill();
    }

    public static inline function mixColor(a:Int, b:Int, t:Float) : Int {
        var ar = (a >> 16) & 0xff, ag = (a >> 8) & 0xff, ab = a & 0xff;
        var br = (b >> 16) & 0xff, bg = (b >> 8) & 0xff, bb = b & 0xff;
        var r = Std.int(ar + (br - ar) * t);
        var gg = Std.int(ag + (bg - ag) * t);
        var bbc = Std.int(ab + (bb - ab) * t);
        return (r << 16) | (gg << 8) | bbc;
    }

    /** Horizontal movement + solid-tile collision resolution. */
    public function moveX(body:PhysBody, dx:Float) : Bool {
        body.x += dx;
        var left = Std.int(Math.floor(body.x / Const.TILE));
        var right = Std.int(Math.floor((body.x + body.w - 0.01) / Const.TILE));
        var top = Std.int(Math.floor(body.y / Const.TILE));
        var bottom = Std.int(Math.floor((body.y + body.h - 0.01) / Const.TILE));
        var hit = false;
        for (y in top...bottom + 1) for (x in left...right + 1) {
            if (isSolid(x, y)) {
                if (dx > 0) body.x = x * Const.TILE - body.w;
                else if (dx < 0) body.x = (x + 1) * Const.TILE;
                hit = true;
            }
        }
        return hit;
    }

    /** Vertical movement + collision. Returns 0 none / 1 bottom / -1 top. */
    public function moveY(body:PhysBody, dy:Float, allowDrop:Bool) : Int {
        var prevBottom = body.y + body.h;
        body.y += dy;
        var left = Std.int(Math.floor(body.x / Const.TILE));
        var right = Std.int(Math.floor((body.x + body.w - 0.01) / Const.TILE));
        var top = Std.int(Math.floor(body.y / Const.TILE));
        var bottom = Std.int(Math.floor((body.y + body.h - 0.01) / Const.TILE));
        var hit = 0;
        for (y in top...bottom + 1) for (x in left...right + 1) {
            if (isSolid(x, y)) {
                if (dy > 0) { body.y = y * Const.TILE - body.h; hit = 1; }
                else if (dy < 0) { body.y = (y + 1) * Const.TILE; hit = -1; }
            } else if (isPlatform(x, y) && dy > 0 && !allowDrop) {
                var tileTop = y * Const.TILE;
                if (prevBottom <= tileTop + 2) {
                    body.y = tileTop - body.h;
                    hit = 1;
                }
            }
        }
        return hit;
    }

    public function touchesSpike(body:PhysBody) : Bool {
        var left = Std.int(Math.floor(body.x / Const.TILE));
        var right = Std.int(Math.floor((body.x + body.w - 0.01) / Const.TILE));
        var top = Std.int(Math.floor(body.y / Const.TILE));
        var bottom = Std.int(Math.floor((body.y + body.h - 0.01) / Const.TILE));
        for (y in top...bottom + 1) for (x in left...right + 1) {
            if (isSpike(x, y)) return true;
        }
        return false;
    }

    public function destroy() {
        gfx.remove();
        bgGfx.remove();
        doorGfx.remove();
    }
}

typedef PhysBody = { x:Float, y:Float, w:Float, h:Float };
