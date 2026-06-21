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

@onready var glow_sprite: PointLight2D = $WallLightSource
@onready var core_sprite: Sprite2D = $Light

# ─────────────────────────────────────────────
#  Exports — Color
# ─────────────────────────────────────────────

@export_group("Color")

@export var light_color: Color = Color(0.2, 0.765, 1.0, 1.0):
	set(value): light_color = value; _rebuild_color()

@export var glow_alpha: float = 1.0:
	set(value): glow_alpha = value; _rebuild_color()

## When true, randomize_color picks from the palette instead of a random hue.
@export var use_color_palette: bool = true

@export var palette: Array[Color] = [
	Color("#b6b6b6")
]

@export var glow_direction: GlowDirection = GlowDirection.DOWN:
	set(value): glow_direction = value;

# ─────────────────────────────────────────────
#  Exports — Glow Texture
# ─────────────────────────────────────────────

## Pushes the glow sprite away from the anchor in the facing direction.
@export var glow_origin_offset: float = 0.0:
	set(value): glow_origin_offset = value; _apply_glow_offset()

# ─────────────────────────────────────────────
#  Private
# ─────────────────────────────────────────────

var _notifier: VisibleOnScreenNotifier2D

# ─────────────────────────────────────────────
#  Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	_pick_random_color()
	
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	
	core_sprite.material = mat
	
	if not glow_direction == GlowDirection.DOWN:
		core_sprite.z_index  = 98

	_notifier = VisibleOnScreenNotifier2D.new()
	add_child(_notifier)
	_notifier.screen_entered.connect(_on_screen_entered)
	_notifier.screen_exited.connect(_on_screen_exited)
	_update_notifier_rect()

	# glow_direction is set by WallLightPlacer before add_child, so order matters
	_rebuild_color()
	_apply_glow_offset()

# ─────────────────────────────────────────────
#  Helpers — rebuild
# ─────────────────────────────────────────────

func _rebuild_color() -> void:
	if core_sprite:
		core_sprite.modulate = light_color
	if glow_sprite:
		var tex = glow_sprite.texture as GradientTexture2D
	
		if tex and tex.gradient:
			tex.gradient.colors = PackedColorArray([light_color, Color.BLACK])
		else:
			glow_sprite.color = light_color

func _apply_glow_offset() -> void:
	if not glow_sprite:
		return
	glow_sprite.position = -_facing_vector() * glow_origin_offset

func _update_notifier_rect() -> void:
	if not _notifier:
		return
	var size := glow_sprite.texture.get_width()
	var half := size * 0.5
	_notifier.rect = Rect2(-half, -half, size, size)

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

# ─────────────────────────────────────────────
#  Visibility culling
# ─────────────────────────────────────────────

func _on_screen_entered() -> void:
	glow_sprite.visible = true
	core_sprite.visible = true

func _on_screen_exited() -> void:
	glow_sprite.visible = false
	core_sprite.visible = false
