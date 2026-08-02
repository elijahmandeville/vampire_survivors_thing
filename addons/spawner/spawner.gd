class_name Spawner
extends Node2D
## Spawner
## -----------------------------------------------------------------
## System #5 — Spawner (enemy waves, timing, difficulty scaling)
##
## Contract:
##   IN:  @export var target — a Node2D whose position spawns are
##        centered around every tick (e.g. the Player). Not hardcoded to
##        "the Player" specifically — this script only knows it's tracking
##        SOME Node2D, wired from the outside in main.tscn (same pattern
##        as Movement2D not knowing Stats exists — keeps this addon usable
##        in a project that tracks something else entirely, like a boss
##        arena's center).
##        @export var enemy_scene — a PackedScene to instance. Not
##        hardcoded to "Enemy" specifically (Reusability Standard #4).
##        @export var spawn_radius, min_spawn_distance, spawn_interval,
##        min_spawn_interval, interval_decrease_rate — timing/placement/
##        difficulty knobs, all tunable in the Inspector.
##   OUT: none yet — spawned enemies are just added to the scene tree.
##        Add a signal later (e.g. enemy_spawned) only if something
##        downstream actually needs to react to it.
##
## Self-contained: since `target` is handed in from outside rather than
## looked up by name, this script never reaches into the scene tree for
## anything specific — set `target` to null and it simply won't spawn
## (see the guard below), rather than erroring.
##
## Requires one thing to be set up in the scene: a child node named
## exactly "Timer" (Godot's built-in Timer type). Same idea as Hitbox/
## Hurtbox requiring a CollisionShape2D child — this script drives the
## Timer's behavior but doesn't create the node itself.
##
## Pausing needs no code here. This used to guard on GameState.is_running(),
## which worked but made a reusable addon depend on an autoload that only
## exists in one game. Now GameState drives get_tree().paused instead, and
## the engine stops this node's Timer for us. Nothing to remember, and this
## script drops into a fresh project with no GameState at all.
## -----------------------------------------------------------------

@export var target: Node2D

## What can spawn, how likely, and when. Replaces the old single
## `enemy_scene` — see spawn_entry.gd.
@export var spawn_table: Array[SpawnEntry] = []

## Spawns per second across the run. X axis is run PROGRESS (0 = start,
## 1 = difficulty_ramp_time), Y is the rate at that moment.
##
## A Curve rather than a number because difficulty isn't linear. Godot
## gives you a visual editor for this, so the pacing of the whole run —
## calm open, mid-run pressure, a nasty final stretch — becomes something
## you draw and feel rather than a formula you reason about. Drag points,
## play, adjust.
##
## Suggested starting shape: 0.5 at X=0 rising to about 8 at X=1, with an
## ease-in so the first minute stays breathable.
@export var spawn_rate_curve: Curve

## Seconds until the curve reaches X=1. Past this, rate stays at the
## curve's end value. Should normally match RunTimer.run_duration.
@export var difficulty_ramp_time: float = 300.0

## Seconds since the run started. Not exported — measured, not configured.
##
## Counted here rather than read from RunTimer so this addon needs no
## reference to a game-specific node. It also self-corrects for pausing
## for free: _process stops while the tree is paused, so paused time
## simply never accumulates.
var elapsed: float = 0.0
## Sized against the base viewport (1152x648), whose half-diagonal is ~661
## px — the distance from the player at screen centre to a corner. Spawning
## further out than that guarantees enemies appear offscreen and walk in,
## instead of popping into existence in view.
##
## This only stays true because Display > Stretch > Aspect is "keep", which
## pins how much world is visible regardless of window size. If that ever
## changes to "expand", these numbers stop meaning what they say.
@export var spawn_radius: float = 900.0
@export var min_spawn_distance: float = 700.0

## Floor on the gap between spawns, so a runaway curve can't try to spawn
## every frame. Same protective role as Weapon.min_fire_interval.
@export var min_spawn_interval: float = 0.05

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	_update_wait_time()
	timer.start()


func _process(delta: float) -> void:
	# Frozen automatically while the tree is paused, so this measures time
	# spent actually PLAYING rather than wall-clock time.
	elapsed += delta


## Seconds to wait before the next spawn, read off the difficulty curve.
func _update_wait_time() -> void:
	if spawn_rate_curve == null:
		timer.wait_time = 1.0
		return
	var progress := clampf(elapsed / difficulty_ramp_time, 0.0, 1.0)
	var rate := spawn_rate_curve.sample(progress)
	if rate <= 0.0:
		timer.wait_time = 1.0
	else:
		timer.wait_time = maxf(1.0 / rate, min_spawn_interval)


## Weighted random pick from whichever entries are currently in their time
## window. Returns null if nothing is eligible.
func _pick_enemy_scene() -> PackedScene:
	# HOW THE WALK WORKS: picture the weights laid end to end on a line —
	# 3.0, then 1.0, then 1.0, total 5.0. A uniform roll in 0..5 lands
	# inside one of the segments, and the wider the segment the likelier
	# it is. Subtracting each weight in turn is just measuring along that
	# line until you've used up the roll.
	var eligible: Array[SpawnEntry] = []
	var total_weight := 0.0
	for entry in spawn_table:
		if entry == null or entry.enemy_scene == null:
			continue
		if not entry.is_active_at(elapsed):
			continue
		eligible.append(entry)
		total_weight += entry.weight
	if eligible.is_empty() or total_weight <= 0.0:
		return null
	var roll := randf() * total_weight
	for entry in eligible:
		roll -= entry.weight
		if roll <= 0.0:
			return entry.enemy_scene
	return eligible[0].enemy_scene


## Spawns one enemy per tick, in a ring around `target` so it arrives from
## offscreen rather than popping into view.
func _on_timer_timeout() -> void:
	# Recompute the gap every tick — that's what makes the curve continuous
	# rather than a one-time setting. Do it FIRST so it happens even on the
	# frames where nothing spawns.
	_update_wait_time()

	if target == null:
		return

	var scene := _pick_enemy_scene()
	if scene == null:
		return

	var angle := randf() * TAU
	var distance := randf_range(min_spawn_distance, spawn_radius)
	var offset := Vector2(cos(angle), sin(angle)) * distance
	var enemy := scene.instantiate()

	enemy.global_position = target.global_position + offset
	get_parent().add_child(enemy)
