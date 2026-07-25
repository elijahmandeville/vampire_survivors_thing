class_name Follow2D
extends CharacterBody2D
## Follow2D
## -----------------------------------------------------------------
## System #9 — Enemy AI (the simplest possible version)
##
## Contract:
##   IN:  @export var speed — movement speed.
##        @export var target_group — the group name to chase. NOT a direct
##        node reference, so a spawned enemy needs no wiring from whoever
##        spawned it; it finds its own target. Same approach as Weapon's
##        enemy_group (Reusability Standard #1 — no hard scene references).
##        @export var stop_distance — how close before it stops pushing in.
##   OUT: none yet.
##
## Deliberate near-mirror of Movement2D: same shape, same move_and_slide()
## at the end — the only difference is where the direction comes from.
## Movement2D reads the keyboard; this reads a target's position. That
## symmetry is the point: "what decides the direction" is the only thing
## that varies between a player-controlled body and an AI-controlled one.
##
## Why it extends CharacterBody2D (i.e. IS the body) rather than being a
## child component: consistency with Movement2D. The cost is one movement
## behavior per entity, fixed by inheritance. Revisit if an enemy ever
## needs to swap movement behavior at runtime (a charger that winds up,
## a fleeing enemy) — that's the point where composition earns its keep.
## -----------------------------------------------------------------

@export var speed: float = 100.0
@export var target_group: String = "player"
## Stops closing in once this near, so a swarm doesn't grind into a single
## overlapping pile on top of the player. Contact damage still applies —
## the Hitbox reaches further than this.
@export var stop_distance: float = 8.0

## Cached so we're not searching the group every physics frame. Not
## exported: it's discovered at runtime, not configured in the Inspector.
var target: Node2D


func _physics_process(_delta: float) -> void:
	# TODO: Steer toward the target each frame.
	#
	# Approach:
	#   1. Make sure we have a valid target:
	#        if target == null or not is_instance_valid(target):
	#            target = _find_target()
	#        if target == null:
	#            velocity = Vector2.ZERO
	#            move_and_slide()
	#            return
	#      (is_instance_valid() matters because the player may be freed
	#      mid-run — a plain `== null` check won't catch an already-freed
	#      node, and touching it would crash.)
	#   2. Stop pushing in once close enough:
	#        if global_position.distance_to(target.global_position) <= stop_distance:
	#            velocity = Vector2.ZERO
	#        else:
	#            velocity = global_position.direction_to(target.global_position) * speed
	#      direction_to() again — same normalized-direction helper you used
	#      for weapon targeting.
	#   3. move_and_slide()
	#
	# Compare this to Movement2D._physics_process when you're done: the
	# last line is identical, and the rest is just a different way of
	# arriving at `velocity`.
	if target == null or not is_instance_valid(target):
		target = _find_target()
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if global_position.distance_to(target.global_position) <= stop_distance:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(target.global_position) * speed
	move_and_slide()


func _find_target() -> Node2D:
	# TODO: Return the first node in target_group, or null if there are none.
	#
	# Approach:
	#   1. var candidates := get_tree().get_nodes_in_group(target_group)
	#   2. if candidates.is_empty(): return null
	#   3. return candidates[0]
	#
	# candidates[0] is "the first one" — arrays are zero-indexed. Fine while
	# there's exactly one player; a co-op version would pick the nearest
	# instead, which is the same loop you already wrote in weapon.gd.
	var candidates := get_tree().get_nodes_in_group(target_group)
	if candidates.is_empty():
		return null
	return candidates[0]
