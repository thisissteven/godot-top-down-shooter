@tool
extends Node2D

@export var top_walls: TileMapLayer
@export var door_scene: PackedScene
@export var regenerate := false : set = _set_regenerate

var spawned := []

func _set_regenerate(v):
	if not v:
		return

	regenerate = false
	_generate_doors()


func _generate_doors():
	if top_walls == null:
		return

	_clear()

	var grid = _extract_grid()

	for y in range(grid.size()):
		for x in range(grid[y].size()):

			if grid[y][x] == false:
				continue  # only floor

			var is_door = _is_door_cell(grid, x, y)

			if is_door:
				var door = door_scene.instantiate()
				add_child(door)

				door.position = top_walls.map_to_local(Vector2i(x, y))
				spawned.append(door)


func _clear():
	for d in spawned:
		if is_instance_valid(d):
			d.queue_free()
	spawned.clear()


func _extract_grid():
	# assumes TileMapLayer exposes get_cell_source_id or similar
	# fallback: sample from used cells

	var rect = top_walls.get_used_rect()
	var grid = []

	for y in range(rect.size.y):
		grid.append([])
		for x in range(rect.size.x):

			var cell = Vector2i(x + rect.position.x, y + rect.position.y)

			# IMPORTANT: adjust depending on your TileMapLayer API
			var has_floor = top_walls.get_cell_source_id(cell) != -1

			grid[y].append(has_floor)

	return grid
	
	
func _is_door_cell(grid, x, y):

	var left  = x > 0 and grid[y][x - 1]
	var right = x < grid[y].size() - 1 and grid[y][x + 1]
	var up    = y > 0 and grid[y - 1][x]
	var down  = y < grid.size() - 1 and grid[y + 1][x]

	# horizontal corridor → door is vertical connection point
	if left and right and not up and not down:
		return false

	# vertical corridor → door is horizontal connection point
	if up and down and not left and not right:
		return false

	# CROSS / transition point (your carved 2-cell connectors often show here)
	if (left and right) and (up or down):
		return true

	if (up and down) and (left or right):
		return true

	return false
