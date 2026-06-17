@tool
extends Node2D

# ─────────────────────────────────────────────
#  Exports
# ─────────────────────────────────────────────

@export var tilemap: TileMapLayer

@export var room_count: int = 16

@export var width_min:  int = 3
@export var width_max:  int = 8
@export var height_min: int = 6
@export var height_max: int = 12

@export var terrain_set: int = 0
@export var terrain:     int = 0

## Max width:height (or height:width) ratio of the whole map bounding box.
@export var max_aspect_ratio: float = 2.0

## Fraction of the shorter shared edge that must overlap for a placement to be valid.
@export var min_overlap_fraction: float = 0.5

## How often the placer picks the side that corrects toward a square map.
## 0 = random sides, 1 = always corrects.
@export_range(0.0, 1.0) var aspect_bias: float = 0.75

@export var generate: bool = false :
	set(v):
		generate = false
		if Engine.is_editor_hint():
			run_generation()


# ─────────────────────────────────────────────
#  Room record
# ─────────────────────────────────────────────

class Room:
	var x: int
	var y: int
	var w: int
	var h: int

	func _init(px: int, py: int, pw: int, ph: int) -> void:
		x = px; y = py; w = pw; h = ph

	func right()  -> int: return x + w - 1
	func bottom() -> int: return y + h - 1


# ─────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────

func run_generation() -> void:
	if tilemap == null:
		push_error("MapGenerator: 'tilemap' is not set.")
		return

	tilemap.clear()

	var rooms: Array[Room] = _create_rooms()
	_place_rooms(rooms)

	# Collect wall cells, carve MST connections, then paint.
	var wall_cells: Dictionary = _collect_wall_cells(rooms)
	
	var adjacency_edges := _force_make_adjacency(rooms)
	_carve_forced_adjacency(adjacency_edges, wall_cells)
	
	var hubs := _build_wall_hubs(rooms)
	var segments := _dedupe_segments(hubs)
	_carve_wall_hubs(segments, wall_cells)

	var cell_array: Array[Vector2i] = []
	cell_array.assign(wall_cells.keys())
	tilemap.set_cells_terrain_connect(cell_array, terrain_set, terrain)

	print("MapGenerator: placed %d rooms." % rooms.size())

func _build_wall_hubs(rooms: Array[Room]) -> Array:
	var hubs := []

	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var a := rooms[i]
			var b := rooms[j]

			var seg = _get_shared_band(a, b)
			if seg == null:
				continue

			hubs.append({
				"rooms": [i, j],
				"seg": seg
			})

	return hubs

func _get_shared_band(a: Room, b: Room):
	if a.right() == b.x or b.right() == a.x:
		var x := a.right() if (a.right() == b.x) else b.right()

		var y0 := maxi(a.y, b.y)
		var y1 := mini(a.bottom(), b.bottom())

		if y1 < y0:
			return null

		return { "axis": "col", "coord": x, "start": y0, "end": y1 }

	if a.bottom() == b.y or b.bottom() == a.y:
		var y :=  a.bottom() if (a.bottom() == b.y) else b.bottom()

		var x0 := maxi(a.x, b.x)
		var x1 := mini(a.right(), b.right())

		if x1 < x0:
			return null

		return { "axis": "row", "coord": y, "start": x0, "end": x1 }

	return null

func _dedupe_segments(hubs: Array) -> Array:
	var seen := {}
	var result := []

	for h in hubs:
		var s = h["seg"]

		var key := str(s["axis"]) + "_" + str(s["coord"]) + "_" + str(s["start"]) + "_" + str(s["end"])
		if seen.has(key):
			continue

		seen[key] = true
		result.append(s)

	return result

func _carve_wall_hubs(segments: Array, wall_cells: Dictionary) -> void:
	for s in segments:
		var center = (s["start"] + s["end"]) / 2

		if s["axis"] == "col":
			wall_cells.erase(Vector2i(s["coord"], center))
		else:
			wall_cells.erase(Vector2i(center, s["coord"]))
				
func _force_make_adjacency(rooms: Array[Room]) -> Array:
	var edges: Array = []

	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var a := rooms[i]
			var b := rooms[j]

			var edge = _detect_soft_adjacency(a, b)
			if edge != null:
				edges.append(edge)

	return edges

func _detect_soft_adjacency(a: Room, b: Room):
	# horizontal gap (east-west)
	var gap_x = min(abs(a.right() - b.x), abs(b.right() - a.x))

	# vertical gap (north-south)
	var gap_y = min(abs(a.bottom() - b.y), abs(b.bottom() - a.y))

	# allow 0 (touching) OR 1 (1-wall gap) OR 2 (your broken case)
	var max_gap := 2

	# EAST/WEST
	if gap_x <= max_gap:
		var overlap_top := maxi(a.y, b.y)
		var overlap_bottom := mini(a.bottom(), b.bottom())
		if overlap_bottom < overlap_top:
			return null

		return {
			"axis": "col",
			"coord": (a.right() + 1) if (a.right() < b.x) else (b.right() + 1),
			"seg_start": overlap_top,
			"seg_end": overlap_bottom
		}

	# NORTH/SOUTH
	if gap_y <= max_gap:
		var overlap_left := maxi(a.x, b.x)
		var overlap_right := mini(a.right(), b.right())
		if overlap_right < overlap_left:
			return null

		return {
			"axis": "row",
			"coord":  (a.bottom() + 1) if (a.bottom() < b.y) else (b.bottom() + 1),
			"seg_start": overlap_left,
			"seg_end": overlap_right
		}

	return null

func _carve_forced_adjacency(edges: Array, wall_cells: Dictionary) -> void:
	for e in edges:
		_carve_one_tile(wall_cells, e)
		
# ─────────────────────────────────────────────
#  Step 1 — generate room sizes
# ─────────────────────────────────────────────

func _create_rooms() -> Array[Room]:
	var rooms: Array[Room] = []
	for _i in room_count:
		var w := randi_range(width_min, width_max)
		var h := randi_range(height_min, height_max)
		rooms.append(Room.new(0, 0, w, h))
	return rooms


# ─────────────────────────────────────────────
#  Step 2 — place rooms (V1 logic + aspect bias + snap)
# ─────────────────────────────────────────────

const ALL_SIDES := ["north", "south", "east", "west"]
const INVALID   := Vector2i(-999999, -999999)

func _place_rooms(rooms: Array[Room]) -> void:
	if rooms.is_empty():
		return

	rooms[0].x = 0
	rooms[0].y = 0
	var placed: Array[Room] = [rooms[0]]

	for i in range(1, rooms.size()):
		var room := rooms[i]
		var placed_ok := false

		for _attempt in range(400):
			var bb   := _bounding_box(placed)
			var bb_w := float(bb.size.x)
			var bb_h := float(bb.size.y)

			# ── Candidate parents: remove the farthest room along the over-extended axis ──
			var candidates: Array[Room] = placed.duplicate()
			if bb_w > 0 and bb_h > 0:
				if bb_w / bb_h > max_aspect_ratio:
					var fx := _farthest(placed, "right")
					candidates = candidates.filter(func(r): return r != fx)
				elif bb_h / bb_w > max_aspect_ratio:
					var fy := _farthest(placed, "bottom")
					candidates = candidates.filter(func(r): return r != fy)
			if candidates.is_empty():
				candidates = placed.duplicate()

			# ── Pick a side biased toward correcting the aspect ratio ──
			var side := _pick_side(room, bb_w, bb_h)

			# ── Multi-snap: score every candidate by neighbor count, pick best ──
			var best_parent: Room    = null
			var best_pos:    Vector2i = INVALID
			var best_score:  int     = -1

			candidates.shuffle()   # randomise tie-breaking

			for parent in candidates:
				var pos := _compute_position(room, parent, side)
				if pos == INVALID:
					continue

				# Quick collision test
				var old_x := room.x; var old_y := room.y
				room.x = pos.x; room.y = pos.y
				var collides := false
				for other in placed:
					if _rooms_overlap(room, other):
						collides = true
						break
				if collides:
					room.x = old_x; room.y = old_y
					continue

				# Score = number of placed rooms this position is adjacent to
				var score := 0
				for other in placed:
					if _rooms_adjacent(room, other):
						score += 1

				room.x = old_x; room.y = old_y

				if score > best_score:
					best_score  = score
					best_parent = parent
					best_pos    = pos

			if best_parent != null:
				room.x = best_pos.x
				room.y = best_pos.y
				placed.append(room)
				placed_ok = true
				break

		if not placed_ok:
			push_warning("MapGenerator: could not place room %d after 400 attempts." % i)


# Pick a side biased toward keeping the map square.
# Wide rooms prefer N/S, tall rooms prefer E/W.
func _pick_side(room: Room, bb_w: float, bb_h: float) -> String:
	if randf() >= aspect_bias:
		return ALL_SIDES[randi() % ALL_SIDES.size()]

	var map_wide  := bb_w >= bb_h
	var room_wide := room.w >= room.h

	if map_wide and room_wide:
		return "north" if randi() % 2 == 0 else "south"
	if not map_wide and not room_wide:
		return "east"  if randi() % 2 == 0 else "west"
	return ALL_SIDES[randi() % ALL_SIDES.size()]


# Compute where `room` goes when placed on `side` of `parent`.
# Free axis snaps flush to parent's leading edge; falls back to center.
func _compute_position(room: Room, parent: Room, side: String) -> Vector2i:
	var rx: int
	var ry: int

	match side:
		"east":
			rx = parent.right()
			var min_ov := ceili(mini(room.h, parent.h) * min_overlap_fraction)
			var lo := parent.bottom() - room.h + min_ov
			var hi := parent.y + parent.h - min_ov
			if lo > hi: return INVALID
			ry = _snap_axis(parent.y, lo, hi)

		"west":
			rx = parent.x - room.w + 1
			var min_ov := ceili(mini(room.h, parent.h) * min_overlap_fraction)
			var lo := parent.bottom() - room.h + min_ov
			var hi := parent.y + parent.h - min_ov
			if lo > hi: return INVALID
			ry = _snap_axis(parent.y, lo, hi)

		"south":
			ry = parent.bottom()
			var min_ov := ceili(mini(room.w, parent.w) * min_overlap_fraction)
			var lo := parent.right() - room.w + min_ov
			var hi := parent.x + parent.w - min_ov
			if lo > hi: return INVALID
			rx = _snap_axis(parent.x, lo, hi)

		"north":
			ry = parent.y - room.h + 1
			var min_ov := ceili(mini(room.w, parent.w) * min_overlap_fraction)
			var lo := parent.right() - room.w + min_ov
			var hi := parent.x + parent.w - min_ov
			if lo > hi: return INVALID
			rx = _snap_axis(parent.x, lo, hi)

		_:
			return INVALID

	return Vector2i(rx, ry)


# Prefer flush with parent_start; fall back to center of [lo, hi].
func _snap_axis(parent_start: int, lo: int, hi: int) -> int:
	if parent_start >= lo and parent_start <= hi:
		return parent_start
	return (lo + hi) / 2


# ─────────────────────────────────────────────
#  Step 3 — collect wall cells
# ─────────────────────────────────────────────

func _collect_wall_cells(rooms: Array[Room]) -> Dictionary:
	var cells: Dictionary = {}
	for room in rooms:
		for col in range(room.x, room.x + room.w):
			cells[Vector2i(col, room.y)]        = true
			cells[Vector2i(col, room.bottom())] = true
		for row in range(room.y + 1, room.bottom()):
			cells[Vector2i(room.x,       row)] = true
			cells[Vector2i(room.right(), row)] = true
	return cells


# Carve the single center tile of the shared wall segment.
func _carve_one_tile(wall_cells: Dictionary, info: Dictionary) -> void:
	var coord:     int = info["coord"]
	var seg_start: int = info["seg_start"]
	var seg_end:   int = info["seg_end"]
	var center:    int = (seg_start + seg_end) / 2

	if info["axis"] == "col":
		wall_cells.erase(Vector2i(coord, center))
	else:
		wall_cells.erase(Vector2i(center, coord))




# ─────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────

func _bounding_box(rooms: Array[Room]) -> Rect2i:
	if rooms.is_empty():
		return Rect2i()
	var min_x := rooms[0].x;      var min_y := rooms[0].y
	var max_x := rooms[0].right(); var max_y := rooms[0].bottom()
	for r in rooms:
		min_x = mini(min_x, r.x);      min_y = mini(min_y, r.y)
		max_x = maxi(max_x, r.right()); max_y = maxi(max_y, r.bottom())
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _farthest(rooms: Array[Room], axis: String) -> Room:
	var best: Room = rooms[0]
	for r in rooms:
		if axis == "right"  and r.right()  > best.right():  best = r
		if axis == "bottom" and r.bottom() > best.bottom(): best = r
	return best


## Two rooms overlap (genuine collision) if they share more than one
## wall column/row — i.e. both axes have overlap > 1 tile.
func _rooms_overlap(a: Room, b: Room) -> bool:
	var ox := mini(a.right(), b.right()) - maxi(a.x, b.x) + 1
	var oy := mini(a.bottom(), b.bottom()) - maxi(a.y, b.y) + 1
	return ox > 1 and oy > 1


## Two rooms are adjacent if they share exactly one wall column or row
## with at least one tile of overlap.
func _rooms_adjacent(a: Room, b: Room) -> bool:
	var ox := mini(a.right(), b.right()) - maxi(a.x, b.x) + 1
	var oy := mini(a.bottom(), b.bottom()) - maxi(a.y, b.y) + 1
	return (ox == 1 and oy >= 1) or (oy == 1 and ox >= 1)
