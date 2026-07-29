extends CanvasLayer
## UpgradeScreen
## -----------------------------------------------------------------
## System #13 — Upgrade Selection (the machinery half)
##
## Reusable: it pauses, offers N choices from a pool, applies the picked
## one, and resumes. It never learns what an upgrade DOES — it only calls
## apply(). New upgrade categories require no changes here.
##
## Contract:
##   IN:  EventBus.level_up (the signal that's been emitting into the void
##        since Progression was built).
##        @export upgrade_pool — Array[UpgradeData], the .tres files to
##        draw from.
##        @export target — what upgrades get applied to (the Player).
##        @export choice_buttons — Array[Button], assigned in the
##        Inspector so layout is entirely your business, not this script's.
##   OUT: GameState.pause_run() / resume_run(), and upgrade.apply(target).
##
## Add as a child of main, below HUD so it draws on top.
##
## FIRST SYSTEM THAT PAUSES AS PART OF NORMAL PLAY. GameState.pause_run()
## has existed since system #1 and — like end_run() before Run End — has
## never once been called. Same PROCESS_MODE_ALWAYS requirement as the
## game-over screen: this screen appears because the game froze, so it has
## to opt out of the freeze to be clickable.
## -----------------------------------------------------------------

@export var upgrade_pool: Array[UpgradeData] = []
@export var target: Node
@export var choice_buttons: Array[Button] = []

## Levels gained but not yet spent. A single big XP drop can cross two
## thresholds, firing level_up twice before the player picks anything —
## without this counter the second level-up would be silently swallowed.
## Same reasoning as the `while` loop in progression.gd.
var pending_levels: int = 0

## The upgrades currently on offer, in button order.
var current_choices: Array[UpgradeData] = []


func _ready() -> void:
	# TODO: Opt out of the pause, hide, and wire up the signals.
	#
	# Approach:
	#   1. process_mode = Node.PROCESS_MODE_ALWAYS
	#   2. visible = false
	#   3. EventBus.level_up.connect(_on_level_up)
	#   4. Connect each button, remembering WHICH button it was:
	#        for i in choice_buttons.size():
	#            choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))
	#
	# bind(i) is new. Button's `pressed` signal carries no arguments, so
	# three buttons would all call the same handler with no way to tell
	# them apart. bind() pre-loads an argument at CONNECT time, so button 0
	# calls _on_choice_pressed(0), button 1 calls _on_choice_pressed(1),
	# and so on. It's the standard way to wire up a row of similar buttons
	# without writing a near-identical handler for each.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.level_up.connect(_on_level_up)
	for i in choice_buttons.size():
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))


func _on_level_up(_level: int) -> void:
	# TODO: Bank the level-up, and present a choice if one isn't already up.
	#
	# Approach:
	#   1. pending_levels += 1
	#   2. if not visible:
	#          _present_choices()
	#
	# The `if not visible` guard is what makes the counter work: if the
	# screen is already open, just bank the level and let _on_choice_pressed
	# re-present when the current pick resolves.
	pending_levels += 1
	if not visible:
		_present_choices()


func _present_choices() -> void:
	# TODO: Pick upgrades, label the buttons, show the screen, pause.
	#
	# Approach:
	#   1. Guard: if upgrade_pool.is_empty(): return
	#      (Otherwise a level-up with an unpopulated pool would freeze the
	#      game behind an empty, unclickable screen — much worse than
	#      simply not offering anything.)
	#   2. current_choices = _pick_choices()
	#   3. Label each button from its matching choice, hiding any spare
	#      buttons if the pool is smaller than choice_buttons.size():
	#        for i in choice_buttons.size():
	#            if i < current_choices.size():
	#                choice_buttons[i].text = "%s\n%s" % [
	#                    current_choices[i].display_name,
	#                    current_choices[i].description]
	#                choice_buttons[i].visible = true
	#            else:
	#                choice_buttons[i].visible = false
	#   4. visible = true
	#   5. Pause only if not already paused:
	#        if not GameState.is_paused():
	#            GameState.pause_run()
	#      The guard matters for the second of two banked level-ups —
	#      pause_run() early-returns unless state is RUNNING, so calling it
	#      while already paused would do nothing, but checking makes the
	#      intent obvious rather than relying on that guard.
	if upgrade_pool.is_empty():
		return
	current_choices = _pick_choices()
	for i in choice_buttons.size():
		if i < current_choices.size():
			choice_buttons[i].text = "%s\n%s" % [
				current_choices[i].display_name,
				current_choices[i].description]
			choice_buttons[i].visible = true
		else:
			choice_buttons[i].visible = false
	visible = true
	if not GameState.is_paused():
		GameState.pause_run()


func _pick_choices() -> Array[UpgradeData]:
	# TODO: Return up to choice_buttons.size() DISTINCT random upgrades.
	#
	# Approach:
	#   1. var pool := upgrade_pool.duplicate()
	#      Duplicate first — shuffling upgrade_pool itself would permanently
	#      reorder the exported array, which is shared state you don't own.
	#   2. pool.shuffle()
	#   3. var count := mini(choice_buttons.size(), pool.size())
	#      mini() is integer min(). Guards the case where the pool has
	#      fewer upgrades than there are buttons.
	#   4. return pool.slice(0, count)
	#      slice(start, end) returns a sub-array; end is exclusive.
	#
	# Distinct WITHIN one offer (shuffle-and-take can't repeat an entry),
	# but nothing stops the same upgrade appearing across different
	# level-ups — which is what makes upgrades stackable, as intended.
	var pool = upgrade_pool.duplicate()
	pool.shuffle()
	var count := mini(choice_buttons.size(), pool.size())
	return pool.slice(0, count)


func _on_choice_pressed(index: int) -> void:
	# TODO: Apply the chosen upgrade, then either offer again or resume.
	#
	# Approach:
	#   1. Guard: if index >= current_choices.size(): return
	#   2. current_choices[index].apply(target)
	#      THE POLYMORPHIC CALL — the whole design in one line. This script
	#      has no idea whether it just added health, granted a weapon, or
	#      spawned a follower. Every future upgrade category flows through
	#      here unchanged.
	#   3. pending_levels -= 1
	#   4. if pending_levels > 0:
	#          _present_choices()   # another level is waiting
	#      else:
	#          visible = false
	#          GameState.resume_run()
	if index >= current_choices.size():
		return
	current_choices[index].apply(target)
	EventBus.upgrade_applied.emit()
	pending_levels -= 1
	if pending_levels > 0:
		_present_choices()
	else:
		visible = false
		GameState.resume_run()
