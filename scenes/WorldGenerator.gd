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
	$BottomWalls.modulate = Color("b1b1b1ff")
	for door in $Doors.get_children():
		var door_sprite = door.get_node("Move/DoorSprite")
		door_sprite.modulate = Color("ababab")
	$OuterBottomWalls.modulate = Color("ababab")
	$StationUnderside.modulate = Color("ababab")
	$Windows.modulate = Color("b1b1b1ff")
	$Tiles.modulate = Color("d5ffd8ff")
	$TopWalls.modulate = Color("6d6d6dff")
	$TopWallWindows.modulate = Color("6d6d6dff")

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
