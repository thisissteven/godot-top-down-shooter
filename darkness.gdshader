shader_type canvas_item;
render_mode blend_mul;

uniform float darkness : hint_range(0.0, 1.0) = 0.92;
uniform sampler2D map_mask : hint_default_transparent;

void fragment() {
    // Sample our generated map visibility mask
    vec4 mask = texture(map_mask, UV);
    
    // Process your original lighting math
    vec4 light = texture(TEXTURE, UV);
    float ambient = 1.0 - darkness;
    vec3 light_result = clamp(vec3(ambient) + light.rgb, 0.0, 1.0);

    // If mask.a is 1.0 (inside map), it applies full darkness/light.
    // If mask.a is 0.0 (transparent space), it outputs vec3(1.0) which does nothing in blend_mul.
    COLOR.rgb = mix(vec3(1.0), light_result, mask.a);
    COLOR.a = 1.0;
}