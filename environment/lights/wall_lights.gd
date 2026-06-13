@tool
class_name WallLightPlacer
extends Node

@export var top_wall_layer: TopWalls
@export var wall_light_scene: PackedScene

@export_group("Placement")
## Total number of wall lights to place across the map
@export var light_count := 6
## Minimum distance between two lights (in tiles, Chebyshev)
@export var min_spacing := 8
## Only place lights on vertical wall segments facing downward
## (wall tile has open floor directly below — south-facing wall)
@export var south_facing_only := true

@export_group("Offset")
## Fine-tune light position relative to the tile center (in pixels)
@export var light_offset: Vector2 = Vector2(0, 0)

@export_group("Seed")
@export var seed_value := 0

var initialized := false

func _ready() -> void:
	initialized = true


func generate() -> void:
	#if !initialized:
		#await ready
	
	if not top_wall_layer:
		push_error("WallLightPlacer: Assign top_wall_layer in the Inspector.")
		return
	if not wall_light_scene:
		push_error("WallLightPlacer: Assign wall_light_scene in the Inspector.")
		return

	var parent = get_parent()
	if not parent:
		push_error("WallLightPlacer: Must have a parent node.")
		return

	# ── Clean up previous pass ──
	for node_name in ["WallLights"]:
		var existing = parent.find_child(node_name, false, false)
		if is_instance_valid(existing):
			existing.queue_free()
	while parent.find_child("WallLights", false, false) != null:
		await get_tree().process_frame

	var container = Node2D.new()
	container.name = "WallLights"
	container.y_sort_enabled = true
	parent.add_child(container)
	container.owner = owner
	container.set_unique_name_in_owner(true)

	# ── Collect candidates ──
	var candidates: Array = _collect_candidates()

	if candidates.is_empty():
		push_warning("WallLightPlacer: No valid wall candidates found.")
		return

	# ── Shuffle candidates ──
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	# Fisher-Yates shuffle
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	# ── Place lights with spacing enforcement ──
	var placed: Array = []
	var tile_size: Vector2 = Vector2(top_wall_layer.tile_set.tile_size)

	for cell in candidates:
		if placed.size() >= light_count:
			break

		if not _is_far_enough(cell, placed):
			continue

		var light = wall_light_scene.instantiate()
		# Center of the tile in world space
		light.position = (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size + light_offset
		light.name = "WallLight_" + str(cell.x) + "_" + str(cell.y)
		container.add_child(light)
		light.owner = owner

		placed.append(cell)

	print("WallLightPlacer: Placed %d lights." % placed.size())


# ── Find all vertical wall tiles that face open floor ──
func _collect_candidates() -> Array:
	var grid = top_wall_layer.grid
	var w := top_wall_layer.map_width
	var h := top_wall_layer.map_height
	var border := top_wall_layer.border_thickness
	var candidates: Array = []

	for y in range(border, h - border):
		for x in range(border, w - border):

			# Must be a wall tile
			if grid[y][x] != false:
				continue

			# Must have at least one horizontal wall neighbor
			# (confirms it's part of a wall segment, not an isolated block)
			var has_wall_neighbor := false
			if x > 0 and grid[y][x - 1] == false:
				has_wall_neighbor = true
			if x < w - 1 and grid[y][x + 1] == false:
				has_wall_neighbor = true

			if not has_wall_neighbor:
				continue

			if south_facing_only:
				# Wall tile must have open floor directly below (south-facing)
				var floor_below : bool = (y < h - 1 and grid[y + 1][x] == true)
				if not floor_below:
					continue
			else:
				# Accept any wall tile adjacent to floor (any direction)
				var floor_above : bool = (y > 0       and grid[y - 1][x] == true)
				var floor_below : bool = (y < h - 1   and grid[y + 1][x] == true)
				if not floor_above and not floor_below:
					continue

			candidates.append(Vector2i(x, y))

	return candidates


# ── Chebyshev distance check against all already-placed lights ──
func _is_far_enough(cell: Vector2i, placed: Array) -> bool:
	for p in placed:
		var dx : int = abs(cell.x - p.x)
		var dy : int = abs(cell.y - p.y)
		if max(dx, dy) < min_spacing:
			return false
	return true
