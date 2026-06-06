@tool
extends TilesBase

# Press in inspector to generate
@export var generate := false:
	set(value):
		if value:
			generate_floor()
			generate = false
