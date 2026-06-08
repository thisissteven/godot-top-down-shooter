extends Area2D

@export var speed := 250
@export var lifetime := 2

var direction := Vector2.RIGHT

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
func _process(delta: float) -> void:
	position += direction * speed * delta
	
func _on_body_entered(_body: Node) -> void:
	queue_free()
