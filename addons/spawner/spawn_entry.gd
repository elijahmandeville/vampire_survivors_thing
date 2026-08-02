class_name SpawnEntry
extends Resource
## SpawnEntry
## -----------------------------------------------------------------
## One row of a spawn table: "this enemy, this common, between these
## times." Pure data — a .tres per enemy type per phase, no code.
##
## This is what breaks Spawner's one-enemy-only limit. Before, Spawner had
## a single `enemy_scene`, so a second enemy type was literally impossible
## without changing the script. Now the script reads a table it knows
## nothing about, and new enemies are new .tres files (Standard #4).
##
## The time window is what turns a flat stream into a RUN. Weak drones
## early, heavier things fading in at 60s, the early trash fading out at
## 180s — that arc is the difference between a game and a shooting range.
## -----------------------------------------------------------------

## What to spawn.
@export var enemy_scene: PackedScene

## Relative likelihood versus other ELIGIBLE entries. Weights don't need
## to add up to anything — an entry at 3.0 is simply three times as likely
## as one at 1.0 among whatever else is currently in the window.
@export var weight: float = 1.0

## Seconds into the run before this can appear. 0 = from the start.
@export var start_time: float = 0.0

## Seconds into the run after which this stops appearing.
## Negative = never expires.
##
## Retiring early enemies matters as much as introducing late ones: if
## drones never stop spawning, late-run difficulty gets diluted by trash
## the player one-shots, and the swarm stops feeling like an escalation.
@export var end_time: float = -1.0


## True if `elapsed` (seconds since the run began) falls inside this
## entry's window.
func is_active_at(elapsed: float) -> bool:
	if elapsed < start_time:
		return false
	if end_time >= 0.0 and elapsed > end_time:
		return false
	return true
