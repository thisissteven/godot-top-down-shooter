# PlayerLight.gd
extends PointLight2D

func _ready() -> void:
	position = Vector2(0, -14)   # above feet, avoids adjacent occluders
	height = 20                  # lifts above floor-plane occluders
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
