@tool
extends Node

@export var top_walls_scene: PackedScene
@export var bottom_walls_scene: PackedScene
@export var tiles_scene: PackedScene
@export var doors_scene: PackedScene


@export var run: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate()
		run = false

func _generate() -> void:
	if not top_walls_scene or not bottom_walls_scene or not tiles_scene or not doors_scene:
		push_error("LevelGenerator: Assign all four PackedScenes in the Inspector.")
		return

	var parent = get_parent()
	if not parent:
		push_error("LevelGenerator: Must have a parent node.")
		return

	# Remove previous instances
	for node_name in ["TopWalls", "BottomWalls", "Tiles", "DoorPlacer"]:
		var existing = parent.find_child(node_name, false, false)
		if is_instance_valid(existing):
			existing.queue_free()

	# queue_free is deferred — wait until they are actually gone
	while parent.find_child("TopWalls", false, false) != null \
		or parent.find_child("BottomWalls", false, false) != null \
		or parent.find_child("Tiles", false, false) != null \
		or parent.find_child("DoorPlacer", false, false) != null:
			await get_tree().process_frame

	# Now safe to add — no name collisions possible
	var top_walls = top_walls_scene.instantiate()
	var bottom_walls = bottom_walls_scene.instantiate()
	var tiles = tiles_scene.instantiate()

	parent.add_child(tiles)
	parent.add_child(bottom_walls)
	parent.add_child(top_walls)

	top_walls.name = "TopWalls"
	bottom_walls.name = "BottomWalls"
	tiles.name = "Tiles"

	# Set owner so nodes are saved in the scene
	top_walls.owner = owner
	bottom_walls.owner = owner
	tiles.owner = owner

	# Mark as unique names so they're accessible via % in the scene tree
	top_walls.set_unique_name_in_owner(true)
	bottom_walls.set_unique_name_in_owner(true)
	tiles.set_unique_name_in_owner(true)

	top_walls.generate()
	bottom_walls.top_wall_layer = top_walls
	await bottom_walls.generate()
	tiles.top_wall_layer = top_walls
	await tiles.generate()
	
	var door_placer = doors_scene.instantiate()
	parent.add_child(door_placer)
	door_placer.name = "DoorPlacer"
	door_placer.owner = owner
	door_placer.set_unique_name_in_owner(true)
	door_placer.top_wall_layer = top_walls
	await door_placer.generate()
	
	print("LevelGenerator: Done.")
