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

@onready var glow_sprite: Sprite2D = $Glow
@onready var core_sprite: Sprite2D = $Light

# ─────────────────────────────────────────────
#  Exports — Color
# ─────────────────────────────────────────────

@export_group("Color")

@export var light_color: Color = Color(0.2, 0.765, 1.0, 1.0):
	set(value): light_color = value; _rebuild_color()

@export var glow_alpha: float = 0.3:
	set(value): glow_alpha = value; _rebuild_color()

## When true, randomize_color picks from the palette instead of a random hue.
@export var use_color_palette: bool = true

@export var palette: Array[Color] = [
	Color(0.28, 0.7, 0.7, 1.0),   # cyan-teal (wall light)
	Color(0.875, 0.498, 0.67, 1.0),   # ice blue (cooler variant)
]

# ─────────────────────────────────────────────
#  Exports — Glow Shape
# ─────────────────────────────────────────────

@export_group("Glow Shape")

@export var glow_shape: GlowShape = GlowShape.RADIAL:
	set(value): glow_shape = value; _rebuild_texture()

@export var glow_direction: GlowDirection = GlowDirection.DOWN:
	set(value): glow_direction = value; _rebuild_texture(); _apply_glow_offset()

## Cone spread in degrees (180 = semicircle, 90 = narrow, 270 = wide).
## Only used when glow_shape is CONE.
@export_range(10.0, 360.0) var glow_cone_angle: float = 150.0:
	set(value): glow_cone_angle = value; _rebuild_texture()

## How soft the cone edges are. 0.0 = hard cutoff, 0.5 = very soft.
## Only used when glow_shape is CONE.
@export_range(0.0, 0.5) var glow_edge_softness: float = 0.15:
	set(value): glow_edge_softness = value; _rebuild_texture()

# ─────────────────────────────────────────────
#  Exports — Glow Texture
# ─────────────────────────────────────────────

@export_group("Glow Texture")

## Steeper falloff (3–5) = bright only near center. Lower (0.8) = spreads evenly.
@export var glow_exponent: float = 3.0:
	set(value): glow_exponent = value; _rebuild_texture()

## Values above 1.0 shrink the bright core, making the glow softer overall.
@export var glow_inner_radius: float = 0.5:
	set(value): glow_inner_radius = value; _rebuild_texture()

## Texture resolution in pixels — also controls rendered size since scale is 1:1.
@export var glow_texture_size: int = 128:
	set(value): glow_texture_size = value; _rebuild_texture(); _update_notifier_rect()

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

	glow_sprite.material = mat
	glow_sprite.scale    = Vector2.ONE
	glow_sprite.z_index = 1 # targets only floors and walls
	glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	core_sprite.material = mat
	
	if not glow_direction == GlowDirection.DOWN:
		core_sprite.z_index  = 98

	_notifier = VisibleOnScreenNotifier2D.new()
	add_child(_notifier)
	_notifier.screen_entered.connect(_on_screen_entered)
	_notifier.screen_exited.connect(_on_screen_exited)
	_update_notifier_rect()

	# glow_direction is set by WallLightPlacer before add_child, so order matters
	_rebuild_texture()
	_rebuild_color()
	_apply_glow_offset()

# ─────────────────────────────────────────────
#  Helpers — rebuild
# ─────────────────────────────────────────────

func _rebuild_texture() -> void:
	if not glow_sprite:
		return
	glow_sprite.texture = _make_glow_texture()

func _rebuild_color() -> void:
	if core_sprite:
		core_sprite.modulate = light_color
	if glow_sprite:
		glow_sprite.modulate = Color(light_color.r, light_color.g, light_color.b, glow_alpha)

func _apply_glow_offset() -> void:
	if not glow_sprite:
		return
	glow_sprite.position = -_facing_vector() * glow_origin_offset

func _update_notifier_rect() -> void:
	if not _notifier:
		return
	var half := glow_texture_size * 0.5
	_notifier.rect = Rect2(-half, -half, glow_texture_size, glow_texture_size)

# ─────────────────────────────────────────────
#  Helpers — color
# ─────────────────────────────────────────────

func _pick_random_color() -> void:
	if use_color_palette and not palette.is_empty():
		light_color = palette[randi() % palette.size()]
	else:
		light_color = Color.from_hsv(randf(), 0.7, 1.0)

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

# ─────────────────────────────────────────────
#  Texture generation
# ─────────────────────────────────────────────

func _make_glow_texture() -> ImageTexture:
	var img    := Image.create(glow_texture_size, glow_texture_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(glow_texture_size / 2.0, glow_texture_size / 2.0)
	var radius := glow_texture_size / 2.0
	var facing := _facing_vector()

	# Cone constants (computed once, used per-pixel only for CONE shape)
	var cos_threshold := cos(deg_to_rad(glow_cone_angle * 0.5))

	for x in glow_texture_size:
		for y in glow_texture_size:
			var offset := Vector2(x, y) - center
			var dist   := offset.length() / radius                          # 0.0 at center, 1.0 at edge
			var scaled := dist * glow_inner_radius                          # >1.0 shrinks core, <1.0 expands it
			var alpha  := pow(clamp(1.0 - scaled, 0.0, 1.0), glow_exponent)

			alpha *= _shape_alpha(offset, facing, cos_threshold)

			img.set_pixel(x, y, Color(alpha, alpha, alpha, alpha))

	return ImageTexture.create_from_image(img)


func _shape_alpha(offset: Vector2, facing: Vector2, cos_threshold: float) -> float:
	if offset.length() == 0.0:
		return 1.0

	match glow_shape:
		GlowShape.CONE:
			var dot := offset.normalized().dot(facing)
			return smoothstep(
				cos_threshold - glow_edge_softness,
				cos_threshold + glow_edge_softness,
				dot
			)

		GlowShape.RADIAL:
			return 1.0

		GlowShape.STRIP:
			# Bright band perpendicular to facing; fades off to the sides
			var perp     := Vector2(-facing.y, facing.x)
			var side_dot = abs(offset.normalized().dot(perp))
			# Forward bias: dim the half pointing away from facing
			var fwd_dot  := offset.normalized().dot(facing)
			var fwd_mask := smoothstep(-0.1, 0.4, fwd_dot)
			return smoothstep(0.7, 0.1, side_dot) * fwd_mask

	return 1.0
