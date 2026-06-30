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

func _ready() -> void:
	$BottomWalls.modulate = Color("ababab")
	$OuterBottomWalls.modulate = Color("ababab")
	$StationUnderside.modulate = Color("ababab")
	$Windows.modulate = Color("ababab")
	$Tiles.modulate = Color("ababab")
	$TopWalls.modulate = Color("434343ff")

func generate() -> void:
	super.generate()
	
	$Tiles.generate()
	$BottomWalls.generate()
	$Doors.generate()
	$Windows.generate()
	$OuterBottomWalls.generate()
	$StationUnderside.generate()
	$WallLights.generate()

	
func generate_light_mask() -> void:
	var map_layers: Array[Node] = [
		$Tiles, 
		$BottomWalls, 
		$Windows, 
		$OuterBottomWalls, 
		$StationUnderside
	]
	$LightOverlay.setup_from_generated_lights(map_layers)
