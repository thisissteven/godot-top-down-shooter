class_name ArmController
extends Node

@onready var arm_pivot: Node2D = $"../Sprite/ArmPivot"
@onready var arm_sprite: Sprite2D = $"../Sprite/ArmPivot/ArmSprite"
@onready var arm_sprite_back: Sprite2D = $"../Sprite/ArmPivot/ArmSpriteBack"

@onready var facing: FacingComponent = $"../FacingComponent"
@onready var equipment: EquipmentComponent = $"../EquipmentComponent"
@onready var presentation: PresentationComponent = $"../PresentationComponent"

@export var arm_hide_timeout := 1.0

@export var recoil_distance := 4.0
@export var recoil_recovery_speed := 18.0
@export var arm_pivot_offset_x := 1.0

var hide_timer := 0.0
var recoil_offset := Vector2.ZERO
var base_position := Vector2.ZERO

func _ready():
    equipment.weapon_changed.connect(_on_weapon_changed)
    base_position = arm_pivot.position
    process_physics_priority = 20

func _physics_process(delta):
    update_visibility(delta)
    update_rotation()
    update_z()

func update_visibility(_delta):
    arm_pivot.visible = presentation.show_arms

func update_rotation():
    if !presentation.show_arms:
        return

    arm_pivot.rotation = facing.aim_direction.angle()

    recoil_offset = recoil_offset.lerp(
        Vector2.ZERO,
        get_process_delta_time() * recoil_recovery_speed
    )

    arm_pivot.position = base_position + recoil_offset
    
func trigger_recoil(direction: Vector2):
    recoil_offset = -direction.normalized() * recoil_distance
        
func update_z():
    match presentation.dir:
        FacingComponent.Dir.N:
            arm_pivot.z_index = -1
        FacingComponent.Dir.NE:
            arm_pivot.z_index = -1
        FacingComponent.Dir.NW:
            arm_pivot.z_index = -1
        _:
            arm_pivot.z_index = 1


func _on_weapon_changed(_weapon):
    var textures := equipment.get_arm_textures()

    arm_sprite.texture = textures.front
    arm_sprite_back.texture = textures.back

    arm_sprite_back.visible = (
        textures.back != null
    )
