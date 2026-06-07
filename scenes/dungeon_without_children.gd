extends Node2D

const top_walls_scene := preload('uid://dp2wjhnq3o5ui')
const bottom_walls_scene := preload('uid://cv45s283crols')
const tiles_scene := preload('uid://frmrxjt8ngmj')

var _top_walls: Node = null
var _bottom_walls: Node = null
var _tiles: Node = null

func _ready() -> void:
	_top_walls = top_walls_scene.instantiate()
	_bottom_walls = bottom_walls_scene.instantiate()
	_tiles = tiles_scene.instantiate()
	
	add_child(_tiles)
	add_child(_bottom_walls)
	add_child(_top_walls)
	
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_top_walls.generate()

		_bottom_walls.top_wall_layer = _top_walls
		await _bottom_walls.generate()

		_tiles.top_wall_layer = _top_walls
		await _tiles.generate()
