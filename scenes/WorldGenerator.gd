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
	$OuterBottomWalls.generate()
	$StationUnderside.generate()
	$WallLights.generate()
	
	$BottomWalls.modulate = Color("ababab")
	$OuterBottomWalls.modulate = Color("ababab")
	$StationUnderside.modulate = Color("ababab")
	$Windows.modulate = Color("ababab")
	$Tiles.modulate = Color("bcbcbc")
	$TopWalls.modulate = Color("666666")
