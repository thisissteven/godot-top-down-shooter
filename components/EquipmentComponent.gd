class_name EquipmentComponent
extends Node

enum WeaponType { NONE, PISTOL, PLASMA }  # collapse AMMO+PLASMA into one

signal weapon_changed(type: WeaponType)

@export var arm_texture_pistol:       Texture2D  # single front hand
@export var arm_texture_plasma_front: Texture2D  # plasma front hand
@export var arm_texture_plasma_back:  Texture2D  # plasma back hand

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

func get_arm_textures() -> Dictionary:
	match current_weapon:
		WeaponType.PISTOL:
			return { "front": arm_texture_pistol, "back": null }
		WeaponType.PLASMA:
			return { "front": arm_texture_plasma_front, "back": arm_texture_plasma_back }
	return { "front": null, "back": null }
