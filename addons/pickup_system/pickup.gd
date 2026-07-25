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
## -----------------------------------------------------------------

signal collected(collector: Node)


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	collected.emit(area.get_parent())
