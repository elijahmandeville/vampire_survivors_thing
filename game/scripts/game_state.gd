extends Node
## GameState
## -----------------------------------------------------------------
## System #1 — Game State (run start/pause/end/reset)
##
## Contract:
##   IN:  start_run(), pause_run(), resume_run(), end_run(reason), reset_run()
##   OUT: EventBus signals -> run_started, run_paused, run_resumed, run_ended(reason)
##        current state readable via `state` or is_running() / is_paused()
##
## Registered as an autoload, so any other system can check
## `GameState.is_running()` from anywhere — no reference/get_node() needed,
## same as EventBus.
##
## HOW PAUSING WORKS (decided after building Run End):
## Each state change also drives Godot's built-in `get_tree().paused`,
## rather than every system polling `is_running()` for itself. The engine
## then stops `_process`, `_physics_process`, timers, and input on every
## node whose `process_mode` inherits the default.
##
## Why this and not per-system guards: guards meant each system had to
## remember to check, and — worse — meant scripts in `addons/` depended on
## a `GameState` autoload that only exists in THIS project, breaking
## Reusability Standard #1. Spawner and Weapon both had that dependency and
## no longer do. Movement2D and Follow2D never needed one.
##
## The tradeoff: pause is all-or-nothing per node. Anything that must keep
## running while paused (a pause menu, a game-over screen, this autoload)
## has to opt out explicitly with `process_mode = PROCESS_MODE_ALWAYS`.
## That's the same mechanism a pause menu needs anyway.
## -----------------------------------------------------------------

enum State { READY, RUNNING, PAUSED, ENDED }

var state: State = State.READY


func _ready() -> void:
	# An autoload must keep running even while the tree is paused —
	# otherwise GameState would freeze itself and nothing could ever call
	# resume_run(). PROCESS_MODE_ALWAYS opts this node out of the pause.
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_run() -> void:
	if state != State.READY:
		return
	state = State.RUNNING
	get_tree().paused = false
	EventBus.run_started.emit()


func pause_run() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	get_tree().paused = true
	EventBus.run_paused.emit()


func resume_run() -> void:
	if state != State.PAUSED:
		return
	state = State.RUNNING
	get_tree().paused = false
	EventBus.run_resumed.emit()


func end_run(reason: String = "") -> void:
	if state != State.RUNNING and state != State.PAUSED:
		return
	state = State.ENDED
	# Freezing on run end is intentional: it holds the final frame in place
	# behind whatever game-over screen ends up on top of it.
	get_tree().paused = true
	EventBus.run_ended.emit(reason)


func reset_run() -> void:
	if state != State.ENDED:
		return
	state = State.READY
	get_tree().paused = false


func is_running() -> bool:
	return state == State.RUNNING


func is_paused() -> bool:
	return state == State.PAUSED
