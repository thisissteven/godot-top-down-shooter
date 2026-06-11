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

@export var recoil_distance := 4.0
@export var recoil_recovery_speed := 18.0
@export var arm_pivot_offset_x := 1.0

@onready var recoil_node: Node2D = $"../Sprite/ArmPivot/RecoilNode"
@onready var base_position := arm_pivot.position

var hide_timer := 0.0

func _ready():
	equipment.weapon_changed.connect(_on_weapon_changed)
	base_position = arm_pivot.position
	process_physics_priority = 20

func _physics_process(delta):
	update_visibility(delta)
	update_rotation()
	update_z()
	recoil_node.position = recoil_node.position.lerp(
		Vector2.ZERO,
		recoil_recovery_speed * delta
	)

func update_visibility(_delta):
	arm_pivot.visible = presentation.show_arms

func update_rotation():
	if !presentation.show_arms:
		return
	var aim_angle := facing.aim_direction.angle()
	var flip := facing.aim_direction.x < 0.0
	arm_pivot.rotation = aim_angle
	# Flip Y (not X) to mirror correctly after rotation
	arm_pivot.scale.x = 1.0
	arm_pivot.scale.y = -1.0 if flip else 1.0
	arm_sprite.flip_h = false
	arm_sprite_back.flip_h = false
	gun_pivot.scale = Vector2.ONE
	
	
func trigger_recoil(_direction: Vector2):
	var local_recoil = arm_pivot.to_local(arm_pivot.global_position - facing.aim_direction * recoil_distance)
	recoil_node.position = local_recoil
		
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


func _on_weapon_changed(_weapon):
	var textures := equipment.get_arm_textures()

	arm_sprite.texture = textures.front
	arm_sprite_back.texture = textures.back

	arm_sprite_back.visible = (
		textures.back != null
	)
