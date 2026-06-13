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
	input_component.switch_weapon_pressed.connect(equipment.cycle_weapon)
	
	equipment.weapon_changed.connect(_on_weapon_changed)
	equipment.equip_by_index(1)

func _on_weapon_changed(type: EquipmentComponent.WeaponType) -> void:
	facing.set_armed(type != EquipmentComponent.WeaponType.NONE)
	var gun := equipment.get_current_gun()
	if gun:
		gun.fired.connect(_trigger_recoil)

func _trigger_recoil(_pos: Vector2, direction: Vector2):
	arm_controller.trigger_recoil(direction)
	
func _physics_process(delta: float) -> void:
	facing.update(
		input_component.mouse_world_pos,
		arm_pivot.global_position,
		input_component.move_input,
		delta,
	)

	loco.move(input_component.move_input)
	loco.apply_movement(self)
	
	if Input.is_action_pressed("shoot") and can_shoot:
		var gun := equipment.get_current_gun()
		if gun:
			facing.activate_cursor_mode()
			gun.try_fire_dir(facing.aim_direction, true)

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
