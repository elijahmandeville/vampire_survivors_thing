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
@onready var weapon: Weapon = $Weapon


## Public accessor for this player's live Stats instance.
##
## Exists so upgrades (and anything else) can reach the runtime Stats
## without walking `player.hurtbox.stats` from outside, which would couple
## callers to the Player's internal node layout — the thing Reusability
## Standard #2 rules out. Move the Hurtbox, rename it, or restructure the
## scene, and only this one line changes.
##
## Worth remembering WHY this can't just be player_stats.tres: Hurtbox
## calls .duplicate() in _ready(), so the file on disk is a template and
## this is the only handle on the copy actually being played.
func get_stats() -> Stats:
	return hurtbox.stats


## Public accessor for this player's Weapon, for the same reason as
## get_stats(): callers shouldn't depend on where it sits in the scene.
##
## Returns null-safe garbage if the node is missing, so upgrades should
## check. Will need rethinking once the player can hold MORE than one
## weapon — at which point this probably becomes get_weapons() -> Array,
## and a WeaponUpgrade decides whether it applies to one or all of them.
func get_weapon() -> Weapon:
	return weapon


func _ready() -> void:
	super()
	hurtbox.died.connect(_on_hurtbox_died)
	
	# General pattern worth remembering: when something joins late and needs
	# current state, connect for updates AND read the value once.
	hurtbox.stats.health_changed.connect(_on_health_changed)
	_on_health_changed(hurtbox.stats.current_health, hurtbox.stats.max_health)
	
	EventBus.upgrade_applied.connect(_sync_from_stats)
	_sync_from_stats()

	# TODO: Push Stats values into the components that consume them, now and
	# whenever an upgrade changes them.
	#
	# Approach:
	#   1. EventBus.upgrade_applied.connect(_sync_from_stats)
	#   2. _sync_from_stats()
	#
	# Same connect-AND-read-once pattern as health above, for the same
	# reason: connecting alone would leave the components on their scene
	# defaults until the first upgrade landed.


func _sync_from_stats() -> void:
	# TODO: Copy Stats values into the addons that actually use them.
	#
	# Approach:
	#   1. speed = get_stats().move_speed
	#      `speed` is inherited from Movement2D, which reads it every
	#      physics frame — so writing it here is enough, no other change.
	#   2. weapon.damage_mult = get_stats().damage_mult
	#      Weapon multiplies each projectile's damage by this at spawn.
	#
	# WHY A PUSH INSTEAD OF THE ADDONS READING STATS DIRECTLY:
	# Movement2D and Weapon are in addons/ and must run in a project with no
	# Stats system at all (Reusability Standard #1). So they expose plain
	# numbers, and this script — game-specific glue that knows both sides
	# exist — copies between them. movement_2d.gd's own docs have called for
	# exactly this since system #3; this is the first thing to actually do it.
	#
	# THE FAILURE THIS FIXES: upgrades were writing to Stats and nothing was
	# reading. move_speed and damage_mult were inert — the upgrade applied
	# cleanly, the number changed, and the game played identically. No error,
	# no warning. Worth remembering the shape of that bug: a value with a
	# writer and no reader looks exactly like a working feature.
	#
	# NOTE: check player_stats.tres's move_speed matches Movement2D's `speed`
	# default (200). Once this sync runs, the .tres value wins — so a
	# mismatch would silently change your starting speed.
	speed = get_stats().move_speed
	weapon.damage_mult = get_stats().damage_mult


func _on_health_changed(current_health: float, max_health: float) -> void:
	# TODO: Republish a local signal as a global one.
	#
	# Approach:
	#   1. EventBus.player_health_changed.emit(current_health, max_health)
	#
	# That's the whole function. Stats has no idea who owns it, so it can
	# only emit locally; this script knows it's the player, so it's the
	# right place to say "the PLAYER's health changed" to the world.
	EventBus.player_health_changed.emit(current_health, max_health)


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
	GameState.end_run("player_died")
