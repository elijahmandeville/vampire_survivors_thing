class_name UpgradeData
extends Resource
## UpgradeData
## -----------------------------------------------------------------
## System #13 — Upgrade Selection (the "what can be offered" half)
##
## A BASE CLASS, not something you make .tres files from directly. Every
## real upgrade is a subclass that overrides apply().
##
## THE POINT OF THIS DESIGN:
## Reusability Standard #4 says content should be .tres files, not code.
## Taken literally that would mean every upgrade is "a stat name and a
## number" — which rules out new weapons, followers, status effects, and
## anything else that isn't arithmetic.
##
## The escape is to pay per CATEGORY instead of per ITEM. Each *kind* of
## effect is one small subclass written once; each *instance* of that kind
## is a .tres with no code at all. Twenty stat upgrades = one script and
## twenty .tres files. Inventing followers later = one new script, then
## unlimited follower .tres files.
##
## Crucially, the selection machinery (upgrade_screen.gd) only ever calls
## apply() and reads the display fields below. It never learns what any
## upgrade actually does, which is why new categories need no changes to
## it — the same reason Hurtbox never needed changing when projectiles
## arrived.
##
## Subclasses belong in game/, NOT here. What an upgrade does is content
## and content is game-specific; only the machinery is reusable.
## -----------------------------------------------------------------

## Shown on the choice button.
@export var display_name: String = "Unnamed Upgrade"

## Shown under the name. Keep it short — it's a button, not a tooltip.
@export var description: String = ""

## Optional art. Unused while gray-boxing; here so adding icons later needs
## no changes to the screen that draws them.
@export var icon: Texture2D

## Relative likelihood of being offered. 1.0 is baseline; 0.1 is rare, 5.0
## is common. Not used by the first version of the picker (which draws
## uniformly) — declared now so rarity can be added without touching every
## existing .tres file.
@export var weight: float = 1.0


## Override this in every subclass. `target` is whatever the upgrade acts
## on — the Player node, in this game.
##
## The base version does nothing on purpose rather than push an error: an
## upgrade that's purely cosmetic or purely a marker is legitimate, and a
## silent no-op is easier to debug than a crash mid-level-up.
func apply(_target: Node) -> void:
	pass
