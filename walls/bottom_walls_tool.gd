@tool
extends BottomWalls

@export var generate_now := false:
	set(v):
		if v:
			generate_now = false
			generate()
