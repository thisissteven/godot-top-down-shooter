@tool
class_name WallLight
extends Node2D

# ─────────────────────────────────────────────
#  Enums
# ─────────────────────────────────────────────

enum GlowDirection { UP, DOWN, LEFT, RIGHT }
enum GlowShape     { CONE, RADIAL, STRIP }

# ─────────────────────────────────────────────
#  Node refs
# ─────────────────────────────────────────────

@onready var core_sprite: Sprite2D = $Light

# ─────────────────────────────────────────────
#  Exports — Color
# ─────────────────────────────────────────────

@export_group("Color")

@export var light_color: Color = Color(0.2, 0.765, 1.0, 1.0):
	set(value): light_color = value; _rebuild_color()
	
@export var light_texture: Texture2D

@export var glow_alpha: float = 1.0:
	set(value): glow_alpha = value; _rebuild_color()

## When true, randomize_color picks from the palette instead of a random hue.
@export var use_color_palette: bool = true

@export var palette: Array[Color] = [
	Color("447cffff")
]

@export var glow_direction: GlowDirection = GlowDirection.DOWN:
	set(value): glow_direction = value;

# ─────────────────────────────────────────────
#  Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	
	core_sprite.material = mat
	_rebuild_color()
	
	if not glow_direction == GlowDirection.DOWN:
		core_sprite.z_index  = 98

## Called by LightOverlay when building stamps.
func get_light_stamp_data(selected_color: Color) -> Dictionary:
	core_sprite.modulate = selected_color
	return {
		"position" : global_position,
		"texture"  : light_texture,          # your existing @export var
	}

# ─────────────────────────────────────────────
#  Helpers — rebuild
# ─────────────────────────────────────────────

func _rebuild_color() -> void:
	if core_sprite:
		core_sprite.modulate = light_color

# ─────────────────────────────────────────────
#  Helpers — color
# ─────────────────────────────────────────────

func _pick_random_color() -> void:
	if use_color_palette and not palette.is_empty():
		light_color = palette[randi() % palette.size()]

# ─────────────────────────────────────────────
#  Helpers — geometry
# ─────────────────────────────────────────────

func _facing_vector() -> Vector2:
	match glow_direction:
		GlowDirection.DOWN:  return Vector2(0,  1)
		GlowDirection.LEFT:  return Vector2(-1, 0)
		GlowDirection.RIGHT: return Vector2(1,  0)
	return Vector2.ZERO


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		remove_from_group('wall_light')
		var overlay := get_tree().get_first_node_in_group("light_overlay")
		if overlay:
			overlay.rebuild()
		queue_free()
