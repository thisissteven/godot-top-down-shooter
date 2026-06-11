extends CanvasLayer


# In a CanvasLayer node (not affected by camera)
func _ready():
	var sprite = $VignetteSprite
	sprite.texture = make_vignette_texture(512)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# scale to fill screen
	sprite.scale = Vector2(
		get_viewport().size.x / 512.0,
		get_viewport().size.y / 512.0
	)

func make_vignette_texture(size: int = 512) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0
	for x in size:
		for y in size:
			var dist = Vector2(x, y).distance_to(center) / radius
			var alpha = clamp(dist - 0.3, 0.0, 1.0)  # transparent center
			alpha = pow(alpha, 1.5)
			img.set_pixel(x, y, Color(0, 0, 0, alpha))
	return ImageTexture.create_from_image(img)
