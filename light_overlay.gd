# LightOverlay.gd
# Attach to a Node2D named LightOverlay.
# Add that node to group "light_overlay".
#
# Scene tree:
#   LightOverlay (Node2D)          ← this script
#   ├── SubViewport
#   │   └── LightContainer (Node2D)
#   └── TextureRect
#
# TextureRect:
#   - Anchor: full rect (0,0,1,1)
#   - Mouse Filter: Ignore
#   - Shader: darkness.gdshader (below)
#   - flip_v = true  (SubViewport UV is flipped)
#
# SubViewport:
#   - Transparent BG: true
#   - Disable 3D: true
#   - Handle Input Locally: false
#   - Update Mode: UPDATE_ONCE (we set this in code)

@tool
class_name LightOverlay
extends Node2D

## How dark the unlit areas are. 0 = invisible overlay, 1 = pitch black.
@export var darkness : float = 1.0
## Intensity multiplier (e.g., 1.0 = normal, 3.0 = extra bright)
@export var intensity : float = 2.5
@export var darkness_tint : Color = Color(0.05, 0.05, 0.15)


@onready var _viewport     : SubViewport = $SubViewport
@onready var _container    : Node2D      = $SubViewport/LightContainer
@onready var _rect         : TextureRect = $TextureRect

func _ready() -> void:
	_rect.z_index = 1024
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
## Call this once after the dungeon is fully generated,
## passing the world-space rect that covers the entire map.
## e.g.  LightOverlay.init(Rect2(Vector2.ZERO, map_pixel_size))
func init(world_rect: Rect2) -> void:
	_viewport.size = Vector2i(
		int(world_rect.size.x),
		int(world_rect.size.y)
	)

	# Offset the container so world position (world_rect.position)
	# maps to viewport pixel (0, 0).
	_container.position = -world_rect.position

	# Size and position the TextureRect to cover the same world rect.
	# It lives as a child of this Node2D, so position is local.
	_rect.position = world_rect.position
	_rect.size     = world_rect.size
	_rect.texture  = _viewport.get_texture()

	_rect.material.set_shader_parameter("darkness", darkness)
	_rect.material.set_shader_parameter("light_intensity", intensity)
	_rect.material.set_shader_parameter("darkness_tint", darkness_tint)
	
	rebuild()

var _dynamic_stamps: Dictionary = {}  # id (String) -> Sprite2D
var _rebuild_queued := false

## Coalesced rebuild — safe to call multiple times in the same frame
## (e.g. several lights changing/dying at once). Use this instead of
## rebuild() directly from gameplay code.
func request_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_do_rebuild")

func _do_rebuild() -> void:
	_rebuild_queued = false
	rebuild()


## For lights that move/animate every frame (door glows, player flashlight).
## Call every frame while the light should be visible, with a stable id —
## the same stamp gets updated in place instead of duplicated.
func update_dynamic_light(id: String, world_position: Vector2, texture: Texture2D, color: Color = Color.WHITE, local_scale: Vector2 = Vector2.ONE, local_rotation: float = 0.0) -> void:
	var stamp: Sprite2D = _dynamic_stamps.get(id)
	if not stamp:
		stamp = Sprite2D.new()
		stamp.centered = true
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		stamp.material = mat
		_container.add_child(stamp)
		_dynamic_stamps[id] = stamp

	stamp.texture  = texture
	stamp.position = world_position
	stamp.rotation = local_rotation
	stamp.modulate = color
	stamp.scale    = local_scale

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Call when a dynamic light should stop existing (door fully closed
## and off, light destroyed, etc).
func remove_dynamic_light(id: String) -> void:
	if _dynamic_stamps.has(id):
		_dynamic_stamps[id].queue_free()
		_dynamic_stamps.erase(id)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func rebuild() -> void:
	for child in _container.get_children():
		if not _dynamic_stamps.values().has(child):
			child.free()

	var lights := get_tree().get_nodes_in_group("wall_light")
	for light in lights:
		if not light.has_method("get_light_stamp_data"):
			continue

		var data : Dictionary = light.get_light_stamp_data()
		
		var stamp := Sprite2D.new()
		
		stamp.texture   = data["texture"]
		stamp.modulate  = data["color"]
		stamp.scale     = data["scale"]
		stamp.position  = data["position"]
		stamp.centered  = true

		var mat := CanvasItemMaterial.new()
		mat.blend_mode  = CanvasItemMaterial.BLEND_MODE_ADD
		stamp.material  = mat
		
		_container.add_child(stamp)
		stamp.owner = owner

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Computes the world-space bounding rect from all registered wall lights,
## expanding each light's contribution by its glow texture's radius
## (so the hole's full extent is included, not just the light's origin).
func compute_world_rect_from_lights() -> Rect2:
	var lights := get_tree().get_nodes_in_group("wall_light")
	if lights.is_empty():
		push_warning("LightOverlay: no wall_light nodes found, using zero rect")
		return Rect2()

	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF

	for light in lights:
		if not light.has_method("get_light_stamp_data"):
			continue

		var data : Dictionary = light.get_light_stamp_data()
		var pos    : Vector2  = data["position"]
		var tex    : Texture2D = data["texture"]
		var local_scale  : Vector2  = data.get("scale", Vector2.ONE)

		# Half-extent of the glow texture in world space (it's centered).
		var half_size := Vector2(tex.get_width(), tex.get_height()) * 0.5 * local_scale

		min_pos = min_pos.min(pos - half_size)
		max_pos = max_pos.max(pos + half_size)

	return Rect2(min_pos, max_pos - min_pos)


## Call this once, after WallLights has generated, at actual runtime.
## Skips entirely in the editor.
func setup_from_generated_lights(map_nodes: Array[Node] = []) -> void:
	var rect := compute_world_rect_from_lights()
	init(rect)
	
	if not map_nodes.is_empty():
		_generate_and_apply_map_mask(rect, map_nodes)


func _generate_and_apply_map_mask(world_rect: Rect2, map_nodes: Array[Node]) -> void:
	if world_rect.size.x <= 0 or world_rect.size.y <= 0:
		return

	var mask_image := Image.create(int(world_rect.size.x), int(world_rect.size.y), false, Image.FORMAT_RGBA8)
	mask_image.fill(Color(0, 0, 0, 0))
	

	var atlas_cache := {}

	for node in map_nodes:
		_draw_node_to_mask(node, mask_image, world_rect, atlas_cache)

	var mask_texture := ImageTexture.create_from_image(mask_image)
	_rect.material.set_shader_parameter("map_mask", mask_texture)


static func _transpose_image(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(h, w, false, img.get_format())
	for y in range(h):
		for x in range(w):
			out.set_pixel(y, x, img.get_pixel(x, y))
	return out


func _draw_node_to_mask(node: Node, img: Image, world_rect: Rect2, atlas_cache: Dictionary = {}) -> void:
	if not node:
		return

	if node.has_method("get_used_cells"):
		var cells = node.get_used_cells()
		var tile_set: TileSet = node.get("tile_set")

		if tile_set:
			for cell in cells:
				var source_id: int = node.call("get_cell_source_id", cell)
				if source_id == -1:
					continue

				var atlas_coords: Vector2i = node.call("get_cell_atlas_coords", cell)
				var alternative_id: int = node.call("get_cell_alternative_tile", cell)

				var source = tile_set.get_source(source_id) as TileSetAtlasSource
				if not source or not source.texture:
					continue

				var cache_key := str(tile_set.get_instance_id()) + "_" + str(source_id)
				if not atlas_cache.has(cache_key):
					var src_img = source.texture.get_image()
					if src_img.is_compressed():
						src_img.decompress()
					src_img.convert(Image.FORMAT_RGBA8)
					atlas_cache[cache_key] = src_img
				var atlas_img: Image = atlas_cache[cache_key]

				var region := source.get_tile_texture_region(atlas_coords, alternative_id)
				var tile_img := atlas_img.get_region(region)

				if alternative_id > 0:
					if alternative_id & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
						tile_img = _transpose_image(tile_img)
					if alternative_id & TileSetAtlasSource.TRANSFORM_FLIP_H:
						tile_img.flip_x()
					if alternative_id & TileSetAtlasSource.TRANSFORM_FLIP_V:
						tile_img.flip_y()

				# KEY FIX: use the tile's actual texture origin + real region size,
				# not the grid's logical tile_size. Tiles can be larger than the
				# grid cell (e.g. underside/overhang art) and texture_origin tells
				# you how it's offset relative to the cell center.
				var texture_origin := Vector2.ZERO
				if source.has_method("get_tile_texture_origin"):
					texture_origin = source.get_tile_texture_origin(atlas_coords, alternative_id)

				var local_center: Vector2 = node.map_to_local(cell)
				var local_top_left: Vector2 = local_center - Vector2(region.size) / 2.0 + texture_origin
				var global_top_left: Vector2 = node.to_global(local_top_left)
				var img_pos := Vector2i((global_top_left - world_rect.position).round())

				var src_rect := Rect2i(Vector2i.ZERO, tile_img.get_size())
				if img_pos.x < 0:
					src_rect.position.x -= img_pos.x
					src_rect.size.x += img_pos.x
					img_pos.x = 0
				if img_pos.y < 0:
					src_rect.position.y -= img_pos.y
					src_rect.size.y += img_pos.y
					img_pos.y = 0
				src_rect.size.x = min(src_rect.size.x, img.get_width() - img_pos.x)
				src_rect.size.y = min(src_rect.size.y, img.get_height() - img_pos.y)

				if src_rect.size.x > 0 and src_rect.size.y > 0:
					img.blit_rect_mask(tile_img, tile_img, src_rect, img_pos)
				
	elif node is Sprite2D and node.texture:
		var sprite_img = node.texture.get_image()
		if sprite_img.is_compressed():
			sprite_img.decompress()
		sprite_img.convert(Image.FORMAT_RGBA8)

		var size: Vector2 = node.texture.get_size() * node.global_scale
		var offset: Vector2 = node.offset if node.centered else Vector2.ZERO
		if node.centered:
			offset -= size / 2.0

		var img_pos := Vector2i(((node.global_position + offset) - world_rect.position).round())
		var src_rect := Rect2i(Vector2i.ZERO, sprite_img.get_size())

		if img_pos.x >= 0 and img_pos.y >= 0 \
		and img_pos.x + src_rect.size.x <= img.get_width() \
		and img_pos.y + src_rect.size.y <= img.get_height():
			img.blit_rect_mask(sprite_img, sprite_img, src_rect, img_pos)

	for child in node.get_children():
		_draw_node_to_mask(child, img, world_rect, atlas_cache)
	
