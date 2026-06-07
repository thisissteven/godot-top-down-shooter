extends Node

const TARGET_CURSOR_SIZE := Vector2i(32, 32)

var fps_label: Label

func _ready():
	_setup_cursor()
	_setup_fps()

func _process(_delta):
	if fps_label:
		fps_label.text = "%d / %d FPS" % [
			Engine.get_frames_per_second(),
			DisplayServer.screen_get_refresh_rate()
		]


func _setup_cursor():
	var texture: Texture2D = load("res://assets/crosshair.png")
	var image := texture.get_image()

	image.resize(
		TARGET_CURSOR_SIZE.x,
		TARGET_CURSOR_SIZE.y,
		Image.INTERPOLATE_NEAREST
	)

	var scaled_texture := ImageTexture.create_from_image(image)

	Input.set_custom_mouse_cursor(
		scaled_texture,
		Input.CURSOR_ARROW,
		TARGET_CURSOR_SIZE / 2.0
	)


func _setup_fps():
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)

	fps_label = Label.new()
	canvas_layer.add_child(fps_label)

	fps_label.text = "FPS: 0"
	fps_label.add_theme_color_override("font_color", Color.RED)
	fps_label.add_theme_font_size_override("font_size", 16)

	# Anchor to top-right
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)

	# Move inward from edges
	fps_label.offset_right = -4
	fps_label.offset_top = 4
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
