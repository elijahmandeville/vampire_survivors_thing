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
## Respects Game State: only actually spawns while GameState.is_running(),
## so pausing the run correctly pauses spawning without needing to stop/
## restart the Timer itself.
## -----------------------------------------------------------------

@export var target: Node2D
@export var enemy_scene: PackedScene
@export var spawn_radius: float = 400.0
@export var min_spawn_distance: float = 300.0
@export var spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.5
@export var interval_decrease_rate: float = 0.0  # 0 = no difficulty scaling yet

@onready var timer: Timer = $Timer


func _ready() -> void:
	# TODO: Configure and start the Timer.
	#
	# Approach:
	#   1. timer.wait_time = spawn_interval
	#   2. timer.timeout.connect(_on_timer_timeout)
	#   3. timer.start()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timer_timeout)
	timer.start()


func _on_timer_timeout() -> void:
	# TODO: Spawn one enemy at a random point in a ring around `target`
	# (between min_spawn_distance and spawn_radius away from it — this
	# keeps enemies from popping in right on top of the target, similar
	# to how enemies appear just out of view in Vampire Survivors), but
	# only while the run is actually active.
	#
	# Approach:
	#   1. Guard: if target == null or not GameState.is_running(): return
	#      (still let the Timer keep ticking in the background — just
	#      skip spawning while there's nothing to track, or the run isn't
	#      active, rather than stopping/restarting the Timer itself)
	#   2. Pick a random point in the ring around the target's CURRENT
	#      position (read target.global_position fresh each time, since
	#      the target moves):
	#        var angle := randf() * TAU
	#        var distance := randf_range(min_spawn_distance, spawn_radius)
	#        var offset := Vector2(cos(angle), sin(angle)) * distance
	#   3. Instance and place it:
	#        var enemy := enemy_scene.instantiate()
	#        enemy.global_position = target.global_position + offset
	#        get_parent().add_child(enemy)
	#   4. Difficulty scaling (simple version): shrink the next interval a
	#      little, floored so it never goes below min_spawn_interval:
	#        timer.wait_time = max(timer.wait_time - interval_decrease_rate, min_spawn_interval)
	#      Leaving interval_decrease_rate at its default of 0 means no
	#      scaling happens yet — that's fine, tune it once the base loop
	#      feels right.
	if target == null or not GameState.is_running():
		return
	var angle := randf() * TAU
	var distance := randf_range(min_spawn_distance, spawn_radius)
	var offset := Vector2(cos(angle), sin(angle)) * distance
	var enemy := enemy_scene.instantiate()
	
	enemy.global_position = target.global_position + offset
	get_parent().add_child(enemy)
	
	timer.wait_time = max(timer.wait_time - interval_decrease_rate, min_spawn_interval)
