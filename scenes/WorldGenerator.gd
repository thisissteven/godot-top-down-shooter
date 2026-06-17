@tool
class_name WorldGenerator
extends WorldGeneratorBase


@export var run := false:
	set(value):
		if value and Engine.is_editor_hint():
			generate()
		run = false


func generate() -> void:
	super.generate()
	
	$Tiles.generate()
	$BottomWalls.generate()
	$Doors.generate()
	$Windows.generate()
	$WallLights.generate()
