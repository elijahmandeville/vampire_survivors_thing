extends CanvasLayer
## HUD
## -----------------------------------------------------------------
## System #11 — UI/HUD (display only)
##
## Game-specific glue. Add as a child of main.
##
## Contract:
##   IN:  EventBus.player_health_changed, EventBus.xp_changed (pushed).
##        @export var run_timer — polled each frame for the countdown.
##   OUT: nothing. This system is READ-ONLY. It draws state and takes no
##        input and changes nothing. Restart, pause, and upgrade picking
##        all come later as separate things.
##
## WHY CanvasLayer: a plain Control is a child of the world and would
## scroll away with the camera. A CanvasLayer draws in screen space,
## pinned regardless of where the camera is. Any HUD in Godot wants this.
##
## PUSHED vs POLLED — the two halves work differently on purpose:
##   - Health and XP arrive as signals. They change rarely and at moments
##     something else already knows about, so waking up only when they
##     change is both cheaper and simpler than asking every frame.
##   - The run timer is polled in _process. It changes continuously; a
##     signal per frame would be a signal for its own sake, and a signal
##     per second would make the countdown tick in visible jumps.
## Rule of thumb: push for events, poll for continuously-varying values.
##
## Requires these child nodes (build them in the editor, names must match):
##   HealthBar   — ProgressBar
##   XPBar       — ProgressBar
##   LevelLabel  — Label
##   TimerLabel  — Label
## -----------------------------------------------------------------

## Assigned in the Inspector by dragging the RunTimer node in. An exported
## reference, NOT get_node("../RunTimer") — the path would silently break
## the moment either node moved in the tree, whereas Godot updates an
## exported NodePath automatically.
@export var run_timer: Node

@onready var health_bar: ProgressBar = $HealthBar
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var timer_label: Label = $TimerLabel


func _ready() -> void:
	# TODO: Subscribe to the two pushed signals.
	#
	# Approach:
	#   1. EventBus.player_health_changed.connect(_on_player_health_changed)
	#   2. EventBus.xp_changed.connect(_on_xp_changed)
	#
	# No "read the current value once" step needed here, unlike player.gd —
	# this node is created with the scene, so it's already listening before
	# player.gd and Progression push their initial values. Worth checking
	# that assumption if the bars ever start out blank: it depends on the
	# HUD appearing ABOVE Player in main.tscn's node order, since Godot
	# runs _ready() top to bottom.
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.xp_changed.connect(_on_xp_changed)


func _process(_delta: float) -> void:
	# TODO: Refresh the countdown display.
	#
	# Approach:
	#   1. Guard: if run_timer == null: return
	#   2. timer_label.text = _format_time(run_timer.get_time_left())
	if run_timer == null:
		return
	timer_label.text = _format_time(run_timer.get_time_left())


func _on_player_health_changed(current_health: float, max_health: float) -> void:
	# TODO: Update the health bar.
	#
	# Approach:
	#   1. health_bar.max_value = max_health
	#   2. health_bar.value = current_health
	#
	# Setting max_value every time looks redundant, but it means a
	# max-health upgrade later just works with no extra wiring.
	health_bar.max_value = max_health
	health_bar.value = current_health


func _on_xp_changed(current_xp: int, xp_to_next: int, level: int) -> void:
	# TODO: Update the XP bar and level readout.
	#
	# Approach:
	#   1. xp_bar.max_value = xp_to_next
	#   2. xp_bar.value = current_xp
	#   3. level_label.text = "Level %d" % level
	#
	# `"%d" % value` is GDScript's format syntax — %d for a whole number,
	# %s for anything as text. Same idea as printf in C, or f-strings in
	# Python. Handy here because xp_to_next grows every level, so the bar's
	# scale has to be reset each time rather than set once.
	xp_bar.max_value = xp_to_next
	xp_bar.value = current_xp
	level_label.text = "Level %d" % level


func _format_time(seconds: float) -> String:
	# TODO: Turn 95.4 seconds into "1:35".
	#
	# Approach:
	#   1. var total := int(seconds)          # drop the fraction
	#   2. var minutes := total / 60          # int division floors for you
	#   3. var secs := total % 60             # % is remainder
	#   4. return "%d:%02d" % [minutes, secs]
	#
	# %02d means "at least 2 digits, pad with zeros" — that's what turns
	# 1:5 into 1:05. When a format string has more than one placeholder,
	# the values go in an array on the right.
	var total := int(seconds)
	var minutes := floori(total / 60.0)
	var secs := total % 60
	return "%d:%02d" % [minutes, secs]
