extends Node2D

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		$TopWalls.generate()
		
		$BottomWalls.top_wall_layer = $TopWalls
		await $BottomWalls.generate()
		
		$Tiles.top_wall_layer = $TopWalls
		await $Tiles.generate_floor()
	
