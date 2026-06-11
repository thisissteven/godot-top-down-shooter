class_name FacingComponent
extends Node

enum Dir { N, NE, E, SE, S, SW, W, NW }

signal direction_changed(dir: Dir, flip_h: bool)

@export var cursor_timeout := 1.0

var current_dir: Dir = Dir.SE
var flip_h: bool = false
var _cursor_active := false
var _cursor_timer := 0.0
var _is_armed := false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor_active = true
		_cursor_timer = cursor_timeout
		

func _process(delta: float) -> void:
	if _cursor_active:
		_cursor_timer -= delta
		if _cursor_timer <= 0.0:
			_cursor_active = false
			
func cursor_active() -> bool:
	return _cursor_active

# Called by InputComponent each frame
func update(mouse_world_pos: Vector2, player_pos: Vector2,
			move_input: Vector2, _delta: float) -> void:
	var new_dir: Dir
	var new_flip: bool

	if _cursor_active:
		var angle := (mouse_world_pos - player_pos).angle()
		new_dir = _angle_to_dir(angle)
		new_flip = _flip_for(new_dir)
		# Only suppress south when mouse-aimed — keyboard south is always valid
		if _is_armed and new_dir == Dir.S:
			new_dir = Dir.SW if new_flip else Dir.SE
	else:
		if move_input.length_squared() > 0.01:
			new_dir = _vec_to_dir(move_input)
			new_flip = _flip_for(new_dir)
		else:
			new_dir = current_dir
			new_flip = flip_h
		# No suppression here — keyboard south = walk_s is valid

	if new_dir != current_dir or new_flip != flip_h:
		current_dir = new_dir
		flip_h = new_flip
		direction_changed.emit(current_dir, flip_h)
		
				
func set_armed(armed: bool) -> void:
	_is_armed = armed

func _angle_to_dir(angle: float) -> Dir:
	# angle is -PI..PI from Vector2.angle()
	# Remap to 0..360 clockwise starting from right
	var deg := wrapf(rad_to_deg(angle), 0.0, 360.0)
	# 8 sectors of 45 degrees, offset by 22.5
	var sector := int((deg + 22.5) / 45.0) % 8
	# sector 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
	const SECTOR_MAP := [Dir.E, Dir.SE, Dir.S, Dir.SW, Dir.W, Dir.NW, Dir.N, Dir.NE]
	return SECTOR_MAP[sector]

func _vec_to_dir(v: Vector2) -> Dir:
	return _angle_to_dir(v.angle())

func _flip_for(dir: Dir) -> bool:
	# NW, W, SW need horizontal flip of their NE/E/SE sprites
	return dir in [Dir.NW, Dir.W, Dir.SW]
