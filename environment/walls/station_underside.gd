@tool
class_name StationUnderside
extends TileMapLayer

@export var outer_bottom_walls: OuterBottomWalls
@export var windows_layer: WindowPlacer

@export var left_tile := Vector2i(0, 0)
@export var middle_tile := Vector2i(1, 0)
@export var right_tile := Vector2i(2, 0)
@export var single_tile := Vector2i(3, 0)


func _get_available_source_ids() -> Array[int]:
	var ids: Array[int] = []

	if tile_set == null:
		return ids

	for i in tile_set.get_source_count():
		ids.append(tile_set.get_source_id(i))

	return ids


func _is_window_bottom(cell: Vector2i) -> bool:
	if windows_layer == null:
		return false

	if windows_layer.get_cell_source_id(cell) != windows_layer.horizontal_source_id:
		return false

	var atlas := windows_layer.get_cell_atlas_coords(cell)
	return atlas.y == 1


func _is_support_cell(cell: Vector2i) -> bool:
	# Outer bottom wall
	if outer_bottom_walls != null:
		if outer_bottom_walls.get_cell_source_id(cell) != -1:
			return true

	# Horizontal window bottom
	if _is_window_bottom(cell):
		return true

	return false


func _piece_from_neighbors(cell: Vector2i) -> Vector2i:
	var has_left := _is_support_cell(cell + Vector2i.LEFT)
	var has_right := _is_support_cell(cell + Vector2i.RIGHT)

	if !has_left and !has_right:
		return single_tile

	if !has_left and has_right:
		return left_tile

	if has_left and !has_right:
		return right_tile

	return middle_tile


func generate():
	clear()

	if outer_bottom_walls == null:
		push_error("Assign OuterBottomWalls")
		return

	var source_ids := _get_available_source_ids()

	if source_ids.is_empty():
		push_error("No sources found in TileSet")
		return

	var source_id := source_ids[randi() % source_ids.size()]

	# --------------------------------------------------
	# Build one combined horizontal run map
	# (outer bottom walls + horizontal window bottoms)
	# --------------------------------------------------

	var support_cells := {}

	# Outer bottom walls
	for cell in outer_bottom_walls.get_used_cells():
		support_cells[cell] = true

	# Horizontal window bottoms
	if windows_layer != null:
		for cell in windows_layer.get_used_cells():

			if !_is_window_bottom(cell):
				continue

			support_cells[cell] = true

	# --------------------------------------------------
	# Generate undersides from combined runs
	# --------------------------------------------------

	for cell in support_cells.keys():

		var underside_tile := _piece_from_neighbors(cell)

		set_cell(
			cell + Vector2i.DOWN,
			source_id,
			underside_tile
		)
