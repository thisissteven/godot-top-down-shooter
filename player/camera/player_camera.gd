extends Camera2D

@export var target: Node2D
@export var follow_speed := 16

func _ready() -> void:
	if target == null:
		return
		
	position = target.position

func _process(delta):
	if target == null:
		return

	position = position.lerp(
		target.position,
		follow_speed * delta
	)
