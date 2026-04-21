class Biome {
    public var name : String;
    public var flavor : String;
    public var bg : Int;
    public var fog : Int;
    public var wall : Int;
    public var wallTop : Int;
    public var wallShadow : Int;
    public var accent : Int;
    public var platform : Int;
    public var enemies : Array<String>;
    public var enemyMin : Int;
    public var enemyMax : Int;

    public function new(
        name:String, flavor:String,
        bg:Int, fog:Int, wall:Int, wallTop:Int, wallShadow:Int,
        accent:Int, platform:Int,
        enemies:Array<String>, enemyMin:Int, enemyMax:Int
    ) {
        this.name = name; this.flavor = flavor;
        this.bg = bg; this.fog = fog; this.wall = wall;
        this.wallTop = wallTop; this.wallShadow = wallShadow;
        this.accent = accent; this.platform = platform;
        this.enemies = enemies;
        this.enemyMin = enemyMin; this.enemyMax = enemyMax;
    }

    public static var ALL : Array<Biome> = [
        new Biome(
            "PRISON DES AMES",
            "Des murs froids et des gardes endormis...",
            0x100f1a, 0x1a1830, 0x3a3450, 0x554a78, 0x221d33,
            0xc8a8ff, 0x6a5a96,
            ["grunt", "grunt", "archer", "bat"],
            4, 7
        ),
        new Biome(
            "EGOUTS TOXIQUES",
            "Il y a quelque chose qui bouge dans la vase...",
            0x0c120c, 0x141e14, 0x2a3a28, 0x4a6044, 0x1a241a,
            0xb0ff70, 0x4a6044,
            ["grunt", "archer", "archer", "bat", "slasher"],
            5, 9
        ),
        new Biome(
            "REMPARTS OUBLIES",
            "Le vent hurle entre les creneaux fissures...",
            0x140e10, 0x241822, 0x4a2a3a, 0x6a4058, 0x2a1522,
            0xff88aa, 0x6a4058,
            ["slasher", "archer", "bat", "bat"],
            6, 10
        ),
        new Biome(
            "DONJON DU ROI",
            "Une presence ancienne attend...",
            0x180810, 0x281020, 0x5a1830, 0x8a2848, 0x2a0815,
            0xffcc44, 0x8a2848,
            ["slasher", "slasher", "archer", "bat"],
            7, 11
        )
    ];
}
