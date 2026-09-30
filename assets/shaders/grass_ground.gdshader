shader_type spatial;
// Lawn: a procedural grass texture (no image files). Patchy light/dark greens at a
// few sizes, with the finest detail fading out with distance so it doesn't shimmer in VR.

uniform vec3 grass_light : source_color = vec3(0.40, 0.58, 0.30);
uniform vec3 grass_dark : source_color = vec3(0.32, 0.50, 0.24);
uniform vec3 dry_patch : source_color = vec3(0.55, 0.58, 0.32);
uniform float detail_fade_distance = 12.0;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
	vec2 p = world_pos.xz;
	float big = noise(p * 0.08);                   // large patches (10+ m)
	float mid = noise(p * 0.6);                    // clumps
	float fine = noise(p * 6.0) * 0.6 + noise(p * 14.0) * 0.4;  // blade-level grain
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	fine = mix(fine, 0.5, smoothstep(detail_fade_distance * 0.5, detail_fade_distance, dist));
	vec3 col = mix(grass_dark, grass_light, clamp(mid * 0.7 + fine * 0.5 - 0.1, 0.0, 1.0));
	col = mix(col, dry_patch, smoothstep(0.7, 0.85, big) * 0.3);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
