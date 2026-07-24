class_name Projectile
extends Hitbox
## Projectile
## -----------------------------------------------------------------
## System #6 — Weapons/Abilities (the "attack firing" half)
##
## Contract:
##   IN:  @export var speed, lifetime — movement/self-destruct knobs.
##        `direction` (plain var, NOT exported — whoever spawns this,
##        e.g. Weapon, sets it right after instancing, before adding it
##        to the tree).
##        Inherits `damage` from Hitbox — this class IS a Hitbox. The
##        `if not area is Hitbox` guard already in hurtbox.gd matches
##        subclasses too, so nothing anywhere in Combat/Damage needed to
##        change for this to work.
##   OUT: none — just moves, deals damage via the inherited Hitbox
##        behavior (Hurtbox does the actual detection/damage work, same
##        as it does for any other Hitbox), and frees itself.
##
## Self-contained: doesn't know what fired it or what it's for. See the
## note in weapon.gd about NOT parenting a Projectile under a moving node
## when adding it to the tree.
## -----------------------------------------------------------------

@export var speed: float = 400.0
@export var lifetime: float = 2.0

var source: Node
var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() == source:
		return
	if area is Hurtbox:
		queue_free()
