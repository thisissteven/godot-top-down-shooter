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
    if top_wall_layer == null:
        push_error("Top wall layer missing")
        return
    clear()

    var grid = top_wall_layer.grid

    if grid.is_empty():
        push_error("TopWalls grid is empty — is Tiles.generate() called after TopWalls._draw()?")
        return

    var offset: Vector2i = Vector2i.ZERO
    if "world_offset" in top_wall_layer:
        offset = top_wall_layer.world_offset

    var grid_height = grid.size()
    var grid_width = grid[0].size()
    var rect = Rect2i(offset.x, offset.y, grid_width, grid_height)
    var sinkhole_cells := _generate_sinkholes(rect)

    var exterior_cells = get_exterior_cells(rect, grid)

    for y in range(grid_height + 1):
        for x in range(grid_width):
            var cell = Vector2i(x + offset.x, y + offset.y)

            var is_in_structure = not exterior_cells.has(cell)

            var is_below_wall = false
            if y > 0 and not grid[y - 1][x]:
                is_below_wall = true

            if is_in_structure or is_below_wall:
                if cell in sinkhole_cells:
                    continue

                # ─────────────────────────────────────
                # ONLY APPLY RULE ON LAST ROW
                # ─────────────────────────────────────
                if y == grid_height:
                    var above_cell = Vector2i(x + offset.x, (y - 1) + offset.y)
                    if top_wall_layer.get_cell_source_id(above_cell) == -1:
                        continue

                set_cell(cell, source_id, _pick_floor_tile())

    update_internals()
    print("Floor generation complete")

func _compute_reachable_air(grid: Array) -> Dictionary:
    var h = grid.size()
    var w = grid[0].size()

    var visited := {}
    var stack := []

    # Start from all boundary empty cells
    for x in range(w):
        if not grid[0][x]:
            stack.append(Vector2i(x, 0))
        if not grid[h - 1][x]:
            stack.append(Vector2i(x, h - 1))

    for y in range(h):
        if not grid[y][0]:
            stack.append(Vector2i(0, y))
        if not grid[y][w - 1]:
            stack.append(Vector2i(w - 1, y))

    var dirs = [
        Vector2i(1, 0),
        Vector2i(-1, 0),
        Vector2i(0, 1),
        Vector2i(0, -1)
    ]

    while stack.size() > 0:
        var p = stack.pop_back()
        if visited.has(p):
            continue
        if grid[p.y][p.x]: # wall blocks flood fill
            continue

        visited[p] = true

        for d in dirs:
            var n = p + d
            if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h:
                if not visited.has(n):
                    stack.append(n)

    return visited
    
func get_exterior_cells(rect: Rect2i, grid: Array) -> Dictionary:
    var exterior := {}
    var queue: Array[Vector2i] = []
    
    # 1. Start the queue with all border cells of your grid
    for x in range(rect.position.x, rect.end.x):
        for y in range(rect.position.y, rect.end.y):
            # Check if this is a border cell
            if x == rect.position.x or x == rect.end.x - 1 or \
               y == rect.position.y or y == rect.end.y - 1:
                # If it's not a wall, it's an exterior starting point
                if grid[y - rect.position.y][x - rect.position.x]:
                    exterior[Vector2i(x, y)] = true
                    queue.append(Vector2i(x, y))
    
    # 2. Spread the "exterior" flag to all connected non-wall cells
    var neighbors = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
    while not queue.is_empty():
        var current = queue.pop_front()
        for n in neighbors:
            var next = current + n
            if rect.has_point(next) and not exterior.has(next):
                # If not a wall (grid is true), it's part of the exterior
                if grid[next.y - rect.position.y][next.x - rect.position.x]:
                    exterior[next] = true
                    queue.append(next)
                    
    return exterior
    
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
