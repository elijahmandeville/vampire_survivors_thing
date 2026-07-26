extends Follow2D
## Enemy
## -----------------------------------------------------------------
## Game-specific glue — NOT a reusable addon.
##
## Lives in game/scripts/ rather than addons/ on purpose. Everything in
## addons/ has to be droppable into any project; this script makes a
## decision that's specific to THIS game ("when an enemy's health hits
## zero, the whole thing disappears and awards XP"). A different game
## might play a death animation first, ragdoll it, or turn it into a
## pickup. That decision belongs here, not inside Hurtbox.
##
## This is the answer to the open follow-up we left in project-context.md:
## "what should happen when a whole entity dies."
##
## Contract:
##   IN:  requires a child node named "Hurtbox" (a Hurtbox) — same kind of
##        scene requirement as Spawner/Weapon needing a child Timer.
##   OUT: EventBus.enemy_died(position) — global, so Progression/UI can
##        react later without this script knowing they exist.
## -----------------------------------------------------------------

@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	super()
	hurtbox.died.connect(_on_hurtbox_died)


func _on_hurtbox_died() -> void:
	EventBus.enemy_died.emit(global_position)
	queue_free()
