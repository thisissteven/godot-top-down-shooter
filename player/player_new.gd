extends CharacterBody2D

@export var projectile_scene: PackedScene
@export var fire_rate := 10

@onready var input_component: InputComponent  = $InputComponent
@onready var equipment: EquipmentComponent    = $EquipmentComponent
@onready var loco: LocomotionComponent        = $LocomotionComponent
@onready var shooting_timer: Timer            = $ShootingTimer
@onready var facing: FacingComponent          = $FacingComponent
@onready var shine_light                      = $ShineLight
@onready var shadow_light                     = $ShadowLight
@onready var anim_director: AnimationDirector = $AnimationDirector
@onready var sprite: Node2D                   = $Sprite
@onready var arm_pivot: Node2D                = $Sprite/ArmPivot
@onready var arm_controller: ArmController    = $ArmController

var can_shoot := true
var flashlight_tween: Tween
var is_shooting := false

func _ready() -> void:
	shooting_timer.one_shot = true
	shooting_timer.timeout.connect(func(): can_shoot = true)
	input_component.flashlight_pressed.connect(_on_flashlight_pressed)
	equipment.equip(EquipmentComponent.WeaponType.PISTOL)

func _physics_process(delta: float) -> void:
	facing.update(
		input_component.mouse_world_pos,
		global_position,
		input_component.move_input,
		delta
	)

	loco.move(input_component.move_input)
	loco.apply_movement(self)
	
	if Input.is_action_pressed("shoot") and can_shoot:
		_shoot()

func _shoot() -> void:
	if not projectile_scene:
		return
	can_shoot = false
	
	var direction := (input_component.mouse_world_pos - global_position).normalized()
	
	arm_controller.trigger_recoil(direction)
	
	var projectile = projectile_scene.instantiate()
	
	# Spawn from barrel tip instead of player center
	var barrel_offset := 12.0  # distance from arm_pivot along aim direction
	projectile.global_position = arm_pivot.global_position + direction * barrel_offset
	projectile.direction = direction
	projectile.rotation = direction.angle()
	
	# Z-index: behind player when aiming upward, in front when aiming downward
	var is_aiming_up := direction.y < 0
	projectile.z_index = -1 if is_aiming_up else 1
	
	get_tree().current_scene.add_child(projectile)
	shooting_timer.start(1.0 / fire_rate)

func _on_flashlight_pressed() -> void:
	var turning_on: bool = not shine_light.enabled

	if flashlight_tween:
		flashlight_tween.kill()

	if turning_on:
		shine_light.enabled  = true
		shadow_light.enabled = true
		shine_light.energy   = 0.0
		shadow_light.energy  = 0.0

		flashlight_tween = create_tween()
		flashlight_tween.tween_property(shine_light,  "energy", 1.0, 0.2)
		flashlight_tween.parallel().tween_property(shadow_light, "energy", 1.0, 0.2)
	else:
		shine_light.enabled  = false
		shadow_light.enabled = false
		shine_light.energy   = 1.0
		shadow_light.energy  = 1.0
