class_name WeaponUpgrade
extends UpgradeData
## WeaponUpgrade
## -----------------------------------------------------------------
## The SECOND upgrade category — and the real test of the base-class
## design. Note what didn't have to change to add it: upgrade_screen.gd is
## untouched, UpgradeData is untouched, StatUpgrade is untouched. The
## screen still just calls apply() and has no idea this exists.
##
## Game-specific (game/, not addons/) for the same reason StatUpgrade is:
## it knows this game has a Player with a Weapon on it.
##
## WHY THIS COULDN'T BE A StatUpgrade: fire rate doesn't live on Stats. It
## lives on the Weapon node, because weapon_system is an addon that must
## work in a project with no Stats system. Rather than dragging weapon
## numbers into Stats (coupling the two addons), a new category reaches the
## Weapon directly. Paying per category instead of per item, exactly as
## designed.
## -----------------------------------------------------------------

## Multiplied into the weapon's fire_interval. Values BELOW 1.0 make it
## fire faster: 0.85 means each shot's wait is 85% of what it was.
##
## MULTIPLICATIVE, not additive — the one place this genuinely differs from
## StatUpgrade, and worth understanding rather than copying.
##
## Subtracting a flat 0.15 from an interval of 1.0 repeatedly gives
## 0.85, 0.70, 0.55 ... 0.10, then NEGATIVE. Each pick would also be worth
## progressively more: going 1.0 -> 0.85 is a 18% rate increase, but
## 0.30 -> 0.15 doubles your rate. Wildly escalating, then broken.
##
## Multiplying by 0.85 each time gives 1.0, 0.85, 0.72, 0.61 ... approaching
## zero without ever reaching it, and every pick is worth the same ~18%.
##
## General rule: additive for quantities (health, damage, speed),
## multiplicative for intervals and rates.
@export var fire_interval_mult: float = 0.85


func apply(target: Node) -> void:
	# TODO: Scale the player's weapon fire interval.
	#
	# Approach:
	#   1. var weapon: Weapon = target.get_weapon()
	#      Same explicit-type-instead-of-`:=` reason as StatUpgrade: apply()
	#      takes a plain Node, which has no get_weapon() to infer from.
	#   2. Guard, because a player might legitimately have no weapon:
	#        if weapon == null:
	#            push_error("WeaponUpgrade: target has no weapon")
	#            return
	#   3. weapon.fire_interval *= fire_interval_mult
	#
	# Step 3 is one line and does two things, thanks to the setter on
	# weapon.fire_interval — it updates the field AND the running Timer's
	# wait_time, and clamps to min_fire_interval. Worth appreciating: this
	# script doesn't know a Timer is involved at all.
	var weapon: Weapon = target.get_weapon()
	if weapon == null:
		push_error("WeaponUpgrade: target has no weapon")
		return
	weapon.fire_interval *= fire_interval_mult
