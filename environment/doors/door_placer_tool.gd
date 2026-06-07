@tool
extends DoorPlacer

@export var run: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			generate()
		run = false
