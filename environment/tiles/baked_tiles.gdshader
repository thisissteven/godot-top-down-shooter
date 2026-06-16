shader_type canvas_item;

// 1. Pass the pre-generated image files into the shader
uniform sampler2D baked_noise_tex; 
uniform float tile_size = 16.0;
uniform float effect_strength = 0.6;

varying vec2 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    
    // Snap our lookup coordinates to the tile grid
    vec2 world_uv = floor(world_pos / tile_size);
    
    // 2. Instead of complex math loops, we just read the picture!
    // We scale the UV slightly so the texture repeats naturally across tiles.
    vec4 noise_data = texture(baked_noise_tex, world_uv * 0.05);
    
    // Suppose Red channel = Dirt, Green channel = Cracks, Blue channel = Moisture
    float dirt = noise_data.r;
    float cracks = noise_data.g;
    float moisture = noise_data.b;
    
    // Do your basic math on these values
    float darken = (dirt * 0.35) + (cracks * 0.5) + (moisture * 0.25);
    darken = clamp(darken * effect_strength, -0.15, 1.0);
    
    vec3 final_color = base.rgb * (1.0 - darken);
    COLOR = vec4(final_color, base.a);
}
