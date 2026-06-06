@tool
extends TopWalls

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

func _generate_editor():

	if !Engine.is_editor_hint():
		return

	if tile_set.get_terrain_sets_count()==0:
		push_error("Create terrain set first")
		return

	if seed_value==0:
		rng.randomize()
	else:
		rng.seed=seed_value

	generate()
