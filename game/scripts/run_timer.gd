extends Node
## RunTimer
## -----------------------------------------------------------------
## System #10 — Win Condition (survive to the end of the run)
##
## Game-specific glue — NOT a reusable addon. It calls GameState directly,
## which is exactly the dependency we just finished stripping out of
## Spawner and Weapon. The difference: "the run has a fixed length and
## surviving it wins" IS a rule of this game, not a reusable behavior, so
## living in game/scripts/ and knowing about GameState is correct here.
## Add as a child of main.
##
## Contract:
##   IN:  @export var run_duration — run length in seconds.
##        Requires a child node named "Timer".
##        Starts on EventBus.run_started.
##   OUT: GameState.end_run("time_up") -> EventBus.run_ended("time_up").
##        get_time_left() for the HUD to display.
##
## Note this is the FIRST thing in the project to listen for
## `run_started`. GameState has been emitting it since system #1 with
## nothing on the other end. Worth noticing that adding a listener required
## no change whatsoever to GameState — the signal was already the seam.
##
## Pausing needs no handling: the child Timer freezes with the rest of the
## tree, so time spent paused doesn't count against the run.
## -----------------------------------------------------------------

## 300 = five minutes. Tune freely — this is the single number that decides
## how long a run lasts.
@export var run_duration: float = 10.0

@onready var timer: Timer = $Timer


func _ready() -> void:
	# TODO: Configure the Timer, then wait for the run to actually begin.
	#
	# Approach:
	#   1. timer.wait_time = run_duration
	#   2. timer.one_shot = true
	#      Unlike Spawner's and Weapon's timers, this one must NOT repeat —
	#      it fires once, at the end of the run. Without this it would
	#      restart and call end_run() again every run_duration seconds.
	#      (Harmless today, since end_run() early-returns when the state
	#      isn't RUNNING or PAUSED — but relying on that would be sloppy.)
	#   3. timer.timeout.connect(_on_timeout)
	#   4. EventBus.run_started.connect(_on_run_started)
	#
	# Note what's NOT here: timer.start(). Starting in _ready() would begin
	# counting the moment the scene loads, which is subtly wrong — the
	# timer should measure the RUN, not the scene's lifetime. Child nodes
	# also run _ready() before their parent, so main.gd's start_run() call
	# hasn't even happened yet at this point.
	timer.wait_time = run_duration
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	EventBus.run_started.connect(_on_run_started)


func _on_run_started() -> void:
	# TODO: Begin counting down.
	#
	# Approach:
	#   1. timer.start()
	timer.start()


func _on_timeout() -> void:
	# TODO: The player survived — end the run as a win.
	#
	# Approach:
	#   1. GameState.end_run("time_up")
	#
	# Same door "player_died" goes through. Nothing new was needed on
	# GameState's side to support a win as well as a loss: the reason
	# string was designed for exactly this, back when there was only one
	# possible way for a run to end. Whatever renders the game-over screen
	# reads that string to decide between "You Survived" and "You Died".
	GameState.end_run("time_up")


## For the HUD to poll each frame. Returns seconds remaining, or the full
## duration before the run has started.
func get_time_left() -> float:
	# TODO: Report remaining time.
	#
	# Approach:
	#   1. if timer.is_stopped(): return run_duration
	#   2. return timer.time_left
	#
	# `time_left` is built into Godot's Timer — no need to track elapsed
	# time by hand in _process. The is_stopped() guard matters because a
	# stopped Timer reports 0.0, which would make the HUD flash "0:00"
	# before the run begins.
	if timer.is_stopped():
		return run_duration
	return timer.time_left
