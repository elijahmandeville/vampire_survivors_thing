# Project Context — [Working Title]
### Godot 2D Survivors-like

## Overview
A top-down 2D auto-battler/survival game inspired by Vampire Survivors. Player moves manually, weapons auto-fire, enemies swarm in escalating waves, player levels up mid-run and picks upgrades. Run ends in death or a time-based win.

## Engine & Scope
- **Engine:** Godot
- **Dimension:** 2D only — deliberate choice to cut complexity (no 3D pipeline, camera, or lighting overhead)

## Development Philosophy
**Systems-first, not feature-first or content-first.**

Build and validate independent, swappable systems using placeholder art ("gray boxing"). Get the full game loop playable and fun with primitive shapes before layering in real art, animation, or juice. This avoids the trap of building specific weapons/enemies/art before the underlying systems are proven to work.

**Known pain point:** Gets overwhelmed prioritizing tasks. Solution is a task list organized by *system*, not by week/sprint, worked one system at a time.

## Core Systems (build in this dependency order)

| # | System | Purpose | Status |
|---|--------|---------|--------|
| 1 | Game State | Run start/pause/end/reset | **Done** |
| 2 | Stats | Central data layer (health, speed, damage mult, etc.) that other systems read/write | **Done** |
| 3 | Movement/Input | Player control | **Done** |
| 4 | Combat/Damage | Hit detection, damage application, death handling | **Done** |
| 5 | Spawner | Enemy waves, timing, difficulty scaling | **Done** |
| 6 | Weapons/Abilities | Attack firing, upgrades, combos | **Done** |
| 7 | Progression | XP, leveling, upgrade selection | Not started |
| 8 | UI/HUD | Health bar, XP bar, timer | Not started |
| 9 | Art/Juice | Real art, animation, screen shake, VFX — last | Not started |

*Rule of thumb: a system isn't modular yet if it needs final art or another unfinished system to be testable in isolation.*

## System Communication Pattern
**Decided (see `docs/ADR-001-system-communication.md`).** Use all three, each for what it's good at:
- **Godot signals** — local, in-scene wiring (a component talking to its own parent/owner).
- **Autoload event bus** (`addons/event_bus/`) — global, many-to-many events any system can react to (`enemy_died`, `xp_gained`, `level_up`, `run_started`, `run_ended`, etc.).
- **Shared Resources** — continuous state (Stats, WeaponData, EnemyData), not one-off events.

Rule of thumb: if only this entity's own children need to know, use a local signal; if any other system might care, emit it on the bus.

## System Contracts
Once a system is gray-boxed and working, write a short contract for it here: what it takes in, what it sends out. This is what makes it swappable/extendable later without rot.

- **Game State:** IN — `start_run()`, `pause_run()`, `resume_run()`, `end_run(reason: String)`, `reset_run()`. OUT — `EventBus.run_started`, `run_paused`, `run_resumed`, `run_ended(reason)`. Readable state via `GameState.state`, `is_running()`, `is_paused()`. Autoload (`game/scripts/game_state.gd`, singleton name `GameState`). Verified: state walks READY → RUNNING → PAUSED → RUNNING → ENDED → READY as expected.
- **Stats:** IN — exported base values (`max_health`, `move_speed`, `damage_mult`, set in Inspector or via `.tres`), plus `reset_to_full()`, `take_damage(amount)`, `heal(amount)` at runtime. OUT — local signals `health_changed(current_health, max_health)`, `died` (fires once, on the RUNNING→0 transition only). Plain `Resource` (`class_name Stats`, `addons/stat_system/stats.gd`) — NOT an autoload; every entity owns its own instance. Remember to `.duplicate()` before handing a loaded `.tres` to more than one entity. Verified: health clamps correctly on both ends, `died` fires exactly once.
- **Movement/Input:** IN — `@export var speed`, plus directional input read internally via `Input.get_vector("move_left", "move_right", "move_up", "move_down")` (requires those four actions bound in Input Map). OUT — none yet; add a signal later only if something needs to react to movement. `class_name Movement2D`, `extends CharacterBody2D` (`addons/movement_2d/movement_2d.gd`) — the node itself is the physics body, droppable into any scene, no Stats dependency (sync speed from outside if wanted). Verified: WASD/arrow input moves the body correctly on screen.
- **Combat/Damage:** IN — `Hitbox` (`@export var damage`, pure data, `addons/health_system/hitbox.gd`) and `Hurtbox` (`@export var stats`, `addons/health_system/hurtbox.gd`), both `Area2D`. OUT — local signal `took_damage(amount)`; relies on `Stats.died` for death. Hurtbox ignores a Hitbox sharing its own parent (prevents an entity damaging itself when it carries both pieces, e.g. Enemy). Minimal death handling by design: Hurtbox only frees itself on death — deciding what "the whole entity disappearing" means (despawn animation, game-over screen, XP reward, etc.) is still an open follow-up for when Player/Enemy get their own scripts. Verified end-to-end with real Player/Enemy scenes: overlap detection, damage application, health clamping, and single-fire death all confirmed working.
- **Self-hit and friendly-fire guards:** `Hitbox` carries a non-exported `var source: Node` plus `get_source()`, which returns `source` if set and `get_parent()` otherwise. Hurtbox's single guard is `if area.get_source() == get_parent(): return`. This one function covers both shapes of Hitbox: a contact box that's simply a child of its owner (leave `source` null), and one parented elsewhere — a Projectile lives under `current_scene` so it doesn't inherit the firer's transform, so Weapon sets `projectile.source = get_parent()` explicitly. Before this, Projectile and Hurtbox had two *different* self-hit checks that disagreed, and the Player silently shot itself to death in about four seconds. Any future detached Hitbox (thrown weapon, orbiting shield, lingering fire pool) just sets `source` and behaves correctly.
- **Collision layers (the deferred "split them apart later" note in `hurtbox.gd`, now done):** named in Project Settings → Layer Names → 2D Physics. `1 world`, `2 player_hitbox`, `3 player_hurtbox`, `4 enemy_hitbox`, `5 enemy_hurtbox`. Assignments (Layer = what I am, Mask = what I watch for):
  | Node | Layer | Mask |
  |---|---|---|
  | Projectile | player_hitbox | enemy_hurtbox |
  | Player/Hurtbox | player_hurtbox | enemy_hitbox |
  | Enemy/Hurtbox | enemy_hurtbox | player_hitbox |
  | Enemy/Hitbox | enemy_hitbox | player_hurtbox |

  Physical `CharacterBody2D` bodies stay on `world` — body collision and Area2D detection are separate systems and shouldn't share layers. This is what stops enemies chipping each other: an Enemy Hurtbox watches only `player_hitbox`, so another enemy's contact box is invisible to it. Note Area2D detection is one-directional — only the *detector's* mask matters — so Enemy/Hitbox's mask is technically unused (Hurtbox does all detecting); it's set symmetrically anyway so the table reads consistently.
- **Entity death (follow-up from Combat/Damage — now RESOLVED):** `Hurtbox` no longer frees itself on death. It sets `monitoring = false` / `monitorable = false` (immediately stops detecting and being detected, so projectiles don't pass through or collide with a corpse) and emits a local `died` signal outward. Deciding what death *means* belongs to game-specific code, not a reusable addon (Reusability Standard #1 — an addon can't assume "my parent is the whole entity"). `game/scripts/enemy.gd` (attached to Enemy's root, deliberately in `game/` not `addons/`) listens for `hurtbox.died`, emits `EventBus.enemy_died(global_position)`, then `queue_free()`s the whole entity. Freeing also auto-removes the node from its groups, so Weapon's `get_nodes_in_group()` stops targeting it. Nothing listens to `enemy_died` yet — it exists so Progression can drop an XP gem at that position later with zero changes to `enemy.gd`.
- **Shared Resource gotcha (hit for real, now fixed):** the gotcha documented in `stats.gd` bit us the moment Spawner made multiple enemies — every enemy was handed the same `enemy_stats.tres` instance, so they shared one health pool AND every new spawn's `reset_to_full()` wiped the damage already dealt. Fix: `Hurtbox._ready()` now calls `stats = stats.duplicate()` before anything else, giving every entity its own copy. Worth remembering for any future Resource handed to more than one instance.
- **Spawner:** IN — `@export var target` (a `Node2D` to spawn around, e.g. Player — not hardcoded), `enemy_scene` (a `PackedScene`, not hardcoded to "Enemy"), plus `spawn_radius`/`min_spawn_distance`/`spawn_interval`/`min_spawn_interval`/`interval_decrease_rate`. Requires a child `Timer` node. OUT — none yet; spawned scenes are just added as siblings via `get_parent().add_child()`. `class_name Spawner`, `extends Node2D` (`addons/spawner/spawner.gd`). Only spawns while `GameState.is_running()` — which meant a small piece of glue was needed: `game/scripts/main.gd`, attached to `main.tscn`'s root, calls `GameState.start_run()` on `_ready()` so a run actually begins when the game launches. Verified: enemies spawn in a ring around the moving Player at the configured interval.
- **Weapons/Abilities:** Two pieces, both in `addons/weapon_system/`.
  - `Weapon` (`class_name Weapon`, `extends Node2D`) — IN: `@export projectile_scene` (a `PackedScene`, not hardcoded to one weapon), `fire_interval`, `target_mode`, `enemy_group`. Requires a child `Timer` node (same pattern as Spawner). OUT: none. Meant to be a child of whatever fires it, so its own `global_position` is the muzzle automatically. Only fires while `GameState.is_running()`.
  - `Projectile` (`class_name Projectile`, `extends Hitbox`) — IN: `@export speed`, `lifetime`; plus two plain (non-exported) vars set by the spawner right after `instantiate()`: `direction` and `source`. OUT: none — it inherits `damage` from Hitbox, so the existing `if not area is Hitbox` check in Hurtbox already matched it. **Nothing in Combat/Damage had to change to support projectiles** — a good sign the Hitbox/Hurtbox split was drawn in the right place.
  - **Targeting is an enum, not a subclass.** `TargetMode { RANDOM, NEAREST_ENEMY }` — different weapon *types* are different Weapon nodes with different exported values, not new scripts (Reusability Standard #4). NEAREST_ENEMY loops `get_nodes_in_group(enemy_group)` tracking a running `nearest_distance` (seeded to `INF`) alongside a separate `nearest_enemy`, then converts to a heading with `direction_to()` exactly once *after* the loop. Keeping the "comparison value" and the "answer" in two separate variables is the part that's easy to get wrong. Falls back to a random direction when the group is empty. Requires enemies to be in the group — set as a **global group** named `enemies` so it autocompletes project-wide.
  - **Two parenting gotchas, both real bugs we hit:** (1) projectiles are added to `get_tree().current_scene`, NOT `get_parent()` — parenting under a moving Player makes them inherit its transform and drag along instead of flying. (2) Because of that, a `get_parent()`-based self-damage guard silently never matches — hence the explicit `source` field, set by Weapon to `get_parent()`, compared as `area.get_parent() == source`.
  - Verified: projectiles auto-fire on an interval, track the nearest enemy, deal damage, and enemies die and despawn correctly.
- **Progression:** _(TBD)_
- **UI/HUD:** _(TBD)_

## Reusability Standards
Goal: build systems once, reuse across projects, stop rewriting things like 2D movement from scratch.

Check every new system against these before considering it "done":

1. **Self-contained, no hard scene references.** A system should never reach out via things like `get_node("../../Player/Sprite")`. It should be droppable into an empty scene and run without errors. If it throws null errors because some other specific node doesn't exist, it's coupled, not reusable.
2. **Signal-only communication (in/out).** Systems talk to the outside world only through signals (out) and exported variables (in) — never by reaching into another system's internals.
3. **Composition over monolith scripts.** Favor small components (Movement2D, Health, Hitbox/Hurtbox, StatModifiers, Inventory, etc.) as their own nodes/scripts, attached to a scene, rather than one big Player script that does everything. Swapping behavior = swapping a child node, not rewriting a class.
4. **Data lives in Resources, not hardcoded values.** Things like `WeaponData` or `EnemyData` should be custom `Resource` (`.tres`) files. Systems (Spawner, Weapon system, etc.) read whatever Resource they're given — new content = new `.tres` file, zero new code. This is what keeps "building systems" and "making content" as separate activities.
5. **Extract after first use, not before.** Build a system inside the current game first, but with the discipline of rules 1–4. Once it's used and proven, pull it out into the reusable `/addons/` folder. Don't try to pre-engineer the "perfect generic" version before it's been used once.

**Actual repo folder structure (as of now, files added as we go):**
```
vampire_survivor_thing/
├── addons/
│   ├── movement_2d/
│   ├── stat_system/
│   ├── health_system/
│   ├── event_bus/
│   ├── spawner/
│   └── weapon_system/
│
├── game/
│   ├── scenes/
│   │   ├── player/
│   │   ├── enemies/
│   │   ├── weapons/
│   │   ├── ui/
│   │   └── main/
│   ├── data/
│   │   ├── enemies/
│   │   ├── weapons/
│   │   └── stats/
│   └── scripts/
│
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
│
└── docs/
```
- `addons/` = reusable, game-agnostic systems. Never references anything in `game/`.
- `game/scenes/` = this game's scenes built from those systems.
- `game/data/` = `.tres` Resource files (enemy stats, weapon stats) — content with zero code.
- `assets/` = art/audio, added last per the gray-box-first rule.
- Currently one repo for this game. Decision made: keep everything in one repo for now (easier for a git/GDScript beginner than managing submodules), and only graduate a system out to its own repo once it's proven stable across more than one project.
- Empty folders don't get tracked by git — each needs at least one file (a `README.md` describing the folder, or `.gitkeep`) to persist through a commit/push.

## Dev Environment
- **Godot editor:** scene composition, node trees, signal wiring in the inspector, running/testing. No real substitute for this.
- **VS Code:** writing/reading GDScript, bulk folder restructuring, multi-file search across `/addons/`, git integration. Install the **godot-tools** extension and set it as the external editor in Godot (Editor Settings → General → Text Editor → External) for debugging/breakpoints support.
- Run both side by side: Godot for building/testing, VS Code for scripting and folder architecture.

## Version Control
- **Repo:** one repo for this game (`vampire_survivor_thing`), already created on GitHub and cloned locally on both a desktop and a laptop.
- **Multi-machine workflow:** always `git pull` before starting work, always commit + `git push` before stopping. If both machines get edited without syncing, resolve the merge conflict when it comes up — not dangerous, just needs attention.
- **Committing:** Godot has no built-in git UI. Using **VS Code's Source Control panel** (`Ctrl+Shift+G`) as the daily driver — stage, write a commit message, commit, then Push/Sync. Terminal (`git add .` / `git commit -m "..."` / `git push`) kept as a fallback for merge conflicts or anything the GUI doesn't make clear.
- **Godot-specific `.gitignore`:** should exclude the `.godot/` cache folder (regenerated automatically, machine-specific) but keep everything else.

## Working Rules
1. Gray-box everything before art.
2. One system per working session — checkpoint before switching.
3. Write the contract as soon as a system works, not after.
4. No content (specific weapons, enemies, art) until the loop is proven with placeholders.
5. Check every finished system against the Reusability Standards before moving on.

## Open Decisions
- [x] System communication pattern — resolved, see `docs/ADR-001-system-communication.md`
- [ ] Working title / theme (repo is currently named `vampire_survivor_thing`, placeholder)
- [ ] Art style direction (for later, post-gray-box)

## Where We Left Off
**Systems 1–6 are all done, tested, and contracted above — the core combat loop is playable.** Player moves, enemies spawn in a ring around them, weapons auto-fire at the nearest enemy, damage applies, enemies die and despawn. All in gray-box primitives, as intended.

Two pieces of game-specific glue live in `game/scripts/` (deliberately not in `addons/`, since they encode decisions specific to this game):
- `main.gd` — attached to `main.tscn`'s root, calls `GameState.start_run()`. Any other "on game start" wiring goes here.
- `enemy.gd` — attached to Enemy's root, turns a Hurtbox death into a full despawn plus `EventBus.enemy_died`.

`EventBus.enemy_died(position)` is emitted but has **zero listeners** — that's intentional and is the hook Progression plugs into next.

Next step: gray-box Progression (system #7 — XP, leveling, upgrade selection). It's the first system that makes the loop a *game* rather than a sandbox, and the first one that will consume an EventBus signal rather than just emitting one.
