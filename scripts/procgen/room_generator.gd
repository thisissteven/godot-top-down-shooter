@tool
class_name RoomGenerator
extends Node2D

@export var chunk_id := -1

var chunk_rect: Rect2i

@export var run: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			generate()
		run = false

func set_chunk_size(width: int, height: int) -> void:
	$TopWalls.map_width = width
	$TopWalls.map_height = height


func generate() -> void:
	var top_walls = $TopWalls
	var bottom_walls = $BottomWalls
	var tiles = $Tiles
	var doors = $Doors
	var windows = $Windows
	var wall_lights = $WallLights

	if not top_walls or not tiles:
		push_error("RoomGenerator: child nodes not found!")
		return

	top_walls.generate()
	bottom_walls.generate()
	tiles.generate()
	doors.generate()
	windows.generate()
	wall_lights.generate()
	

func generate_top_only() -> void:
	$TopWalls.generate()


func generate_remaining() -> void:
	$BottomWalls.generate()
	$Tiles.generate()
	$Doors.generate()
	$Windows.generate()
	$WallLights.generate()


func get_top_walls():
	return $TopWalls
