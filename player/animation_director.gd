class_name AnimationDirector
extends Node

@onready var body_sprite: AnimatedSprite2D = $"../Sprite/BodySprite"

@onready var facing: FacingComponent = $"../FacingComponent"
@onready var equipment: EquipmentComponent = $"../EquipmentComponent"
@onready var loco: LocomotionComponent = $"../LocomotionComponent"

enum BodyState {
    IDLE,
    WALK,
    GUN_IDLE,
    GUN_WALK
}

const DIR_SUFFIX := {
    FacingComponent.Dir.N: "n",
    FacingComponent.Dir.NE: "ne",
    FacingComponent.Dir.NW: "ne",
    FacingComponent.Dir.E: "se",
    FacingComponent.Dir.SE: "se",
    FacingComponent.Dir.S: "s",
    FacingComponent.Dir.SW: "se",
    FacingComponent.Dir.W: "se",
}

const ANIM_PREFIX : Dictionary[BodyState, String] = {
    BodyState.IDLE: "idle_",
    BodyState.WALK: "walk_",
    BodyState.GUN_IDLE: "gun_idle_",
    BodyState.GUN_WALK: "gun_walk_",
}

var current_anim := ""

func _ready():
    facing.direction_changed.connect(_on_direction_changed)

func _process(_delta):
    update_animation()

func _on_direction_changed(_dir, flip):
    body_sprite.flip_h = flip
    
func update_animation():
    var state := get_body_state()

    var anim : String = (
        ANIM_PREFIX[state]
        + DIR_SUFFIX[facing.current_dir]
    )

    if anim == current_anim:
        return

    current_anim = anim

    if body_sprite.sprite_frames.has_animation(anim):
        body_sprite.play(anim)

func get_body_state() -> BodyState:
    var walking := loco.velocity.length() > 5

    if equipment.is_armed() and facing.cursor_active():
        return BodyState.GUN_WALK if walking else BodyState.GUN_IDLE

    return BodyState.WALK if walking else BodyState.IDLE
