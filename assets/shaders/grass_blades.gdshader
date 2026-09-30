shader_type spatial;
// Grass tufts and reeds: darker at the root, lighter at the tip, gently swaying in the wind.
render_mode cull_disabled, unshaded;   // thin blades: flat colour (lighting from behind would turn them black)

uniform vec3 root_color : source_color = vec3(0.18, 0.32, 0.12);
uniform vec3 tip_color : source_color = vec3(0.55, 0.72, 0.35);
uniform float wind_strength = 0.06;
uniform float wind_speed = 1.2;

varying float height_frac;

void vertex() {
	height_frac = UV.y;   // 0 at the root, 1 at the tip
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * wind_speed + world.x * 0.7 + world.z * 0.5)
			+ 0.5 * sin(TIME * wind_speed * 2.3 + world.z * 1.3);
	VERTEX.x += sway * wind_strength * UV.y * UV.y;
	VERTEX.z += sway * wind_strength * 0.5 * UV.y * UV.y;
}

void fragment() {
	ALBEDO = mix(root_color, tip_color, height_frac);
}
