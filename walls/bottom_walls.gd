@tool
class_name BottomWalls
extends TileMapLayer

@export var top_wall_layer: TileMapLayer
@export var wall_height := 1

# Change these to your atlas coordinates
@export var left_tile := Vector2i(0,0)
@export var middle_tile := Vector2i(1,0)
@export var right_tile := Vector2i(2,0)
@export var single_tile := Vector2i(3,0)

func generate():

	clear()

	if top_wall_layer == null:
		push_error("Assign WallTopLayer")
		return

	for top_cell in top_wall_layer.get_used_cells():

		for h in range(1, wall_height+1):

			var pos = top_cell + Vector2i.DOWN * h

			# stop if another top wall exists below
			if top_wall_layer.get_cell_source_id(pos) != -1:
				break

			var has_left = (
				top_wall_layer.get_cell_source_id(
					top_cell + Vector2i.LEFT
				) != -1
			)

			var has_right = (
				top_wall_layer.get_cell_source_id(
					top_cell + Vector2i.RIGHT
				) != -1
			)

			var atlas

			if has_left and has_right:
				atlas = middle_tile

			elif has_left:
				atlas = right_tile

			elif has_right:
				atlas = left_tile

			else:
				atlas = single_tile

			set_cell(
				pos,
				0,
				atlas
			)
