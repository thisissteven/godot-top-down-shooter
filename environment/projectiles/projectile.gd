## Projectile.gd
## Root script for the Projectile.tscn scene that GunComponent spawns.
##
## Scene tree:
##   Projectile (Area2D)       ← this script
##   ├─ CollisionShape2D       (small circle or capsule)
##   ├─ Sprite2D / GPUParticles2D
##   └─ VisibleOnScreenNotifier2D   (optional — for off-screen culling)
##
## GunComponent calls set_direction() immediately after instantiating.
## All configuration is read from a ProjectileData resource.

class_name Projectile
extends Area2D

# ── Signals ───────────────────────────────────────────────────────────────────

signal hit_target(target: Node2D, position: Vector2)
signal expired()

# ── Exports ───────────────────────────────────────────────────────────────────

@export var speed: float = 900.0
@export var lifetime: float = 2.5
@export var damage: float = 12.0
@export var knockback_force: float = 200.0
@export var pierce_count: int = 0         ## 0 = destroyed on first hit
@export var homing_strength: float = 0.0  ## 0 = straight, >0 = seeks nearest enemy

## Tag of entities this projectile can damage. Compared against FactionComponent.
@export var target_faction: StringName = &"enemy"

## VFX scene instantiated at the impact point.
@export var hit_effect_scene: PackedScene

# ── State ─────────────────────────────────────────────────────────────────────

var _direction: Vector2 = Vector2.RIGHT
var _lifetime_remaining: float = 0.0
var _pierce_remaining: int = 0
var _homing_target: Node2D = null
var _already_hit: Array[Node] = []   # prevent double-hitting same target


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_lifetime_remaining = lifetime
	_pierce_remaining = pierce_count
	rotation = _direction.angle()

	# Connect area detection.
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		_expire()
		return

	if homing_strength > 0.0:
		_tick_homing(delta)

	var move := _direction * speed * delta
	_check_raycast(move)
	position += move

func _check_raycast(move: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + move
	)
	query.exclude = [self]
	query.collision_mask = collision_mask  # reuse the Area2D's own mask
	
	var result := space.intersect_ray(query)
	if result:
		var body = result.collider
		if body.is_in_group(&"wall"):
			position = result.position
			_spawn_hit_effect(result.position)
			_expire()


# ── Public API ────────────────────────────────────────────────────────────────

## Called by GunComponent immediately after instantiation.
func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()
	rotation = _direction.angle()


# ── Internal ──────────────────────────────────────────────────────────────────

func _on_area_entered(area: Area2D) -> void:
	# HitboxComponent should be an Area2D; check faction tag before applying damage.
	if area in _already_hit:
		return
	var owner_node := area.get_parent()
	if not _is_valid_target(owner_node):
		return
	_deal_damage(owner_node, area)


func _on_body_entered(body: Node2D) -> void:
	# Handle solid walls / TileMap collision.
	if body.is_in_group(&"wall"):
		_expire()


func _is_valid_target(node: Node) -> bool:
	# Look for a FactionComponent to check allegiance.
	var fc := node.get_node_or_null("FactionComponent")
	if fc == null:
		return false
	return fc.faction == target_faction


func _deal_damage(target: Node2D, hitbox: Area2D) -> void:
	_already_hit.append(hitbox)

	# Route damage through the target's HealthComponent if it has one.
	var health: Node = target.get_node_or_null("HealthComponent")
	if health and health.has_method(&"take_damage"):
		health.take_damage(damage, self)

	# Apply knockback via KnockbackComponent if present.
	var kb: Node = target.get_node_or_null("KnockbackComponent")
	if kb and kb.has_method(&"apply_knockback"):
		kb.apply_knockback(_direction * knockback_force)

	_spawn_hit_effect(global_position)
	hit_target.emit(target, global_position)

	if _pierce_remaining <= 0:
		_expire()
	else:
		_pierce_remaining -= 1


func _tick_homing(delta: float) -> void:
	if not is_instance_valid(_homing_target):
		_homing_target = _find_nearest_enemy()
	if not is_instance_valid(_homing_target):
		return

	var desired := (_homing_target.global_position - global_position).normalized()
	_direction = _direction.lerp(desired, homing_strength * delta).normalized()
	rotation = _direction.angle()


func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(target_faction):
		if node is Node2D:
			var d := global_position.distance_squared_to(node.global_position)
			if d < best_dist:
				best_dist = d
				best = node
	return best


func _spawn_hit_effect(pos: Vector2) -> void:
	if hit_effect_scene == null:
		return
	var fx: Node = hit_effect_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx is Node2D:
		fx.global_position = pos


func _expire() -> void:
	expired.emit()
	queue_free()
