extends Node2D

# ─────────────────────────────────────────────
#  REFERENCES
# ─────────────────────────────────────────────
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var core_sprite: Sprite2D = $ProjectileSprite

# ─────────────────────────────────────────────
#  COLOR
# ─────────────────────────────────────────────
@export_group("Color")
## If true, samples the average color from ProjectileSprite's texture automatically
@export var use_sprite_color: bool = false
## Manual glow color — ignored if use_sprite_color is true
@export var glow_color: Color = Color(0.2, 0.6, 1.0)

# ─────────────────────────────────────────────
#  GLOW SHAPE
# ─────────────────────────────────────────────
@export_group("Glow Shape")
## Horizontal radius of the glow in pixels
@export var glow_radius_h: float = 24.0
## Vertical radius of the glow in pixels
@export var glow_radius_v: float = 8.0
## Falloff sharpness — lower = softer/wider, higher = tighter
@export var falloff: float = 1.5
## Base alpha of the glow (0–1)
@export var glow_alpha: float = 0.4


# ─────────────────────────────────────────────
#  ANIMATION
# ─────────────────────────────────────────────
@export_group("Animation")
@export_enum("None", "Pulse", "Brighten", "Dimmer", "Flicker") var animation: int = 0

## Speed of the animation
@export var animation_speed: float = 1.0

## For Pulse: min/max alpha range
@export var pulse_min: float = 0.2
@export var pulse_max: float = 0.6

## For Brighten: starting alpha (ramps up to 1.0 over lifetime)
@export var brighten_start: float = 0.1

## For Dimmer: starting alpha (ramps down to 0.0 over lifetime)
@export var dimmer_start: float = 0.6

## For Flicker: how chaotic the flicker is (0 = smooth, 1 = very choppy)
@export_range(0.0, 1.0) var flicker_intensity: float = 0.6

# ─────────────────────────────────────────────
#  INTERNALS
# ─────────────────────────────────────────────
var _mat: CanvasItemMaterial
var _time: float = 0.0
var _resolved_color: Color
var _flicker_target: float = 0.5
var _flicker_current: float = 0.5
var _flicker_timer: float = 0.0


func _ready() -> void:
    _mat = CanvasItemMaterial.new()
    _mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

    _resolved_color = _resolve_color()

    var tex_w := int(glow_radius_h * 2)
    var tex_h := int(glow_radius_v * 2)
    glow_sprite.texture = _make_glow_texture(tex_w, tex_h)
    glow_sprite.material = _mat
    glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    glow_sprite.scale = Vector2.ONE
    glow_sprite.modulate = Color(_resolved_color.r, _resolved_color.g, _resolved_color.b, glow_alpha)
    glow_sprite.z_index = 1001

    if animation == 0:
        set_process(false)


func _process(delta: float) -> void:
    _time += delta
    var c := _resolved_color

    match animation:
        1: # Pulse
            var t := (sin(_time * animation_speed * TAU) + 1.0) * 0.5
            var a = lerp(pulse_min, pulse_max, t)
            glow_sprite.modulate = Color(c.r, c.g, c.b, a)

        2: # Brighten
            var a = clamp(brighten_start + _time / animation_speed, 0.0, 1.0)
            glow_sprite.modulate = Color(c.r, c.g, c.b, a)

        3: # Dimmer
            var a = clamp(dimmer_start - (_time / animation_speed) * dimmer_start, 0.0, dimmer_start)
            glow_sprite.modulate = Color(c.r, c.g, c.b, a)

        4: # Flicker
            _flicker_timer -= delta
            if _flicker_timer <= 0.0:
                _flicker_target = randf_range(pulse_min, pulse_max)
                _flicker_timer = randf_range(0.03, 0.12) / max(animation_speed, 0.01)
            var smooth_speed = lerp(20.0, 2.0, flicker_intensity)
            _flicker_current = lerp(_flicker_current, _flicker_target, delta * smooth_speed)
            glow_sprite.modulate = Color(c.r, c.g, c.b, _flicker_current)


# ─────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────

func _resolve_color() -> Color:
    if not use_sprite_color:
        return glow_color

    if not core_sprite or not core_sprite.texture:
        push_warning("GlowComponent: use_sprite_color is true but ProjectileSprite has no texture. Falling back to glow_color.")
        return glow_color

    var img: Image = core_sprite.texture.get_image()
    if not img:
        return glow_color

    # Sample a grid of pixels and average the opaque ones
    var total := Color(0, 0, 0, 0)
    var count := 0
    var step = max(1, img.get_width() / 8.0)

    for y in range(0, img.get_height(), step):
        for x in range(0, img.get_width(), step):
            var px: Color = img.get_pixel(x, y)
            if px.a > 0.1:  # skip transparent pixels
                total.r += px.r
                total.g += px.g
                total.b += px.b
                count += 1

    if count == 0:
        return glow_color

    return Color(total.r / count, total.g / count, total.b / count)

func _make_glow_texture(w: int, h: int) -> ImageTexture:
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    var cx := w / 2.0
    var cy := h / 2.0
    for x in w:
        for y in h:
            var dx := (x - cx) / cx  # -1..1
            var dy := (y - cy) / cy  # -1..1
            var dist := sqrt(dx * dx + dy * dy)
            var alpha := pow(clamp(1.0 - dist, 0.0, 1.0), falloff)
            img.set_pixel(x, y, Color(1, 1, 1, alpha))
    return ImageTexture.create_from_image(img)
