@tool
class_name WorldGenerator
extends WorldGeneratorBase


@export var run := false:
	set(value):
		if value and Engine.is_editor_hint():
			generate()
		run = false

@export var run_light_mask := false:
	set(value):
		if value and Engine.is_editor_hint():
			generate_light_mask()
		run_light_mask = false

func coloring():
	$BottomWalls.modulate = Color("8e8e8eff")
	$OuterBottomWalls.modulate = Color("ababab")
	$StationUnderside.modulate = Color("ababab")
	$Windows.modulate = Color("8e8e8eff")
	$Tiles.modulate = Color("4e84a7ff")
	$TopWalls.modulate = Color("434343ff")
	$TopWallWindows.modulate = Color("434343ff")

func _ready() -> void:
	coloring()

func generate() -> void:
	super.generate()
	
	$Tiles.generate()
	$BottomWalls.generate()
	$Doors.generate()
	$TopWallWindows.generate()
	$Windows.generate()
	$OuterBottomWalls.generate()
	$StationUnderside.generate()
	$WallLights.generate()
	
	coloring()

	
func generate_light_mask() -> void:
	var map_layers: Array[Node] = [
		$Tiles,
		$BottomWalls,
		$Windows,
		$TopWallWindows,
		$OuterBottomWalls,
		$StationUnderside
	]
	$LightOverlay.setup_from_generated_lights(map_layers)
