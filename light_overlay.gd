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

    rebuild()


## Rebuild the light stamp list and re-render the viewport.
## Cheap: only called when lights are added or removed.
# Added to LightOverlay.gd

## Nodes in this group are treated as "always lit": their footprint
## is stamped at full brightness into the SubViewport, so the
## darkness shader never darkens that area — no z-index or
## per-sprite shader needed.
const ALWAYS_LIT_GROUP := "always_lit"


func rebuild() -> void:
    for child in _container.get_children():
        child.free()

    # ── Normal point lights (existing) ──────────────────────────
    var lights := get_tree().get_nodes_in_group("wall_light")
    for light in lights:
        if not light.has_method("get_light_stamp_data"):
            continue

        var data : Dictionary = light.get_light_stamp_data()

        var stamp := Sprite2D.new()
        stamp.texture   = data["texture"]
        stamp.modulate  = data.get("modulate", Color.WHITE)
        stamp.scale     = data.get("scale", Vector2.ONE)
        stamp.position  = data["position"]
        stamp.centered  = true

        var mat := CanvasItemMaterial.new()
        mat.blend_mode  = CanvasItemMaterial.BLEND_MODE_ADD
        stamp.material  = mat

        _container.add_child(stamp)
        stamp.owner = owner

    var always_lit := get_tree().get_nodes_in_group(ALWAYS_LIT_GROUP)
    for node in always_lit:
        if not node.has_method("get_always_lit_stamp_data"):
            continue

        var data : Dictionary = node.get_always_lit_stamp_data()
        # data: { "position": Vector2, "texture": Texture2D, "scale": Vector2 }

        var stamp := Sprite2D.new()
        stamp.texture   = data["texture"]
        stamp.position  = data["position"]
        stamp.scale     = data.get("scale", Vector2.ONE)
        stamp.centered  = true
        stamp.modulate  = Color.WHITE   # full brightness wherever the texture has alpha

        var mat := CanvasItemMaterial.new()
        mat.blend_mode  = CanvasItemMaterial.BLEND_MODE_ADD
        stamp.material  = mat

        _container.add_child(stamp)

    _viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

# Added to LightOverlay.gd

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
        var scale  : Vector2  = data.get("scale", Vector2.ONE)

        # Half-extent of the glow texture in world space (it's centered).
        var half_size := Vector2(tex.get_width(), tex.get_height()) * 0.5 * scale

        min_pos = min_pos.min(pos - half_size)
        max_pos = max_pos.max(pos + half_size)

    return Rect2(min_pos, max_pos - min_pos)


## Call this once, after WallLights has generated, at actual runtime.
## Skips entirely in the editor.
func setup_from_generated_lights() -> void:
    var rect := compute_world_rect_from_lights()
    init(rect)
    
