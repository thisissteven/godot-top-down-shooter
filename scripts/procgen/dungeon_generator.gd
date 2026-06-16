@tool
class_name LevelGenerator
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


func _safe_set_owner_recursive(target_node: Node, scene_root: Node) -> void:
	# 1. Immediate Safety Escape: Skip Dialog and Window objects completely
	if target_node is Window:
		return

	# 2. Assign ownership safely if it's a valid candidate
	if target_node != scene_root and target_node != self:
		# If the node has an internal, native sub-component, skip it to prevent internal breakages
		if not target_node.get_scene_file_path().is_empty() and target_node != scene_root:
			# This is an instantiated sub-scene; we shouldn't dig into its internal children!
			target_node.owner = scene_root
			return 
		else:
			target_node.owner = scene_root

	# 3. Process children
	for child in target_node.get_children():
		_safe_set_owner_recursive(child, scene_root)


func generate() -> void:
	var top_walls = $TopWalls
	var bottom_walls = $BottomWalls
	var tiles = $Tiles
	var doors = $Doors
	var windows = $Windows
	var wall_lights = $WallLights

	if not top_walls or not tiles:
		push_error("LevelGenerator: child nodes not found!")
		return

	top_walls.generate()
	bottom_walls.generate()
	tiles.generate()
	doors.generate()
	windows.generate()
	wall_lights.generate()
	
	var true_root = get_tree().edited_scene_root if Engine.is_editor_hint() else (owner if owner else self)
	call_deferred("_safe_set_owner_recursive", self, true_root)

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
