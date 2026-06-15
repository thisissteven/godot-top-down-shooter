shader_type canvas_item;

// ─────────────────────────────────────────────
//  Global
// ─────────────────────────────────────────────

/// Size of one tile in pixels. Keep this at 16 for default tile size.
uniform float tile_size : hint_range(8.0, 64.0) = 16.0;

/// Overall darkness of all effects combined. 0 = invisible, 1 = full strength.
uniform float effect_strength : hint_range(0.0, 1.0) = 0.6;

// ─────────────────────────────────────────────
//  Dirt / Grime
// ─────────────────────────────────────────────

uniform bool  enable_dirt = true;

/// How dark the dirt patches are. Higher = darker blotches.
uniform float dirt_strength : hint_range(0.0, 1.0) = 0.35;

/// Controls the scale of dirt blobs relative to tile size.
/// Lower = larger blotches, higher = finer grain.
uniform float dirt_scale : hint_range(0.5, 8.0) = 2.5;

/// Threshold below which a pixel is considered "dirty".
/// Higher = more surface area covered.
uniform float dirt_threshold : hint_range(0.0, 1.0) = 0.45;

// ─────────────────────────────────────────────
//  Cracks
// ─────────────────────────────────────────────

uniform bool  enable_cracks = true;

/// How visible the cracks are.
uniform float crack_strength : hint_range(0.0, 1.0) = 0.5;

/// Crack network density. Higher = more cracks.
uniform float crack_scale : hint_range(0.5, 8.0) = 3.0;

/// How thin the crack lines are. Higher = thinner.
uniform float crack_sharpness : hint_range(1.0, 32.0) = 10.0;

// ─────────────────────────────────────────────
//  Moisture / Wet Streaks
// ─────────────────────────────────────────────

uniform bool  enable_moisture = true;

/// How dark/visible the wet areas are.
uniform float moisture_strength : hint_range(0.0, 1.0) = 0.25;

/// Scale of moisture streaks. Lower = wider streaks.
uniform float moisture_scale : hint_range(0.5, 6.0) = 1.8;

/// How much the streaks lean vertically (simulates dripping/pooling).
uniform float moisture_stretch : hint_range(1.0, 6.0) = 3.0;


// ═════════════════════════════════════════════
//  Noise helpers
// ═════════════════════════════════════════════

// Classic hash → pseudo-random float
float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

// Smooth value noise (bilinear interpolation over a hash grid)
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f); // smoothstep curve

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Two octaves of value noise for more organic feel
float fbm(vec2 p) {
	float v = 0.0;
	v += 0.6  * vnoise(p);
	v += 0.4  * vnoise(p * 2.1 + vec2(5.3, 1.7));
	return v;
}

// Worley-style cell distance — gives crack-like veins
// Returns distance to nearest cell point
float worley(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float min_dist = 8.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point    = vec2(hash(i + neighbor), hash(i + neighbor + vec2(31.7, 48.3)));
			vec2 diff     = neighbor + point - f;
			float dist    = length(diff);
			min_dist      = min(min_dist, dist);
		}
	}

	return min_dist;
}


// ═════════════════════════════════════════════
//  Main
// ═════════════════════════════════════════════

varying vec2 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

uniform vec4 modulate_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// World-space position in tile units — patterns span tile boundaries
	// VERTEX is in local canvas space (pixels). Dividing by tile_size
	// puts us in tile-coordinate space so noise scales correctly.
	vec2 world_uv = world_pos / tile_size;

	float darken = 0.0; // accumulates darkening from all effects

	// ── Dirt / Grime ──────────────────────────────────────────────────────────
	if (enable_dirt) {
		// Two layers of fbm at different offsets give uneven blotchy patches
		float n1 = fbm(world_uv * dirt_scale);
		float n2 = fbm(world_uv * dirt_scale * 1.7 + vec2(42.3, 17.9));
		float dirt = n1 * n2; // multiply = only dark where BOTH layers agree

		// Threshold: only pixels below the cutoff show visible dirt
		float mask = smoothstep(dirt_threshold, dirt_threshold - 0.15, dirt);
		darken += mask * dirt_strength;
	}

	// ── Cracks ────────────────────────────────────────────────────────────────
	if (enable_cracks) {
		// Worley noise edges = natural crack network
		float w = worley(world_uv * crack_scale);

		// Narrow the Worley distance into a thin dark line
		// pow sharpens the falloff: higher crack_sharpness = thinner lines
		float crack = 1.0 - pow(clamp(w * crack_sharpness, 0.0, 1.0), 0.5);

		// Second layer at different angle/offset for branching feel
		float w2    = worley(world_uv * crack_scale * 0.7 + vec2(3.1, 8.6));
		float crack2 = 1.0 - pow(clamp(w2 * crack_sharpness * 1.3, 0.0, 1.0), 0.5);

		darken += max(crack, crack2 * 0.5) * crack_strength;
	}

	// ── Moisture / Wet Streaks ────────────────────────────────────────────────
	if (enable_moisture) {
		// Stretch UVs vertically to simulate pooling / drip direction
		vec2 wet_uv = world_uv * vec2(moisture_scale, moisture_scale / moisture_stretch);

		float m1 = fbm(wet_uv);
		float m2 = fbm(wet_uv + vec2(0.0, 9.3)); // vertical offset for layering

		// Moisture pools in low-frequency blobs that are elongated vertically
		float wet = smoothstep(0.45, 0.65, m1 * m2 * 2.5);

		// Slight shimmer edge: bright rim around wet patches (additive)
		// We handle this as a slight lightening rather than darkening,
		// so subtract from darken instead of adding
		darken -= wet * moisture_strength * 0.15; // subtle highlight rim

		// Core wet area is darker (absorbed light)
		float wet_core = smoothstep(0.55, 0.75, m1 * m2 * 2.5);
		darken += wet_core * moisture_strength;
	}

	// ── Composite ─────────────────────────────────────────────────────────────
	darken = clamp(darken * effect_strength, -0.15, 1.0);

	// Multiply base color toward black by darken amount
	// Negative darken (from moisture rim) brightens slightly
	vec3 final_color = base.rgb * (1.0 - darken);

	COLOR = vec4(final_color * modulate_color.rgb, base.a * modulate_color.a);
}
