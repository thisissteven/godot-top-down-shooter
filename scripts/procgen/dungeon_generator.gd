@tool
extends Node2D

@export var run: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate()
		run = false

func _generate() -> void:
	var top_walls = $TopWalls
	var bottom_walls = $BottomWalls
	var tiles = $Tiles
	var doors = $Doors
	var windows = $Windows

	if not top_walls or not tiles:
		push_error("LevelGenerator: child nodes not found!")
		return

	top_walls.generate()
	bottom_walls.generate()
	tiles.generate()
	doors.generate()
	windows.generate()

	print("LevelGenerator: Done.")
