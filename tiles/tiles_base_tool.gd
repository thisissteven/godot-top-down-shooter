@tool
extends TileMapLayer

@export var top_wall_layer: TileMapLayer

# TileSet source ID
@export var source_id := 0

# Atlas coordinates of the 8 floor tiles
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
var main_floor_chance := 0.9

@export var seed_value := 0

# Press in inspector to generate
@export var generate := false:
	set(value):
		if value:
			generate_floor()
			generate = false


func generate_floor():

	if !Engine.is_editor_hint():
		return

	if top_wall_layer == null:
		push_error("Top wall layer missing")
		return

	clear()

	var rng := RandomNumberGenerator.new()
	
	if seed_value==0:
		rng.randomize()
	else:
		rng.seed=seed_value

	var rect = top_wall_layer.get_used_rect()

	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):

			var cell = Vector2i(x,y)

			# Skip wall cells
			if top_wall_layer.get_cell_source_id(cell) != -1:
				continue

			var tile = pick_floor_tile(rng)

			set_cell(
				cell,
				source_id,
				tile
			)

	notify_runtime_tile_data_update()

	print("Floor generation complete")


func pick_floor_tile(rng: RandomNumberGenerator):

	if rng.randf() <= main_floor_chance:
		return floor_tiles[0]

	return floor_tiles[
		rng.randi_range(1, floor_tiles.size()-1)
	]
