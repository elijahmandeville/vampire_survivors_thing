extends CanvasLayer
## GameOverScreen
## -----------------------------------------------------------------
## System #12 — Run End UI (game over + restart)
##
## Game-specific glue. Add as a child of main, BELOW the HUD so it draws
## on top of it.
##
## Contract:
##   IN:  EventBus.run_ended(reason).
##        Requires children named "TitleLabel" (Label) and
##        "RestartButton" (Button).
##   OUT: GameState.reset_run(), then a scene reload.
##
## First UI that isn't read-only — it takes input and acts on it.
##
## TWO THINGS MAKE THIS DIFFERENT FROM THE HUD:
##
## 1. process_mode must be PROCESS_MODE_ALWAYS. end_run() freezes the whole
##    tree, and this screen only appears AFTER that. Without opting out of
##    the pause, the button would render but never respond — it'd look
##    like a broken button rather than a paused one.
##
## 2. Restart has to reset GameState BEFORE reloading the scene. Autoloads
##    survive a scene reload — that's the whole point of them — so
##    GameState would still be sitting in ENDED when the fresh scene loads,
##    main.gd would call start_run(), and start_run()'s `if state !=
##    State.READY: return` guard would silently do nothing. Result: a scene
##    that looks correct but never starts, with no error to explain it.
##    This is the sharp edge of global state, and worth remembering
##    whenever an autoload holds anything run-scoped.
## -----------------------------------------------------------------

@onready var title_label: Label = $TitleLabel
@onready var restart_button: Button = $RestartButton


func _ready() -> void:
	# TODO: Opt out of the pause, hide until needed, and wire everything up.
	#
	# Approach:
	#   1. process_mode = Node.PROCESS_MODE_ALWAYS
	#      Children inherit this, so the Button becomes clickable too.
	#   2. visible = false
	#      Hidden during play; run_ended is what reveals it.
	#   3. EventBus.run_ended.connect(_on_run_ended)
	#   4. restart_button.pressed.connect(_on_restart_pressed)
	#      `pressed` is Button's built-in signal — same .connect() pattern
	#      as every custom signal you've written, just supplied by Godot.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.run_ended.connect(_on_run_ended)
	restart_button.pressed.connect(_on_restart_pressed)


func _on_run_ended(reason: String) -> void:
	# TODO: Show the screen, worded for how the run actually ended.
	#
	# Approach:
	#   1. Branch on the reason string:
	#        if reason == "time_up":
	#            title_label.text = "You Survived!"
	#        else:
	#            title_label.text = "You Died"
	#   2. visible = true
	#
	# Defaulting to defeat in `else` rather than testing for "player_died"
	# explicitly: any future end reason ("quit", "out_of_bounds") shows a
	# neutral-to-negative screen rather than falsely congratulating the
	# player. Fail toward the less wrong option.
	#
	# NOTE: this is where the reason strings finally get compared, so they
	# have to match exactly. player.gd currently emits "Player Died" with a
	# capital P and a space — worth fixing to "player_died" so the two
	# call sites read as consistent identifiers.
	if reason == "time_up":
		title_label.text = "You Survived!"
	else:
		title_label.text = "You Died"
	visible = true


func _on_restart_pressed() -> void:
	# TODO: Put GameState back to READY, then reload the scene.
	#
	# Approach:
	#   1. GameState.reset_run()
	#   2. get_tree().reload_current_scene()
	#
	# ORDER IS NOT OPTIONAL — see the note at the top of this file. Reload
	# first and GameState stays ENDED, start_run() no-ops, and the new
	# scene sits there frozen and inert with nothing in the console.
	#
	# reset_run() also sets get_tree().paused = false, so the fresh scene
	# isn't born frozen.
	#
	# Everything else rebuilds itself from scratch on reload: a new Player
	# with full health, an empty Progression back at level 1, a fresh
	# RunTimer. Nothing needs an explicit "clean up" pass, because no
	# run-scoped state lives outside the scene — GameState is the one
	# exception, which is exactly why it needs the manual reset.
	GameState.reset_run()
	get_tree().reload_current_scene()
