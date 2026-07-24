class_name Movement2D
extends CharacterBody2D
## Movement2D
## -----------------------------------------------------------------
## System #3 — Movement/Input (player control)
##
## Contract:
##   IN:  @export var speed — how fast this body moves, in pixels/second.
##        Reads directional input every physics frame via Godot's Input
##        singleton (four named actions — see setup note below).
##   OUT: none yet. Nothing downstream needs to react to "movement
##        happened" at this stage — add a signal later only if something
##        actually needs it (e.g. footstep audio reacting to a
##        started_moving/stopped_moving signal).
##
## Self-contained by design: this script extends CharacterBody2D directly,
## so this node IS the physics body — drop it into any empty scene and it
## moves itself, no sibling/parent node lookups required (Reusability
## Standard #1). It deliberately doesn't know Stats exists; if you want
## stat-driven speed later, sync it from the OUTSIDE instead of reaching
## into Stats from here — e.g. in the Player scene's own (game-specific)
## script: `$Movement2D.speed = stats.move_speed`. That keeps this addon
## usable in a project that has no Stats system at all.
##
## Setup required before this does anything: it reads four input actions
## that don't exist by default. Add them in Project Settings > Input Map:
## "move_up", "move_down", "move_left", "move_right" — bind each to WASD
## and/or arrow keys.
## -----------------------------------------------------------------

@export var speed: float = 200.0


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
