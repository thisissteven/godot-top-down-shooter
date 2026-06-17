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
# MERGE TILEMAPS (POST-PROCESSING ENGINE)
# ==================================================

func _merge_chunks() -> void:
    if master_tilemap == null:
        push_error("Assign a master_tilemap to merge into.")
        return
    
    master_tilemap.clear()
    master_tilemap.grid = []
    master_tilemap.door_gaps = []
    
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
            if tile_data and tile_data.terrain_set == 0 and tile_data.terrain == 0:
                var global_pos = cell_pos + grid_offset
                unique_terrain_cells[global_pos] = true
            
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
                    
        chunk_tilemap.free()
        
    # ==================================================
    # RUN POST-PROCESSING PIPELINE
    # ==================================================

    # Pass 1: Force global network connectivity
    _force_global_connectivity(unique_terrain_cells)

    # Pass 2: Carve doorways at chunk interfaces
    _carve_chunk_intersections(unique_terrain_cells)

    # Pass 3: Clean up thin parallel walls
    _carve_thin_parallel_walls(unique_terrain_cells, raw_door_gaps)

    # Pass 4: Fix diagonal pinches
    _fix_diagonal_pinches(unique_terrain_cells)

    # Pass 5: Guarantee door gap structural integrity first
    _seal_door_gap_borders(unique_terrain_cells, raw_door_gaps)

    # Pass 6: Fix traversal pinches iteratively
    for i in range(5):
        _enforce_diagonal_clearance(unique_terrain_cells, raw_door_gaps)

   
        
    # ==================================================
    # CONSTRUCT MASTER GRID
    # ==================================================
    var all_terrain_cells: Array[Vector2i] = []
    all_terrain_cells.assign(unique_terrain_cells.keys())
        
    if not all_terrain_cells.is_empty():
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
# POST-PROCESSING: DIAGONAL + L-SHAPED CLEARANCE
# ==================================================

func _enforce_diagonal_clearance(unique_terrain_cells: Dictionary, raw_door_gaps: Array) -> void:
    if unique_terrain_cells.is_empty():
        return

    # Build gap cell protection set
    var gap_cells := {}
    for gap in raw_door_gaps:
        if not "cells" in gap:
            continue
        for cell in gap["cells"]:
            gap_cells[cell] = true
            # Also protect immediate frame walls
            for dir in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
                gap_cells[cell + dir] = true

    var is_internal_floor = func(pos: Vector2i) -> bool:
        if unique_terrain_cells.has(pos):
            return false
        for chunk in chunks:
            if chunk.rect.has_point(pos):
                return true
        return false

    var is_protected = func(pos: Vector2i) -> bool:
        return gap_cells.has(pos)

    var cells_to_erase := {}

    for wall_pos in unique_terrain_cells.keys():
        if is_protected.call(wall_pos):
            continue

        # --- DIAGONAL PINCH ---
        for diag in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
            var diag_pos = wall_pos + diag
            if not unique_terrain_cells.has(diag_pos):
                continue
            if is_protected.call(diag_pos):
                continue
            var corner_a = Vector2i(wall_pos.x + diag.x, wall_pos.y)
            var corner_b = Vector2i(wall_pos.x, wall_pos.y + diag.y)
            if is_internal_floor.call(corner_a) and is_internal_floor.call(corner_b):
                var score_wall = _get_wall_density_score(wall_pos, unique_terrain_cells)
                var score_diag = _get_wall_density_score(diag_pos, unique_terrain_cells)
                if score_wall <= score_diag:
                    cells_to_erase[wall_pos] = true
                else:
                    cells_to_erase[diag_pos] = true

        # --- L-SHAPED PINCH ---
        # Only fires when below_1, below_2, below_left, below_right are all floor
        var below_1       = wall_pos + Vector2i( 0, 1)
        var below_2       = wall_pos + Vector2i( 0, 2)
        var below_1_left  = wall_pos + Vector2i(-1, 1)
        var below_1_right = wall_pos + Vector2i( 1, 1)
        var below_2_left  = wall_pos + Vector2i(-1, 2)
        var below_2_right = wall_pos + Vector2i( 1, 2)

        if is_internal_floor.call(below_1) and is_internal_floor.call(below_2) \
        and is_internal_floor.call(below_1_left) and is_internal_floor.call(below_1_right):
            if unique_terrain_cells.has(below_2_left) and not is_protected.call(below_2_left):
                cells_to_erase[below_2_left] = true
            if unique_terrain_cells.has(below_2_right) and not is_protected.call(below_2_right):
                cells_to_erase[below_2_right] = true

    for cell in cells_to_erase:
        unique_terrain_cells.erase(cell)


# ==================================================
# POST-PROCESSING: FILL VERTICAL 1-TILE GAPS
# ==================================================

func _fill_vertical_single_gaps(unique_terrain_cells: Dictionary) -> void:
    if unique_terrain_cells.is_empty():
        return

    var is_internal_floor = func(pos: Vector2i) -> bool:
        if unique_terrain_cells.has(pos):
            return false
        for chunk in chunks:
            if chunk.rect.has_point(pos):
                return true
        return false

    var cells_to_fill := {}

    for wall_pos in unique_terrain_cells.keys():
        var below_1 = wall_pos + Vector2i(0, 1)
        var below_2 = wall_pos + Vector2i(0, 2)
        if is_internal_floor.call(below_1) and unique_terrain_cells.has(below_2):
            cells_to_fill[below_1] = true

    for cell in cells_to_fill:
        unique_terrain_cells[cell] = true
                   
# ==================================================
# POST-PROCESSING: SEAL DOOR GAP BORDERS
# ==================================================

func _seal_door_gap_borders(unique_terrain_cells: Dictionary, raw_door_gaps: Array) -> void:
    for gap in raw_door_gaps:
        if not "cells" in gap:
            continue
        var cells: Array = gap["cells"]
        if cells.is_empty():
            continue

        var is_horizontal := true
        if cells.size() >= 2:
            is_horizontal = cells[0].y == cells[1].y

        if is_horizontal:
            var min_x = cells[0].x
            var max_x = cells[0].x
            for c in cells:
                if c.x < min_x: min_x = c.x
                if c.x > max_x: max_x = c.x

            var gap_ys := {}
            for c in cells:
                gap_ys[c.y] = true

            for y in gap_ys:
                # Fill leftward — skip first wall, fill until second wall
                var hit_first_wall := false
                for dist in range(1, 3):
                    var target = Vector2i(min_x - dist, y)
                    if unique_terrain_cells.has(target):
                        if hit_first_wall:
                            break  # Second wall — stop
                        hit_first_wall = true  # First wall — skip and keep going
                    elif hit_first_wall:
                        unique_terrain_cells[target] = true  # Fill the gap

                # Fill rightward — skip first wall, fill until second wall
                hit_first_wall = false
                for dist in range(1, 3):
                    var target = Vector2i(max_x + dist, y)
                    if unique_terrain_cells.has(target):
                        if hit_first_wall:
                            break
                        hit_first_wall = true
                    elif hit_first_wall:
                        unique_terrain_cells[target] = true
        else:
            var min_y = cells[0].y
            var max_y = cells[0].y
            for c in cells:
                if c.y < min_y: min_y = c.y
                if c.y > max_y: max_y = c.y

            var gap_xs := {}
            for c in cells:
                gap_xs[c.x] = true

            for x in gap_xs:
                # Fill upward — skip first wall, fill until second wall
                var hit_first_wall := false
                for dist in range(1, 4):
                    var target = Vector2i(x, min_y - dist)
                    if unique_terrain_cells.has(target):
                        if hit_first_wall:
                            break
                        hit_first_wall = true
                    elif hit_first_wall:
                        unique_terrain_cells[target] = true

                # Fill downward — skip first wall, fill until second wall
                hit_first_wall = false
                for dist in range(1, 4):
                    var target = Vector2i(x, max_y + dist)
                    if unique_terrain_cells.has(target):
                        if hit_first_wall:
                            break
                        hit_first_wall = true
                    elif hit_first_wall:
                        unique_terrain_cells[target] = true
                        
                                                                                                                                       
# ==================================================
# POST-PROCESSING: PARALLEL WALL & PINCH CARVER (DOOR & VOID SAFE)
# ==================================================

func _carve_thin_parallel_walls(unique_terrain_cells: Dictionary, raw_door_gaps: Array) -> void:
    if unique_terrain_cells.is_empty():
        return
        
    var keys = unique_terrain_cells.keys()
    var min_x = keys[0].x
    var max_x = keys[0].x
    var min_y = keys[0].y
    var max_y = keys[0].y
    
    for k in keys:
        if k.x < min_x: min_x = k.x
        if k.x > max_x: max_x = k.x
        if k.y < min_y: min_y = k.y
        if k.y > max_y: max_y = k.y
        
    var cells_to_erase := {}
    
    for x in range(min_x, max_x + 1):
        for y in range(min_y, max_y + 1):
            var current = Vector2i(x, y)
            
            # Check if this tile or its immediate neighbors are part of a door gap
            var is_near_door_gap = func(pos: Vector2i) -> bool:
                for gap in raw_door_gaps:
                    if "cells" in gap:
                        # If the tile itself or any 1-tile neighbor is a door cell, protect it!
                        for gap_cell in gap["cells"]:
                            if abs(pos.x - gap_cell.x) <= 1 and abs(pos.y - gap_cell.y) <= 1:
                                return true
                return false

            # Helper lambda to check if a tile is valid internal playable floor
            var is_internal_floor = func(pos: Vector2i) -> bool:
                if unique_terrain_cells.has(pos):
                    return false # It's a wall, not a floor
                for chunk in chunks:
                    if chunk.rect.has_point(pos):
                        return true # It's inside a generated room area!
                return false # It's outside the map (the infinite void)

            # --- HORIZONTAL SCAN ---
            var left_1 = current + Vector2i(-1, 0)
            var right_1 = current + Vector2i(1, 0)
            
            # Scenario A: [Wall] [Internal Floor] [Wall]
            if unique_terrain_cells.has(left_1) and unique_terrain_cells.has(right_1) and is_internal_floor.call(current):
                if not is_near_door_gap.call(current) and not is_near_door_gap.call(left_1) and not is_near_door_gap.call(right_1):
                    cells_to_erase[left_1] = true
                    cells_to_erase[current] = true
                    cells_to_erase[right_1] = true
                
            # Scenario B: [Internal Floor] [Wall] [Internal Floor]
            if is_internal_floor.call(left_1) and is_internal_floor.call(right_1) and unique_terrain_cells.has(current):
                if not is_near_door_gap.call(current):
                    cells_to_erase[current] = true

            # --- VERTICAL SCAN ---
            var up_1 = current + Vector2i(0, -1)
            var down_1 = current + Vector2i(0, 1)
            
            # Scenario A: Vertical 1-tile corridor pinch
            if unique_terrain_cells.has(up_1) and unique_terrain_cells.has(down_1) and is_internal_floor.call(current):
                if not is_near_door_gap.call(current) and not is_near_door_gap.call(up_1) and not is_near_door_gap.call(down_1):
                    cells_to_erase[up_1] = true
                    cells_to_erase[current] = true
                    cells_to_erase[down_1] = true
                
            # Scenario B: Vertical 1-tile wall
            if is_internal_floor.call(up_1) and is_internal_floor.call(down_1) and unique_terrain_cells.has(current):
                if not is_near_door_gap.call(current):
                    cells_to_erase[current] = true

    # Execute safe modifications
    for cell in cells_to_erase:
        unique_terrain_cells.erase(cell)
            
# ==================================================
# POST-PROCESSING: FORCE GLOBAL CONNECTIVITY
# ==================================================

func _force_global_connectivity(unique_terrain_cells: Dictionary) -> void:
    var components = _get_chunk_components()
    
    # Keep bridging isolated groups until only 1 master group remains
    while components.size() > 1:
        var best_dist := 1e9
        var chunk_a: ChunkData = null
        var chunk_b: ChunkData = null
        var comp_a_idx := -1
        var comp_b_idx := -1
        
        # Find the two closest chunks that belong to completely separate network islands
        for i in range(components.size()):
            for j in range(i + 1, components.size()):
                for c1 in components[i]:
                    for c2 in components[j]:
                        var center1 = c1.rect.position + c1.rect.size / 2
                        var center2 = c2.rect.position + c2.rect.size / 2
                        var dist = center1.distance_to(center2)
                        if dist < best_dist:
                            best_dist = dist
                            chunk_a = c1
                            chunk_b = c2
                            comp_a_idx = i
                            comp_b_idx = j
                            
        if chunk_a != null and chunk_b != null:
            var start_pos = chunk_a.rect.position + chunk_a.rect.size / 2
            var end_pos = chunk_b.rect.position + chunk_b.rect.size / 2
            
            # Blast an explicit wide corridor across the void/walls to weld them together
            _blast_forced_corridor(start_pos, end_pos, unique_terrain_cells)
            
            # Merge tracking components
            components[comp_a_idx].append_array(components[comp_b_idx])
            components.remove_at(comp_b_idx)
            
            # Re-calculate adjacency to reflect the brand-new connection path
            _compute_adjacency()

func _get_chunk_components() -> Array:
    var components := []
    var visited := {}
    
    for chunk in chunks:
        if visited.has(chunk.id): 
            continue
            
        var comp := []
        var queue := [chunk]
        visited[chunk.id] = true
        
        while queue.size() > 0:
            var curr = queue.pop_front()
            comp.append(curr)
            for neighbor_id in curr.neighbors:
                if not visited.has(neighbor_id):
                    visited[neighbor_id] = true
                    queue.append(chunks[neighbor_id])
        components.append(comp)
    return components

func _blast_forced_corridor(p1: Vector2i, p2: Vector2i, unique_terrain_cells: Dictionary) -> void:
    var tunnel_width := 3 # Hallway width when tearing across the void
    var curr = p1
    
    # Horizontal legs
    var step_x = 1 if p2.x > p1.x else -1
    while curr.x != p2.x:
        _clear_brush_radius(curr, tunnel_width, unique_terrain_cells)
        curr.x += step_x
        
    # Vertical legs
    var step_y = 1 if p2.y > p1.y else -1
    while curr.y != p2.y:
        _clear_brush_radius(curr, tunnel_width, unique_terrain_cells)
        curr.y += step_y
        
    _clear_brush_radius(p2, tunnel_width, unique_terrain_cells)

func _clear_brush_radius(pos: Vector2i, width: int, unique_terrain_cells: Dictionary) -> void:
    var radius = width / 2
    for x in range(pos.x - radius, pos.x - radius + width):
        for y in range(pos.y - radius, pos.y - radius + width):
            unique_terrain_cells.erase(Vector2i(x, y))


# ==================================================
# POST-PROCESSING: INTERSECTION CARVING
# ==================================================

func _carve_chunk_intersections(unique_terrain_cells: Dictionary) -> void:
    var carved_pairs := {}
    
    for chunk in chunks:
        for neighbor_id in chunk.neighbors:
            var pair_id = min(chunk.id, neighbor_id) * 10000 + max(chunk.id, neighbor_id)
            if carved_pairs.has(pair_id):
                continue
            carved_pairs[pair_id] = true
            
            var a = chunk.rect
            var b = chunks[neighbor_id].rect
            
            if a.end.x == b.position.x:
                _carve_deep_tunnel_v(a.end.x, max(a.position.y, b.position.y), min(a.end.y, b.end.y), unique_terrain_cells)
            elif b.end.x == a.position.x:
                _carve_deep_tunnel_v(b.end.x, max(a.position.y, b.position.y), min(a.end.y, b.end.y), unique_terrain_cells)
            elif a.end.y == b.position.y:
                _carve_deep_tunnel_h(max(a.position.x, b.position.x), min(a.end.x, b.end.x), a.end.y, unique_terrain_cells)
            elif b.end.y == a.position.y:
                _carve_deep_tunnel_h(max(a.position.x, b.position.x), min(a.end.x, b.end.x), b.end.y, unique_terrain_cells)

func _carve_deep_tunnel_v(boundary_x: int, start_y: int, end_y: int, unique_terrain_cells: Dictionary) -> void:
    var depth := 3 # Pierces up to 3 tiles deep into both adjoining walls
    var width := 3 # Opens up a wide double/triple wide door footprint
    
    var mid_y = (start_y + end_y) / 2
    var y_start = mid_y - (width / 2)
    
    for y in range(y_start, y_start + width):
        for x in range(boundary_x - depth, boundary_x + depth):
            unique_terrain_cells.erase(Vector2i(x, y))

func _carve_deep_tunnel_h(start_x: int, end_x: int, boundary_y: int, unique_terrain_cells: Dictionary) -> void:
    var depth := 3
    var width := 3
    
    var mid_x = (start_x + end_x) / 2
    var x_start = mid_x - (width / 2)
    
    for x in range(x_start, x_start + width):
        for y in range(boundary_y - depth, boundary_y + depth):
            unique_terrain_cells.erase(Vector2i(x, y))


# ==================================================
# POST-PROCESSING: DIAGONAL PINCH REMOVAL
# ==================================================

func _fix_diagonal_pinches(unique_terrain_cells: Dictionary) -> void:
    if unique_terrain_cells.is_empty():
        return
        
    var keys = unique_terrain_cells.keys()
    var min_x = keys[0].x
    var max_x = keys[0].x
    var min_y = keys[0].y
    var max_y = keys[0].y
    
    for k in keys:
        if k.x < min_x: min_x = k.x
        if k.x > max_x: max_x = k.x
        if k.y < min_y: min_y = k.y
        if k.y > max_y: max_y = k.y
        
    # Scan layout bounding box checking 2x2 grid intersections
    for x in range(min_x - 1, max_x + 1):
        for y in range(min_y - 1, max_y + 1):
            var tl = Vector2i(x, y)
            var tr = Vector2i(x + 1, y)
            var bl = Vector2i(x, y + 1)
            var br = Vector2i(x + 1, y + 1)
            
            var has_tl = unique_terrain_cells.has(tl)
            var has_tr = unique_terrain_cells.has(tr)
            var has_bl = unique_terrain_cells.has(bl)
            var has_br = unique_terrain_cells.has(br)
            
            # Pattern A: Wall at Top-Left and Bottom-Right / Floor at Top-Right and Bottom-Left
            if has_tl and has_br and not has_tr and not has_bl:
                _carve_thicker_wall_node(tl, br, unique_terrain_cells)
                
            # Pattern B: Wall at Top-Right and Bottom-Left / Floor at Top-Left and Bottom-Right
            if has_tr and has_bl and not has_tl and not has_br:
                _carve_thicker_wall_node(tr, bl, unique_terrain_cells)

func _carve_thicker_wall_node(w1: Vector2i, w2: Vector2i, unique_terrain_cells: Dictionary) -> void:
    var density1 = _get_wall_density_score(w1, unique_terrain_cells)
    var density2 = _get_wall_density_score(w2, unique_terrain_cells)
    
    # Selects the thicker architectural block to punch outward, opening paths cleanly
    if density1 >= density2:
        unique_terrain_cells.erase(w1)
    else:
        unique_terrain_cells.erase(w2)

func _get_wall_density_score(pos: Vector2i, unique_terrain_cells: Dictionary) -> int:
    var score := 0
    for dx in [-1, 0, 1]:
        for dy in [-1, 0, 1]:
            if dx == 0 and dy == 0: 
                continue
            if unique_terrain_cells.has(pos + Vector2i(dx, dy)):
                score += 1
    return score


# ==================================================
# CHUNK CREATION
# ==================================================

func _create_first_chunk() -> void:
    var chunk := ChunkData.new()
    chunk.id = 0

    var w = rng.randi_range(min_chunk_width, max_chunk_width)
    var h = rng.randi_range(min_chunk_height, max_chunk_height)

    chunk.rect = Rect2i(0, 0, w, h)
    chunks.append(chunk)

# ==================================================
# ADD CHUNK
# ==================================================

func _add_chunk(id: int) -> void:
    var width = rng.randi_range(min_chunk_width, max_chunk_width)
    var height = rng.randi_range(min_chunk_height, max_chunk_height)
    var candidates: Array = []

    for existing in chunks:
        candidates.append_array(_build_candidates(existing.rect, width, height))

    if candidates.is_empty():
        push_error("No valid placement found.")
        return

    candidates.sort_custom(func(a, b): return a.score < b.score)
    var top_count = min(10, candidates.size())
    var winner = candidates[rng.randi_range(0, top_count - 1)]

    var chunk := ChunkData.new()
    chunk.id = id
    chunk.rect = winner.rect
    chunks.append(chunk)

# ==================================================
# BUILD CANDIDATES
# ==================================================

func _build_candidates(base: Rect2i, width: int, height: int) -> Array:
    var results: Array = []
    results.append_array(_candidates_north(base, width, height))
    results.append_array(_candidates_south(base, width, height))
    results.append_array(_candidates_west(base, width, height))
    results.append_array(_candidates_east(base, width, height))
    return results

func _candidates_south(base: Rect2i, width: int, height: int) -> Array:
    var results := []
    var min_x = base.position.x - width + minimum_shared_edge
    var max_x = base.position.x + base.size.x - minimum_shared_edge

    for x in range(min_x, max_x + 1):
        var rect := Rect2i(x, base.position.y + base.size.y, width, height)
        if _candidate_is_valid(rect):
            results.append(_make_candidate(rect))
    return results

func _candidates_west(base: Rect2i, width: int, height: int) -> Array:
    var results := []
    var min_y = base.position.y - height + minimum_shared_edge
    var max_y = base.position.y + base.size.y - minimum_shared_edge

    for y in range(min_y, max_y + 1):
        var rect := Rect2i(base.position.x - width, y, width, height)
        if _candidate_is_valid(rect):
            results.append(_make_candidate(rect))
    return results
    
func _candidates_east(base: Rect2i, width: int, height: int) -> Array:
    var results := []
    var min_y = base.position.y - height + minimum_shared_edge
    var max_y = base.position.y + base.size.y - minimum_shared_edge

    for y in range(min_y, max_y + 1):
        var rect := Rect2i(base.position.x + base.size.x, y, width, height)
        if _candidate_is_valid(rect):
            results.append(_make_candidate(rect))
    return results
    
func _candidates_north(base: Rect2i, width: int, height: int) -> Array:
    var results := []
    var min_x = base.position.x - width + minimum_shared_edge
    var max_x = base.position.x + base.size.x - minimum_shared_edge

    for x in range(min_x, max_x + 1):
        var rect := Rect2i(x, base.position.y - height, width, height)
        if _candidate_is_valid(rect):
            results.append(_make_candidate(rect))
    return results
    
func _candidate_is_valid(rect: Rect2i) -> bool:
    for chunk in chunks:
        # 1. Reject complete layout overlaps
        if rect.intersects(chunk.rect):
            return false
            
        # 2. Calculate the exact directional distance on both axes
        var dx = max(0, max(rect.position.x - chunk.rect.end.x, chunk.rect.position.x - rect.end.x))
        var dy = max(0, max(rect.position.y - chunk.rect.end.y, chunk.rect.position.y - rect.end.y))
        
        # 3. Handle rooms that are touching (Distance is 0)
        if dx == 0 and dy == 0:
            var overlap_x = min(rect.end.x, chunk.rect.end.x) - max(rect.position.x, chunk.rect.position.x)
            var overlap_y = min(rect.end.y, chunk.rect.end.y) - max(rect.position.y, chunk.rect.position.y)
            
            # Filter out unstable diagonal corner-to-corner touches
            if overlap_x == 0 and overlap_y == 0:
                return false 
                
            # Check shared edge length. If they touch, they MUST share enough space to carve a doorway safely.
            if (overlap_x > 0 and overlap_x < minimum_shared_edge) or (overlap_y > 0 and overlap_y < minimum_shared_edge):
                return false
                
            # This is a solid, flush connection. Let it pass so post-processing can carve a door.
            continue
            
        # 4. ENFORCE BUFFER REGULATION:
        # If they are NOT touching (distance > 0), they MUST be separated by at least 2 tiles.
        # This cleanly blocks 1-tile wide parallel wall pinches and diagonal wall-edge snags.
        if (dx > 0 and dx < 2) or (dy > 0 and dy < 2):
            return false
            
    return true

# ==================================================
# SCORING
# ==================================================

func _make_candidate(rect: Rect2i):
    var bounds = rect
    var used_area = rect.size.x * rect.size.y

    for chunk in chunks:
        bounds = bounds.merge(chunk.rect)
        used_area += (chunk.rect.size.x * chunk.rect.size.y)

    var aspect = float(max(bounds.size.x, bounds.size.y)) / float(min(bounds.size.x, bounds.size.y))
    var density = float(used_area) / float(bounds.size.x * bounds.size.y)
    var score = abs(aspect - target_aspect_ratio) * 10.0
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
            if _chunks_touch(chunks[i].rect, chunks[j].rect):
                chunks[i].neighbors.append(j)
                chunks[j].neighbors.append(i)

# ==================================================
# TOUCH TEST
# ==================================================

func _chunks_touch(a: Rect2i, b: Rect2i) -> bool:
    var expanded = Rect2i(
        a.position - Vector2i.ONE,
        a.size + Vector2i.ONE * 2
    )
    return expanded.intersects(b)

# ==================================================
# SPAWN
# ==================================================

func _clear_old_generation() -> void:
    for i in range(get_child_count() - 1, -1, -1):
        var child = get_child(i)
        if "Chunk_" in child.name:
            child.free()
            
func _spawn_chunks() -> void:
    if level_generator_scene == null:
        push_error("Assign level_generator_scene.")
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
        level.set_chunk_size(chunk.rect.size.x, chunk.rect.size.y)
        level.generate()
        chunk.generator = level

# ==================================================
# CLEANUP
# ==================================================

func _clear_old_chunks() -> void:
    for child in get_children():
        child.queue_free()
    await get_tree().process_frame
