@tool
extends Node

@export var top_walls_scene: PackedScene
@export var bottom_walls_scene: PackedScene
@export var tiles_scene: PackedScene

@export var run: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate()
		run = false

var _top_walls: Node = null
var _bottom_walls: Node = null
var _tiles: Node = null

func _generate() -> void:
	if not top_walls_scene or not bottom_walls_scene or not tiles_scene:
		push_error("LevelGenerator: Assign all three PackedScenes in the Inspector.")
		return

	var parent = get_parent()
	if not parent:
		push_error("LevelGenerator: Must have a parent node.")
		return

	# Remove only the previous instances of our three nodes
	if is_instance_valid(_top_walls): _top_walls.queue_free()
	if is_instance_valid(_bottom_walls): _bottom_walls.queue_free()
	if is_instance_valid(_tiles): _tiles.queue_free()
	await get_tree().process_frame

	_top_walls = top_walls_scene.instantiate()
	_bottom_walls = bottom_walls_scene.instantiate()
	_tiles = tiles_scene.instantiate()
	
	_top_walls.name = "TopWalls"
	_bottom_walls.name = "BottomWalls"
	_tiles.name = "Tiles"

	parent.add_child(_tiles)
	parent.add_child(_bottom_walls)
	parent.add_child(_top_walls)

	_top_walls.owner = owner
	_bottom_walls.owner = owner
	_tiles.owner = owner

	_top_walls.generate()

	_bottom_walls.top_wall_layer = _top_walls
	await _bottom_walls.generate()

	_tiles.top_wall_layer = _top_walls
	await _tiles.generate_floor()

	print("LevelGenerator: Done.")
