@tool
extends WindowPlacer

@export_group("Run")
@export var run: bool:
	set(v):
		if v and Engine.is_editor_hint():
			generate()
