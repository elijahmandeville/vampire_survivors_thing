extends Node2D
## XpGem
## -----------------------------------------------------------------
## Game-specific glue — NOT a reusable addon. Same reasoning as enemy.gd:
## "being collected grants XP" is a decision this game makes. A different
## game's pickup might grant ammo, or open a door.
##
## Contract:
##   IN:  @export var xp_value — how much XP this gem is worth. Exported so
##        a "big gem" from a tough enemy is just a different value in the
##        Inspector, not a different script (Reusability Standard #4).
##        Requires a child node named "Pickup" (a Pickup).
##   OUT: EventBus.xp_gained(amount) — global, so Progression (and later,
##        the XP bar in the HUD) can react without this gem knowing either
##        of them exists.
##
## Mirrors the structure of Enemy exactly: a plain body node, a reusable
## detector component as a child, and a small script deciding what the
## component's signal means.
## -----------------------------------------------------------------

@export var xp_value: int = 1

@onready var pickup: Pickup = $Pickup


func _ready() -> void:
	# Identical pattern to enemy.gd connecting to hurtbox.died.
	pickup.collected.connect(_on_collected)


func _on_collected(_collector: Node) -> void:
	# The `_collector` parameter is prefixed with an underscore because we
	# accept it but don't use it — GDScript convention to signal "yes, this
	# is intentionally unused" and suppress the editor warning. It's there
	# because a future co-op mode would need to know WHICH player collected
	# it; today there's only one.

	EventBus.xp_gained.emit(xp_value)
	queue_free()
