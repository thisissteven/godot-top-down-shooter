@tool
class_name WindowLight
extends Node2D

@export var light_color: Color = Color(0.2, 0.765, 1.0, 1.0):
    set(value): light_color = value; _rebuild_color()

@export var light_texture: Texture2D
@export var glow_alpha: float = 1.0:
    set(value): glow_alpha = value; _rebuild_color()

@export var glow_scale: float = 0.5

@export var strip_length: float = 1.0:
    set(value):
        strip_length = value
        _apply_strip_length()

func _ready() -> void:
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

    var left := get_node_or_null("LightStripLeft")
    var right := get_node_or_null("LightStripRight")
    if left: left.material = mat
    if right: right.material = mat

    _apply_strip_length()
    _rebuild_color()

func _apply_strip_length() -> void:
    var left := get_node_or_null("LightStripLeft")
    var right := get_node_or_null("LightStripRight")
    if left: left.scale.y = strip_length
    if right: right.scale.y = strip_length

func set_color(selected_color: Color):
    light_color = selected_color
    _rebuild_color()

func set_strip_length(length: float):
    var left := get_node_or_null("LightStripLeft")
    var right := get_node_or_null("LightStripRight")

    if left:
        left.scale.y = length
    if right:
        right.scale.y = length

## Called by LightOverlay when building stamps.
func get_light_stamp_data() -> Dictionary:
    return {
        "position" : global_position,
        "texture"  : light_texture,
        "color": light_color,
        "scale": Vector2(glow_scale, glow_scale)
    }

func _rebuild_color() -> void:
    var left := get_node_or_null("LightStripLeft")
    var right := get_node_or_null("LightStripRight")
    
    if left:
        left.modulate = light_color
        
    if right:
        right.modulate = light_color
