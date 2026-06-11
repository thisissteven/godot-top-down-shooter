class_name EquipmentComponent
extends Node

enum WeaponType { NONE, PISTOL, AMMO, PLASMA }

signal weapon_changed(type: WeaponType)

@export var arm_texture_pistol: Texture2D
@export var arm_texture_ammo:   Texture2D
@export var arm_texture_plasma: Texture2D

var current_weapon: WeaponType = WeaponType.NONE

func equip(type: WeaponType) -> void:
	if type == current_weapon:
		return
	current_weapon = type
	weapon_changed.emit(type)

func unequip() -> void:
	equip(WeaponType.NONE)

func is_armed() -> bool:
	return current_weapon != WeaponType.NONE

func get_arm_texture() -> Texture2D:
	match current_weapon:
		WeaponType.PISTOL: return arm_texture_pistol
		WeaponType.AMMO:   return arm_texture_ammo
		WeaponType.PLASMA: return arm_texture_plasma
	return null
