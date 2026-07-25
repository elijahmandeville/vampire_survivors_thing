class_name Progression
extends Node
## Progression
## -----------------------------------------------------------------
## System #7 — Progression (XP, leveling)
##
## Contract:
##   IN:  EventBus.xp_gained(amount) — subscribed globally, so this doesn't
##        care where XP came from (gems today, quest rewards later).
##        @export var base_xp_to_level, xp_curve_multiplier — the level
##        curve as tunable data rather than hardcoded numbers.
##   OUT: EventBus.level_up(level). Readable state: current_xp, level,
##        xp_to_next.
##
## NOT an autoload, deliberately — same call as Stats. Add it as a child of
## main. XP is per-run state, and a node that's part of the run gets reset
## simply by reloading the scene, whereas an autoload would carry a stale
## level into the next run unless something remembered to clear it.
##
## Knows nothing about upgrades or UI. It emits level_up and stops there;
## what a level-up *offers the player* is system #8's problem. This is what
## keeps Progression testable right now with nothing but console prints.
## -----------------------------------------------------------------

@export var base_xp_to_level: int = 5
## Each level costs this much more than the last (1.5 = each level needs
## 50% more XP). Float on purpose so the curve can be tuned finely; the
## result gets rounded back to an int in _recalculate_xp_to_next().
@export var xp_curve_multiplier: float = 1.5

var current_xp: int = 0
var level: int = 1
var xp_to_next: int = 0


func _ready() -> void:
	# TODO: Set the first level's XP requirement and subscribe to XP events.
	#
	# Approach:
	#   1. xp_to_next = base_xp_to_level
	#   2. EventBus.xp_gained.connect(_on_xp_gained)
	xp_to_next = base_xp_to_level
	EventBus.xp_gained.connect(_on_xp_gained)


func _on_xp_gained(amount: int) -> void:
	# TODO: Bank the XP, then level up as many times as it warrants.
	#
	# Approach:
	#   1. current_xp += amount
	#   2. Level up WHILE current_xp >= xp_to_next — a `while`, not an `if`.
	#      A single big XP drop could cross two thresholds at once, and an
	#      `if` would silently swallow the second level. Inside the loop:
	#        current_xp -= xp_to_next   # carry the remainder forward
	#        level += 1
	#        _recalculate_xp_to_next()
	#        EventBus.level_up.emit(level)
	#
	# Subtracting rather than resetting current_xp to 0 means overflow XP
	# isn't wasted — 7 XP into a 5-XP level leaves you 2 into the next one.
	#
	# Watch out: _recalculate_xp_to_next() must run BEFORE the loop checks
	# its condition again, or xp_to_next stays at the old value and the
	# loop may never exit. It's already ordered correctly above.
	current_xp += amount
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		level += 1
		_recalculate_xp_to_next()
		EventBus.level_up.emit(level)


func _recalculate_xp_to_next() -> void:
	# TODO: Work out the XP cost of the level just reached.
	#
	# Approach:
	#   1. xp_to_next = int(base_xp_to_level * pow(xp_curve_multiplier, level - 1))
	#
	# pow(base, exponent) is exponentiation. `level - 1` so level 1 costs
	# exactly base_xp_to_level (anything to the power of 0 is 1). int()
	# truncates the float back to a whole number of XP.
	#
	# Derived from level rather than accumulated by repeated multiplication
	# on purpose: the cost of any level is computable from scratch at any
	# time, which makes it far easier to debug and to save/load later.
	xp_to_next = int(base_xp_to_level * pow(xp_curve_multiplier, level - 1))
