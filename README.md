# Hollow Cells

A nervous metroidvania roguelike inspired by Dead Cells, built with the same
tech stack Motion Twin uses: **Haxe 4** and **[Heaps.io](https://heaps.io)**
(the engine written by Nicolas Cannasse).

The project targets JavaScript/WebGL so it runs in any modern browser. Heaps
can also target HashLink for native desktop builds, which is the path used by
shipping Motion Twin titles.

## Running

### Build

```
haxe build.hxml
```

This produces `bin/game.js`.

### Play

Serve the `bin/` folder with any static file server and open `index.html`:

```
cd bin && python3 -m http.server 8123
# then browse to http://127.0.0.1:8123/
```

### Dependencies

The build uses Heaps as a `haxelib` library. If you don't have it, clone the
repo and register it as a dev lib:

```
git clone https://github.com/HeapsIO/heaps.git /tmp/heaps
haxelib dev heaps /tmp/heaps
git clone https://github.com/HaxeFoundation/format.git /tmp/format
haxelib dev format /tmp/format
```

## Controls

| Action        | Keys                                 |
| ------------- | ------------------------------------ |
| Move          | Arrow keys / A D / Q D               |
| Jump          | Space / W / Z (double jump, wall jump) |
| Roll / Dash   | Shift (i-frames)                     |
| Sword         | X / J                                |
| Bow           | C / K                                |
| Potion        | E                                    |
| Door / next   | F                                    |
| Start / retry | Enter                                |

## Features

- Procedurally generated rooms stitched into multi-platform levels
- Four themed biomes: Prison of Souls, Toxic Sewers, Forgotten Ramparts, King's Keep
- Four enemy archetypes: grunt, slasher, archer, bat — each with its own AI
- Tight platformer feel: coyote time, jump buffering, wall slide, wall jump,
  double jump, i-frame dash
- Melee sword arc with hit-stop, screen shake and particles
- Arrow bow with gravity-affected projectiles
- Cells and flasks as drops with magnetic attraction
- Meta-progression via `localStorage`: spend cells on permanent upgrades
- Biome banners, vignette, flash overlay, camera lookahead

## Source layout

```
src/
  Main.hx        entry point (hxd.App subclass)
  Const.hx       tuning constants
  Game.hx        top-level orchestrator, camera, entity lists
  Level.hx       tilemap, procedural generation, AABB collision
  Biome.hx       biome palette / enemy roster tables
  Entity.hx      base physics entity
  Player.hx      player movement + combat
  Enemies.hx     EnemyBase + Grunt / Slasher / Archer / Bat + factory
  SwordSwing.hx  melee hitbox
  Projectile.hx  arrows
  Pickup.hx      cells / flasks
  Particles.hx   pooled particles
  UI.hx          HUD + overlay screens
  Meta.hx        localStorage-backed upgrade shop
```
