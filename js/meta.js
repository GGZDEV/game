const KEY = 'hollowcells_meta_v1';

const DEFAULT = {
    cells: 0,
    upgrades: {
        maxHp: 0,      // +10 each
        damage: 0,     // +1 each
        flasks: 0,     // +1 each
        flaskHeal: 0,  // +10% each
    },
};

export const UPGRADES = [
    { key: 'maxHp', name: 'Vitalité',        desc: '+10 PV max',           baseCost: 15, step: 10, max: 10 },
    { key: 'damage', name: 'Fureur',         desc: '+1 dégâts',            baseCost: 20, step: 15, max: 10 },
    { key: 'flasks', name: 'Fioles',         desc: '+1 charge de potion',  baseCost: 25, step: 20, max: 5  },
    { key: 'flaskHeal', name: 'Alchimie',    desc: '+10% soin par potion', baseCost: 15, step: 10, max: 5  },
];

export function loadMeta() {
    try {
        const raw = localStorage.getItem(KEY);
        if (!raw) return { ...DEFAULT, upgrades: { ...DEFAULT.upgrades } };
        const saved = JSON.parse(raw);
        return {
            cells: saved.cells ?? 0,
            upgrades: { ...DEFAULT.upgrades, ...(saved.upgrades ?? {}) },
        };
    } catch {
        return { ...DEFAULT, upgrades: { ...DEFAULT.upgrades } };
    }
}

export function saveMeta(meta) {
    localStorage.setItem(KEY, JSON.stringify(meta));
}

export function upgradeCost(u, level) {
    return u.baseCost + u.step * level;
}

export function canBuy(meta, upgradeKey) {
    const u = UPGRADES.find(x => x.key === upgradeKey);
    const lvl = meta.upgrades[upgradeKey];
    if (lvl >= u.max) return false;
    return meta.cells >= upgradeCost(u, lvl);
}

export function buyUpgrade(meta, upgradeKey) {
    const u = UPGRADES.find(x => x.key === upgradeKey);
    const lvl = meta.upgrades[upgradeKey];
    const cost = upgradeCost(u, lvl);
    if (meta.cells < cost || lvl >= u.max) return false;
    meta.cells -= cost;
    meta.upgrades[upgradeKey] = lvl + 1;
    saveMeta(meta);
    return true;
}
