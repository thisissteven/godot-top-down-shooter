@tool
extends TilesBase

# Press in inspector to generate
@export var is_generated := false:
	set(value):
		if value:
			generate()
			is_generated = false
