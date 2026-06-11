class_name AnimationDirector
extends Node

# Sprite references — assign in inspector or @onready
@onready var body_sprite: AnimatedSprite2D = $"../BodySprite"
@onready var arm_sprite:  Sprite2D         = $"../ArmPivot/ArmSprite"
@onready var arm_pivot:   Node2D           = $"../ArmPivot"

# Component references
@onready var facing:    FacingComponent    = $"../FacingComponent"
@onready var loco:      LocomotionComponent = $"../LocomotionComponent"
@onready var equipment: EquipmentComponent = $"../EquipmentComponent"
@onready var input_component: InputComponent = $"../InputComponent"

@export var walk_bob_degrees: float = 1.5
@export var walk_bob_speed: float = 10.0

var _bob_time: float = 0.0

# Cursor-inactivity for armed↔idle-with-arms transition
@export var arm_hide_timeout := 1.0
var _arm_visible_timer := 0.0
var _cursor_was_active := false

var _is_jumping: bool = false

func set_jumping(jumping: bool) -> void:
    _is_jumping = jumping

const DIR_SUFFIX := {
    FacingComponent.Dir.N:  "n",
    FacingComponent.Dir.NE: "ne",
    FacingComponent.Dir.NW: "ne",   # reused, flip handled by body_sprite.flip_h
    FacingComponent.Dir.E:  "se",   # reuse southeast
    FacingComponent.Dir.SE: "se",
    FacingComponent.Dir.S:  "s",
    FacingComponent.Dir.SW: "se",   # reuse, flip
    FacingComponent.Dir.W:  "se",   # reuse, flip
}

func _ready() -> void:
    facing.direction_changed.connect(_on_direction_changed)
    equipment.weapon_changed.connect(_on_weapon_changed)

func _process(delta: float) -> void:
    _update_walk_bob(delta)
    _play_current_animation()
    _update_arm_visibility(delta)
    _update_arm_rotation()
    _update_arm_z_index()


func _update_walk_bob(delta: float) -> void:
    if _get_loco_state() == &"walk":
        _bob_time += delta * walk_bob_speed
        body_sprite.rotation = sin(_bob_time) * deg_to_rad(walk_bob_degrees)
    else:
        # Smoothly reset rotation back to zero when not walking
        body_sprite.rotation = lerp(body_sprite.rotation, 0.0, delta * 15.0)
        _bob_time = 0.0
        
        
# ── Direction / animation name resolution ──────────────────────────────────

func _on_direction_changed(_dir: FacingComponent.Dir, flip: bool) -> void:
    body_sprite.flip_h = flip
    arm_pivot.scale.x = -1.0 if flip else 1.0
    arm_pivot.position.x = -abs(arm_pivot.position.x) if flip else abs(arm_pivot.position.x)
    _play_current_animation()
    
    
func _get_loco_state() -> StringName:
    #if _is_jumping:
        #return &"jump"
    if input_component.move_input.length() > 0.01:
        return &"walk"
    return &"idle"

func _on_weapon_changed(_weapon) -> void:
    facing.set_armed(equipment.is_armed())
    arm_sprite.texture = equipment.get_arm_texture()
    _play_current_animation()

func _safe_play(anim_name: String) -> void:
    if body_sprite.sprite_frames and body_sprite.sprite_frames.has_animation(anim_name):
        body_sprite.play(anim_name)
    else:
        push_warning("AnimationDirector: missing animation '%s'" % anim_name)
        
# In AnimationDirector._play_current_animation():
func _play_current_animation() -> void:
    var dir    := facing.current_dir
    var state  := _get_loco_state()
    var armed  := equipment.is_armed()
    var suffix : String = DIR_SUFFIX[dir]
    var cursor_active := facing._cursor_active

    match state:
        &"idle":
            if armed and cursor_active:
                _safe_play("gun_idle_" + suffix)
            else:
                _safe_play("idle_" + suffix)
                arm_sprite.visible = false

        &"walk":
            if armed and cursor_active:
                _safe_play("gun_walk_" + suffix)
            else:
                _safe_play("walk_" + suffix)   # with-arms walk on timeout
                arm_sprite.visible = false

        &"jump":
            _safe_play("jump_" + suffix)
            body_sprite.stop()
            arm_sprite.visible = false
            
# ── Arm visibility (cursor-inactivity logic) ────────────────────────────────

func _update_arm_visibility(delta: float) -> void:
    if not equipment.is_armed():
        arm_sprite.visible = false
        return

    # FacingComponent exposes cursor_active — read it directly
    var cursor_active: bool = facing._cursor_active

    if cursor_active:
        _arm_visible_timer = arm_hide_timeout
        arm_sprite.visible = true
        _cursor_was_active = true
    else:
        if _cursor_was_active:
            _arm_visible_timer -= delta
            if _arm_visible_timer <= 0.0:
                arm_sprite.visible = false
                _cursor_was_active = false
                # Revert body to idle-with-arms
                _play_current_animation()

# ── Arm rotation ─────────────────────────────────────────────────────────────

func _update_arm_rotation() -> void:
    if not arm_sprite.visible:
        return
    var cursor_world := get_viewport().get_camera_2d().get_global_mouse_position() \
        if get_viewport().get_camera_2d() else get_viewport().get_mouse_position()
    var to_cursor := cursor_world - arm_pivot.global_position
    var angle := to_cursor.angle()
    
    # When scale.x is -1, rotation needs to be negated to compensate for the flip
    if arm_pivot.scale.x < 0.0:
        angle = -angle
    
    arm_pivot.rotation = angle

# ── Arm z-index (in front when facing south hemisphere, behind for north) ───

func _update_arm_z_index() -> void:
    var dir := facing.current_dir
    var behind_dirs := [
        FacingComponent.Dir.N,
        FacingComponent.Dir.NE,
        FacingComponent.Dir.NW,
    ]
    arm_pivot.z_index = -1 if dir in behind_dirs else 1
