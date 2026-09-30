shader_type spatial;
// For things in the pond that aren't fish (floor, walls, bridge posts): a plain
// colour that fades with water exactly the way the fish do (same lighting, same
// fade colour), so fish never stand out just because the background ignores the murk.
render_mode unshaded, cull_disabled;

uniform vec3 albedo : source_color = vec3(0.5);
uniform float shade_amount = 0.35;   // same simple lighting as the fish
uniform float surface_y = 100.0;
uniform vec3 water_color : source_color = vec3(0.2, 0.45, 0.55);
uniform float murk_per_metre = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float water_path(vec3 p, vec3 eye) {
	float below = surface_y - p.y;
	if (below <= 0.0) return 0.0;
	float drop = eye.y - p.y;
	if (drop <= below) return length(p - eye);
	return length(p - eye) * below / drop;
}

void fragment() {
	float light = clamp(dot(normalize(NORMAL), normalize((VIEW_MATRIX * vec4(0.3, 1.0, 0.4, 0.0)).xyz)), 0.0, 1.0);
	vec3 col = albedo * mix(1.0, 0.65 + 0.35 * light, shade_amount);
	float fade = 1.0 - exp(-water_path(world_pos, CAMERA_POSITION_WORLD) * murk_per_metre);
	ALBEDO = mix(col, water_color, fade);
}
