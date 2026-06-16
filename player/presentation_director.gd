class_name PresentationDirector
extends Node

@onready var input: InputComponent = $"../InputComponent"
@onready var facing: FacingComponent = $"../FacingComponent"
@onready var equipment = $"../EquipmentComponent"
@onready var presentation: PresentationComponent = $"../PresentationComponent"
@onready var player := get_parent()


func _ready() -> void:
	process_physics_priority = 0

func _physics_process(_delta):

	presentation.dir = facing.current_dir
	presentation.flip_h = facing.flip_h
	
	presentation.armed = equipment.is_armed()

	presentation.aiming = (
		presentation.armed
		and facing.cursor_active()
	)
	
	presentation.jumping = input.is_jumping
	presentation.running = input.is_running and not input.is_jumping
	presentation.moving = input.move_input.length_squared() > 0.01 and not input.is_jumping
	
	if presentation.jumping:
		presentation.motion = PresentationComponent.Motion.JUMP
	elif presentation.moving:
		presentation.motion = PresentationComponent.Motion.WALK
	else:
		presentation.motion = PresentationComponent.Motion.IDLE

	presentation.show_arms = presentation.aiming

	presentation.use_gun_body = presentation.aiming

	presentation.animation_name = _build_animation_name()
	
func _build_animation_name() -> String:

	var suffix := _dir_suffix()

	if presentation.motion == PresentationComponent.Motion.JUMP:
		return "jump_" + suffix

	if presentation.use_gun_body:

		if presentation.motion == PresentationComponent.Motion.WALK:
			return "gun_walk_" + suffix

		return "gun_idle_" + suffix

	else:

		if presentation.motion == PresentationComponent.Motion.WALK:
			return "walk_" + suffix

		return "idle_" + suffix


func _dir_suffix() -> String:

	match presentation.dir:

		FacingComponent.Dir.N:
			return "n"

		FacingComponent.Dir.NE:
			return "ne"

		FacingComponent.Dir.NW:
			return "ne"

		FacingComponent.Dir.E:
			return "se"

		FacingComponent.Dir.SE:
			return "se"

		FacingComponent.Dir.W:
			return "se"

		FacingComponent.Dir.SW:
			return "se"

		FacingComponent.Dir.S:
			if presentation.aiming:
				return "se"
			return "s"

	return "se"
