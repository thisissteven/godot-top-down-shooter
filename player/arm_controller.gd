class_name ArmController
extends Node

@onready var arm_pivot: Node2D = $"../Sprite/ArmPivot"
@onready var arm_sprite: Sprite2D = $"../Sprite/ArmPivot/RecoilNode/ArmSprite"
@onready var arm_sprite_back: Sprite2D = $"../Sprite/ArmPivot/RecoilNode/ArmSpriteBack"
@onready var gun_pivot: Node2D = $"../Sprite/ArmPivot/RecoilNode/GunPivot"

@onready var facing: FacingComponent = $"../FacingComponent"
@onready var equipment: EquipmentComponent = $"../EquipmentComponent"
@onready var presentation: PresentationComponent = $"../PresentationComponent"

@export var arm_hide_timeout := 1.0

@export var recoil_distance := 2.0
@export var recoil_recovery_speed := 18.0

@onready var recoil_node: Node2D = $"../Sprite/ArmPivot/RecoilNode"
@onready var base_position := recoil_node.position

var hide_timer := 0.0
var base_arm_sprite_x_north: float
var base_arm_sprite_x_south: float

func _ready():
	equipment.weapon_changed.connect(_on_weapon_changed)
	process_physics_priority = 20

func get_flipped_base() -> Vector2:
	var flip := facing.aiming_left()
	var aiming_up := facing.current_dir == facing.Dir.N or facing.current_dir == facing.Dir.NE or facing.current_dir == facing.Dir.NW
	var offset := (-2.5 if flip else 2.5) if aiming_up else 0.0
	return Vector2(
		(-base_position.x if flip else base_position.x) + offset,
		base_position.y
	)
	
func _physics_process(delta):
	update_visibility(delta)
	update_rotation()
	update_z()
	recoil_node.position = recoil_node.position.lerp(
		get_flipped_base(),
		recoil_recovery_speed * delta
	)

func update_visibility(_delta):
	arm_pivot.visible = presentation.show_arms

func update_rotation():
	if !presentation.show_arms:
		return
	var aim_angle := facing.aim_direction.angle()
	var flip := facing.aiming_left()
	recoil_node.rotation = aim_angle
	# Flip Y (not X) to mirror correctly after rotation
	recoil_node.scale.x = 1.0
	recoil_node.scale.y = -1.0 if flip else 1.0
	arm_sprite.flip_h = false
	arm_sprite_back.flip_h = false
	gun_pivot.scale = Vector2.ONE
	
	if facing.aiming_up():
		var current_dir = facing.current_dir
		if current_dir == facing.Dir.E:
			arm_sprite.offset.x = base_arm_sprite_x_south
		elif current_dir == facing.Dir.W:
			arm_sprite.offset.x = base_arm_sprite_x_south
		else:
			arm_sprite.offset.x = base_arm_sprite_x_north
	else:
		arm_sprite.offset.x = base_arm_sprite_x_south
	
func trigger_recoil(_direction: Vector2):
	var recoil_offset := -facing.aim_direction * recoil_distance
	recoil_node.position = get_flipped_base() + recoil_offset
	
func update_z():
	var facing_up = presentation.dir in [
		FacingComponent.Dir.N,
		FacingComponent.Dir.NE,
		FacingComponent.Dir.NW
	]
	
	if facing_up:
		arm_pivot.get_parent().move_child(arm_pivot, 0)
	else:
		arm_pivot.get_parent().move_child(
			arm_pivot,
			arm_pivot.get_parent().get_child_count() - 1
		)

func _on_weapon_changed(type: EquipmentComponent.WeaponType):
	var textures := equipment.get_arm_textures()

	arm_sprite.texture = textures.front
	arm_sprite_back.texture = textures.back
	
	if type == EquipmentComponent.WeaponType.PLASMA:
		base_arm_sprite_x_north = 3.5
		base_arm_sprite_x_south = 6.5
	else:
		base_arm_sprite_x_north = 3.5
		base_arm_sprite_x_south = 3.5

	arm_sprite_back.visible = (
		textures.back != null
	)
