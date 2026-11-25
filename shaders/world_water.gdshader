shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
// Superficie de agua visual de F4.3 (presets por bioma). Solo presentación:
// sin física, sin vadeo (F5.1) y sin clima simulado (F4.4).

uniform vec3 water_color : source_color = vec3(0.05, 0.11, 0.13);
uniform float water_roughness : hint_range(0.0, 1.0) = 0.12;
uniform float water_metallic : hint_range(0.0, 1.0) = 0.25;
uniform float wave_amplitude : hint_range(0.0, 2.0) = 0.12;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.35;

varying float v_shimmer;

void vertex() {
	float wave = sin(VERTEX.x * 0.12 + TIME * wave_speed) * cos(VERTEX.z * 0.1 + TIME * wave_speed * 0.8);
	VERTEX.y += wave * wave_amplitude;
	v_shimmer = wave * 0.5 + 0.5;
}

void fragment() {
	ALBEDO = water_color + vec3(0.018, 0.032, 0.038) * v_shimmer;
	ROUGHNESS = water_roughness;
	METALLIC = water_metallic;
	SPECULAR = 0.6;
}
