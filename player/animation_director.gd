class_name AnimationDirector
extends Node

@onready var body_sprite: AnimatedSprite2D = $"../Sprite/BodySprite"
@onready var presentation: PresentationComponent = $"../PresentationComponent"

var _current_anim := ""

func _ready() -> void:
	process_physics_priority = 10
	
func _physics_process(_delta):
	body_sprite.flip_h = presentation.flip_h

	if presentation.animation_name == _current_anim:
		return

	_current_anim = presentation.animation_name

	if _current_anim.begins_with("jump_"):
		body_sprite.play(_current_anim)
		body_sprite.frame = 0
		body_sprite.pause()
	else:
		body_sprite.play(_current_anim)
