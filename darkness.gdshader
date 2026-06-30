shader_type canvas_item;
render_mode blend_mul;

uniform float darkness : hint_range(0.0, 1.0) = 0.92;

void fragment() {
    vec4 light = texture(TEXTURE, UV);
    float ambient = 1.0 - darkness;
    vec3 result = clamp(vec3(ambient) + light.rgb, 0.0, 1.0);

    COLOR.rgb = result;
    COLOR.a = 1.0;
}