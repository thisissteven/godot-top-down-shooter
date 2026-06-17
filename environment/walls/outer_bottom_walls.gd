@tool
class_name OuterBottomWalls
extends TileMapLayer

@export var top_wall_layer: TopWalls
@export var floor_layer: TilesBase

@export var wall_height := 1

# Atlas coords (same as BottomWalls)
@export var left_tile := Vector2i(0, 0)
@export var middle_tile := Vector2i(1, 0)
@export var right_tile := Vector2i(2, 0)
@export var single_tile := Vector2i(3, 0)

const SOURCE_ID := 0


func generate() -> void:
	clear()

	if top_wall_layer == null or floor_layer == null:
		push_error("Assign top_wall_layer and floor_layer")
		return

	var top_cells = top_wall_layer.get_used_cells()

	for top_cell in top_cells:

		var below = top_cell + Vector2i.DOWN
		var below_floor_check = top_cell + Vector2i.DOWN * 2

		# must be exposed (no wall directly below)
		if top_wall_layer.get_cell_source_id(below) != -1:
			continue

		# CORE RULE:
		# if NO floor at y+2 → place outer bottom wall at y+1
		var has_floor := floor_layer.get_cell_source_id(below_floor_check) != -1
		if has_floor:
			continue

		var place_pos = below

		if get_cell_source_id(place_pos) != -1:
			continue

		set_cell(place_pos, SOURCE_ID, _choose_tile(top_cell))


func _choose_tile(top_cell: Vector2i) -> Vector2i:
	var has_left = top_wall_layer.get_cell_source_id(top_cell + Vector2i.LEFT) != -1
	var has_right = top_wall_layer.get_cell_source_id(top_cell + Vector2i.RIGHT) != -1

	if has_left and has_right:
		return middle_tile
	elif has_left:
		return right_tile
	elif has_right:
		return left_tile
	else:
		return single_tile
