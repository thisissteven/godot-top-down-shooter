## LocomotionComponent.gd
## Owns velocity, acceleration, friction, and the move_and_slide call.
##
## The entity root calls move(direction) each physics frame to set intent,
## then calls apply_movement(body) to actually move the CharacterBody2D.
##
## Other components (DashComponent, KnockbackComponent) add to velocity
## through request_velocity_add() — they never write velocity directly.

class_name LocomotionComponent
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Signals
# ─────────────────────────────────────────────────────────────────────────────

signal stopped()

# ─────────────────────────────────────────────────────────────────────────────
# Exports
# ─────────────────────────────────────────────────────────────────────────────

@export var max_speed: float    = 88.0
@export var acceleration: float = 800.0   ## px/s² — how fast we reach max_speed
@export var friction: float     = 600.0   ## px/s² — how fast we slow to zero

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

@export var instant_movement: bool = true

## Current movement velocity. Read by DashComponent, KnockbackComponent, etc.
var velocity: Vector2 = Vector2.ZERO

var _input_direction: Vector2 = Vector2.ZERO
var _extra_velocity: Vector2  = Vector2.ZERO   # knockback, dash, etc.
var _was_moving: bool = false

# ─────────────────────────────────────────────────────────────────────────────
# Public API — called by entity root each physics frame
# ─────────────────────────────────────────────────────────────────────────────

## Set the intended movement direction. Pass Vector2.ZERO to stop.
## Direction does NOT need to be normalised — get_vector() already handles that.
func move(direction: Vector2) -> void:
    _input_direction = direction


## Apply physics and call move_and_slide on the body.
## body must be the CharacterBody2D (the entity root, i.e. get_parent()).
func apply_movement(body: CharacterBody2D) -> void:
    var delta := get_physics_process_delta_time()

    if instant_movement:
        velocity = _input_direction * max_speed
    else:
        if _input_direction.length() > 0.01:
            velocity = velocity.move_toward(_input_direction * max_speed, acceleration * delta)
        else:
            velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

    # Add external forces (dash impulse, knockback).
    var total_velocity := velocity + _extra_velocity
    _extra_velocity = _extra_velocity.move_toward(Vector2.ZERO, friction * delta)

    body.velocity = total_velocity
    body.move_and_slide()

    # Sync back from CharacterBody2D in case of wall collisions.
    velocity = body.velocity - _extra_velocity

    # Emit stopped once when we come to rest.
    var is_moving := body.velocity.length() > 5.0
    if _was_moving and not is_moving:
        stopped.emit()
    _was_moving = is_moving


## Other components call this to add a one-time velocity impulse
## (dash burst, knockback hit, explosion push).
func request_velocity_add(impulse: Vector2) -> void:
    _extra_velocity += impulse


## Hard override — used to teleport or snap velocity (e.g. wall slide lock).
func set_velocity_override(new_velocity: Vector2) -> void:
    velocity = new_velocity
    _extra_velocity = Vector2.ZERO
