@tool
class_name WorldGeneratorBase
extends Node2D

class ChunkData:
	var id: int
	var rect: Rect2i
	var neighbors: Array[int] = []
	var generator

# --------------------------------------------------
# Scene
# --------------------------------------------------

@export var level_generator_scene: PackedScene
@export var master_tilemap: TopWalls
		
# --------------------------------------------------
# Chunk Count
# --------------------------------------------------

@export_group("Chunk Count")

@export var min_chunks := 8
@export var max_chunks := 12

# --------------------------------------------------
# Chunk Width
# --------------------------------------------------

@export_group("Chunk Width")

@export var min_chunk_width := 8
@export var max_chunk_width := 16

# --------------------------------------------------
# Chunk Height
# --------------------------------------------------

@export_group("Chunk Height")

@export var min_chunk_height := 8
@export var max_chunk_height := 16

# --------------------------------------------------
# Placement
# --------------------------------------------------

@export_group("Placement")

@export var minimum_shared_edge := 3

# --------------------------------------------------
# Shape
# --------------------------------------------------

@export_group("Shape")

@export var target_aspect_ratio := 1.0
@export var max_aspect_ratio := 1.5

# --------------------------------------------------
# Tiles
# --------------------------------------------------

@export_group("Tiles")

@export var tile_size := 16

# --------------------------------------------------
# RNG
# --------------------------------------------------

var rng := RandomNumberGenerator.new()

var chunks: Array[ChunkData] = []


# ==================================================
# GENERATE
# ==================================================
func generate() -> void:
	_clear_old_generation()
	
	chunks.clear()
	
	rng.randomize()

	var chunk_count = rng.randi_range(
		min_chunks,
		max_chunks
	)

	_create_first_chunk()

	for i in range(1, chunk_count):
		_add_chunk(i)

	_compute_adjacency()

	_spawn_chunks()
	
	_merge_chunks()

	print(
		"Generated ",
		chunks.size(),
		" chunks."
	)

# ==================================================
# MERGE TILEMAPS (TERRAIN SYSTEM)
# ==================================================

func _merge_chunks() -> void:
	if master_tilemap == null:
		push_error("Assign a master_tilemap to merge into.")
		return
	
	master_tilemap.clear()
	master_tilemap.grid = []
	master_tilemap.door_gaps = []
	
	# Using a Dictionary as a hash-set to instantly prevent duplicate coordinates
	var unique_terrain_cells := {}
	var raw_door_gaps: Array = []
	

	for chunk in chunks:
		var level = chunk.generator
		if level == null:
			continue
			
		var chunk_tilemap = level.get_node("TopWalls") as TileMapLayer
		if chunk_tilemap == null:
			push_error("Could not find TileMapLayer in chunk ", chunk.id)
			continue
			
		var grid_offset = chunk.rect.position
		
		# 1. Harvest ONLY Wall Terrain Cells
		var used_cells = chunk_tilemap.get_used_cells()
		for cell_pos in used_cells:
			var tile_data = chunk_tilemap.get_cell_tile_data(cell_pos)
			
			# Safety check: ensure it actually belongs to Terrain Set 0, Terrain 0 (Walls)
			if tile_data and tile_data.terrain_set == 0 and tile_data.terrain == 0:
				var global_pos = cell_pos + grid_offset
				unique_terrain_cells[global_pos] = true # Automatically overwrites/ignores duplicates
			
		# 2. Rescue the Door Gaps and Grid
		if "door_gaps" in chunk_tilemap:
			for gap in chunk_tilemap.door_gaps:
				var global_gap_cells: Array[Vector2i] = []
				
				for cell in gap.cells:
					global_gap_cells.append(cell + grid_offset)
				
				raw_door_gaps.append({
					"cells": global_gap_cells,
					"type": gap.type
				})
					
		# 3. Clean up the chunk safely
		chunk_tilemap.free()
		
	# Convert our unique dictionary keys back into an Array
	var all_terrain_cells: Array[Vector2i] = []
	all_terrain_cells.assign(unique_terrain_cells.keys())
		
	# Draw all collected cells
	if not all_terrain_cells.is_empty():
		# CRITICAL FIX: Changed the last argument from 'true' to 'false' 
		# so Godot respects empty spaces and draws edges/corners properly.
		
		# --- REDO INIT_GRID FOR MASTER TILEMAP ---
		var min_x = all_terrain_cells[0].x
		var max_x = all_terrain_cells[0].x
		var min_y = all_terrain_cells[0].y
		var max_y = all_terrain_cells[0].y
		
		for cell in all_terrain_cells:
			if cell.x < min_x: min_x = cell.x
			if cell.x > max_x: max_x = cell.x
			if cell.y < min_y: min_y = cell.y
			if cell.y > max_y: max_y = cell.y
			
		var map_width = abs(min_x - max_x) + 1
		var map_height = abs(min_y - max_y) + 1
		
		if "map_width" in master_tilemap: master_tilemap.map_width = map_width
		if "map_height" in master_tilemap: master_tilemap.map_height = map_height
		if "world_offset" in master_tilemap: master_tilemap.world_offset = Vector2i(min_x, min_y)
		
		for gap in raw_door_gaps:
			var local_gap_cells: Array[Vector2i] = []
			
			for cell in gap["cells"]:
				local_gap_cells.append(cell - Vector2i(min_x, min_y))
			
			master_tilemap.door_gaps.append({
				"cells": local_gap_cells,
				"type": gap["type"]
			})
	
		var new_grid := []

		for y in range(map_height):
			var row := []
			for x in range(map_width):
				row.append(true)
			new_grid.append(row)

		for cell in all_terrain_cells:
			var array_x = cell.x - min_x
			var array_y = cell.y - min_y
			new_grid[array_y][array_x] = false

		master_tilemap.grid = new_grid
		master_tilemap._draw()
						
# ==================================================
# CHUNK CREATION
# ==================================================

func _create_first_chunk() -> void:

	var chunk := ChunkData.new()

	chunk.id = 0

	var w = rng.randi_range(
		min_chunk_width,
		max_chunk_width
	)

	var h = rng.randi_range(
		min_chunk_height,
		max_chunk_height
	)

	chunk.rect = Rect2i(
		0,
		0,
		w,
		h
	)

	chunks.append(chunk)

# ==================================================
# ADD CHUNK
# ==================================================

func _add_chunk(id: int) -> void:

	var width = rng.randi_range(
		min_chunk_width,
		max_chunk_width
	)

	var height = rng.randi_range(
		min_chunk_height,
		max_chunk_height
	)

	var candidates: Array = []

	for existing in chunks:

		candidates.append_array(
			_build_candidates(
				existing.rect,
				width,
				height
			)
		)

	if candidates.is_empty():
		push_error("No valid placement found.")
		return

	candidates.sort_custom(
		func(a,b):
			return a.score < b.score
	)

	var top_count = min(
		10,
		candidates.size()
	)

	var winner = candidates[
		rng.randi_range(
			0,
			top_count - 1
		)
	]

	var chunk := ChunkData.new()

	chunk.id = id
	chunk.rect = winner.rect

	chunks.append(chunk)

# ==================================================
# BUILD CANDIDATES
# ==================================================

func _build_candidates(
	base: Rect2i,
	width: int,
	height: int
) -> Array:

	var results: Array = []

	results.append_array(
		_candidates_north(
			base,
			width,
			height
		)
	)

	results.append_array(
		_candidates_south(
			base,
			width,
			height
		)
	)

	results.append_array(
		_candidates_west(
			base,
			width,
			height
		)
	)

	results.append_array(
		_candidates_east(
			base,
			width,
			height
		)
	)

	return results

func _candidates_south(
	base: Rect2i,
	width: int,
	height: int
) -> Array:

	var results := []

	var min_x = base.position.x - width + minimum_shared_edge

	var max_x = base.position.x + base.size.x - minimum_shared_edge

	for x in range(
		min_x,
		max_x + 1
	):

		var rect := Rect2i(
			x,
			base.position.y +
			base.size.y,
			width,
			height
		)

		if _candidate_is_valid(rect):
			results.append(
				_make_candidate(rect)
			)

	return results


func _candidates_west(
	base: Rect2i,
	width: int,
	height: int
) -> Array:

	var results := []

	var min_y = base.position.y - height + minimum_shared_edge

	var max_y = base.position.y + base.size.y - minimum_shared_edge

	for y in range(
		min_y,
		max_y + 1
	):

		var rect := Rect2i(
			base.position.x - width,
			y,
			width,
			height
		)

		if _candidate_is_valid(rect):
			results.append(
				_make_candidate(rect)
			)

	return results
	

func _candidates_east(
	base: Rect2i,
	width: int,
	height: int
) -> Array:

	var results := []

	var min_y = base.position.y - height + minimum_shared_edge

	var max_y = base.position.y + base.size.y - minimum_shared_edge

	for y in range(
		min_y,
		max_y + 1
	):

		var rect := Rect2i(
			base.position.x +
			base.size.x,
			y,
			width,
			height
		)

		if _candidate_is_valid(rect):
			results.append(
				_make_candidate(rect)
			)

	return results
	
	
func _candidates_north(
	base: Rect2i,
	width: int,
	height: int
) -> Array:

	var results := []

	var _overlap = min(
		base.size.x,
		width
	)

	var min_x = base.position.x - width + minimum_shared_edge

	var max_x = base.position.x + base.size.x - minimum_shared_edge

	for x in range(
		min_x,
		max_x + 1
	):

		var rect := Rect2i(
			x,
			base.position.y - height,
			width,
			height
		)

		if _candidate_is_valid(rect):
			results.append(
				_make_candidate(rect)
			)

	return results
	
func _candidate_is_valid(
	rect: Rect2i
) -> bool:

	for chunk in chunks:

		if rect.intersects(
			chunk.rect
		):
			return false

	return true
# ==================================================
# SIDE CANDIDATES
# ==================================================

func _candidates_on_side(
	base: Rect2i,
	width: int,
	height: int,
	side: int
) -> Array:

	var results := []

	match side:

		# NORTH
		0:

			var max_overlap = min(
					base.size.x,
					width
				)

			for overlap in range(
				minimum_shared_edge,
				max_overlap + 1
			):

				var offset = rng.randi_range(
						0,
						base.size.x - overlap
					)

				var rect := Rect2i(
					base.position.x + offset,
					base.position.y - height + 1,
					width,
					height
				)

				results.append(
					_make_candidate(rect)
				)

		# SOUTH
		1:

			var max_overlap = min(
					base.size.x,
					width
				)

			for overlap in range(
				minimum_shared_edge,
				max_overlap + 1
			):

				var offset = rng.randi_range(
						0,
						base.size.x - overlap
					)

				var rect := Rect2i(
					base.position.x + offset,
					base.position.y + base.size.y - 1,
					width,
					height
				)

				results.append(
					_make_candidate(rect)
				)

		# WEST
		2:

			var max_overlap = min(
					base.size.y,
					height
				)

			for overlap in range(
				minimum_shared_edge,
				max_overlap + 1
			):

				var offset = rng.randi_range(
						0,
						base.size.y - overlap
					)

				var rect := Rect2i(
					base.position.x - width + 1,
					base.position.y + offset,
					width,
					height
				)

				results.append(
					_make_candidate(rect)
				)

		# EAST
		3:

			var max_overlap = min(
					base.size.y,
					height
				)

			for overlap in range(
				minimum_shared_edge,
				max_overlap + 1
			):

				var offset = rng.randi_range(
						0,
						base.size.y - overlap
					)

				var rect := Rect2i(
					base.position.x + base.size.x - 1,
					base.position.y + offset,
					width,
					height
				)

				results.append(
					_make_candidate(rect)
				)

	return results

# ==================================================
# SCORING
# ==================================================

func _make_candidate(
	rect: Rect2i
):

	var bounds = rect

	var used_area = rect.size.x * rect.size.y

	for chunk in chunks:

		bounds = bounds.merge(
			chunk.rect
		)

		used_area += (
			chunk.rect.size.x *
			chunk.rect.size.y
		)

	var aspect = float(
			max(
				bounds.size.x,
				bounds.size.y
			)
		) / float(
			min(
				bounds.size.x,
				bounds.size.y
			)
		)

	var density = float(used_area) / float(
			bounds.size.x *
			bounds.size.y
		)

	var score = abs(
			aspect -
			target_aspect_ratio
		) * 10.0

	score -= density * 5.0

	return {
		"rect": rect,
		"score": score
	}
	
# ==================================================
# ADJACENCY
# ==================================================

func _compute_adjacency() -> void:

	for chunk in chunks:
		chunk.neighbors.clear()

	for i in range(chunks.size()):

		for j in range(i + 1, chunks.size()):

			if _chunks_touch(
				chunks[i].rect,
				chunks[j].rect
			):

				chunks[i].neighbors.append(j)
				chunks[j].neighbors.append(i)

# ==================================================
# TOUCH TEST
# ==================================================

func _chunks_touch(
	a: Rect2i,
	b: Rect2i
) -> bool:

	var expanded = Rect2i(
		a.position - Vector2i.ONE,
		a.size + Vector2i.ONE * 2
	)

	return expanded.intersects(b)

# ==================================================
# SPAWN
# ==================================================

func _clear_old_generation() -> void:
	# Loop backward to avoid index shifting bugs when freeing nodes
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		if "Chunk_" in child.name:
			# CRITICAL FIX: Use free() instantly in tool mode to bypass the queue layout bug
			child.free()
			
func _spawn_chunks() -> void:
	if level_generator_scene == null:
		push_error(
			"Assign level_generator_scene."
		)
		return

	for chunk in chunks:

		var level = level_generator_scene.instantiate()
		level.name = "Chunk_%d" % chunk.id

		add_child(level)

		level.position = Vector2(
				chunk.rect.position.x * tile_size,
				chunk.rect.position.y * tile_size
			)

		level.chunk_id = chunk.id

		level.set_chunk_size(
			chunk.rect.size.x,
			chunk.rect.size.y
		)

		level.generate()

		chunk.generator = level

# ==================================================
# CLEANUP
# ==================================================

func _clear_old_chunks() -> void:
	for child in get_children():
		#if child.name.begins_with("Chunk_"):
			child.queue_free()

	await get_tree().process_frame
