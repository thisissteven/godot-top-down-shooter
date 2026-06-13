@tool
class_name DoorPlacer
extends Node2D

@export var top_wall_layer: TopWalls
@export var horizontal_door_scene: PackedScene
@export var vertical_door_scene: PackedScene

@export var horizontal_door_offset: Vector2 = Vector2(0, 0)
@export var vertical_door_offset: Vector2 = Vector2(0, 0)

var initialized := false

func _ready() -> void:
	initialized = true

func generate() -> void:
	#if !initialized:
		#await ready
		
	if not top_wall_layer:
		push_error("DoorPlacer: Assign top_wall_layer in the Inspector.")
		return
	if not horizontal_door_scene or not vertical_door_scene:
		push_error("DoorPlacer: Assign both door scenes in the Inspector.")
		return

	for node_name in ["Doors"]:
		var existing = find_child(node_name, false, false)
		if is_instance_valid(existing):
			existing.queue_free()

	while find_child("Doors", false, false) != null:
		await get_tree().process_frame

	var doors_container = Node2D.new()
	add_child(doors_container)
	doors_container.y_sort_enabled = true
	doors_container.name = "Doors"
	doors_container.owner = owner
	doors_container.set_unique_name_in_owner(true)

	# top_wall_layer IS the TileMapLayer — use it directly
	var tilemap: TileMapLayer = top_wall_layer
	var tile_size = tilemap.tile_set.tile_size

	for gap in top_wall_layer.door_gaps:
		var vertical = gap.type == "vertical"
		_place_door(doors_container, gap.cells, tile_size, vertical)

	print("DoorPlacer: Done.")


func _place_door(container: Node2D, door_cells: Array, tile_size: Vector2i, vertical: bool) -> void:
	var scene = vertical_door_scene if vertical else horizontal_door_scene
	if not scene:
		push_error("DoorPlacer: Missing " + ("vertical" if vertical else "horizontal") + " door scene.")
		return

	var door = scene.instantiate()

	var first: Vector2i = door_cells[0]
	var last: Vector2i = door_cells[-1]
	var mid_cell = Vector2(first + last) / 2.0
	door.position = (mid_cell + Vector2(0.5, 0.5)) * Vector2(tile_size)
	door.position += vertical_door_offset if vertical else horizontal_door_offset

	door.name = "Door_" + ("V" if vertical else "H") + "_" + str(first.x) + "_" + str(first.y)

	container.add_child(door)
	door.owner = owner
