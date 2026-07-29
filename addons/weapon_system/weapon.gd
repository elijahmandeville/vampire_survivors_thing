class_name Weapon
extends Node2D
## Weapon
## -----------------------------------------------------------------
## System #6 — Weapons/Abilities (attack firing)
##
## Contract:
##   IN:  @export var projectile_scene — a PackedScene whose root is a
##        Projectile (or anything with a `direction` property and
##        Hitbox-derived damage). Not hardcoded to one specific weapon —
##        a new weapon is a new projectile scene handed to this same
##        script, matches Reusability Standard #4.
##        @export var fire_interval — seconds between shots.
##   OUT: none yet.
##
## Meant to be a child of whatever should fire it (e.g. Player) — its own
## global_position becomes the firing origin automatically, since it
## inherits the parent's transform. Requires a child Timer node, same
## pattern as Spawner.
##
## IMPORTANT: spawned projectiles get added to get_tree().current_scene,
## NOT to get_parent(). If Weapon is a child of a moving Player and a
## projectile were added as a sibling/child under Player instead, the
## projectile would inherit the Player's transform and drag along with
## the Player's movement instead of flying independently through the
## world. get_tree().current_scene is Godot's built-in reference to
## whatever scene is currently running (main.tscn's root, here) — a
## generic engine API, not a hardcoded reference to a specific named
## node, so this still doesn't know anything about "main" or "Player"
## specifically.
##
## Pausing needs no code here — see the same note in spawner.gd. GameState
## drives get_tree().paused, so the engine stops this node's Timer, and
## this script has no dependency on any autoload.
## -----------------------------------------------------------------

## Targeting: RANDOM fires in a random direction (good for an AoE-on-the-
## ground weapon type); NEAREST_ENEMY aims at whatever's currently
## closest. Different weapon TYPES are just different Weapon nodes/scenes
## with different exported values — no new script needed per weapon
## (Reusability Standard #4).
enum TargetMode { RANDOM, NEAREST_ENEMY }

@export var projectile_scene: PackedScene
@export var fire_interval: float = 1.0
@export var target_mode: TargetMode = TargetMode.RANDOM
@export var enemy_group: String = "enemies"  # group NEAREST_ENEMY searches

## Scales the damage of every projectile this weapon fires. 1.0 = the
## projectile scene's own damage, unchanged.
##
## A plain float, NOT a reference to a Stats resource — this addon still
## knows nothing about the Stats system and drops into a project without
## one. Whoever owns the weapon syncs this from outside (player.gd does),
## the same "sync from outside" pattern movement_2d.gd documents for speed.
##
## Applied at spawn time rather than by the damage system, because each
## projectile is a fresh instance — scaling its own `damage` is safe and
## needed no changes at all to Hitbox or Hurtbox.
@export var damage_mult: float = 1.0

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.wait_time = fire_interval
	timer.timeout.connect(_on_timer_timeout)
	timer.start()


func _on_timer_timeout() -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate()

	projectile.global_position = global_position
	projectile.direction = _get_fire_direction()
	projectile.source = get_parent()
	projectile.damage *= damage_mult
	get_tree().current_scene.add_child(projectile)


func _get_fire_direction() -> Vector2:
	if target_mode == TargetMode.RANDOM:
		return Vector2.RIGHT.rotated(randf() * TAU)

	# Only TargetMode.NEAREST_ENEMY reaches here, since RANDOM already
	# returned above — no need to re-check target_mode again.
	var enemies := get_tree().get_nodes_in_group(enemy_group)
	if enemies.is_empty():
		return Vector2.RIGHT.rotated(randf() * TAU)

	# Two separate trackers: nearest_distance is the comparison value used
	# WHILE looping, nearest_enemy is the actual answer we want. Keeping
	# these separate (instead of one variable doing both jobs) avoids
	# mixing a position/distance with the final direction mid-loop.
	var nearest_enemy: Node2D = null
	var nearest_distance := INF

	for enemy in enemies:
		if enemy.is_queued_for_deletion():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	# Convert to a direction exactly once, after the loop has already
	# determined who the true nearest enemy is.
	return global_position.direction_to(nearest_enemy.global_position)
		
