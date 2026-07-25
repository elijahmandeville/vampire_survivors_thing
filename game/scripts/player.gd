extends Movement2D
## Player
## -----------------------------------------------------------------
## System #9 — Run End (player death → game over)
##
## Game-specific glue — NOT a reusable addon. Exact mirror of enemy.gd:
## same "listen to my Hurtbox, decide what death means" shape, different
## decision. An enemy dying is a routine event; the player dying ends the
## run.
##
## Note `extends Movement2D`, not `extends CharacterBody2D` — the same move
## enemy.gd made to `extends Follow2D`. A Godot node holds one script, so
## game glue on an entity's root has to extend whichever movement component
## that entity uses. WASD control comes along for free; nothing about
## movement needs restating here.
##
## Contract:
##   IN:  requires a child node named "Hurtbox" (a Hurtbox).
##        Inherits @export var speed from Movement2D.
##   OUT: GameState.end_run("player_died") -> EventBus.run_ended(reason).
##
## Deliberately does NOT queue_free() the player, unlike enemy.gd. Deleting
## the player mid-frame would break anything still holding a reference to
## it (Spawner's `target`, every Follow2D's cached `target`), and a
## game-over screen will probably want to show the body where it fell.
## Ending the run is enough — Spawner and Weapon already stop on their own
## via their is_running() guards.
## -----------------------------------------------------------------

@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	# TODO: Listen for this player's Hurtbox announcing death.
	#
	# Approach:
	#   1. hurtbox.died.connect(_on_hurtbox_died)
	#
	# Identical to enemy.gd's _ready(). If you ever add other "on spawn"
	# player setup, it goes here too.
	hurtbox.died.connect(_on_hurtbox_died)


func _on_hurtbox_died() -> void:
	# TODO: End the run.
	#
	# Approach:
	#   1. GameState.end_run("player_died")
	#
	# That's the whole thing. GameState flips its state to ENDED and emits
	# EventBus.run_ended("player_died") for anyone listening — which today
	# is nobody, and that's fine. The game-over screen (UI/HUD) is what
	# will consume it.
	#
	# Reason strings are already accounted for on the other side: the win
	# condition will call end_run("time_up") through this same door.
	#
	# WHAT TO WATCH FOR WHEN TESTING — this is the real point of this
	# system. It's a live test of whether the is_running() guard pattern
	# holds up. On death you should see, with no extra code:
	#   - Spawner stops making enemies (its timeout guard fails)
	#   - Weapon stops firing (same guard)
	#   - Enemies KEEP CHASING and movement still works, because
	#     Movement2D/Follow2D never took that guard
	# That last one is the open question in project-context.md: whether to
	# spread is_running() into the movement addons, or switch everything to
	# Godot's built-in get_tree().paused + process_mode instead. Decide it
	# after seeing the behavior firsthand.
	GameState.end_run("Player Died")
