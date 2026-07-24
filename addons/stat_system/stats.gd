class_name Stats
extends Resource
## Stats
## -----------------------------------------------------------------
## System #2 — Stats (central data layer)
##
## Contract:
##   IN:  exported base values (set in the Inspector, or via a .tres file),
##        plus reset_to_full(), take_damage(amount), heal(amount) at runtime
##   OUT: signals -> health_changed(current_health, max_health), died
##
## Important difference from GameState/EventBus: those are autoloads —
## there is exactly ONE of each, always reachable by name. Stats is NOT an
## autoload. It's a plain Resource, so there are MANY instances — the
## player owns one, and every enemy owns its own. Whoever owns an entity
## creates or loads a Stats instance and hands it to that entity's scripts
## (matches Reusability Standard #4: data lives in Resources, not autoloads
## or hardcoded values).
##
## Since a Resource has no position in the scene tree, it can only emit its
## own local signals — there's no "global bus" version of health_changed,
## because there's no single Stats to broadcast from. Whatever owns this
## specific instance connects to its signals directly.
##
## Gotcha to remember once you have more than one enemy on screen: if
## multiple enemies are handed the SAME Stats resource instance (e.g. you
## preload one EnemyStats.tres and assign it to every spawned enemy),
## they'll all share one current_health — damaging one damages all of
## them. Each spawned entity needs its own instance via `.duplicate()`,
## not the same shared reference. Not a problem yet with zero enemies,
## but worth remembering when Spawner exists.
##
## Deliberately does NOT decide what happens when an entity dies (no
## despawning, no animation) — it only tracks the number and emits `died`
## once when it reaches 0. Reacting to that is Combat/Damage's job (#4).
## -----------------------------------------------------------------

signal health_changed(current_health: float, max_health: float)
signal died

@export var max_health: float = 100.0
@export var move_speed: float = 200.0
@export var damage_mult: float = 1.0

var current_health: float = 0.0


func reset_to_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	var was_alive := current_health > 0.0
	current_health = max(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if was_alive and current_health == 0.0:
		died.emit()


func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
