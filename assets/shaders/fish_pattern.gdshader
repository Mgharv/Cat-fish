shader_type spatial;
// Flat-coloured fish body with a pattern that is defined by numbers,
// so its spatial frequency is exact. UV.x = 0 at the nose -> 1 at the tail,
// UV.y = angle around the body (0.25 = top of the back, 0.75 = belly).
render_mode unshaded, cull_disabled, fog_disabled;   // fog is for the far scenery only; fish visibility comes from the murk alone

uniform vec3 body_color : source_color = vec3(0.62, 0.64, 0.66);
uniform vec3 pattern_color : source_color = vec3(0.18, 0.19, 0.21);
uniform int pattern = 0;            // 0 none, 1 spots, 2 bands, 3 stripes, 4 speckles
uniform float pattern_frequency = 3.0;
uniform float pattern_size = 0.5;
uniform float shade_amount = 0.25;  // 0 = perfectly flat colour, 1 = strong 3D shading
uniform float length_to_girth = 3.0; // keeps spots round

// ---- water murk, set by the pond ----
// Light fades the further it travels through water, so deep or far-away fish
// fade toward the water colour and lose contrast.
uniform float surface_y = 100.0;    // world height of the water surface
uniform vec3 water_color : source_color = vec3(0.2, 0.45, 0.55);
uniform float murk_per_metre = 0.0; // 0 = crystal clear

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// How many metres of water lie between the eye and this point.
float water_path(vec3 p, vec3 eye) {
	float below = surface_y - p.y;            // depth of the point under the surface
	if (below <= 0.0) return 0.0;             // above the water: no murk
	float drop = eye.y - p.y;
	if (drop <= below) return length(p - eye); // eye is underwater too
	return length(p - eye) * below / drop;     // only the part of the sight line under water
}

void fragment() {
	float t = UV.x;          // along the body
	float a = UV.y;          // around the body
	float mark = 0.0;

	if (pattern == 1) {        // SPOTS: large round spots along the back
		float n = max(pattern_frequency, 1.0);
		float cell = (t - 0.18) / 0.6 * n;            // spots between 18% and 78% of body
		float ci = clamp(floor(cell), 0.0, n - 1.0);
		float ct = 0.18 + (ci + 0.5) / n * 0.6;
		vec2 d = vec2((t - ct) * length_to_girth, (a - 0.25));
		float r = pattern_size * 0.12;
		mark = step(length(d), r);
	} else if (pattern == 2) { // BANDS: wide bands across the body
		float n = max(pattern_frequency, 1.0);
		float cell = (t - 0.15) / 0.65 * n;
		float inside = step(0.0, cell) * step(cell, n);
		mark = inside * step(fract(cell), pattern_size);
	} else if (pattern == 3) { // STRIPES: thin stripes running nose-to-tail, wrapping around the body
		mark = step(fract(a * pattern_frequency), pattern_size);
	} else if (pattern == 4) { // SPECKLES: many tiny dots
		vec2 g = vec2(t * pattern_frequency, a * pattern_frequency / length_to_girth * 2.0);
		vec2 cell = floor(g);
		vec2 f = fract(g) - 0.5;
		vec2 jitter = vec2(hash(cell), hash(cell + 7.3)) - 0.5;
		mark = step(length(f - jitter * 0.4), pattern_size * 0.35);
	}
	// no pattern on the head or the very tail end
	mark *= smoothstep(0.08, 0.12, t) * (1.0 - smoothstep(0.93, 0.97, t));

	vec3 col = mix(body_color, pattern_color, mark);
	// gentle fixed-direction shading so the body still reads as 3D
	float light = clamp(dot(normalize(NORMAL), normalize((VIEW_MATRIX * vec4(0.3, 1.0, 0.4, 0.0)).xyz)), 0.0, 1.0);
	col *= mix(1.0, 0.65 + 0.35 * light, shade_amount);
	// murk: the more water in the way, the more it fades toward the water colour
	float path = water_path(world_pos, CAMERA_POSITION_WORLD);
	col = mix(col, water_color, 1.0 - exp(-path * murk_per_metre));
	ALBEDO = col;
}
