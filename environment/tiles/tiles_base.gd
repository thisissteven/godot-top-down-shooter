@tool
class_name TilesBase
extends TileMapLayer
@export var top_wall_layer: TopWalls
@export var source_id := 0
@export var floor_tiles := [
	Vector2i(0,0), # Main floor (90%)
	Vector2i(1,0),
	Vector2i(2,0),
	Vector2i(3,0),
	Vector2i(4,0),
	Vector2i(5,0),
	Vector2i(6,0),
	Vector2i(7,0)
]
@export_range(0.0,1.0)
var main_floor_chance := 0.85
@export var seed_value := 0
@export var sinkhole_areas := 8
@export var sinkhole_min_tiles := 12
@export var sinkhole_max_tiles := 32
var rng := RandomNumberGenerator.new()
var initialized := false

func _ready():
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	initialized = true

func generate():
	if !initialized:
		await ready
	if top_wall_layer == null:
		push_error("Top wall layer missing")
		return
	clear()
	var rect = top_wall_layer.get_used_rect()

	# Build sinkhole exclusion set before placing tiles
	var sinkhole_cells := _generate_sinkholes(rect)

	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell = Vector2i(x,y)
			# Skip walls
			if top_wall_layer.get_cell_source_id(cell) != -1:
				continue
			# Skip sinkhole cells (leave them empty)
			if cell in sinkhole_cells:
				continue
			var tile = _pick_floor_tile()
			set_cell(cell, source_id, tile)

	notify_runtime_tile_data_update()
	print("Floor generation complete")

func _generate_sinkholes(rect: Rect2i) -> Dictionary:
	var excluded := {}
	if sinkhole_areas <= 0:
		return excluded

	var neighbors := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	# Build wall-adjacent buffer
	var wall_adjacent := {}
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell = Vector2i(x, y)
			if top_wall_layer.get_cell_source_id(cell) != -1:
				for n in neighbors:
					wall_adjacent[cell + n] = true

	var valid_cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell = Vector2i(x, y)
			if top_wall_layer.get_cell_source_id(cell) == -1 and not wall_adjacent.has(cell):
				valid_cells.append(cell)

	if valid_cells.is_empty():
		return excluded

	var times = randi_range(1, sinkhole_areas)
	for _i in range(times):
		var target_size = rng.randi_range(sinkhole_min_tiles, sinkhole_max_tiles)
		var seed_cell = valid_cells[rng.randi_range(0, valid_cells.size() - 1)]
		var sinkhole := _grow_sinkhole(seed_cell, target_size, rect, wall_adjacent)
		for cell in sinkhole:
			excluded[cell] = true
		# Fill any interior cells fully enclosed by this sinkhole
		_fill_enclosed(sinkhole, excluded, rect)

	return excluded

# After growing, flood-fill outward from the rect border.
# Any floor cell that flood-fill can NOT reach is fully enclosed — add it to excluded.
func _fill_enclosed(sinkhole: Array[Vector2i], excluded: Dictionary, rect: Rect2i) -> void:
	if sinkhole.is_empty():
		return

	# Build bounding box of the sinkhole with 1-cell padding
	var min_x = sinkhole[0].x
	var max_x = sinkhole[0].x
	var min_y = sinkhole[0].y
	var max_y = sinkhole[0].y
	for cell in sinkhole:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	# Pad by 1 so the flood-fill has a walkable border to start from
	min_x = max(min_x - 1, rect.position.x)
	max_x = min(max_x + 1, rect.end.x - 1)
	min_y = max(min_y - 1, rect.position.y)
	max_y = min(max_y + 1, rect.end.y - 1)

	var local_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

	# Flood-fill from every border cell of the padded bounding box.
	# Blocked by: sinkhole cells, actual wall tiles, already-visited cells.
	var reachable := {}
	var queue: Array[Vector2i] = []
	var neighbors := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	# Seed the flood-fill from the padded border
	for x in range(local_rect.position.x, local_rect.end.x):
		for y in range(local_rect.position.y, local_rect.end.y):
			var cell = Vector2i(x, y)
			var on_border = (x == local_rect.position.x or x == local_rect.end.x - 1
							or y == local_rect.position.y or y == local_rect.end.y - 1)
			if on_border and not excluded.has(cell) and top_wall_layer.get_cell_source_id(cell) == -1:
				if not reachable.has(cell):
					reachable[cell] = true
					queue.append(cell)

	# BFS outward
	while not queue.is_empty():
		var current = queue.pop_front()
		for n in neighbors:
			var next = current + n
			if not local_rect.has_point(next):
				continue
			if reachable.has(next) or excluded.has(next):
				continue
			if top_wall_layer.get_cell_source_id(next) != -1:
				continue
			reachable[next] = true
			queue.append(next)

	# Anything inside the local rect that flood-fill couldn't reach is enclosed — exclude it
	for x in range(local_rect.position.x, local_rect.end.x):
		for y in range(local_rect.position.y, local_rect.end.y):
			var cell = Vector2i(x, y)
			if not reachable.has(cell) and not excluded.has(cell):
				if top_wall_layer.get_cell_source_id(cell) == -1:
					excluded[cell] = true

# Pass wall_adjacent in so growth also respects the 1-tile buffer
func _grow_sinkhole(start: Vector2i, target_size: int, rect: Rect2i, wall_adjacent: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var in_sinkhole := { start: true }
	var border: Array[Vector2i] = [start]
	var neighbors := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	if not rect.has_point(start) or top_wall_layer.get_cell_source_id(start) != -1:
		return result

	result.append(start)

	while result.size() < target_size and not border.is_empty():
		var border_idx = rng.randi_range(0, border.size() - 1)
		var current = border[border_idx]

		var candidates: Array[Vector2i] = []
		for n in neighbors:
			var next = current + n
			if in_sinkhole.has(next):
				continue
			if not rect.has_point(next):
				continue
			if top_wall_layer.get_cell_source_id(next) != -1:
				continue
			# Reject cells adjacent to any wall
			if wall_adjacent.has(next):
				continue
			candidates.append(next)

		if candidates.is_empty():
			border.remove_at(border_idx)
			continue

		var chosen = candidates[rng.randi_range(0, candidates.size() - 1)]
		in_sinkhole[chosen] = true
		result.append(chosen)
		border.append(chosen)

	return result
	
	
func _pick_floor_tile():
	if rng.randf() <= main_floor_chance:
		return floor_tiles[0]
	return floor_tiles[
		rng.randi_range(
			1,
			floor_tiles.size() - 1
		)
	]
