class_name ArmController
extends Node

@onready var arm_pivot: Node2D = $"../Sprite/ArmPivot"
@onready var arm_sprite: Sprite2D = $"../Sprite/ArmPivot/ArmSprite"
@onready var arm_sprite_back: Sprite2D = $"../Sprite/ArmPivot/ArmSpriteBack"

@onready var facing: FacingComponent = $"../FacingComponent"
@onready var equipment: EquipmentComponent = $"../EquipmentComponent"

@export var arm_hide_timeout := 1.0

@export var recoil_distance := 4.0
@export var recoil_recovery_speed := 18.0
@export var arm_pivot_offset_x := 1.0

var hide_timer := 0.0
var recoil_offset := Vector2.ZERO
var base_position := Vector2.ZERO

func _ready():
    facing.direction_changed.connect(_on_direction_changed)
    equipment.weapon_changed.connect(_on_weapon_changed)
    base_position = arm_pivot.position

func _process(delta):
    update_visibility(delta)
    update_rotation()
    update_z()

func update_visibility(delta):
    if !equipment.is_armed():
        arm_pivot.visible = false
        return

    if facing.cursor_active():
        arm_pivot.visible = true
        hide_timer = arm_hide_timeout
    else:
        hide_timer -= delta

        if hide_timer <= 0:
            arm_pivot.visible = false

func update_rotation():
    if !arm_pivot.visible:
        return

    var camera := get_viewport().get_camera_2d()

    var mouse_pos := (
        camera.get_global_mouse_position()
        if camera
        else get_viewport().get_mouse_position()
    )

    var direction := (mouse_pos - arm_pivot.global_position).normalized()

    arm_pivot.rotation = direction.angle()

    recoil_offset = recoil_offset.lerp(
        Vector2.ZERO,
        get_process_delta_time() * recoil_recovery_speed
    )

    arm_pivot.position = base_position + recoil_offset
    
func trigger_recoil(direction: Vector2):
    recoil_offset = -direction.normalized() * recoil_distance
        
func update_z():
    if facing.current_dir in [
        FacingComponent.Dir.N,
        FacingComponent.Dir.NE,
        FacingComponent.Dir.NW
    ]:
        arm_pivot.z_index = -1
    else:
        arm_pivot.z_index = 1

func _on_direction_changed(_dir, flip):
    arm_sprite.flip_v = flip
    arm_sprite_back.flip_v = flip

func _on_weapon_changed(_weapon):
    var textures := equipment.get_arm_textures()

    arm_sprite.texture = textures.front
    arm_sprite_back.texture = textures.back

    arm_sprite_back.visible = (
        textures.back != null
    )
