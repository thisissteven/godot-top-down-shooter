extends StaticBody2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var detection_area: Area2D = $Area2D

func _ready() -> void:
	animation_player.play("close")
	animation_player.seek(animation_player.current_animation_length, true)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var current_pos = animation_player.current_animation_position
		var current_length = animation_player.current_animation_length
		# Play open but seek to the mirrored position of where close was
		animation_player.play("open")
		animation_player.seek(current_length - current_pos)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		var current_pos = animation_player.current_animation_position
		var current_length = animation_player.current_animation_length
		animation_player.play("close")
		animation_player.seek(current_length - current_pos)
