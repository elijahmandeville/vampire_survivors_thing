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
	if state != State.READY:
		return
	state = State.RUNNING
	EventBus.run_started.emit()
		


func pause_run() -> void:
	if state != State.RUNNING:
		return
	
	state = State.PAUSED
	EventBus.run_paused.emit()


func resume_run() -> void:
	if state != State.PAUSED:
		return
	state = State.RUNNING
	EventBus.run_resumed.emit()


func end_run(reason: String = "") -> void:
	if state != State.RUNNING and state != State.PAUSED:
		return
	state = State.ENDED
	EventBus.run_ended.emit(reason)


func reset_run() -> void:
	if state != State.ENDED:
		return
	state = State.READY


func is_running() -> bool:
	return state == State.RUNNING


func is_paused() -> bool:
	return state == State.PAUSED
