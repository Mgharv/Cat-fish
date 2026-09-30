shader_type spatial;
// The pond's water surface: a see-through tint with gently moving ripples.
// The ripples are bright, wavy lines that drift across the surface, so the
// fish underneath are seen through a moving pattern (like real water).
// ripple_strength = 0 gives a flat, calm surface.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.1, 0.5, 0.45, 0.3);  // colour + see-through-ness
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.5;
uniform float ripple_scale = 1.2;   // ripples per metre (bigger = finer ripples)
uniform float ripple_speed = 0.35;  // how fast they drift

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// smooth random value noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
			mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * ripple_scale;
	float t = TIME * ripple_speed;
	// two layers of noise drifting in different directions
	float n = noise(p + vec2(t, t * 0.6)) + noise(p * 2.1 - vec2(t * 0.8, -t * 1.1)) * 0.5;
	n /= 1.5;
	// thin bright lines where the noise crosses the middle (like light on ripples)
	float lines = 1.0 - smoothstep(0.0, 0.08, abs(n - 0.5));
	float glint = lines * ripple_strength;
	ALBEDO = tint.rgb + vec3(0.55, 0.65, 0.65) * glint;
	ALPHA = clamp(tint.a + glint * 0.45, 0.0, 1.0);
}
