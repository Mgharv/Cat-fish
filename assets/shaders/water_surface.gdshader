shader_type spatial;
// The pond's water surface: a see-through muted teal tint with soft, low-contrast
// ripples and a gentle sky reflection at shallow viewing angles.
//
// Design rule: pretty from a distance, quiet where you search. Looking down into
// the pond (steep angle) the surface is almost just a tint, so fine fish markings
// stay readable. Looking across the pond (shallow angle) it reflects more sky, like
// real water.
//
// ripple_strength = 0 gives a flat, calm surface. reflection_strength = 0 turns the
// sky reflection off. Neither changes the murk (that's water_clarity on the Pond).
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 tint : source_color = vec4(0.12, 0.44, 0.45, 0.3);  // colour + see-through-ness
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.5;
uniform float ripple_scale = 1.2;   // ripples per metre (bigger = finer ripples)
uniform float ripple_speed = 0.25;  // how fast they drift
uniform vec3 sky_color : source_color = vec3(0.62, 0.74, 0.80);   // what the water reflects
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.45;

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

	// far away the ripple pattern would shimmer, so fade it out with distance
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(8.0, 25.0, dist);

	// 1) broad, gentle light/dark swells (low contrast)
	float swell = (n - 0.5) * 0.16 * ripple_strength;
	// 2) soft, faint highlight bands where the noise crosses the middle
	float band = 1.0 - smoothstep(0.0, 0.12, abs(n - 0.5));
	float glint = band * ripple_strength * near;

	// 3) sky reflection: stronger when looking across the water, weak looking straight down
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0) * reflection_strength;
	fresnel *= 1.0 + (n - 0.5) * 0.6 * ripple_strength;   // ripples break up the reflection a little

	vec3 col = tint.rgb * (1.0 + swell) + vec3(0.16, 0.20, 0.20) * glint;
	col = mix(col, sky_color, clamp(fresnel, 0.0, 0.85));
	ALBEDO = col;
	ALPHA = clamp(tint.a + glint * 0.06 + fresnel * 0.55, 0.0, 0.95);
}
