extends CharacterBody2D

@export var projectile_scene: PackedScene
@export var fire_rate := 10

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var shooting_timer: Timer = $ShootingTimer

const max_speed := 132
const acceleration := 24
const friction := 32

var can_shoot := true

func _ready() -> void:
	shooting_timer.one_shot = true
	shooting_timer.timeout.connect(func(): can_shoot = true)
	
func _physics_process(delta: float) -> void:
	var input = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()
	
	if input:
		animation_player.play("walk")
		sprite_2d.flip_h = true if input.x < 0 else false
		animation_player.speed_scale = (velocity / max_speed).distance_to(Vector2.ZERO) + 0.5
	else:
		animation_player.play("idle")
		animation_player.speed_scale = 0.5
	
	var lerp_weight = delta * (acceleration if input else friction)
	velocity = lerp(velocity, input * max_speed, lerp_weight)
		
	move_and_slide()
	
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()

func shoot():
	if not projectile_scene:
		return
	
	can_shoot = false
	var projectile = projectile_scene.instantiate()
	
	var direction := (get_global_mouse_position() - global_position).normalized()
	
	projectile.global_position = global_position + direction * 16
	projectile.direction = direction
	projectile.rotation = direction.angle()
	
	get_tree().current_scene.add_child(projectile)
	
	shooting_timer.start(1.0 / fire_rate) 
