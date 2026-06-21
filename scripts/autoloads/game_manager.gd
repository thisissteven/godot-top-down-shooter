extends Node


var _game_world_ref  = null


func set_game_world(game_world ) -> void:
	_game_world_ref = game_world


func get_game_world():
	return _game_world_ref
