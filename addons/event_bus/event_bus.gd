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
