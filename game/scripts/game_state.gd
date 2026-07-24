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
## This will be registered as an autoload (see registration steps), so any
## other system can just check `GameState.is_running()` from anywhere —
## no reference/get_node() needed, same as EventBus.
## -----------------------------------------------------------------

enum State { READY, RUNNING, PAUSED, ENDED }

var state: State = State.READY

func start_run() -> void:
	# TODO: Begin a run. Should only do anything if we're currently READY
	# (guard against starting twice, or starting mid-run).
	#
	# Approach:
	#   1. if state != State.READY: return   (early exit, ignore the call)
	#   2. state = State.RUNNING
	#   3. EventBus.run_started.emit()
	if state != State.READY:
		return
	state = State.RUNNING
	EventBus.run_started.emit()
		


func pause_run() -> void:
	# TODO: Pause an in-progress run. Only valid if state == State.RUNNING.
	#
	# Approach:
	#   1. Guard: if state != State.RUNNING: return
	#   2. state = State.PAUSED
	#   3. EventBus.run_paused.emit()
	#
	# Note: this only tracks *your game's* logical state. Godot also has its
	# own `get_tree().paused = true/false`, which actually freezes physics/
	# process callbacks on nodes (unless they're set to still process while
	# paused). Whether to call that here too, or let something listening to
	# run_paused decide, is your call — worth thinking about once you wire
	# this up in the editor and see what "pause" needs to mean for this game.
	
	if state != State.RUNNING:
		return
	
	state = State.PAUSED
	EventBus.run_paused.emit()


func resume_run() -> void:
	# TODO: Resume a paused run. Only valid if state == State.PAUSED.
	#
	# Approach: mirror pause_run() — guard on PAUSED, set state = RUNNING,
	# emit EventBus.run_resumed.
	if state != State.PAUSED:
		return
	state = State.RUNNING
	EventBus.run_resumed.emit()


func end_run(reason: String = "") -> void:
	# TODO: End the run, valid from RUNNING or PAUSED (a run can end while
	# paused too, e.g. player quits from the pause menu).
	#
	# Approach:
	#   1. Guard: if state != State.RUNNING and state != State.PAUSED: return
	#   2. state = State.ENDED
	#   3. EventBus.run_ended.emit(reason)
	#
	# `reason` is just a plain string ("player_died", "time_up") for now —
	# don't over-engineer this into an enum/class until something actually
	# needs to branch on it in a complex way.
	if state != State.RUNNING and state != State.PAUSED:
		return
	state = State.ENDED
	EventBus.run_ended.emit(reason)


func reset_run() -> void:
	# TODO: Bring things back to READY so start_run() can be called again.
	#
	# Approach:
	#   1. Guard: probably only valid from ENDED — think about whether you
	#      want to allow resetting a RUNNING/PAUSED run too, or force end_run()
	#      first.
	#   2. state = State.READY
	#
	# Open question for you: does anything need to know a reset happened?
	# If not, no bus event needed yet — add one later if a listener needs it.
	if state != State.ENDED:
		return
	state = State.READY


func is_running() -> bool:
	return state == State.RUNNING


func is_paused() -> bool:
	return state == State.PAUSED
