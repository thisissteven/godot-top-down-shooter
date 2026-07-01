shader_type canvas_item;
render_mode blend_mul;

uniform float darkness : hint_range(0.0, 1.0) = 0.92;
uniform float light_intensity : hint_range(0.0, 3.0) = 1.0;
uniform vec4 darkness_tint : source_color = vec4(0.05, 0.05, 0.15, 1.0); // navy shadow tint
uniform sampler2D map_mask : hint_default_transparent;

void fragment() {
    vec4 mask = texture(map_mask, UV);

    vec4 light = texture(TEXTURE, UV);
    vec3 light_clamped = clamp(light.rgb * light_intensity, 0.0, 1.0);

    // Blend from "no darkening" (white) toward the tint color as darkness increases,
    // instead of toward gray/black.
    vec3 ambient_color = mix(vec3(1.0), darkness_tint.rgb, darkness);

    vec3 light_result = clamp(ambient_color + light_clamped, 0.0, 1.0);

    COLOR.rgb = mix(vec3(1.0), light_result, mask.a);
    COLOR.a = 1.0;
}