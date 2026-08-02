class_name Pickup
extends Area2D
## Pickup
## -----------------------------------------------------------------
## System #7 — Progression (the "collect it" half)
##
## Contract:
##   IN:  nothing exported yet. Which entity counts as a collector is
##        decided by Collision Layer/Mask in the Inspector, not by code —
##        same approach as Hitbox/Hurtbox factions.
##   OUT: local signal `collected(collector: Node)`.
##
## Deliberately knows NOTHING about XP, currency, health potions, or
## anything else it might grant. It only answers one question: "did a
## collector touch me?" Whatever this Pickup is attached to decides what
## being collected actually means (see game/scripts/xp_gem.gd).
##
## Same split as Hitbox/Hurtbox: one piece detects, another piece decides
## what the detection means. That's what makes this reusable — a health
## pickup, a coin, and an XP gem are all this same script with a different
## parent script.
##
## Note it does NOT free itself on collection. The owner might want to
## play a sound or animation first. Owner calls queue_free() when ready.
##
## MAGNET BEHAVIOR: overlapping a collector does NOT collect. It starts the
## pickup drifting toward them, accelerating; collection happens on actual
## contact (collect_distance). This splits one radius into two distinct
## things:
##   - the COLLECTOR's shape = how far the magnet reaches
##   - collect_distance      = how close counts as picked up
## Before this, they were the same number, so pickups blinked out of
## existence at the edge of a large collector circle — which reads as a
## bug even though it was working as written. Making the pull visible is
## also most of why collecting feels good in this genre.
## -----------------------------------------------------------------

signal collected(collector: Node)

## Top drift speed once fully accelerated, in px/sec.
@export var attract_speed: float = 500.0

## How fast it winds up to attract_speed. A ramp rather than instant full
## speed is what makes it read as magnetism instead of teleporting — the
## gem creeps, then snaps in. Vampire Survivors does the same thing.
@export var acceleration: float = 900.0

## How close before it counts as collected. Small on purpose: this is the
## ACTUAL pickup radius now. The collector's own shape is just the range at
## which attraction begins.
@export var collect_distance: float = 8.0

## Who we're drifting toward. Null until a collector overlaps.
var _collector: Node2D = null

## Current drift speed, ramping from 0 toward attract_speed.
var _speed: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	# TODO: Start being attracted, instead of collecting immediately.
	#
	# Approach:
	#   1. if _collector != null:
	#          return
	#      (Already homing in on someone — ignore further overlaps.)
	#   2. _collector = area.get_parent()
	#   3. _speed = 0.0
	#
	# This is the behavior change: entering the collector's range no longer
	# means "collected", it means "start moving toward them". Collection now
	# happens in _physics_process, on actual contact.
	if _collector != null:
		return
	_collector = area.get_parent()
	_speed = 0.0


func _physics_process(delta: float) -> void:
	# TODO: Drift toward the collector, and collect once close enough.
	#
	# Approach:
	#   1. Bail if there's nobody to chase, or they've been freed:
	#        if _collector == null or not is_instance_valid(_collector):
	#            return
	#      (is_instance_valid matters — the player can die mid-flight.)
	#   2. Work out the gap. NOTE we move our PARENT, not ourselves:
	#        var mover := get_parent() as Node2D
	#        if mover == null:
	#            return
	#        var to_collector := _collector.global_position - mover.global_position
	#   3. Close enough? Hand off and stop:
	#        if to_collector.length() <= collect_distance:
	#            collected.emit(_collector)
	#            _collector = null
	#            return
	#   4. Otherwise accelerate and step toward them:
	#        _speed = minf(_speed + acceleration * delta, attract_speed)
	#        mover.global_position += to_collector.normalized() * _speed * delta
	#
	# WHY MOVE THE PARENT: this Area2D is a child of the thing being picked
	# up (XpGem), and the sprite lives on that parent. Moving this node
	# alone would slide the collision area out from under a stationary
	# gem — the pickup would work but look broken. Symmetric with
	# _on_area_entered treating `area.get_parent()` as the collector: both
	# sides of this system talk in terms of whole entities, not components.
	if _collector == null or not is_instance_valid(_collector):
		return
	var mover := get_parent() as Node2D
	if mover == null:
		return
	var to_collector := _collector.global_position - mover.global_position
	if to_collector.length() <= collect_distance:
		collected.emit(_collector)
		_collector = null
		return
	else:
		_speed = minf(_speed + acceleration * delta, attract_speed)
		mover.global_position += to_collector.normalized() * _speed * delta
