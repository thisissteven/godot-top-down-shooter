@tool
class_name WindowPlacer
extends TileMapLayer

# grid[y][x] == false → wall tile is drawn  (terrain tile exists)
# grid[y][x] == true  → empty / floor       (no tile)
# Carving = set grid[y][x] = true + erase the tilemap cell

@export var top_wall_layer: TopWalls
@export var bottom_wall_layer: BottomWalls

@export_group("Strip Filtering")
## Strip must be strictly longer than this to be a candidate
@export var min_strip_size := 3
## Window tiles are at least this many cells wide/tall
@export var min_window_size := 3
## Window tiles are at most this many cells wide/tall
@export var max_window_size := 5


@export_group("Limits")
## Max windows to attempt per strip (0 = disabled, place no windows)
@export var max_windows_per_strip := 2
## Total windows across both horizontal + vertical (0 = unlimited)
@export var max_total_windows := 10

@export_group("Tile Sources")
@export var horizontal_source_id := 0
@export var vertical_source_id   := 1

@export_group("Horizontal Window Atlas Coords")
@export var h_left_tile      := Vector2i(0, 0)
@export var h_mid_tile       := Vector2i(1, 0)
@export var h_right_tile     := Vector2i(2, 0)
@export var h_bot_left_tile  := Vector2i(0, 1)
@export var h_bot_mid_tile   := Vector2i(1, 1)
@export var h_bot_right_tile := Vector2i(2, 1)

@export_group("Vertical Window Atlas Coords")
@export var v_top_tile := Vector2i(0, 0)
@export var v_mid_tile := Vector2i(0, 1)
@export var v_bot_tile := Vector2i(0, 2)

var _rng := RandomNumberGenerator.new()
var initialized := false

func _ready() -> void:
	initialized = true


func generate() -> void:
	#if not initialized:
		#await ready

	if not top_wall_layer:
		push_error("WindowPlacer: Assign top_wall_layer in the Inspector.")
		return
	if not bottom_wall_layer:
		push_error("WindowPlacer: Assign bottom_wall_layer in the Inspector.")
		return
	if max_windows_per_strip == 0:
		print("WindowPlacer: max_windows_per_strip is 0, nothing to place.")
		return

	var grid  = top_wall_layer.grid
	var map_w = top_wall_layer.map_width
	var map_h = top_wall_layer.map_height

	if grid.is_empty():
		push_error("WindowPlacer: top_wall_layer.grid is empty — run TopWalls.generate() first.")
		return

	_rng.seed = top_wall_layer.rng.seed

	clear()

	var h_strips = _collect_horizontal_strips(grid, map_w, map_h)
	var v_strips = _collect_vertical_strips(grid, map_w, map_h)

	var h_placed := 0
	var v_placed := 0
	var total_windows := 0

	# Mix strips together so one orientation doesn't consume everything
	var all_strips := []

	for strip in h_strips:
		all_strips.append({
			"cells": strip,
			"horizontal": true
		})

	for strip in v_strips:
		all_strips.append({
			"cells": strip,
			"horizontal": false
		})

	all_strips.shuffle()

	for data in all_strips:

		if max_total_windows > 0 and total_windows >= max_total_windows:
			break

		var remaining := max_total_windows - total_windows
		var placed := _place_windows_in_strip(
			data.cells,
			data.horizontal,
			remaining
		)

		total_windows += placed

		if data.horizontal:
			h_placed += placed
		else:
			v_placed += placed

	print("WindowPlacer: %d horizontal, %d vertical windows placed." % [h_placed, v_placed])


# ── Strip collection ───────────────────────────────────────────────────────────

func _collect_horizontal_strips(grid: Array, map_w: int, map_h: int) -> Array:
	var strips := []
	for y in range(1, map_h - 1):
		var x := 0
		while x < map_w:
			if not _is_h_strip_cell(grid, x, y, map_w, map_h):
				x += 1
				continue
			var run_start := x
			while x < map_w and _is_h_strip_cell(grid, x, y, map_w, map_h):
				x += 1
			if x - run_start > min_strip_size:
				var cells: Array[Vector2i] = []
				for cx in range(run_start, x):
					cells.append(Vector2i(cx, y))
				strips.append(cells)
	return strips


func _collect_vertical_strips(grid: Array, map_w: int, map_h: int) -> Array:
	var strips := []
	for x in range(1, map_w - 1):
		var y := 0
		while y < map_h:
			if not _is_v_strip_cell(grid, x, y, map_w, map_h):
				y += 1
				continue
			var run_start := y
			while y < map_h and _is_v_strip_cell(grid, x, y, map_w, map_h):
				y += 1
			if y - run_start > min_strip_size:
				var cells: Array[Vector2i] = []
				for cy in range(run_start, y):
					cells.append(Vector2i(x, cy))
				strips.append(cells)
	return strips


# ── Strip cell predicates ──────────────────────────────────────────────────────
#
# grid[y][x] == false  →  wall (tile drawn)
# grid[y][x] == true   →  empty/floor (no tile)
#
# A wall cell is a candidate for a window strip if it is a single-tile-thin wall:
#   horizontal strip: wall cell with empty space above AND below (floors either side)
#   vertical strip:   wall cell with empty space left  AND right

func _is_wall(grid: Array, x: int, y: int, map_w: int, map_h: int) -> bool:
	if x < 0 or x >= map_w or y < 0 or y >= map_h:
		return false
	return grid[y][x] == false  # false = wall tile present


func _is_h_strip_cell(grid: Array, x: int, y: int, map_w: int, map_h: int) -> bool:
	if not _is_wall(grid, x, y, map_w, map_h):
		return false
	# empty (true) directly above AND below  →  single-tile-thick horizontal wall
	var empty_above = (y > 0        and grid[y - 1][x] == true)
	var empty_below = (y < map_h - 1 and grid[y + 1][x] == true)
	return empty_above and empty_below


func _is_v_strip_cell(grid: Array, x: int, y: int, map_w: int, map_h: int) -> bool:
	if not _is_wall(grid, x, y, map_w, map_h):
		return false
	# empty (true) directly left AND right  →  single-tile-thick vertical wall
	var empty_left  = (x > 0        and grid[y][x - 1] == true)
	var empty_right = (x < map_w - 1 and grid[y][x + 1] == true)
	return empty_left and empty_right


# ── Window placement within a strip ───────────────────────────────────────────

func _place_windows_in_strip(
	strip: Array,
	horizontal: bool,
	remaining_limit := 999999
) -> int:
	var strip_len := strip.size()
	var effective_max: int = min(max_window_size, strip_len)

	if effective_max < min_window_size:
		return 0

	var num_windows := _rng.randi_range(
		1,
		min(max_windows_per_strip, remaining_limit)
	)
	var placed := 0
	var occupied := {}

	for _w in range(num_windows):
		var attempts := 10
		while attempts > 0:
			attempts -= 1

			var win_size := _rng.randi_range(min_window_size, effective_max)
			var max_offset := strip_len - win_size
			if max_offset < 0:
				break

			var offset := _rng.randi_range(0, max_offset)

			var blocked := false
			for i in range(win_size):
				if occupied.has(offset + i):
					blocked = true
					break
			if blocked:
				continue

			for i in range(win_size):
				occupied[offset + i] = true

			var win_cells: Array[Vector2i] = []
			for i in range(win_size):
				win_cells.append(strip[offset + i])

			if horizontal:
				_paint_horizontal_window(win_cells)
			else:
				_paint_vertical_window(win_cells)

			placed += 1
			break

	return placed


# ── Painting ───────────────────────────────────────────────────────────────────

func _paint_horizontal_window(cells: Array) -> void:
	var count := cells.size()

	for i in range(count):
		var cell: Vector2i = cells[i]

		# Remove top wall
		top_wall_layer.grid[cell.y][cell.x] = true
		top_wall_layer.erase_cell(cell)
		#_spawn_occluder(cell, top_wall_layer)

		# Remove bottom wall
		# bottom_walls places at top_cell + DOWN*h (h=1 default)
		bottom_wall_layer.erase_cell(cell + Vector2i(0, 1))
		

		var top_atlas: Vector2i
		var bot_atlas: Vector2i

		if count == 1:
			top_atlas = h_mid_tile
			bot_atlas = h_bot_mid_tile
		elif i == 0:
			top_atlas = h_left_tile
			bot_atlas = h_bot_left_tile
		elif i == count - 1:
			top_atlas = h_right_tile
			bot_atlas = h_bot_right_tile
		else:
			top_atlas = h_mid_tile
			bot_atlas = h_bot_mid_tile

		# Draw top half
		set_cell(
			cell,
			horizontal_source_id,
			top_atlas
		)

		# Draw bottom half one tile lower
		set_cell(
			cell + Vector2i(0, 1),
			horizontal_source_id,
			bot_atlas
		)
			
		
func _paint_vertical_window(cells: Array) -> void:
	var count := cells.size()

	for i in range(count):
		var cell: Vector2i = cells[i]

		# 1. Carve top wall: mark grid as empty, then erase the terrain tile
		top_wall_layer.grid[cell.y][cell.x] = true
		top_wall_layer.erase_cell(cell)

		# 2. No bottom wall to erase for vertical windows (single tile height)

		# 3 & 4. Pick atlas frame and place window tile
		var atlas: Vector2i
		if count == 1:
			atlas = v_mid_tile
		elif i == 0:
			atlas = v_top_tile
		elif i == count - 1:
			atlas = v_bot_tile
		else:
			atlas = v_mid_tile

		set_cell(cell, vertical_source_id, atlas)
		
			
func _spawn_occluder(cell: Vector2i, layer: TileMapLayer) -> void:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()

	var tile_size := layer.tile_set.tile_size
	poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(tile_size.x, 0),
		Vector2(tile_size.x, tile_size.y),
		Vector2(0, tile_size.y)
	])

	occ.occluder = poly
	occ.position = layer.map_to_local(cell)
	layer.add_child(occ)
