class_name InputComponent
extends Node

signal flashlight_pressed

# Read-only output — other components poll these
var move_input: Vector2 = Vector2.ZERO
var mouse_world_pos: Vector2 = Vector2.ZERO
var mouse_screen_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_physics_priority = -1

func _physics_process(_delta: float) -> void:
	process_physics_priority = -1
	move_input = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()

	mouse_screen_pos = get_viewport().get_mouse_position()

	var camera := get_viewport().get_camera_2d()
	if camera:
		mouse_world_pos = camera.get_global_mouse_position()
	else:
		mouse_world_pos = get_parent().get_global_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flashlight"):
		flashlight_pressed.emit()
