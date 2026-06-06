@tool
class_name TopWalls
extends TileMapLayer

@export_group("Map")
@export var map_width := 128
@export var map_height := 64

@export_group("Rooms")
@export var min_room_size := 6
@export var max_room_size := 6
@export var min_split_size := 10
@export var padding := 1
@export var corridor_width := 1

@export_group("Border")
@export var border_thickness := 12

@export_group("Gap Filling")
@export var max_gap_width := 6
@export var max_gap_height := 6

@export_group("Terrain")
@export var terrain_set := 0
@export var terrain := 0

@export_group("Seed")
@export var seed_value := 0

var grid=[]

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
		await ready   # waits until this node is ready

	clear()

	_init_grid()

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

	_draw()

	
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
	# true  = wall (dark striped)
	# false = walkable (white)

	# --- Pass 1: flood-fill small enclosed walkable regions ---
	var visited := []
	for y in range(map_height):
		visited.append([])
		for x in range(map_width):
			visited[y].append(false)

	for sy in range(map_height):
		for sx in range(map_width):
			if grid[sy][sx] or visited[sy][sx]:
				continue

			# flood-fill connected walkable region
			var region: Array[Vector2i] = []
			var region_set := {}
			var queue: Array[Vector2i] = [Vector2i(sx, sy)]
			visited[sy][sx] = true

			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				region.append(cell)
				region_set[cell] = true
				for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx: int = cell.x + dir.x
					var ny: int = cell.y + dir.y
					if nx < 0 or nx >= map_width or ny < 0 or ny >= map_height:
						continue
					if visited[ny][nx] or grid[ny][nx]:
						continue
					visited[ny][nx] = true
					queue.append(Vector2i(nx, ny))

			# bounding box check
			var min_x := region[0].x; var max_x := region[0].x
			var min_y := region[0].y; var max_y := region[0].y
			for cell in region:
				if cell.x < min_x: min_x = cell.x
				if cell.x > max_x: max_x = cell.x
				if cell.y < min_y: min_y = cell.y
				if cell.y > max_y: max_y = cell.y

			if max_x - min_x + 1 > max_gap_width or max_y - min_y + 1 > max_gap_height:
				continue

			# --- enclosure check via escape flood-fill ---
			var escape_queue: Array[Vector2i] = []
			var escape_visited := {}

			# start from region boundary
			for cell in region:
				for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx = cell.x + dir.x
					var ny = cell.y + dir.y

					if nx < 0 or nx >= map_width or ny < 0 or ny >= map_height:
						continue

					var n := Vector2i(nx, ny)

					# ONLY start from walkable cells not in region
					if not grid[ny][nx] and not escape_visited.has(n) and not region_set.has(n):
						escape_visited[n] = true
						escape_queue.append(n)

			var touches_border := false

			while not escape_queue.is_empty():
				var cell = escape_queue.pop_back()

				if cell.x == 0 or cell.y == 0 or cell.x == map_width-1 or cell.y == map_height-1:
					touches_border = true
					break

				for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx = cell.x + dir.x
					var ny = cell.y + dir.y

					if nx < 0 or nx >= map_width or ny < 0 or ny >= map_height:
						continue

					var n = Vector2i(nx, ny)

					if grid[ny][nx]:
						continue
					if escape_visited.has(n):
						continue
					if region_set.has(n):
						continue

					escape_visited[n] = true
					escape_queue.append(n)

			var fully_enclosed = not touches_border

			if fully_enclosed:
				for cell in region:
					grid[cell.y][cell.x] = true

	# --- Pass 2: fill 1-wide pinched dead-end walkable cells iteratively ---
	var changed := true

	while changed:
		changed = false

		for y in range(map_height):
			for x in range(map_width):

				if not grid[y][x]:
					continue # only process WALLS

				var floor_l = (x > 0 and not grid[y][x - 1])
				var floor_r = (x < map_width - 1 and not grid[y][x + 1])
				var floor_u = (y > 0 and not grid[y - 1][x])
				var floor_d = (y < map_height - 1 and not grid[y + 1][x])

				# horizontal gap: FLOOR WALL FLOOR
				if floor_l and floor_r:
					grid[y][x] = false
					changed = true
					continue

				# vertical gap: FLOOR / WALL / FLOOR
				if floor_u and floor_d:
					grid[y][x] = false
					changed = true
					continue


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
