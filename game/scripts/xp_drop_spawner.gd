extends Node2D
## XpDropSpawner
## -----------------------------------------------------------------
## Game-specific glue — NOT a reusable addon. Add as a child of main.
##
## Contract:
##   IN:  @export var gem_scene — a PackedScene to drop (not hardcoded to
##        one specific gem, so a rare-gem variant needs no code change).
##        Listens to EventBus.enemy_died(position).
##   OUT: none — just adds gems to the scene.
##
## This is the piece that makes enemy_died worth having been on the bus.
## Notice what did NOT have to change to add XP to this game: enemy.gd
## still just announces that it died, exactly as it did before Progression
## existed. The new behavior hangs off that announcement instead of being
## bolted into the enemy. That's the payoff the ADR was betting on.
##
## Why a dedicated node rather than putting this in main.gd: main.gd is
## for run-start wiring. Keeping "what drops when things die" as its own
## node means loot rules can grow (drop chances, rare gems, health drops)
## without main.gd turning into a junk drawer.
## -----------------------------------------------------------------

@export var gem_scene: PackedScene


func _ready() -> void:
	# TODO: Subscribe to the global enemy-death event.
	#
	# Approach:
	#   1. EventBus.enemy_died.connect(_on_enemy_died)
	#
	# Note this connects to an AUTOLOAD's signal, not a child node's.
	# Same .connect() syntax, but no @onready needed — EventBus is
	# reachable by name from anywhere, and already exists before this runs.
	EventBus.enemy_died.connect(_on_enemy_died)


## `death_position`, not `position` — this script extends Node2D, which
## already HAS a `position` property. A parameter by that name shadows it,
## so inside this function `position` would stop meaning "this node's
## position" and Godot would warn about it. Worth watching for on any
## handler in a Node2D-derived script.
func _on_enemy_died(death_position: Vector2) -> void:
	# TODO: Drop a gem where the enemy died.
	#
	# Approach:
	#   1. Guard: if gem_scene == null: return
	#   2. var gem := gem_scene.instantiate()
	#   3. gem.global_position = position
	#   4. get_tree().current_scene.add_child(gem)
	#
	# Same current_scene reasoning as Weapon spawning projectiles — a gem
	# should sit still in the world, so it must not inherit any moving
	# node's transform.
	#
	# Careful with ordering: set global_position BEFORE add_child() and
	# Godot may discard it, since global_position is meaningless until the
	# node is in the tree. If gems end up at (0,0), swap steps 3 and 4.
	if gem_scene == null:
		return
	var gem := gem_scene.instantiate()
	gem.global_position = death_position
	get_tree().current_scene.add_child(gem)
