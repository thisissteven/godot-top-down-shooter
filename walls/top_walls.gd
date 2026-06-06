@tool
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
@export var seed := 0

# Buttons in inspector
@export var generate_now := false:
	set(value):
		if value:
			generate_now=false
			_generate_editor()

@export var clear_now := false:
	set(value):
		if value:
			clear_now=false
			clear()


var grid=[]
var rng:=RandomNumberGenerator.new()


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



func _ready():

	# Don't generate during game runtime
	if !Engine.is_editor_hint():
		return



func _generate_editor():

	if !Engine.is_editor_hint():
		return

	if tile_set.get_terrain_sets_count()==0:
		push_error("Create terrain set first")
		return

	if seed==0:
		rng.randomize()
	else:
		rng.seed=seed

	_generate()



func _generate():

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
	_fill_thin_gaps()

	_draw()


func _fill_thin_gaps():

	var visited := []

	# Initialize visited map
	for y in range(map_height):
		visited.append([])

		for x in range(map_width):
			visited[y].append(false)


	for y in range(map_height):
		for x in range(map_width):

			# Skip already checked cells
			if visited[y][x]:
				continue

			# We only care about walkable pockets
			if !grid[y][x]:
				continue

			var region := []
			var queue := [Vector2i(x, y)]

			visited[y][x] = true

			var min_x = x
			var max_x = x
			var min_y = y
			var max_y = y

			# Flood fill connected area
			while queue.size() > 0:

				var p = queue.pop_front()

				region.append(p)

				min_x = min(min_x, p.x)
				max_x = max(max_x, p.x)
				min_y = min(min_y, p.y)
				max_y = max(max_y, p.y)

				var dirs = [
					Vector2i(1,0),
					Vector2i(-1,0),
					Vector2i(0,1),
					Vector2i(0,-1)
				]

				for d in dirs:

					var nx = p.x + d.x
					var ny = p.y + d.y

					if nx < 0 \
					or nx >= map_width \
					or ny < 0 \
					or ny >= map_height:
						continue

					if visited[ny][nx]:
						continue

					if !grid[ny][nx]:
						continue

					visited[ny][nx] = true
					queue.append(Vector2i(nx, ny))


			# Bounding dimensions
			var w = max_x - min_x + 1
			var h = max_y - min_y + 1

			# Fill if within limits
			if w <= max_gap_width and h <= max_gap_height:

				for p in region:
					grid[p.y][p.x] = false
					
					
			
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

	grid=[]

	for y in map_height:

		grid.append([])

		for x in map_width:

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



func _draw():

	var floor_cells:Array[Vector2i]=[]

	for y in map_height:
		for x in map_width:

			if !grid[y][x]:
				floor_cells.append(
					Vector2i(x,y)
				)

	set_cells_terrain_connect(
		floor_cells,
		terrain_set,
		terrain
	)
