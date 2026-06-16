# EquipmentComponent.gd
class_name EquipmentComponent
extends Node

enum WeaponType { NONE, PISTOL, PLASMA }

signal weapon_changed(type: WeaponType)

# --- Inventory ---
@export var weapons: Array[PackedScene] = []        # fill in inspector for testing
@export var gun_pivot: NodePath                     # drag GunPivot here in inspector

# --- Arm textures (keep as-is for ArmController) ---
@export var arm_texture_pistol:       Texture2D
@export var arm_texture_plasma_front: Texture2D
@export var arm_texture_plasma_back:  Texture2D

var current_weapon: WeaponType = WeaponType.NONE
var current_index:  int        = -1
var _gun_pivot_node: Node2D

func _ready() -> void:
	_gun_pivot_node = get_node(gun_pivot)

# --- Public API ---

func cycle_weapon() -> void:
	if weapons.is_empty():
		return
	current_index = (current_index + 1) % weapons.size()
	_swap_to(current_index)

func equip_by_index(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	current_index = index
	_swap_to(index)

func unequip() -> void:
	_clear_gun_pivot()
	current_index = -1
	_set_weapon(WeaponType.NONE)
	
func get_current_gun() -> GunComponent:
	if _gun_pivot_node == null:
		return null
	for child in _gun_pivot_node.get_children():
		if child is GunComponent and not child.is_queued_for_deletion():
			return child
	return null

func is_armed() -> bool:
	return current_weapon != WeaponType.NONE

func get_arm_textures() -> Dictionary:
	match current_weapon:
		WeaponType.PISTOL:
			return { "front": arm_texture_pistol, "back": null }
		WeaponType.PLASMA:
			return { "front": arm_texture_plasma_front, "back": arm_texture_plasma_back }
	return { "front": null, "back": null }

# --- Internals ---

func _swap_to(index: int) -> void:
	_clear_gun_pivot()

	var scene: PackedScene = weapons[index]
	if scene == null:
		_set_weapon(WeaponType.NONE)
		return

	var instance = scene.instantiate()

	var type := WeaponType.NONE
	if instance is GunComponent and instance.gun_data != null:
		type = instance.gun_data.weapon_type as WeaponType
	
	if type == WeaponType.PLASMA:
		instance.position = Vector2(5.0, -1)
	else:
		instance.position = Vector2(8, -3)
		
	_gun_pivot_node.add_child(instance)
	instance.owner = owner
	
	_set_weapon(type)

func _clear_gun_pivot() -> void:
	for child in _gun_pivot_node.get_children():
		child.queue_free()

func _set_weapon(type: WeaponType) -> void:
	current_weapon = type
	weapon_changed.emit(type)
