shader_type canvas_item;

uniform float world_seed = 0.0;

// How strong the variation is (0 = no change, 1 = full random gray)
uniform float variation_strength : hint_range(0.0, 1.0) = 0.1;

// Base tint (white = no change)
uniform vec4 modulate_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec2 world_pos;

// --- cheap hash (very fast, no loops, no noise) ---
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// IMPORTANT: tile locking
	// assumes tile_size = 16 world units per tile
	float tile_size = 16.0;

	vec2 tile_id = floor(world_pos / tile_size);

	// stable random per tile
	float r = hash(tile_id + world_seed);

	// convert to grayscale factor (0.6–1.0 range)
	// so nothing becomes pure black unless you want it
	float shade = mix(1.0 - variation_strength, 1.0, r);

	vec3 final_rgb = base.rgb * shade;

	COLOR = vec4(final_rgb * modulate_color.rgb, base.a * modulate_color.a);
}