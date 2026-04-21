class Upgrade {
    public var key : String;
    public var name : String;
    public var desc : String;
    public var baseCost : Int;
    public var step : Int;
    public var max : Int;
    public function new(key, name, desc, baseCost, step, max) {
        this.key = key; this.name = name; this.desc = desc;
        this.baseCost = baseCost; this.step = step; this.max = max;
    }
    public function costAt(level:Int) return baseCost + step * level;
}

class Meta {
    static inline var KEY = "hollowcells_heaps_v1";

    public var cells : Int = 0;
    public var maxHp : Int = 0;
    public var damage : Int = 0;
    public var flasks : Int = 0;
    public var flaskHeal : Int = 0;

    public static var UPGRADES : Array<Upgrade> = [
        new Upgrade("maxHp",     "Vitalite",  "+10 PV max",                 15, 10, 10),
        new Upgrade("damage",    "Fureur",    "+1 degats",                  20, 15, 10),
        new Upgrade("flasks",    "Fioles",    "+1 charge de potion",        25, 20, 5),
        new Upgrade("flaskHeal", "Alchimie",  "+10% soin par potion",       15, 10, 5)
    ];

    public function new() load();

    public function load() {
        #if js
        try {
            var raw = js.Browser.window.localStorage.getItem(KEY);
            if (raw == null) return;
            var data : Dynamic = haxe.Json.parse(raw);
            cells = data.cells != null ? data.cells : 0;
            maxHp = data.maxHp != null ? data.maxHp : 0;
            damage = data.damage != null ? data.damage : 0;
            flasks = data.flasks != null ? data.flasks : 0;
            flaskHeal = data.flaskHeal != null ? data.flaskHeal : 0;
        } catch(e:Dynamic) {}
        #end
    }

    public function save() {
        #if js
        try {
            var obj = { cells:cells, maxHp:maxHp, damage:damage, flasks:flasks, flaskHeal:flaskHeal };
            js.Browser.window.localStorage.setItem(KEY, haxe.Json.stringify(obj));
        } catch(e:Dynamic) {}
        #end
    }

    public function level(key:String) : Int {
        return switch(key) {
            case "maxHp": maxHp;
            case "damage": damage;
            case "flasks": flasks;
            case "flaskHeal": flaskHeal;
            default: 0;
        }
    }

    public function setLevel(key:String, v:Int) {
        switch(key) {
            case "maxHp": maxHp = v;
            case "damage": damage = v;
            case "flasks": flasks = v;
            case "flaskHeal": flaskHeal = v;
        }
    }

    public function canBuy(key:String) : Bool {
        for (u in UPGRADES) if (u.key == key) {
            var lvl = level(key);
            if (lvl >= u.max) return false;
            return cells >= u.costAt(lvl);
        }
        return false;
    }

    public function buy(key:String) : Bool {
        for (u in UPGRADES) if (u.key == key) {
            var lvl = level(key);
            if (lvl >= u.max) return false;
            var cost = u.costAt(lvl);
            if (cells < cost) return false;
            cells -= cost;
            setLevel(key, lvl + 1);
            save();
            return true;
        }
        return false;
    }
}
