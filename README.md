# Hollow Cells

Un roguelike metroidvania nerveux inspiré de Dead Cells. 100% HTML5 + JavaScript, aucune dépendance.

## Lancer le jeu

Le jeu utilise des modules ES, il faut donc le servir en HTTP (un simple `file://` ne marchera pas).

```bash
python3 -m http.server 8000
# puis ouvrez http://localhost:8000
```

## Contrôles

| Touche | Action |
|---|---|
| `← →` / `A D` / `Q D` | Se déplacer |
| `Espace` / `W` / `Z` | Sauter (double saut, wall jump) |
| `Shift` | Roulade (i-frames) |
| `X` / `J` | Attaque principale (épée) |
| `C` / `K` | Attaque secondaire (arc) |
| `E` | Boire une potion |
| `F` / `Entrée` | Interagir avec la porte de sortie |
| `↓` / `S` | Tomber des plateformes (en sautant) |

## Mécaniques

- **Combat nerveux** : attaques rapides avec hit-stop, screen shake, knockback et effets de sang.
- **Mouvement fluide** : double saut, dash avec i-frames, wall slide + wall jump, coyote time, jump buffering.
- **Niveaux procéduraux** : chaque étage est généré aléatoirement (sols ondulés, plateformes, pics, salles).
- **4 biomes** : Prison des Âmes → Égouts Toxiques → Remparts Oubliés → Donjon du Roi.
- **4 types d'ennemis** :
  - **Bandit** : patrouille et charge au corps à corps.
  - **Sabreur** : s'élance après une phase de préparation.
  - **Archer** : tire des flèches en ligne de vue.
  - **Chauve-souris** : vole et fond sur le joueur.
- **Méta-progression** : à la mort, les cellules récoltées alimentent 4 améliorations permanentes (vitalité, fureur, fioles, alchimie), stockées en `localStorage`.
- **Loot** : les ennemis laissent tomber des cellules ◆ et parfois des fioles 🧪.

## Structure

```
index.html      — Shell HTML + HUD + écrans
style.css       — UI et overlays
js/main.js      — Boucle principale, caméra, transitions
js/level.js     — Génération procédurale + collision tilemap
js/player.js    — Physique joueur, mouvement, combat
js/enemies.js   — 4 IA d'ennemis
js/weapon.js    — Épée (swing) + projectiles
js/particles.js — Système de particules (sang, étincelles, poussière)
js/meta.js      — Progression permanente + localStorage
js/input.js     — Clavier (keys + justPressed)
js/utils.js     — Math helpers (AABB, clamp, random)
```
