# ADR-001: System Communication Pattern

**Status:** Proposed
**Date:** 2026-07-23
**Deciders:** Elijah

## Context
Nine systems (Game State, Stats, Movement/Input, Combat/Damage, Spawner, Weapons/Abilities, Progression, UI/HUD, Art/Juice) need to talk to each other without becoming coupled. Reusability Standard #2 already requires "signal-only communication (in/out)" — the open question is *which kind* of signal wiring to use, and whether one pattern has to win outright.

Two shapes of communication actually show up in this game:
1. **Local, one-to-few:** something happens inside one entity and a sibling/parent needs to know (a Hurtbox tells its own Health node it was hit).
2. **Global, many-to-many:** something happens and several unrelated systems all care (an enemy dies → Spawner decrements its alive count, Progression grants XP, UI updates the kill counter, Audio/VFX plays a death effect).

## Decision
Use **all three tools, each for what it's good at**, rather than picking a single winner:

- **Godot signals** for local, in-scene wiring (component to its own parent/owner).
- **An autoload event bus** for global, cross-system events that multiple unrelated systems need to react to.
- **Shared Resources** for continuous state, not events (this is already how Stats/WeaponData/EnemyData are planned).

This isn't a compromise so much as recognizing these three solve different problems — event ≠ event ≠ state.

## Options Considered

### Option A: Godot Signals only
| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Scalability to many-to-many | Poor — requires chaining signals up through parents or grabbing direct references, which reintroduces coupling |
| Fits reusability rule #1 (no hard scene refs) | Breaks it once events need to cross unrelated branches of the tree |
| Beginner friendliness | High for local cases, confusing once you need "everyone hears this" |

**Pros:** Native, no extra code, great editor tooling (Inspector-visible connections).
**Cons:** Doesn't scale to "many systems care about one event" without either passing references around or bubbling signals through intermediate nodes — both violate the self-contained/no-hard-reference rule.

### Option B: Autoload/Singleton Event Bus only
| Dimension | Assessment |
|---|---|
| Complexity | Low-Med (one new autoload, one signal per global event) |
| Scalability to many-to-many | Excellent — any system can `EventBus.enemy_died.connect(...)` without knowing who else is listening or where the emitter lives |
| Fits reusability rule #1 | Very well — systems never reach into each other, they only touch the bus |
| Beginner friendliness | Easy once the pattern clicks; slightly more ceremony for simple local cases |

**Pros:** Fully decoupled, matches "droppable into an empty scene" rule perfectly, one obvious place to look for all cross-system events.
**Cons:** Overkill/noisy for tightly-local interactions (e.g. a Hurtbox talking to the Health node sitting right next to it) — everything funneling through one global object gets messy fast.

### Option C: Shared Resource only
| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Scalability to many-to-many | Poor for *events* — Resources hold state well but have no natural "this just happened" broadcast; you'd end up polling or bolting signals onto the Resource anyway |
| Fits reusability rule #4 (data in Resources) | Good — this is really a data-layer answer, not a communication-layer answer |
| Beginner friendliness | Easy to reason about for values like health/speed, awkward for discrete moments like "enemy died" |

**Pros:** Perfect for Stats/EnemyData/WeaponData — data other systems read/write continuously.
**Cons:** Not actually a substitute for signals/events; conflating the two leads to polling hacks.

## Trade-off Analysis
The three options aren't really competing — they answer different questions ("something happened locally," "something happened globally," "what is the current value"). Forcing a single pattern to cover all three either breaks the no-hard-reference rule (pure signals for global events) or adds ceremony where it isn't needed (event bus for local component wiring). Using each where it fits keeps every system's contract simple: local signals for its own children, emit-only onto the event bus for anything another system might care about, Resources for data it reads.

## Consequences
- **Easier:** every system's "contract" section becomes concrete — list the local signals it emits/listens to, list the global events it emits/listens to on the bus, list the Resources it reads/writes. No ambiguity about which channel a given interaction should use.
- **Easier:** new systems can be dropped in and wired up by just connecting to existing bus events (e.g., a future Achievements system just listens to `enemy_died`, `level_up`, etc. — zero changes to existing systems).
- **Harder:** need one small rule of thumb to avoid bikeshedding later — *if only this entity's own children need to know, use a local signal; if any other system might care, put it on the bus.*
- **Revisit:** once a few systems are gray-boxed, confirm the event bus's list of global events isn't turning into a dumping ground — if it gets bloated, consider splitting into topic-specific buses (e.g. `CombatEvents`, `ProgressionEvents`).

## Action Items
1. [ ] Create `addons/event_bus/event_bus.gd` as an autoload singleton with a first pass at global signals: `enemy_died`, `player_died`, `xp_gained`, `level_up`, `run_started`, `run_ended`.
2. [ ] Register it as an autoload in Project Settings → Autoload.
3. [ ] Update each system's contract in `project-context.md` to note local signals vs. bus events vs. Resources it touches, as each system gets gray-boxed.
4. [ ] Update `project-context.md` Open Decisions to mark this resolved.
