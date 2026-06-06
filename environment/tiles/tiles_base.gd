@tool
class_name TilesBase
extends TileMapLayer

@export var top_wall_layer: TileMapLayer

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
var main_floor_chance := 0.9

@export var seed_value := 0

var rng := RandomNumberGenerator.new()
var initialized := false


func _ready():
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	initialized = true


func generate_floor():

	if !initialized:
		await ready

	if top_wall_layer == null:
		push_error("Top wall layer missing")
		return

	clear()

	var rect = top_wall_layer.get_used_rect()

	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):

			var cell = Vector2i(x,y)

			# Skip walls
			if top_wall_layer.get_cell_source_id(cell) != -1:
				continue

			var tile = _pick_floor_tile()

			set_cell(
				cell,
				source_id,
				tile
			)

	notify_runtime_tile_data_update()

	print("Floor generation complete")


func _pick_floor_tile():

	if rng.randf() <= main_floor_chance:
		return floor_tiles[0]

	return floor_tiles[
		rng.randi_range(
			1,
			floor_tiles.size() - 1
		)
	]
