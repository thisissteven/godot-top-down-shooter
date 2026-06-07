@tool
class_name TopWalls
extends TileMapLayer

@export_group("Map")
@export var map_width := 128
@export var map_height := 64

@export_group("Rooms")
@export var min_room_size := 2
@export var max_room_size := 6
@export var min_split_size := 11
@export var padding := 1

@export_group("Border")
@export var border_thickness := 6

@export_group("Door Carving Size")
@export var horizontal_door_size := 1
@export var vertical_door_size := 2

@export_group("Terrain")
@export var terrain_set := 0
@export var terrain := 0

@export_group("Seed")
@export var seed_value := 0

var grid=[]
var door_gaps: Array = []

var rng := RandomNumberGenerator.new()
var initialized := false


func _ready():
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	initialized = true


class BSPNode:

	var rect:Rect2i
	var room:Rect2i
	var left:BSPNode
	var right:BSPNode
	var has_room:=false

	func _init(r):
		rect=r

	func is_leaf():
		return left==null and right==null
		

func generate():
	if !initialized:
		await ready

	clear()

	_init_grid()
	door_gaps = []

	var root=BSPNode.new(
		Rect2i(
			0,
			0,
			map_width,
			map_height
		)
	)

	_split(root)
	_place_rooms(root)
	_connect(root)
	
	_draw_outer_rectangle()
	_fill_gaps()
	_connect_regions()

	_draw()

func _compute_regions():
	var region_map = []
	for y in range(map_height):
		region_map.append([])
		for x in range(map_width):
			region_map[y].append(-1)

	var region_id = 0
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	for y in range(map_height):
		for x in range(map_width):

			if not grid[y][x]: # wall
				continue
			if region_map[y][x] != -1:
				continue

			var q = [Vector2i(x,y)]
			region_map[y][x] = region_id

			while not q.is_empty():
				var c = q.pop_back()

				for d in dirs:
					var nx = c.x + d.x
					var ny = c.y + d.y

					if nx < 0 or nx >= map_width or ny < 0 or ny >= map_height:
						continue

					if not grid[ny][nx]:
						continue

					if region_map[ny][nx] != -1:
						continue

					region_map[ny][nx] = region_id
					q.append(Vector2i(nx, ny))

			region_id += 1

	return {
		"map": region_map,
		"count": region_id
	}
	
	
func _collect_wall_edges(region_map):
	var edges = {}  # key: "a_b" → list of wall cells

	for y in range(map_height):
		for x in range(map_width):

			if grid[y][x]:
				continue  # only walls

			var neighbors = {}

			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nx = x + d.x
				var ny = y + d.y

				if nx < 0 or nx >= map_width or ny < 0 or ny >= map_height:
					continue

				if grid[ny][nx]:
					continue

				var r = region_map[ny][nx]
				if r != -1:
					neighbors[r] = true

			if neighbors.size() < 2:
				continue

			var keys = neighbors.keys()
			var a = keys[0]
			var b = keys[1]

			var key = str(min(a,b)) + "_" + str(max(a,b))

			if not edges.has(key):
				edges[key] = []

			edges[key].append(Vector2i(x,y))

	return edges


var parent: Array = []

func _find(a: int) -> int:
	if parent[a] != a:
		parent[a] = _find(parent[a])
	return parent[a]

func _union(a: int, b: int) -> void:
	parent[_find(a)] = _find(b)
	
	
func _connect_regions():

	var result = _compute_regions()
	var region_map = result["map"]
	var region_count = result["count"]

	parent = []
	for i in range(region_count):
		parent.append(i)

	var is_changed := true

	while is_changed:
		is_changed = false

		var best = null
		var best_score = INF

		for y in range(map_height):
			for x in range(map_width):

				# ONLY WALLS are candidates
				if grid[y][x] == true:
					continue

				var touching := {}

				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx = x + d.x
					var ny = y + d.y

					if nx < 0 or nx >= map_width or ny < 0 or ny >= map_height:
						continue

					# ONLY FLOORS contribute regions
					if grid[ny][nx] == false:
						continue

					var r = region_map[ny][nx]
					if r != -1:
						touching[r] = true

				if touching.size() < 2:
					continue

				var keys = touching.keys()
				var a = keys[0]
				var b = keys[1]

				if _find(a) == _find(b):
					continue

				# score: prefer shorter / more central connections
				var score = abs(x - map_width * 0.5) + abs(y - map_height * 0.5)

				if score < best_score:
					best_score = score
					best = {
						"a": a,
						"b": b,
						"pos": Vector2i(x, y)
					}

		if best != null:
			var p = best.pos

			var dirs = [
				Vector2i(1, 0),
				Vector2i(-1, 0),
				Vector2i(0, 1),
				Vector2i(0, -1)
			]

			for d in dirs:

				var p2 = p + d

				if p2.x < 0 or p2.x >= map_width or p2.y < 0 or p2.y >= map_height:
					continue

				if grid[p.y][p.x] == true or grid[p2.y][p2.x] == true:
					continue

				# strip validity
				var horizontal = (d.x != 0)

				var p_up = (p.y > 0 and grid[p.y - 1][p.x] == false)
				var p_down = (p.y < map_height - 1 and grid[p.y + 1][p.x] == false)
				var p_left = (p.x > 0 and grid[p.y][p.x - 1] == false)
				var p_right = (p.x < map_width - 1 and grid[p.y][p.x + 1] == false)

				var p2_up = (p2.y > 0 and grid[p2.y - 1][p2.x] == false)
				var p2_down = (p2.y < map_height - 1 and grid[p2.y + 1][p2.x] == false)
				var p2_left = (p2.x > 0 and grid[p2.y][p2.x - 1] == false)
				var p2_right = (p2.x < map_width - 1 and grid[p2.y][p2.x + 1] == false)

				if horizontal:
					if p_up or p_down or p2_up or p2_down:
						continue
				else:
					if p_left or p_right or p2_left or p2_right:
						continue

				var size = 1
				if d.x != 0:
					size = horizontal_door_size
				else:
					size = vertical_door_size


				# ---------- PRECHECK FULL SEGMENT ----------
				var cells = []
				var valid = true

				for i in range(size):
					var c = p + d * i

					if c.x < 0 or c.x >= map_width or c.y < 0 or c.y >= map_height:
						valid = false
						break

					# must still be wall
					if grid[c.y][c.x] == true:
						valid = false
						break

					# 🚨 STRIP VALIDATION (prevents 5x5 contamination)
					var up = (c.y > 0 and grid[c.y - 1][c.x] == false)
					var down = (c.y < map_height - 1 and grid[c.y + 1][c.x] == false)
					var left = (c.x > 0 and grid[c.y][c.x - 1] == false)
					var right = (c.x < map_width - 1 and grid[c.y][c.x + 1] == false)

					if d.x != 0:
						# horizontal strip → must NOT have vertical branching
						if up or down:
							valid = false
							break
					else:
						# vertical strip → must NOT have horizontal branching
						if left or right:
							valid = false
							break

					cells.append(c)

				# ---------- APPLY ONLY IF VALID ----------
				if valid:
					for c in cells:
						grid[c.y][c.x] = true
						
					# Record the door gap for DoorPlacer
					door_gaps.append({
						"cells": cells.duplicate(),
						"type": "horizontal" if d.x != 0 else "vertical"
					})

					_union(best.a, best.b)
					is_changed = true
					break
						
										
func _draw_outer_rectangle():

	for t in range(border_thickness):

		# Top and bottom
		for x in range(map_width):
			grid[t][x] = false
			grid[map_height - 1 - t][x] = false

		# Left and right
		for y in range(map_height):
			grid[y][t] = false
			grid[y][map_width - 1 - t] = false
		
		
func _init_grid():

	grid = []

	for y in range(map_height):
		grid.append([])

		for x in range(map_width):
			grid[y].append(true)



func _split(node):

	var w=node.rect.size.x
	var h=node.rect.size.y

	var can_h=h>=min_split_size*2
	var can_v=w>=min_split_size*2

	if !can_h and !can_v:
		return

	var split_h

	if can_h and can_v:
		split_h=h>w
	else:
		split_h=can_h


	if split_h:

		var split_y=rng.randi_range(
			node.rect.position.y+min_split_size,
			node.rect.end.y-min_split_size
		)

		node.left=BSPNode.new(
			Rect2i(
				node.rect.position,
				Vector2i(
					w,
					split_y-node.rect.position.y
				)
			)
		)

		node.right=BSPNode.new(
			Rect2i(
				Vector2i(
					node.rect.position.x,
					split_y
				),
				Vector2i(
					w,
					node.rect.end.y-split_y
				)
			)
		)

	else:

		var split_x=rng.randi_range(
			node.rect.position.x+min_split_size,
			node.rect.end.x-min_split_size
		)

		node.left=BSPNode.new(
			Rect2i(
				node.rect.position,
				Vector2i(
					split_x-node.rect.position.x,
					h
				)
			)
		)

		node.right=BSPNode.new(
			Rect2i(
				Vector2i(
					split_x,
					node.rect.position.y
				),
				Vector2i(
					node.rect.end.x-split_x,
					h
				)
			)
		)

	_split(node.left)
	_split(node.right)



func _place_rooms(node):

	if node==null:
		return

	if node.is_leaf():

		var max_w=min(
			max_room_size,
			node.rect.size.x-padding*2
		)

		var max_h=min(
			max_room_size,
			node.rect.size.y-padding*2
		)

		if max_w<min_room_size:
			return

		if max_h<min_room_size:
			return

		var rw=rng.randi_range(
			min_room_size,
			max_w
		)

		var rh=rng.randi_range(
			min_room_size,
			max_h
		)

		var rx=rng.randi_range(
			node.rect.position.x+padding,
			node.rect.end.x-rw-padding
		)

		var ry=rng.randi_range(
			node.rect.position.y+padding,
			node.rect.end.y-rh-padding
		)

		node.room=Rect2i(
			rx,
			ry,
			rw,
			rh
		)

		node.has_room=true

		for y in range(ry,ry+rh):
			for x in range(rx,rx+rw):
				grid[y][x]=false

	else:

		_place_rooms(node.left)
		_place_rooms(node.right)



func _connect(node):

	if node==null or node.is_leaf():
		return

	_connect(node.left)
	_connect(node.right)

	var a=_find_room(node.left)
	var b=_find_room(node.right)

	if a.x<0 or b.x<0:
		return

	for x in range(min(a.x,b.x),max(a.x,b.x)+1):
		grid[a.y][x]=false

	for y in range(min(a.y,b.y),max(a.y,b.y)+1):
		grid[y][b.x]=false



func _find_room(node):

	if node==null:
		return Vector2i(-1,-1)

	if node.has_room:
		return node.room.get_center()

	var c=_find_room(node.left)

	if c.x>=0:
		return c

	return _find_room(node.right)



func _fill_gaps():
	# true  = wall
	# false = floor

	var is_changed := true
	var safety_passes := 0
	var max_passes := 3  # prevents over-erosion

	while is_changed and safety_passes < max_passes:
		is_changed = false
		safety_passes += 1

		var to_remove: Array[Vector2i] = []

		for y in range(map_height):
			for x in range(map_width):

				if not grid[y][x]:
					continue  # only check WALLS

				var floor_l = (x > 0 and not grid[y][x - 1])
				var floor_r = (x < map_width - 1 and not grid[y][x + 1])
				var floor_u = (y > 0 and not grid[y - 1][x])
				var floor_d = (y < map_height - 1 and not grid[y + 1][x])

				# count how many sides are floor
				var floor_count = 0
				if floor_l: floor_count += 1
				if floor_r: floor_count += 1
				if floor_u: floor_count += 1
				if floor_d: floor_count += 1

				# -------------------------------
				# SAFE REMOVAL RULES
				# -------------------------------

				# Case 1: thin horizontal noise wall
				if floor_l and floor_r and floor_count >= 2:
					to_remove.append(Vector2i(x, y))
					continue

				# Case 2: thin vertical noise wall
				if floor_u and floor_d and floor_count >= 2:
					to_remove.append(Vector2i(x, y))
					continue

		# apply removals AFTER scan (important!)
		for cell in to_remove:
			grid[cell.y][cell.x] = false
			is_changed = true
func _draw():
	if grid.is_empty():
		return

	var floor_cells:Array[Vector2i] = []

	for y in range(map_height):
		for x in range(map_width):

			if !grid[y][x]:
				floor_cells.append(
					Vector2i(x,y)
				)

	set_cells_terrain_connect(
		floor_cells,
		terrain_set,
		terrain
	)
