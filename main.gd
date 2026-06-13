extends Node2D


func _ready() -> void:
	pass
	## handle cleanup
	#var dungeon_generator = find_child("DungeonGenerator", false, false)
	#if is_instance_valid(dungeon_generator):
		#dungeon_generator.queue_free()
			#
	#var door_placer = find_child("DoorPlacer", false, false)
	#if is_instance_valid(door_placer):
		#door_placer.queue_free()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed('ui_accept'):
		$DungeonGenerator._generate()
