## GunData.gd
## Pure data resource — create one .tres file per gun variant.
## Assign to GunComponent.gun_data in the inspector.
## No logic lives here; all behaviour is in GunComponent.

class_name GunData
extends Resource

# ── Identity ──────────────────────────────────────────────────────────────────

@export var gun_name: String = "Pistol"
@export var weapon_type: EquipmentComponent.WeaponType = EquipmentComponent.WeaponType.NONE

# ── Firing ────────────────────────────────────────────────────────────────────

## Shots per second. 2.0 = one shot every 0.5 s.
@export_range(0.1, 30.0, 0.1) var fire_rate: float = 2.0

## Half-angle of the random spread cone (degrees).
## 0 = perfectly accurate.
@export_range(0.0, 45.0, 0.5) var spread_degrees: float = 3.0

## How many projectiles fire in parallel per shot (e.g. shotgun = 8).
@export_range(1, 20) var pellets_per_shot: int = 1

# ── Ammo ──────────────────────────────────────────────────────────────────────

@export_range(1, 999) var magazine_size: int = 12

## -1 means infinite reserve.
@export var reserve_ammo: int = 60

## Time in seconds to fully reload.
@export_range(0.1, 5.0, 0.1) var reload_time: float = 1.2

## Shared pool tag — multiple guns with the same tag share reserve ammo.
## Leave empty for a self-contained ammo pool.
@export var ammo_type: StringName = &""

# ── Projectile ────────────────────────────────────────────────────────────────

## The scene to spawn. Must have a ProjectileComponent (or Projectile.gd) at root.
@export var projectile_scene: PackedScene

## Optional muzzle flash VFX scene. Spawned at the muzzle point and auto-freed.
@export var muzzle_flash_scene: PackedScene

# ── Audio ─────────────────────────────────────────────────────────────────────

@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_click_sound: AudioStream

## Pitch variance applied randomly each shot (±value).
@export_range(0.0, 0.3, 0.01) var pitch_variance: float = 0.07
