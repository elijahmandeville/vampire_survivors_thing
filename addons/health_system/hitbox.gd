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
