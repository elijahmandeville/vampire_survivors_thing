class_name Hurtbox
extends Area2D
## Hurtbox
## -----------------------------------------------------------------
## System #4 — Combat/Damage (the "receives damage" half — hit
## detection + damage application)
##
## Contract:
##   IN:  @export var stats — the Stats resource this Hurtbox protects.
##        Detects overlaps with Hitbox areas automatically via Area2D's
##        built-in `area_entered` signal (requires matching Collision
##        Layer/Mask — see setup note below).
##   OUT: local signal `took_damage(amount)` — for local reactions only
##        (e.g. a hit-flash component on the same entity, if you add one
##        later). Death itself is already covered by `stats.died`
##        (built in the Stats system) — this just listens for it.
##
## Pairs with Hitbox: a Hitbox is pure data (just a damage amount),
## Hurtbox does all the work — detecting the overlap and calling
## stats.take_damage(). Keeps "who deals damage" and "who receives
## damage" as two separate, swappable pieces.
##
## Deliberately minimal death handling for now: on `stats.died`, this
## just frees ITSELF (stops taking/dealing further hits) rather than
## assuming anything about scene structure. No Player/Enemy scene exists
## yet — whoever builds those later decides what "the whole entity
## disappearing" should mean (queue_free the root, play a death
## animation first, show a game-over screen, etc.) by connecting to that
## same stats.died signal in their own script. Extract more shared
## behavior here later if every entity ends up handling it identically
## (Reusability Standard #5 — extract after first use, not before).
##
## Setup required: Area2D overlap detection needs this node's Collision
## Layer/Mask to include whatever layer Hitboxes use. For this first
## gray-box test, simplest is leaving both on the default Layer 1 /
## Mask 1 — everything detects everything. Split hurtbox/hitbox layers
## apart later once Player and Enemy scenes actually exist and you need
## enemies to not hurt each other, etc.
## -----------------------------------------------------------------

signal took_damage(amount: float)

@export var stats: Stats


func _ready() -> void:
	stats.reset_to_full()
	area_entered.connect(_on_area_entered)
	stats.died.connect(_on_stats_died)


func _on_area_entered(area: Area2D) -> void:
	if not area is Hitbox:
		return
	if area.get_parent() == get_parent():
		return
	stats.take_damage(area.damage)
	took_damage.emit(area.damage)


func _on_stats_died() -> void:
	queue_free()
