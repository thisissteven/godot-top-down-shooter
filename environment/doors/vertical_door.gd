extends StaticBody2D

enum State { LOCKED, UNLOCKED, OPENED }

const LIGHT_COLORS := {
	State.LOCKED:   Color(0.812, 0.102, 0.102, 1.0),
	State.UNLOCKED: Color(1.0, 0.792, 0.0, 1.0),
	State.OPENED:   Color(0.102, 1.0, 0.2, 1.0),
}

const FLICKER_DIM    := 0.15
const FLICKER_BRIGHT := 1.0
const FLICKER_STEP   := 0.25
const FLICKER_PAUSE  := 0.25

@export var state: State = State.UNLOCKED

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var detection_area: Area2D = $Area2D
@onready var move: Node2D = $Move
@onready var door_lights: Sprite2D = $Move/DoorLights
@onready var door_glow_down: Sprite2D = $Move/DoorGlowDown
@onready var door_glow_up: Sprite2D = $Move/DoorGlowUp

var _light_nodes: Array[Sprite2D]
var _player_inside := false
var _interacting := false
var _flicker_tween: Tween = null
var _last_animation_played: String = "close"

func _ready() -> void:
	state = [State.UNLOCKED, State.OPENED].pick_random()
	_light_nodes = [door_lights, door_glow_down, door_glow_up]
	_setup_glow(door_glow_down, 4, 8, 0.6)
	_setup_glow(door_glow_up, 4, 8, 0.6)
	animation_player.play("close")
	animation_player.seek(animation_player.current_animation_length, true)
	_last_animation_played = "close"
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	_apply_state()

@onready var overlay := get_tree().get_first_node_in_group("light_overlay")

func _process(_delta: float) -> void:
	if not overlay:
		return

	var is_default_position := not animation_player.is_playing() and _last_animation_played == "close"

	if is_default_position:
		for i in _light_nodes.size():
			var node := _light_nodes[i]
			node.visible = true
			if node.modulate.a <= 0.001 or not node.texture:
				overlay.remove_dynamic_light(_door_light_id(i))
				continue
			overlay.update_dynamic_light(
				_door_light_id(i),
				node.global_position,
				node.texture,
				node.modulate,
				node.scale
			)
	else:
		for i in _light_nodes.size():
			var node := _light_nodes[i]
			node.visible = false
			overlay.remove_dynamic_light(_door_light_id(i))
			
func _door_light_id(index: int) -> String:
	return "door_light_" + str(get_instance_id()) + "_" + str(index)

func _exit_tree() -> void:
	if overlay:
		for i in _light_nodes.size():
			overlay.remove_dynamic_light(_door_light_id(i))
			
# --- State ---

func _apply_state() -> void:
	_set_lights_color(LIGHT_COLORS[state])

func _set_lights_color(color: Color) -> void:
	for node in _light_nodes:
		node.modulate = color

func _set_lights_alpha(alpha: float) -> void:
	for node in _light_nodes:
		node.modulate.a = alpha

# --- Door movement ---

func _open_door() -> void:
	var pos := animation_player.current_animation_position
	var length := animation_player.current_animation_length
	animation_player.play("open")
	animation_player.seek(length - pos)
	_last_animation_played = "open"

func _close_door() -> void:
	var pos := animation_player.current_animation_position
	var length := animation_player.current_animation_length
	animation_player.play("close")
	animation_player.seek(length - pos)
	_last_animation_played = "close"

# --- Interact sequence ---

func _input(event: InputEvent) -> void:
	if state != State.UNLOCKED or not _player_inside or _interacting:
		return
	if event.is_action_pressed("interact"):
		_begin_open_sequence()

func _begin_open_sequence() -> void:
	_interacting = true
	var tween := create_tween().set_loops(2)
	tween.tween_callback(_set_lights_alpha.bind(0.2))
	tween.tween_interval(FLICKER_STEP)
	tween.tween_callback(_set_lights_alpha.bind(FLICKER_BRIGHT))
	tween.tween_interval(FLICKER_STEP)
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	state = State.OPENED
	_apply_state()
	_interacting = false
	if _player_inside:
		_open_door()
		
# --- Flicker ---

func _flicker_tween_once(on_done: Callable) -> void:
	_flicker_tween = create_tween()
	_flicker_tween.tween_callback(_set_lights_alpha.bind(FLICKER_DIM))
	_flicker_tween.tween_interval(FLICKER_STEP)
	_flicker_tween.tween_callback(_set_lights_alpha.bind(FLICKER_BRIGHT))
	_flicker_tween.tween_interval(FLICKER_PAUSE)
	_flicker_tween.finished.connect(on_done, CONNECT_ONE_SHOT)

func _start_flicker() -> void:
	if _flicker_tween and _flicker_tween.is_running():
		return
	_flicker_loop()

func _flicker_loop() -> void:
	if not _player_inside or state != State.LOCKED:
		return
	_flicker_tween_once(_flicker_loop)

func _stop_flicker_then_finish() -> void:
	if _flicker_tween and _flicker_tween.is_running():
		if _flicker_tween.finished.is_connected(_flicker_loop):
			_flicker_tween.finished.disconnect(_flicker_loop)
		_flicker_tween.finished.connect(func(): _do_final_flickers(2), CONNECT_ONE_SHOT)
	else:
		_do_final_flickers(2)

func _do_final_flickers(count: int) -> void:
	if count <= 0:
		_apply_state()
		return
	_flicker_tween_once(func(): _do_final_flickers(count - 1))

# --- Signals ---

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	match state:
		State.LOCKED:   _start_flicker()
		State.OPENED:   _open_door()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	match state:
		State.LOCKED:   _stop_flicker_then_finish()
		State.OPENED:   _close_door()

# --- Glow texture ---

func _setup_glow(glow: Sprite2D, h_radius: int, v_radius: int, brightness: float = 1.0) -> void:
	glow.texture = _make_glow_texture(h_radius, v_radius, brightness)
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = mat

func _make_glow_texture(h_radius: int, v_radius: int, brightness: float = 1.0) -> ImageTexture:
	var img := Image.create(h_radius * 2, v_radius * 2, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var nx := float(x - h_radius) / h_radius
			var ny := float(y - v_radius) / v_radius
			var alpha := clampf((1.0 - sqrt(nx * nx + ny * ny)) * brightness, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	return ImageTexture.create_from_image(img)
