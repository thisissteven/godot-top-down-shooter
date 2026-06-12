## GunComponent.gd
## Attach to a Node2D child of any entity that can shoot.
## Reads all configuration from a GunData resource assigned in the inspector.
##
## Typical scene tree:
##   Player (CharacterBody2D)
##   └─ GunPivot (Node2D)          ← rotated by AimComponent
##      └─ GunComponent (Node2D)   ← this script
##         ├─ MuzzlePoint (Marker2D)
##         ├─ AudioStreamPlayer2D
##         └─ Sprite2D  (gun art)

class_name GunComponent
extends Node2D

# ── Signals ───────────────────────────────────────────────────────────────────

signal fired(muzzle_position: Vector2, direction: Vector2)
signal empty_clicked()
signal reload_started(duration_sec: float)
signal reload_finished()
signal ammo_changed(current_mag: int, current_reserve: int)

# ── Inspector exports ─────────────────────────────────────────────────────────

@export var gun_data: GunData
@export var muzzle_point: Marker2D
@export var auto_reload: bool = true
@export var projectile_parent: Node

# ── State ─────────────────────────────────────────────────────────────────────

var current_magazine: int = 0
var current_reserve: int = 0

var _fire_cooldown: float = 0.0
var _is_reloading: bool = false
var _audio: AudioStreamPlayer2D

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	assert(gun_data != null, "GunComponent: gun_data must be assigned.")
	_audio = AudioStreamPlayer2D.new()
	add_child(_audio)
	_audio.bus = &"SFX"
	_load_gun_data()


func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta


# ── Public API ────────────────────────────────────────────────────────────────

func try_fire_dir(direction: Vector2, _held: bool = false) -> void:
	if _is_reloading or _fire_cooldown > 0.0:
		return
	if current_magazine <= 0:
		_on_empty_trigger()
		return
	_begin_fire_sequence(direction)
	
func try_fire_pos(target_pos: Vector2, _held: bool = false) -> void:
	if _is_reloading or _fire_cooldown > 0.0:
		return
	if current_magazine <= 0:
		_on_empty_trigger()
		return
	var direction := (target_pos - _get_muzzle_position()).normalized()
	_begin_fire_sequence(direction)


func reload() -> void:
	if _is_reloading or current_reserve == 0:
		return
	if current_magazine == gun_data.magazine_size:
		return
	_start_reload()


func set_gun_data(data: GunData, reset_ammo: bool = false) -> void:
	gun_data = data
	_load_gun_data(reset_ammo)


func can_fire() -> bool:
	return not _is_reloading and _fire_cooldown <= 0.0 and current_magazine > 0


# ── Internal — firing ─────────────────────────────────────────────────────────

func _begin_fire_sequence(direction: Vector2) -> void:
	_fire_cooldown = 1.0 / gun_data.fire_rate
	_fire_shot(direction)


func _fire_shot(direction: Vector2) -> void:
	if current_magazine <= 0:
		return

	var spawn_pos := _get_muzzle_position()

	for i in gun_data.pellets_per_shot:
		_spawn_projectile(spawn_pos, _apply_spread(direction))

	current_magazine -= 1
	_play_fire_sound()
	_spawn_muzzle_flash(spawn_pos)
	fired.emit(spawn_pos, direction)
	ammo_changed.emit(current_magazine, current_reserve)

	if current_magazine <= 0 and auto_reload:
		_start_reload()


func _apply_spread(direction: Vector2) -> Vector2:
	if gun_data.spread_degrees == 0.0:
		return direction
	var half_rad := deg_to_rad(gun_data.spread_degrees)
	return direction.rotated(randf_range(-half_rad, half_rad))


func _spawn_projectile(pos: Vector2, direction: Vector2) -> void:
	if gun_data.projectile_scene == null:
		push_warning("GunComponent: projectile_scene is not set in GunData.")
		return
	var parent := projectile_parent if projectile_parent else get_tree().current_scene
	var projectile: Node2D = gun_data.projectile_scene.instantiate()
	projectile.global_position = pos
	if projectile.has_method(&"set_direction"):
		projectile.set_direction(direction)
	else:
		projectile.rotation = direction.angle()

	parent.add_child(projectile)

# ── Internal — empty / reload ─────────────────────────────────────────────────

func _on_empty_trigger() -> void:
	_play_sound(gun_data.empty_click_sound)
	empty_clicked.emit()
	if auto_reload and current_reserve != 0:
		_start_reload()


func _start_reload() -> void:
	_is_reloading = true
	_play_sound(gun_data.reload_sound)
	reload_started.emit(gun_data.reload_time)
	get_tree().create_timer(gun_data.reload_time).timeout.connect(_finish_reload)


func _finish_reload() -> void:
	var needed := gun_data.magazine_size - current_magazine
	if current_reserve == -1:
		current_magazine = gun_data.magazine_size
	else:
		var drawn := mini(needed, current_reserve)
		current_magazine += drawn
		current_reserve -= drawn
	_is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(current_magazine, current_reserve)


# ── Internal — helpers ────────────────────────────────────────────────────────

func _load_gun_data(reset_ammo: bool = true) -> void:
	if reset_ammo:
		current_magazine = gun_data.magazine_size
		current_reserve = gun_data.reserve_ammo
	_fire_cooldown = 0.0
	_is_reloading = false
	ammo_changed.emit(current_magazine, current_reserve)


func _get_muzzle_position() -> Vector2:
	return muzzle_point.global_position if muzzle_point else global_position


func _spawn_muzzle_flash(pos: Vector2) -> void:
	if gun_data.muzzle_flash_scene == null:
		return
	var flash: Node = gun_data.muzzle_flash_scene.instantiate()
	get_tree().current_scene.add_child(flash)
	if flash is Node2D:
		flash.global_position = pos


func _play_fire_sound() -> void:
	if gun_data.fire_sound == null:
		return
	_audio.stream = gun_data.fire_sound
	_audio.pitch_scale = 1.0 + randf_range(-gun_data.pitch_variance, gun_data.pitch_variance)
	_audio.play()


func _play_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	_audio.stream = stream
	_audio.pitch_scale = 1.0
	_audio.play()
