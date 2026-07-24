extends Node

func _ready() -> void:
	var stats := Stats.new()
	stats.health_changed.connect(func(cur, max): print("health: ", cur, "/", max))
	stats.died.connect(func(): print("died fired"))

	stats.reset_to_full()        # health: 100/100
	stats.take_damage(30)        # health: 70/100
	stats.heal(200)               # health: 100/100 (clamped)
	stats.take_damage(1000)      # health: 0/100, then "died fired"
	stats.take_damage(50)         # health: 0/100, no second "died fired"
