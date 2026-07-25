class_name Hitbox
extends Area2D
## Hitbox
## -----------------------------------------------------------------
## System #4 — Combat/Damage (the "deals damage" half)
##
## Pure data, deliberately — same reasoning as EventBus's signal list.
## A Hitbox doesn't detect anything or apply damage itself; it just
## carries a damage amount. Hurtbox (addons/health_system/hurtbox.gd)
## does all the actual work of detecting overlap and calling
## stats.take_damage(). Keeping "who deals damage" this simple means a
## weapon, a contact-damage enemy body, and a hazard can all just be a
## Hitbox with a different `damage` value — zero new code.
## -----------------------------------------------------------------

@export var damage: float = 10.0

## Who is responsible for this Hitbox — used to stop an entity damaging
## itself. NOT exported: it's set in code by whoever spawns the Hitbox, not
## configured in the Inspector.
##
## Leave it null for a Hitbox that's simply a child of the thing it belongs
## to (an Enemy's contact-damage box). Set it explicitly when the Hitbox
## gets parented somewhere else — a Projectile is added to the scene root so
## it doesn't inherit the firer's transform, which means its parent is the
## scene, not the shooter.
var source: Node


## Answers "who does this Hitbox belong to?" in a way that works for both
## cases above: an explicit source if one was set, otherwise just this
## node's parent.
##
## Having this ONE function means Hurtbox needs only one self-hit guard
## instead of a special case per kind of Hitbox — and any future Hitbox
## (thrown weapon, orbiting shield, lingering fire pool) gets correct
## behavior for free by setting `source`.
func get_source() -> Node:
	if source != null:
		return source
	return get_parent()
