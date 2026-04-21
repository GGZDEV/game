import hxd.App;

class Main extends App {
    public static var inst : Main;
    public var game : Game;

    override function init() {
        inst = this;
        engine.backgroundColor = 0xff0d0d18;
        game = new Game(s2d);
        onResize();
    }

    override function onResize() {
        // Scale logical 960x540 viewport with letterboxing.
        s2d.scaleMode = LetterBox(Const.VIEW_W, Const.VIEW_H);
    }

    override function update(dt:Float) {
        // hxd.Timer.dt is seconds; clamp to keep sim stable.
        if (dt > 0.05) dt = 0.05;
        game.update(dt);
    }

    static function main() {
        new Main();
    }
}
