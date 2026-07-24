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
| 4 | Combat/Damage | Hit detection, damage application, death handling | In progress |
| 5 | Spawner | Enemy waves, timing, difficulty scaling | Not started |
| 6 | Weapons/Abilities | Attack firing, upgrades, combos | Not started |
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
- **Combat/Damage:** _(TBD)_
- **Spawner:** _(TBD)_
- **Weapons/Abilities:** _(TBD)_
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
│   └── spawner/
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
Folder skeleton is in place. System communication pattern decided (signals for local, event bus for global, Resources for state) — `EventBus` autoload built and registered. Game State, Stats, and Movement/Input are all gray-boxed, tested, and their contracts are written above. Next step: gray-box Combat/Damage (system #4 — hit detection, damage application, death handling).
