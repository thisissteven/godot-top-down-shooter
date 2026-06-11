class_name WalkBobComponent
extends Node

@onready var sprite_root: Node2D = $"../Sprite"
@onready var loco: LocomotionComponent = $"../LocomotionComponent"

@export var bob_speed := 10.0
@export var bob_height := 3.0
@export var bob_rotation := 1.5

var t := 0.0

func _process(delta):
    var moving := loco.velocity.length() > 5

    if moving:
        t += delta * bob_speed

        sprite_root.position.y = -abs(sin(t)) * bob_height

        sprite_root.rotation = sin(t) * deg_to_rad(bob_rotation)

    else:
        sprite_root.position.y = lerp(sprite_root.position.y, 0.0, delta * 15)

        sprite_root.rotation = lerp(sprite_root.rotation, 0.0, delta * 15)
