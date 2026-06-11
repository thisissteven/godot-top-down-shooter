extends Node2D

@onready var glow_sprite = $Glow
@onready var core_sprite = $Sprite2D

func _ready():
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	# glow gets the gradient — sits BEHIND the core
	glow_sprite.texture = make_glow_texture(64)
	glow_sprite.material = mat
	glow_sprite.scale = Vector2(3, 3)
	glow_sprite.modulate = Color(0.2, 0.6, 1.0, 0.5)
	glow_sprite.z_index = 1
	glow_sprite.z_as_relative = false

	# core gets your real sprite texture, just unshaded + additive
	core_sprite.material = mat
	core_sprite.modulate = Color(0.2, 0.6, 1.0, 1.0)
	
func make_glow_texture(size: int = 64) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0
	for x in size:
		for y in size:
			var dist = Vector2(x, y).distance_to(center) / radius
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.5)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
