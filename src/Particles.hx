import h2d.Graphics;

class Particle {
    public var x : Float;
    public var y : Float;
    public var vx : Float;
    public var vy : Float;
    public var life : Float;
    public var maxLife : Float;
    public var size : Float;
    public var color : Int;
    public var gravity : Float;
    public var drag : Float;
    public function new() {}
}

class Particles {
    public var parts : Array<Particle> = [];
    public var gfx : Graphics;
    var pool : Array<Particle> = [];

    public function new(parent:h2d.Object) {
        gfx = new Graphics(parent);
    }

    public function destroy() gfx.remove();

    function alloc() : Particle {
        if (pool.length > 0) return pool.pop();
        return new Particle();
    }

    public function spawn(x:Float, y:Float, count:Int, color:Int,
                          angle:Float, spread:Float,
                          minSpeed:Float, maxSpeed:Float,
                          minLife:Float, maxLife:Float,
                          minSize:Float, maxSize:Float,
                          gravity:Float, drag:Float) {
        for (i in 0...count) {
            var p = alloc();
            p.x = x; p.y = y;
            var a = angle + (Math.random() * 2 - 1) * spread;
            var sp = minSpeed + Math.random() * (maxSpeed - minSpeed);
            p.vx = Math.cos(a) * sp;
            p.vy = Math.sin(a) * sp;
            p.life = minLife + Math.random() * (maxLife - minLife);
            p.maxLife = p.life;
            p.size = minSize + Math.random() * (maxSize - minSize);
            p.color = color;
            p.gravity = gravity;
            p.drag = drag;
            parts.push(p);
        }
    }

    public function blood(x:Float, y:Float, dir:Float) {
        spawn(x, y, 10, 0xd22840, dir, Math.PI * 0.8, 60, 240, 0.3, 0.7, 1.5, 3, 500, 0.92);
    }
    public function hitSpark(x:Float, y:Float) {
        spawn(x, y, 6, 0xffee88, 0, Math.PI, 100, 260, 0.1, 0.25, 1, 2, 0, 0.92);
    }
    public function dust(x:Float, y:Float) {
        spawn(x, y, 4, 0x887766, -Math.PI / 2, Math.PI / 4, 20, 60, 0.2, 0.4, 1.5, 3, -100, 0.85);
    }
    public function pickup(x:Float, y:Float, color:Int) {
        spawn(x, y, 14, color, 0, Math.PI, 80, 200, 0.4, 0.9, 1, 2.5, 0, 0.88);
    }
    public function puff(x:Float, y:Float, color:Int) {
        spawn(x, y, 10, color, 0, Math.PI, 50, 150, 0.2, 0.4, 1, 2, 200, 0.9);
    }
    public function flash(x:Float, y:Float, color:Int) {
        spawn(x, y, 12, color, 0, Math.PI, 50, 150, 0.2, 0.4, 1, 2.5, 0, 0.88);
    }

    public function update(dt:Float) {
        var i = parts.length - 1;
        while (i >= 0) {
            var p = parts[i];
            p.life -= dt;
            if (p.life <= 0) {
                parts.splice(i, 1);
                pool.push(p);
            } else {
                p.x += p.vx * dt;
                p.y += p.vy * dt;
                p.vy += p.gravity * dt;
                p.vx *= p.drag;
                p.vy *= p.drag;
            }
            i--;
        }
    }

    public function render() {
        gfx.clear();
        for (p in parts) {
            var a = p.life / p.maxLife;
            if (a < 0) a = 0;
            gfx.beginFill(p.color, a);
            gfx.drawRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
            gfx.endFill();
        }
    }
}
