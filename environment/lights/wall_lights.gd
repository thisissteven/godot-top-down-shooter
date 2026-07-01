@tool
class_name WallLightPlacer
extends Node2D

@export var top_wall_layer: TopWalls
@export var bottom_wall_layer: BottomWalls
@export var wall_light_scene: PackedScene          # vertical wall light
@export var horizontal_wall_light_scene: PackedScene  # horizontal wall light
## Light Color
@export var light_color: Color = Color("ffffff")

@export_group("Placement")
## Minimum distance between two lights (in tiles, Chebyshev)
@export var min_spacing := 8
## Chance (0.0–1.0) that a qualifying strip gets a light at all
@export_range(0.0, 1.0) var placement_chance := 0.7
## Minimum strip length in tiles to be eligible
@export var min_strip_length := 3

@export_group("Seed")
@export var seed_value := 0

var initialized := false

func _ready() -> void:
	initialized = true

func generate() -> void:
	if not top_wall_layer:
		push_error("WallLightPlacer: Assign top_wall_layer.")
		return
	if not bottom_wall_layer:
		push_error("WallLightPlacer: Assign bottom_wall_layer.")
		return
	if not wall_light_scene:
		push_error("WallLightPlacer: Assign wall_light_scene.")
		return
	if not horizontal_wall_light_scene:
		push_error("WallLightPlacer: Assign horizontal_wall_light_scene.")
		return

	for child in get_children():
		if child.name.begins_with("WallLight"):
			child.free()

	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	var tile_size: Vector2 = Vector2(top_wall_layer.tile_set.tile_size)
	var placed_centers: Array = []
	var placed_count := 0

	# ── Horizontal lights on bottom wall strips (south-facing, glow DOWN) ──
	var h_strips := _collect_horizontal_strips()
	_shuffle(h_strips, rng)

	for strip in h_strips:
		if strip.size() < min_strip_length:
			continue
		if rng.randf() > placement_chance:
			continue

		var mid_cell: Vector2i = strip[strip.size() / 2]

		if _is_near_door_gap(mid_cell):
			continue
		if not _is_far_enough(mid_cell, placed_centers):
			continue

		var strip_origin_x = strip[0].x * tile_size.x
		var center_x = strip_origin_x + strip.size() * tile_size.x * 0.5
		
		var picked = [1, 2].pick_random()
		if picked == 1:
			var bottom_wall_center_y = (strip[0].y + 1) * tile_size.y + 0

			var light = wall_light_scene.instantiate()
			light.set_color(light_color)
			light.rotation = 0.0
			light.position = Vector2(center_x, bottom_wall_center_y) + Vector2(0, 7)
			light.name = "WallLight_H_%d_%d" % [mid_cell.x, mid_cell.y]
			light.glow_direction = WallLight.GlowDirection.DOWN
			add_child(light)
			light.owner = owner
		else:
			var bottom_wall_center_y = (strip[0].y + 1) * tile_size.y + 0

			var light = horizontal_wall_light_scene.instantiate()
			light.set_color(light_color)
			light.rotation = 0.0
			light.position = Vector2(center_x, bottom_wall_center_y)
			light.name = "WallLight_H_%d_%d" % [mid_cell.x, mid_cell.y]
			light.glow_direction = WallLight.GlowDirection.DOWN
			add_child(light)
			light.owner = owner

		placed_centers.append(mid_cell)
		placed_count += 1

	# ── Horizontal lights on top-facing top wall strips (glow UP) ──
	var t_strips := _collect_top_facing_strips()
	_shuffle(t_strips, rng)

	for strip in t_strips:
		if strip.size() < min_strip_length:
			continue
		if rng.randf() > placement_chance:
			continue

		var mid_cell: Vector2i = strip[strip.size() / 2]

		if _is_near_door_gap(mid_cell):
			continue
		if not _is_far_enough(mid_cell, placed_centers):
			continue

		var strip_origin_x = strip[0].x * tile_size.x
		var center_x = strip_origin_x + strip.size() * tile_size.x * 0.5
		# Top edge of the wall tile
		var top_wall_top_y = strip[0].y * tile_size.y

		var light = horizontal_wall_light_scene.instantiate()
		horizontal_wall_light_scene.set_color(light_color)
		light.rotation = 0.0
		light.position = Vector2(center_x, top_wall_top_y)
		light.name = "WallLight_T_%d_%d" % [mid_cell.x, mid_cell.y]
		light.glow_direction = WallLight.GlowDirection.UP
		add_child(light)
		light.owner = owner

		placed_centers.append(mid_cell)
		placed_count += 1

	# ── Vertical lights on top wall vertical strips (glow LEFT or RIGHT) ──
	var v_strips := _collect_vertical_strips()
	_shuffle(v_strips, rng)

	for strip in v_strips:
		if strip.size() < min_strip_length:
			continue
		if rng.randf() > placement_chance:
			continue

		var mid_cell: Vector2i = strip[strip.size() / 2]
		if not _is_far_enough(mid_cell, placed_centers):
			continue

		var strip_origin_y = strip[0].y * tile_size.y
		var center_y = strip_origin_y + strip.size() * tile_size.y * 0.5

		var go_left: bool = rng.randi_range(0, 1) == 0
		var wall_tile_x = strip[0].x * tile_size.x
		var center_x: float
		var glow_direction

		if go_left:
			center_x = wall_tile_x
			glow_direction = WallLight.GlowDirection.LEFT
		else:
			center_x = wall_tile_x + tile_size.x
			glow_direction = WallLight.GlowDirection.RIGHT

		var light = wall_light_scene.instantiate()
		light.set_color(light_color)
		light.rotation = 0.0
		light.position = Vector2(center_x, center_y)
		light.name = "WallLight_V_%d_%d" % [mid_cell.x, mid_cell.y]
		light.glow_direction = glow_direction
		add_child(light)
		light.owner = owner

		placed_centers.append(mid_cell)
		placed_count += 1

	print("WallLightPlacer: Placed %d lights." % placed_count)


# ── Collect horizontal south-facing top wall strips (floor below) ─────────────
func _collect_horizontal_strips() -> Array:
	var grid = top_wall_layer.grid
	var w := top_wall_layer.map_width
	var h := top_wall_layer.map_height
	var border := top_wall_layer.border_thickness
	var strips: Array = []

	for y in range(border, h - border):
		var x := border
		while x < w - border:
			if grid[y][x] != false:
				x += 1
				continue
			# South-facing: floor directly below
			if not (y < h - 1 and grid[y + 1][x] == true):
				x += 1
				continue

			var run_start := x
			while x < w - border and grid[y][x] == false:
				if not (y < h - 1 and grid[y + 1][x] == true):
					break
				x += 1

			if x > run_start:
				var cells: Array = []
				for cx in range(run_start, x):
					cells.append(Vector2i(cx, y))
				strips.append(cells)

	return strips


# ── Collect horizontal top-facing top wall strips (floor above) ───────────────
func _collect_top_facing_strips() -> Array:
	var grid = top_wall_layer.grid
	var w := top_wall_layer.map_width
	var h := top_wall_layer.map_height
	var border := top_wall_layer.border_thickness
	var strips: Array = []

	for y in range(border, h - border):
		var x := border
		while x < w - border:
			if grid[y][x] != false:
				x += 1
				continue
			# North-facing: floor directly above
			if not (y > 0 and grid[y - 1][x] == true):
				x += 1
				continue

			var run_start := x
			while x < w - border and grid[y][x] == false:
				if not (y > 0 and grid[y - 1][x] == true):
					break
				x += 1

			if x > run_start:
				var cells: Array = []
				for cx in range(run_start, x):
					cells.append(Vector2i(cx, y))
				strips.append(cells)

	return strips


# ── Collect vertical top wall strips (floor left AND right) ───────────────────
func _collect_vertical_strips() -> Array:
	var grid = top_wall_layer.grid
	var w := top_wall_layer.map_width
	var h := top_wall_layer.map_height
	var border := top_wall_layer.border_thickness
	var strips: Array = []

	for x in range(border, w - border):
		var y := border
		while y < h - border:
			if grid[y][x] != false:
				y += 1
				continue
			# Vertical strip: floor on left AND right
			var floor_left  = (x > 0       and grid[y][x - 1] == true)
			var floor_right = (x < w - 1   and grid[y][x + 1] == true)
			if not floor_left or not floor_right:
				y += 1
				continue

			var run_start := y
			while y < h - border and grid[y][x] == false:
				var fl = (x > 0     and grid[y][x - 1] == true)
				var fr = (x < w - 1 and grid[y][x + 1] == true)
				if not fl or not fr:
					break
				y += 1

			if y > run_start:
				var cells: Array = []
				for cy in range(run_start, y):
					cells.append(Vector2i(x, cy))
				strips.append(cells)

	return strips


# ── Door gap proximity check (Chebyshev radius 2) ────────────────────────────
func _is_near_door_gap(cell: Vector2i) -> bool:
	for gap in top_wall_layer.door_gaps:
		for gap_cell in gap["cells"]:
			if max(abs(cell.x - gap_cell.x), abs(cell.y - gap_cell.y)) <= 2:
				return true
	return false


# ── Fisher-Yates shuffle ──────────────────────────────────────────────────────
func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ── Chebyshev spacing check ───────────────────────────────────────────────────
func _is_far_enough(cell: Vector2i, placed: Array) -> bool:
	for p in placed:
		if max(abs(cell.x - p.x), abs(cell.y - p.y)) < min_spacing:
			return false
	return true
