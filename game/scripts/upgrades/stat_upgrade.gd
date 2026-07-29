class_name StatUpgrade
extends UpgradeData
## StatUpgrade
## -----------------------------------------------------------------
## The first upgrade CATEGORY: adds a flat amount to one of the player's
## Stats values.
##
## Game-specific (lives in game/, not addons/) because it knows this game's
## Stats fields and that the target is a Player with a get_stats() method.
##
## Every flat-increase upgrade in the game is a .tres of this class with no
## new code:
##   +20 Max Health   -> stat_name = "max_health",  amount = 20
##   +30 Move Speed   -> stat_name = "move_speed",  amount = 30
##   +0.25 Damage     -> stat_name = "damage_mult", amount = 0.25
## -----------------------------------------------------------------

## Must exactly match a property name on Stats: "max_health", "move_speed",
## or "damage_mult".
##
## A plain String is doing something slightly sneaky here — it's used to
## look up a property by name at RUNTIME, so a typo won't be caught when
## the project compiles. It'll just silently do nothing. That's the price
## of letting content live in .tres files instead of code; the guard in
## apply() below is what turns a silent failure into a visible one.
@export var stat_name: String = ""

## How much to add. Negative works fine if you ever want a cursed upgrade
## that trades one stat for another.
@export var amount: float = 0.0


func apply(target: Node) -> void:
	# TODO: Add `amount` to the named stat on the target's Stats.
	#
	# Approach:
	#   1. var stats: Stats = target.get_stats()
	#      Write the type out rather than using `:=`. apply() must take a
	#      plain `Node` (an override has to match its base signature), and
	#      `Node` has no get_stats() for GDScript to infer a type from, so
	#      inference fails. An explicit annotation tells it what to assume.
	#   2. Guard against a bad stat_name — fail loudly, not silently:
	#        if not stat_name in stats:
	#            push_error("StatUpgrade: no stat named '%s'" % stat_name)
	#            return
	#      push_error() prints to the Debugger with a stack trace, unlike
	#      print(). Worth the two lines: without it, a typo in a .tres
	#      produces an upgrade that appears to work and does nothing.
	#   3. stats.set(stat_name, stats.get(stat_name) + amount)
	#      get()/set() look a property up by string name instead of writing
	#      stats.max_health directly. That indirection is the whole reason
	#      one script can serve every stat.
	#
	# NOTE on max_health: raising it does NOT raise current_health, so a
	# +20 Max Health upgrade leaves the player at the same HP with a longer
	# bar. That's the standard genre behavior. If you'd rather it heal too,
	# call stats.heal(amount) after — but decide deliberately, since it
	# changes how strong the upgrade feels.
	var stats = target.get_stats()
	if not stat_name in stats:
		push_error("StatUpgrade: no stat named '%s'" % stat_name)
		return
	stats.set(stat_name, stats.get(stat_name) + amount)
