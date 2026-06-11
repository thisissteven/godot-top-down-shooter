class_name RecoilComponent
extends Node

@onready var arm_pivot: Node2D = $"../Sprite/ArmPivot"
@onready var facing: FacingComponent = $"../FacingComponent"

@export var recoil_distance := 6.0
@export var recovery_speed := 18.0

var recoil_offset := Vector2.ZERO

var recoil := 0.0
var base_x := 0.0

func _ready():
	facing.direction_changed.connect(_on_direction_changed)

	base_x = pivot_offset_x
	arm_pivot.position.x = base_x

func _process(delta):
	recoil = lerp(
		recoil,
		0.0,
		delta * recovery_speed
	)

	arm_pivot.position.x = base_x - recoil * sign(base_x)

func trigger():
	recoil = recoil_distance

func _on_direction_changed(_dir, flip):
	base_x = (
		-pivot_offset_x
		if flip
		else pivot_offset_x
	)

	recoil = 0.0
