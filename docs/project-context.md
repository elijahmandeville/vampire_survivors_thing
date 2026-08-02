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
| 7 | Progression | XP, leveling, upgrade selection | **Done** (upgrade selection deferred to #8) |
| 8 | Enemy AI | Enemies chase the player | **Done** |
| 9 | Run End | Player death → game over | **Done** |
| 10 | Win Condition | Survive the run timer | **Done** |
| 11 | UI/HUD | Health bar, XP bar, timer, level | **Done** |
| 12 | Run End UI | Game over screen + restart | **Done** |
| 13 | Upgrade Selection | UpgradeData resources, level-up choice screen | **Done** |
| 14 | Art/Juice | Real art, animation, screen shake, VFX — last | Not started |

*Rule of thumb: a system isn't modular yet if it needs final art or another unfinished system to be testable in isolation.*

## System Communication Pattern
**Decided (see `docs/ADR-001-system-communication.md`).** Use all three, each for what it's good at:
- **Godot signals** — local, in-scene wiring (a component talking to its own parent/owner).
- **Autoload event bus** (`addons/event_bus/`) — global, many-to-many events any system can react to (`enemy_died`, `xp_gained`, `level_up`, `run_started`, `run_ended`, etc.).
- **Shared Resources** — continuous state (Stats, WeaponData, EnemyData), not one-off events.

Rule of thumb: if only this entity's own children need to know, use a local signal; if any other system might care, emit it on the bus.

## System Contracts
Once a system is gray-boxed and working, write a short contract for it here: what it takes in, what it sends out. This is what makes it swappable/extendable later without rot.

- **Game State:** IN — `start_run()`, `pause_run()`, `resume_run()`, `end_run(reason: String)`, `reset_run()`. OUT — `EventBus.run_started`, `run_paused`, `run_resumed`, `run_ended(reason)`. Readable state via `GameState.state`, `is_running()`, `is_paused()`. Autoload (`game/scripts/game_state.gd`, singleton name `GameState`). Verified: state walks READY → RUNNING → PAUSED → RUNNING → ENDED → READY as expected. **Also drives `get_tree().paused`** on every transition — this is the project-wide pause mechanism, so no other system implements pausing itself (see the resolved Open Decision below). Sets its own `process_mode = PROCESS_MODE_ALWAYS` in `_ready()`, or it would freeze itself and nothing could call `resume_run()`.
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
  | XpGem/Pickup | pickup | player_collector |
  | Player/Collector | player_collector | pickup |

  Layers `6 pickup` and `7 player_collector` were added for Progression. The Player's `Collector` Area2D is intentionally much larger than its body — that circle *is* the pickup radius, tunable by resizing one shape. Bitmask reminder for reading raw `.tscn` values: layer N = 2^(N-1), so `pickup` = 32 and `player_collector` = 64.

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
- **Progression:** XP is a *collectible*, Vampire-Survivors style — enemies drop gems the player walks over, rather than awarding XP instantly on death. That's a deliberate design call: the walk-toward-the-gem pull is what makes the genre's risk/reward tick. Four pieces, following the same detector/decider split as Hitbox/Hurtbox:
  - `Pickup` (`class_name Pickup`, `extends Area2D`, `addons/pickup_system/`) — IN: nothing exported; *which entity counts as a collector is decided entirely by Collision Layer/Mask*, not code. OUT: local signal `collected(collector)`. Knows nothing about XP — a coin, health potion, or ammo box is this same script under a different parent. Deliberately does NOT free itself, so the owner can play a sound/animation first.
  - `game/scripts/xp_gem.gd` — game glue on the gem's root. `@export var xp_value` (a bigger gem is a different Inspector value, not a different script). On `pickup.collected` → `EventBus.xp_gained.emit(xp_value)` → `queue_free()`.
  - `game/scripts/xp_drop_spawner.gd` — a child of main holding `@export var gem_scene`. Listens for `EventBus.enemy_died(position)` and drops a gem there. Its own node rather than more code in `main.gd`, so loot rules (drop chances, rare gems, health drops) can grow without main.gd becoming a junk drawer.
  - `Progression` (`class_name Progression`, `extends Node`, `addons/progression/`) — IN: `EventBus.xp_gained`, plus `@export base_xp_to_level` / `xp_curve_multiplier`. OUT: `EventBus.level_up(level)`. Readable state: `current_xp`, `level`, `xp_to_next`.
  - **Not an autoload**, same call as Stats: XP is per-run state, so a node inside the run resets by reloading the scene, where an autoload would carry a stale level into the next run unless something remembered to clear it.
  - Two details in the leveling math worth keeping: the level-up check is a `while`, not an `if`, so one big XP drop can cross two thresholds instead of silently swallowing the second; and `current_xp -= xp_to_next` (rather than resetting to 0) carries overflow XP forward. Cost per level is recomputed from scratch as `base * pow(multiplier, level - 1)` rather than accumulated, so any level's cost is derivable at any time — much easier to debug and to save/load later.
  - **Zero changes were needed to `enemy.gd` to add XP to the game.** It still just announces that it died. That's the ADR-001 bet paying off in practice, and the first time a system consumed a bus signal rather than only emitting one.
  - Verified: gems drop at corpses, are collected on contact with the Player's `Collector` area, and levels climb correctly.
- **Enemy AI:** `Follow2D` (`class_name Follow2D`, `extends CharacterBody2D`, `addons/follow_2d/`). IN — `@export speed`, `target_group` (default `"player"`), `stop_distance`. OUT — none. Finds its own target by group lookup rather than taking a node reference, so a Spawner-created enemy needs zero wiring; `Player`'s root is in a global group named `player`. Caches the target and re-resolves it via `is_instance_valid()` (a plain `== null` check won't catch an already-freed node). `stop_distance` keeps a swarm from grinding into one overlapping pile; contact Hitboxes still reach further, so damage is unaffected.
  - **Deliberate near-mirror of `Movement2D`** — identical shape, identical `move_and_slide()` at the end. The only difference is where `velocity` comes from: keyboard vs. a target's position. "Player-controlled" and "AI-controlled" turn out to differ by one expression.
  - **It IS the body** (extends CharacterBody2D) rather than being a child component, matching Movement2D. Consequence: a Godot node holds one script, so `enemy.gd` had to change from `extends CharacterBody2D` to `extends Follow2D` — chasing then came for free and the death-handling code was untouched. Cost of this choice: one movement behavior per entity, fixed by inheritance. Revisit only if an enemy needs to swap movement at runtime (a charger that winds up, a fleeer) — that's where composition would start earning its keep.
  - **Known gap:** neither `Follow2D` nor `Movement2D` guards on `GameState.is_running()`, so both keep moving through a pause or after the run ends. Harmless today; fix both together when Run End lands. Same fix incidentally stops `_find_target()` re-querying the group every frame once the player no longer exists.
- **Run End:** `game/scripts/player.gd` (`extends Movement2D` — same move `enemy.gd` made for `Follow2D`, since a node holds one script and game glue on an entity root has to extend that entity's movement component). IN — requires a child `Hurtbox`. OUT — `GameState.end_run("player_died")` → `EventBus.run_ended(reason)`. Exact mirror of `enemy.gd`, different decision: an enemy dying is routine, the player dying ends the run. Deliberately does **not** `queue_free()` the player — deleting it mid-frame would break everything holding a reference (Spawner's `target`, every Follow2D's cached `target`), and a game-over screen will want the body still on screen. Reason strings are plain identifiers, not player-facing text; `"time_up"` will come through the same door for the win condition.
- **Win Condition:** `game/scripts/run_timer.gd`, a plain `Node` child of main with its own child `Timer`. IN — `@export var run_duration` (seconds); starts on `EventBus.run_started`. OUT — `GameState.end_run("time_up")`, plus `get_time_left()` for the HUD to poll. Game glue, not an addon: "the run has a fixed length and surviving it wins" is a rule of *this* game, so depending on `GameState` is correct here — unlike Spawner/Weapon, which had that dependency removed.
  - **First listener `run_started` ever had.** GameState had been emitting it since system #1 with nothing on the other end, and adding a consumer required no change to GameState at all. The signal was already the seam.
  - `timer.one_shot = true` — the one place this differs from Spawner's and Weapon's repeating timers. Without it, it would restart and call `end_run()` again every `run_duration` seconds.
  - **Starts on `run_started`, not in `_ready()`.** Starting in `_ready()` would count the *scene's* lifetime rather than the run's — and child `_ready()` runs before the parent's, so `main.gd`'s `start_run()` hasn't even fired at that point.
  - Pausing needs no handling: the child Timer freezes with the tree, so paused time doesn't count against the run.
  - A win and a loss both travel the same path — `end_run(reason)` — with the reason string deciding which screen renders. That string was added back when dying was the only way a run could end.
- **UI/HUD (display half):** `game/scripts/hud.gd`, a `CanvasLayer` child of main with `HealthBar`/`XPBar` (ProgressBar) and `LevelLabel`/`TimerLabel` (Label) children. IN — `EventBus.player_health_changed` and `EventBus.xp_changed` (pushed), plus `@export var run_timer` polled in `_process`. OUT — **nothing.** Read-only by design: it draws state, takes no input, changes nothing.
  - **`CanvasLayer`, not `Control`** — draws in screen space, so it's unaffected by the player-following `Camera2D`. Adding the camera required no HUD changes at all.
  - **Pushed vs polled.** Health and XP arrive as signals: they change rarely, at moments something else already knows about. The run timer is polled every frame: it changes continuously, so a signal per frame would be noise and a signal per second would make the countdown tick in visible jumps. Rule of thumb — push for events, poll for continuously-varying values.
  - **Two new relays were needed, and that's the interesting part.** The prediction was that a read-only system wouldn't force changes underneath. Mostly true — but the HUD can't read the player's health directly, because `Hurtbox` calls `.duplicate()` on Stats at runtime, so `player_stats.tres` is NOT the instance taking damage, and walking `player.hurtbox.stats` would violate Standard #2. So `player.gd` now relays its local `health_changed` out as `EventBus.player_health_changed`, and Progression emits `EventBus.xp_changed`. Both are *additive* — no existing system was restructured — but it's worth noting that "read-only" didn't mean "zero changes."
  - **`xp_changed` is separate from `xp_gained` on purpose.** `xp_gained` is an event ("+3 XP happened", good for floating combat text); `xp_changed` is state ("you're at 2/8 toward level 3", which is what a bar needs). A listener can't derive the second from the first without duplicating Progression's math.
  - **Startup ordering is load-bearing.** HUD must sit *above* Player and Progression in main's child order, since Godot runs `_ready()` in tree order and both push their initial state there. Separately, `player.gd` calls its own handler by hand once after connecting — Hurtbox already emitted `health_changed` during its own `_ready()` (children run before parents), so connecting alone catches every future change but misses the starting value. General pattern: **when something joins late and needs current state, connect for updates AND read the value once.**
  - Debugging note for next time: symptoms were bars at 0% and labels blank — the `CanvasLayer` simply had no script attached. Worth checking before suspecting signal wiring.
  - `_format_time()` uses `floori(total / 60.0)`. Godot warns on plain integer division (`total / 60`) because it's usually accidental — here the truncation is the entire point, and `floori()` states that intent out loud instead of leaving it as an implicit side effect of `%d` formatting.
- **Run End UI:** `game/scripts/game_over_screen.gd`, a `CanvasLayer` child of main placed *below* HUD so it draws on top. IN — `EventBus.run_ended(reason)`, plus `TitleLabel` and `RestartButton` children. OUT — `GameState.reset_run()` then `get_tree().reload_current_scene()`. First UI that isn't read-only.
  - **`process_mode = PROCESS_MODE_ALWAYS`** is mandatory. `end_run()` freezes the tree, and this screen only appears afterward — without opting out, the button renders but never responds, which reads as a broken button rather than a paused one. Children inherit the mode, so the Button is covered.
  - **`reset_run()` must run BEFORE `reload_current_scene()`.** Autoloads survive scene reloads by design, so GameState would still be `ENDED` when the fresh scene loads; `main.gd` calls `start_run()`, its `if state != State.READY: return` guard fires, and the result is a scene that looks perfect and never starts, with nothing in the console. **This is the sharp edge of global state** — worth remembering anywhere an autoload holds run-scoped data. Everything else self-heals on reload because no other run-scoped state lives outside the scene.
  - Branches on the reason string, defaulting to defeat in `else` rather than testing `"player_died"` explicitly — so a future reason (`"quit"`, `"out_of_bounds"`) shows a neutral-to-negative screen rather than falsely congratulating the player. Fail toward the less wrong option.
- **Upgrade Selection:** The architecture question here was real — reusability (content as `.tres`, zero code) vs. open-endedness (upgrades that grant weapons, followers, status effects, not just numbers). **Resolved by paying per CATEGORY instead of per ITEM.**
  - `UpgradeData` (`class_name UpgradeData`, `extends Resource`, `addons/upgrade_system/`) — base class, never instanced directly. Holds `display_name`, `description`, `icon`, `weight`, and a virtual `apply(target: Node)` that does nothing. Each *kind* of effect is a subclass written once; each *instance* is a `.tres` with no code.
  - `UpgradeScreen` (`addons/upgrade_system/upgrade_screen.gd`, a `CanvasLayer`) — IN: `EventBus.level_up`, `@export upgrade_pool` / `target` / `choice_buttons`. OUT: `GameState.pause_run()`/`resume_run()`, `upgrade.apply(target)`, `EventBus.upgrade_applied`. **Never learns what an upgrade does** — it only calls `apply()`.
  - `StatUpgrade` (`game/scripts/upgrades/`) — category 1. `stat_name` + `amount`, applied via `stats.set(name, stats.get(name) + amount)`. Additive.
  - `WeaponUpgrade` (`game/scripts/upgrades/`) — category 2. `fire_interval_mult`, applied to the player's Weapon. **Adding it required zero changes to `UpgradeScreen`, `UpgradeData`, or `StatUpgrade`** — the design's first real test, and it passed.
  - **Subclasses live in `game/`, not `addons/`.** What an upgrade *does* is content and content is game-specific; only the machinery is reusable. This is also why `WeaponUpgrade` can reach the Weapon node directly without dragging weapon numbers into `Stats` and coupling two addons.
  - **First thing to call `GameState.pause_run()`** — it had existed unused since system #1, exactly like `end_run()` before Run End. Needs `PROCESS_MODE_ALWAYS` for the same reason as the game-over screen.
  - `pending_levels` counter handles one XP drop crossing two thresholds: if the screen is already open, bank the level and re-present after the current pick resolves. Same reasoning as the `while` loop in `progression.gd`.
  - `bind(i)` on each button's `pressed` signal — pre-loads an argument at connect time so three identical buttons can share one handler and still be distinguishable.
- **Making upgrades actually DO something (the non-obvious half):**
  - **A value with a writer and no reader looks exactly like a working feature.** Both `move_speed` and `damage_mult` were inert when first upgraded: the `.tres` applied cleanly, the number changed, the game played identically. No error, no warning. `max_health` worked only because the HUD happened to read it.
  - **Checklist for any new stat upgrade:** (1) what number changes, (2) *what reads it* — if nothing does, the upgrade is a no-op, (3) is it read live or cached once at `_ready()`, (4) should it live on `Stats` (player-wide) or on the component (component-specific)?
  - **The fix is a push, not a pull.** `player.gd._sync_from_stats()` copies `stats.move_speed` → `Movement2D.speed` and `stats.damage_mult` → `Weapon.damage_mult`, called on `_ready()` and on `EventBus.upgrade_applied`. Addons expose plain numbers; game glue copies between them. `movement_2d.gd` had documented exactly this since system #3 and nothing had done it until now.
  - **`EventBus.upgrade_applied` exists because `stats.set()` is silent** — a plain property write with no signal. Carries no arguments on purpose, so listeners re-read whatever they care about and future upgrade categories need no new plumbing.
  - **Damage went through the Weapon, not the damage system.** `Weapon.damage_mult` scales each projectile's own `damage` at spawn. Since every projectile is a fresh instance this is safe, and **Hitbox/Hurtbox needed no changes at all** — versus threading the attacker's Stats through to the defender's Hurtbox, which would have touched the whole pipeline.
  - **`Weapon.fire_interval` uses a property setter**, updating both the field and the running Timer's `wait_time` (and clamping to `min_fire_interval`). The Timer copies `wait_time` once, so writing the field alone would have been another silent no-op. A setter makes the two impossible to desync — nobody has to remember.
  - **Additive vs multiplicative:** additive for quantities (health, damage, speed), multiplicative for intervals and rates. Subtracting a flat amount from `fire_interval` would reach zero and go negative, and each pick would be worth progressively more (1.0→0.85 is +18% rate; 0.30→0.15 doubles it). Multiplying approaches zero without reaching it and keeps every pick worth the same.

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
│   ├── weapon_system/
│   ├── pickup_system/
│   ├── progression/
│   └── follow_2d/
│
├── game/
│   ├── scenes/
│   │   ├── player/
│   │   ├── enemies/
│   │   ├── weapons/
│   │   ├── pickups/
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
- [x] **How systems should respect pause/run state — RESOLVED: use Godot's built-in pause.** `GameState` now drives `get_tree().paused` on every state change; the engine stops `_process`, `_physics_process`, timers, and input on every node whose `process_mode` inherits the default. Spawner and Weapon had their `is_running()` guards **deleted** — they no longer reference `GameState` at all and are genuinely droppable into a project that has no such autoload (Reusability Standard #1 restored). `Movement2D` and `Follow2D` needed no changes; they simply stop being called. Rejected alternatives: spreading `is_running()` into the movement addons (would have deepened the coupling in two more files), and an `@export var require_running` flag (opt-in per instance, but still leaves every system re-implementing pause). Tradeoff accepted: pause is all-or-nothing per node, so anything that must survive a pause opts out with `process_mode = PROCESS_MODE_ALWAYS` — `GameState` itself does this, or it would freeze itself and nothing could ever call `resume_run()`. A pause menu and game-over screen will need the same.
- [x] **Art style direction — DECIDED, see "Art Direction & Theme" below.**
- [ ] Working title / theme (repo is currently named `vampire_survivor_thing`, placeholder — the netrunner framing should suggest something better)

## Art Direction & Theme
**Japanese cyberpunk / dystopian netrunner.** Decided from a reference set of five pieces (dense neon street with a ronin figure, vertical signage-choked alleys, a grimy jack-in room, a rainy industrial street).

### The framing device
**The player is a netrunner in a chair. Every level is a simulation he jacks into.** The main menu is that room — dentist chair, IV drips, CRTs, cables into the skull, a corporate logo on a screen showing something you'd rather not see.

This is **load-bearing, not flavor**, for three reasons:

1. **It justifies the sparse arena.** A survivors-like needs a hundred entities to read instantly at a glance. The reference art is dense, low-contrast environment art — beautiful, and actively hostile to that. Rendering an alley as the arena floor would make the game unplayable noise. But "you are inside a machine" makes a grid floor, void, and abstract geometry *correct* rather than unfinished.
2. **It makes gray-box shapes diegetic.** Enemies as daemons/ICE — wireframes, glitching polygons — is a legitimate final look, not a placeholder. The current gray-box is closer to shippable than it looks.
3. **It splits the game into two visual registers, each cheap in a different way.** The chair room is *one* detailed static painting made once. The simulation is geometry and glow, generated and cheap at scale. Grubby analog reality vs. clean abstract digital — the contrast is itself an asset.

Theming that falls out of it: weapons are programs you load, upgrades are daemons you install, unlocks are software. Maps onto the existing `UpgradeData` category system directly.

### Palette
Four of the five references share a palette, and it is NOT saturated Blade Runner neon — it's **desaturated teal-green with warm signal accents**. Deliberately chosen over the hot-magenta register: a screen filling with enemies over hot neon becomes unreadable, whereas a dim green-grey world leaves the entities room to own the saturated colors.

| Role | Hex | Used for |
|---|---|---|
| World base | `#0E1A16` | Ground, void |
| World mid | `#2A3B33` | Grid lines, structure |
| Warm signal | `#E8B33A` | Projectiles, player-side effects |
| Alert | `#D2422F` | Enemies |
| Cool signal | `#4FD8C8` | Player accent, XP, UI |
| Magenta | `#E23A8C` | Sparingly — rare/dangerous only |
| Player core | `#E0F0EC` | Near-white; always the brightest thing on screen |

**Legibility rule that outlasts the placeholders:** the player is the lightest, highest-contrast object on screen at all times. Enemies read as a warm mass, not as individuals. Pickups are cool-toned so they never register as a threat at a glance. Value and temperature do the work — not detail — which is why it survives any change in style.

Current placeholders in `assets/sprites/` are already in this palette with a soft glow baked in. Next step for feel: a `WorldEnvironment` with Glow enabled, so bright pixels bloom for real instead of relying on baked halos.

## Display & Fairness
**Display → Stretch → Aspect is `keep`** (was `expand`). Every player sees exactly the same amount of world regardless of window size or monitor; wider aspect ratios get pillarboxed instead of revealing more map. Matches what Vampire Survivors does.

This isn't cosmetic — it's a balance decision. Under `expand`, an ultrawide monitor would see enemies approaching sooner than a 16:9 one, a real competitive advantage. Deriving spawn distance from viewport size would have *preserved* that advantage while only fixing the visual pop-in; pinning the visible area fixes the actual problem.

Consequence worth remembering: **`spawner.gd`'s distances are now written against a fixed visible area** — base viewport 1152×648, half-diagonal ≈661px, so `min_spawn_distance = 700` and `spawn_radius = 900` put spawns just offscreen. If Stretch Aspect ever changes, or a runtime camera zoom gets added, those numbers stop meaning what they say and spawning would need to derive from `get_viewport_rect().size / camera.zoom` instead.

The HUD is a `CanvasLayer`, which draws in screen space and is unaffected by the camera — so adding a player-following `Camera2D` needed no HUD changes at all.

## Deferred Work & Known Issues
Small things consciously left undone, so they don't get rediscovered as surprises. None are bugs in working systems — they're scope boundaries.

| Item | Where | Why deferred / when to fix |
|---|---|---|
| ~~Movement doesn't stop on pause/run end~~ | — | **Fixed** by the engine-pause switch. |
| ~~`_find_target()` re-queries the group every frame when no target exists~~ | — | **Fixed** incidentally — `_physics_process` no longer runs once the run ends. |
| ~~Player death does nothing~~ | — | **Done** — that's the Run End system. |
| ~~No way to restart after death~~ | — | **Done** — `game_over_screen.gd`. |
| ~~`EventBus.level_up` has no listeners~~ | — | **Done** — `UpgradeScreen` consumes it. |
| ~~`damage_mult` unused~~ | — | **Done** — read by `player.gd._sync_from_stats()` into `Weapon.damage_mult`. Still never read by `Stats.take_damage()`, which is fine: it's an *outgoing* multiplier, applied at the attacker's end. |
| Upgrades must be added to `upgrade_pool` by hand | `main.tscn` | Fine at 4 upgrades; tedious at 30. Replaceable with a script that scans `game/data/upgrades/` at startup, making "drop in a `.tres`" genuinely the whole process. |
| Damage upgrades feel like nothing until a breakpoint | — | Enemies have 100 HP, projectiles do 50 — two hits. +15% does nothing visible until enough stacks cross to one-shot. Usual genre fix is higher enemy HP so damage scales smoothly rather than in jumps. |
| No multi-weapon support | `player.gd` | `get_weapon()` returns one Weapon. Becomes `get_weapons() -> Array` when the player can hold several, at which point `WeaponUpgrade` decides whether it applies to one or all. |
| No upgrade selection | — | Deliberately cut from Progression. Needs an `UpgradeData` Resource + a UI screen consuming `EventBus.level_up`. |
| ~~No win condition~~ | — | **Done** — `run_timer.gd` calls `end_run("time_up")`. |
| `get_time_left()` returns `run_duration` on both paths | `run_timer.gd` | Typo; second `return` should be `timer.time_left`. Silent until the HUD polls it. |
| Gems have no magnet | `pickup.gd` | You must walk directly onto them. Vampire Survivors pulls them in past a radius. Pure feel, zero blockers. |
| Enemies overlap each other | `follow_2d.gd` | They physically collide but still bunch up. Real fix is separation steering — worth doing only if it looks bad at higher spawn counts. |
| `enemy_stats.tres` `damage_mult` unused | `stats.gd` | `take_damage()` never reads it. Either wire it up or remove the field so it stops implying behavior that doesn't exist. |

## Where We Left Off
**Systems 1–7 are done, tested, and contracted above — the full core loop runs.** Player moves, enemies spawn in a ring around them, weapons auto-fire at the nearest enemy, enemies take damage and die, they drop XP gems, the player collects them and levels up. All in gray-box primitives, as intended.

Game-specific glue lives in `game/scripts/` (deliberately not in `addons/` — each encodes a decision specific to *this* game):
- `main.gd` — on `main.tscn`'s root, calls `GameState.start_run()`. Other "on game start" wiring goes here.
- `enemy.gd` — turns a Hurtbox death into a full despawn plus `EventBus.enemy_died`.
- `xp_gem.gd` — turns a Pickup collection into `EventBus.xp_gained`.
- `xp_drop_spawner.gd` — turns `enemy_died` into a gem on the ground.

`EventBus.level_up(level)` is emitted with **zero listeners** — intentional, and the hook UI/HUD plugs into next. (The same was true of `enemy_died` before Progression, and adding XP required no change to `enemy.gd` at all.)

Enemies now chase (`Follow2D`), so the game has actual threat for the first time — contact damage matters and the ring-spawn finally means something.

**Decision made:** UI/HUD was deliberately pushed back behind the remaining gameplay logic. A health bar showing 100 forever teaches nothing; better to have real stakes before building anything to display them.

Everything consciously left undone lives in **Deferred Work & Known Issues** above, rather than in this section — that table survives between sessions, this paragraph gets rewritten each time.

### Pick up here — content and feel
**Every system in the plan is built.** Move, spawn, chase, shoot, kill, drop XP, collect, level, choose an upgrade, win or lose, restart. Thirteen systems, all gray-boxed, all contracted above. There is no longer a "next system" in the original dependency order — what's left is content, feel, and the deferred items in the table above.

Reasonable next directions, roughly in order of how much they'd change the game:

1. **Multi-shot** (`projectile_count` + spread on `weapon.gd`), then a `WeaponUpgrade` for it. Not an upgrade problem — the weapon fires exactly one projectile per timeout, so there's no number to raise yet. This is the biggest change to how combat feels.
2. **A second weapon type.** The `TargetMode` enum and `projectile_scene` export were built for this and have never been exercised with more than one weapon. Likely surfaces whatever's wrong with the "one Weapon per player" assumption.
3. **Difficulty scaling.** `Spawner.interval_decrease_rate` exists and defaults to 0, so the game never gets harder. One number away from a difficulty curve.
4. **Balance pass.** Enemy HP, projectile damage, XP curve, upgrade increments — all guesses, none play-tested against each other. Worth doing after multi-shot, since that shifts everything.
5. **Art direction** — the gray-box rule says this comes last, and it's now genuinely unblocked. Elijah has noted art direction will drive what weapons and upgrades should be, so ideation here feeds back into 1 and 2.

### Superseded — Upgrade Selection (system #13, now done)
**The loop is closed.** Start a run, play it, win or lose it, restart — all without touching the editor. Twelve systems, all gray-boxed, all contracted above.

`EventBus.level_up` is now the only signal still emitting into the void, and Upgrade Selection is what consumes it. It's the last *major* system, and the most different from everything so far:

- It's the first system that **mutates another entity's state** rather than announcing something. Every system so far either owned its data or reported on it; this one reaches out and changes the player's `Stats`.
- It's the first that **pauses the game deliberately** as part of normal play, rather than to end it. `GameState.pause_run()` exists and — like `end_run()` before Run End — has never been called.
- It needs a genuinely new piece of architecture: an **`UpgradeData` Resource** type, and a pool of `.tres` files to draw choices from. This is the first real test of Reusability Standard #4 ("new content = new `.tres`, zero new code"), which has been asserted since day one but never actually exercised — every `.tres` so far has been a Stats block, not content.

Design questions worth settling before scaffolding: how an upgrade expresses its effect (a stat name + amount? a script per upgrade?), whether upgrades can repeat or stack, and how many choices to present. The "stat name + amount" version is the one that keeps content in `.tres` files; anything script-based moves content back into code.

**Also worth doing around here:** `Stats.damage_mult` has existed since system #2 and is still never read by `take_damage()`. An upgrade that increases damage is the obvious moment to either wire it up or delete the field.
