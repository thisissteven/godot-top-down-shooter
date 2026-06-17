@tool
class_name BottomWalls
extends TileMapLayer

@export var top_wall_layer: TopWalls
@export var floor_layer: TilesBase
@export var wall_height := 1

# Change these to your atlas coordinates
@export var left_tile := Vector2i(0,0)
@export var middle_tile := Vector2i(1,0)
@export var right_tile := Vector2i(2,0)
@export var single_tile := Vector2i(3,0)

var initialized := false

func _ready():
	initialized = true

func _get_available_source_ids() -> Array[int]:
	var ids: Array[int] = []
	if tile_set == null:
		return ids

	for i in tile_set.get_source_count():
		ids.append(tile_set.get_source_id(i))

	return ids

func generate():
	clear()

	if top_wall_layer == null:
		push_error("Assign WallTopLayer")
		return

	if floor_layer == null:
		push_error("Assign FloorLayer")
		return

	var source_ids = _get_available_source_ids()
	if source_ids.is_empty():
		push_error("No sources found in TileSet")
		return

	var source_id = source_ids[randi() % source_ids.size()]

	for top_cell in top_wall_layer.get_used_cells():

		var wall_pos := top_cell + Vector2i.DOWN
		var floor_check_pos := top_cell + Vector2i.DOWN * 2

		# Must have floor at y + 2
		if floor_layer.get_cell_source_id(floor_check_pos) == -1:
			continue

		# Don't place into an occupied top wall cell
		if top_wall_layer.get_cell_source_id(wall_pos) != -1:
			continue

		# Avoid duplicates
		if get_cell_source_id(wall_pos) != -1:
			continue

		var has_left = top_wall_layer.get_cell_source_id(top_cell + Vector2i.LEFT) != -1
		var has_right = top_wall_layer.get_cell_source_id(top_cell + Vector2i.RIGHT) != -1

		var atlas: Vector2i

		if has_left and has_right:
			atlas = middle_tile
		elif has_left:
			atlas = right_tile
		elif has_right:
			atlas = left_tile
		else:
			atlas = single_tile

		set_cell(wall_pos, source_id, atlas)
