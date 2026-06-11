class_name AnimationDirector
extends Node

# Sprite references — assign in inspector or @onready
@onready var sprite_root: Node2D           = $"../Sprite"
@onready var body_sprite: AnimatedSprite2D = $"../Sprite/BodySprite"
@onready var arm_pivot:   Node2D           = $"../Sprite/ArmPivot"
@onready var arm_sprite:      Sprite2D     = $"../Sprite/ArmPivot/ArmSprite"
@onready var arm_sprite_back: Sprite2D     = $"../Sprite/ArmPivot/ArmSpriteBack"

# Component references
@onready var facing:    FacingComponent    = $"../FacingComponent"
@onready var loco:      LocomotionComponent = $"../LocomotionComponent"
@onready var equipment: EquipmentComponent = $"../EquipmentComponent"
@onready var input_component: InputComponent = $"../InputComponent"

@export var walk_bob_degrees: float = 1.5
@export var walk_bob_speed: float = 10.0
@export var walk_bob_amplitude: float = 3.0

@export var recoil_distance: float = 6.0
@export var recoil_recovery_speed: float = 18.0

var _recoil_offset: float = 0.0
var _arm_pivot_base_x: float = 0.0

var _anim_locked: bool = false

func lock_anim(duration: float) -> void:
    _anim_locked = true
    await get_tree().create_timer(duration).timeout
    _anim_locked = false

@export var arm_pivot_offset_x: float = 1.0 

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
    _update_recoil(delta)

func _update_recoil(delta: float) -> void:
    _recoil_offset = lerp(_recoil_offset, 0.0, delta * recoil_recovery_speed)
    arm_pivot.position.x = _arm_pivot_base_x - _recoil_offset * signf(_arm_pivot_base_x)

func trigger_recoil(duration: float = 0.15) -> void:
    _recoil_offset = recoil_distance
    lock_anim(duration)

func _update_walk_bob(delta: float) -> void:
    if _get_loco_state() == &"walk":
        _bob_time += delta * walk_bob_speed
        sprite_root.position.y = abs(sin(_bob_time)) * -walk_bob_amplitude
        sprite_root.rotation = sin(_bob_time) * deg_to_rad(walk_bob_degrees)
    else:
        sprite_root.position.y = lerp(sprite_root.position.y, 0.0, delta * 15.0)
        sprite_root.rotation = lerp(sprite_root.rotation, 0.0, delta * 15.0)
        # remove the _bob_time = 0.0 line, or only reset once fully settled:
        if abs(sprite_root.position.y) < 0.1:
            _bob_time = 0.0
        
        
# ── Direction / animation name resolution ──────────────────────────────────

func _on_direction_changed(_dir: FacingComponent.Dir, flip: bool) -> void:
    body_sprite.flip_h = flip
    arm_sprite.flip_v = flip
    arm_sprite_back.flip_v = flip
    _arm_pivot_base_x = -arm_pivot_offset_x if flip else arm_pivot_offset_x
    _recoil_offset = 0.0  # cancel any in-progress recoil on turn
    arm_pivot.position.x = _arm_pivot_base_x
    _play_current_animation()
    
    
func _get_loco_state() -> StringName:
    #if _is_jumping:
        #return &"jump"
    if input_component.move_input.length() > 0.01:
        return &"walk"
    return &"idle"

func _on_weapon_changed(_weapon) -> void:
    facing.set_armed(equipment.is_armed())
    var textures := equipment.get_arm_textures()
    arm_sprite.texture      = textures["front"]
    arm_sprite_back.texture = textures["back"]
    arm_sprite_back.visible = textures["back"] != null
    _play_current_animation()

func _safe_play(anim_name: String) -> void:
    if body_sprite.sprite_frames and body_sprite.sprite_frames.has_animation(anim_name):
        body_sprite.play(anim_name)
    else:
        push_warning("AnimationDirector: missing animation '%s'" % anim_name)
        
# In AnimationDirector._play_current_animation():
func _play_current_animation() -> void:
    if _anim_locked:
        return
        
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
                arm_pivot.visible = false

        &"walk":
            if armed and cursor_active:
                _safe_play("gun_walk_" + suffix)
            else:
                _safe_play("walk_" + suffix)   # with-arms walk on timeout
                arm_pivot.visible = false

        &"jump":
            _safe_play("jump_" + suffix)
            body_sprite.stop()
            arm_pivot.visible = false
            
# ── Arm visibility (cursor-inactivity logic) ────────────────────────────────

func _update_arm_visibility(delta: float) -> void:
    if not equipment.is_armed():
        arm_pivot.visible = false
        return

    # FacingComponent exposes cursor_active — read it directly
    var cursor_active: bool = facing._cursor_active

    if cursor_active:
        _arm_visible_timer = arm_hide_timeout
        arm_pivot.visible = true
        _cursor_was_active = true
    else:
        if _cursor_was_active:
            _arm_visible_timer -= delta
            if _arm_visible_timer <= 0.0:
                arm_pivot.visible = false
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
    
    arm_pivot.rotation = to_cursor.angle()

# ── Arm z-index (in front when facing south hemisphere, behind for north) ───

func _update_arm_z_index() -> void:
    var dir := facing.current_dir
    var behind_dirs := [
        FacingComponent.Dir.N,
        FacingComponent.Dir.NE,
        FacingComponent.Dir.NW,
    ]
    arm_pivot.z_index = -1 if dir in behind_dirs else 1
