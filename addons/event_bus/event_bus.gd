extends Node
## EventBus
## -----------------------------------------------------------------
## Global, many-to-many signal bus (see docs/ADR-001-system-communication.md).
## Registered as an autoload singleton — any script can reach this by
## typing `EventBus` from anywhere, no get_node() or reference needed.
##
## Rule of thumb: if only one entity's own children need to know something
## happened, use a local signal instead. Only put events here if more than
## one *system* might care.
##
## Signals get added here as each system that needs them gets built —
## don't pre-add events for systems that don't exist yet.
## -----------------------------------------------------------------

## Emitted by GameState when a run begins.
signal run_started

## Emitted by GameState when a run is paused.
signal run_paused

## Emitted by GameState when a paused run resumes.
signal run_resumed

## Emitted by GameState when a run ends. `reason` is a plain string for now
## (e.g. "player_died", "time_up") — good enough until something more
## structured is needed.
signal run_ended(reason: String)

## Emitted by an enemy right before it despawns. `position` is where it died,
## so Progression can drop an XP gem there later without the enemy itself
## needing to know Progression exists. More than one system will care about
## this (XP, kill counter, UI), which is exactly why it belongs on the bus
## rather than being a local signal.
signal enemy_died(position: Vector2)

## Emitted by an XP pickup when the player collects it. Progression listens
## for this; UI will too, later. Note the pickup emits this rather than
## calling Progression directly — that's the whole point of the bus: the
## gem doesn't need to know Progression exists, or that only one of it does.
signal xp_gained(amount: int)

## Emitted by Progression when enough XP accumulates to cross a threshold.
## The upgrade-selection screen is what will eventually consume this.
signal level_up(level: int)

## Emitted by player.gd, relaying its own Stats.health_changed outward.
##
## Why a relay instead of the HUD reading the player's Stats directly:
## Stats is a per-instance Resource and Hurtbox calls .duplicate() on it at
## runtime, so the .tres file on disk is NOT the instance taking damage.
## The only way to reach the live one is through the entity that owns it —
## and having the HUD walk `player.hurtbox.stats` would be exactly the
## internals-grabbing Reusability Standard #2 rules out. So the player
## announces its own health, and anything that cares listens.
##
## Player-specific on purpose: enemies emit no such signal. A HUD tracking
## "the" health only makes sense for the one entity the camera follows.
signal player_health_changed(current_health: float, max_health: float)

## Emitted by Progression whenever XP or level changes — including on the
## same frame as level_up.
##
## Separate from xp_gained because the two answer different questions:
## xp_gained says "+3 XP just happened" (an event, good for floating combat
## text), while this says "you are now at 2/8 toward level 3" (state, which
## is what a bar actually needs to draw itself). A listener can't derive the
## second from the first without duplicating Progression's own math.
signal xp_changed(current_xp: int, xp_to_next: int, level: int)
