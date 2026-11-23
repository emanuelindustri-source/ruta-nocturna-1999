// wet_glass.gdshader - F3.4 (v0.3.3)
// Cristales del Esteem bajo lluvia: parabrisas con limpiaparabrisas y luneta
// y ventanillas sin el.
//
// Consume el ESTADO de F3.3 por uniforms (SurfaceWetnessModel, DropletFlowModel
// y WiperKinematics): gotas, escurrido, sector barrido y estela de goma
// gastada. No simula barrido ni humedad: solo los representa.

shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

#include "res://shaders/rain_fx_common.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.06, 0.07, 0.08);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.08;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.32;

// Estado de F3.3.
uniform float wetness_value : hint_range(0.0, 1.0) = 0.0;
uniform float film_mm = 0.0;
uniform float drop_density : hint_range(0.0, 1.0) = 0.0;
uniform float drop_radius_mm = 1.0;
uniform float drop_scale = 2.0;
uniform float slide_speed_mm_s = 0.0;
uniform float trail_mm = 0.35;

uniform vec2 flow_dir = vec2(0.0, -1.0);
uniform vec3 axis_u = vec3(1.0, 0.0, 0.0);
uniform vec3 axis_v = vec3(0.0, 1.0, 0.0);
uniform float time_offset = 0.0;

// WiperKinematics: pivotes y angulos en mm/radianes sobre el plano del cristal.
uniform bool wiper_enabled = false;
uniform vec2 wiper_pivot_l_mm = vec2(0.0);
uniform vec2 wiper_pivot_r_mm = vec2(0.0);
uniform float wiper_angle_l = 0.0;
uniform float wiper_angle_r = 0.0;
uniform float wiper_rest_l = 0.0;
uniform float wiper_rest_r = 0.0;
uniform float wiper_radius_mm = 460.0;
uniform float wiper_wear : hint_range(0.0, 1.0) = 0.0;
uniform float wiper_streak = 0.0;
uniform float wiper_efficiency = 0.94;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying vec3 world_normal;
varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p_mm = vec2(dot(obj_pos, axis_u), dot(obj_pos, axis_v)) * 1000.0;
	float time_s = TIME + time_offset;
	vec4 drops = vec4(0.0);
	float density = drop_density;
	// Sector barrido del ciclo actual: la goma lo limpia parcialmente.
	float wiped = 0.0;
	float blade = 0.0;
	if (wiper_enabled) {
		float sector_l = rfx_wiper_sector(
			p_mm, wiper_pivot_l_mm, wiper_rest_l, wiper_angle_l, wiper_radius_mm, 0.22
		);
		float sector_r = rfx_wiper_sector(
			p_mm, wiper_pivot_r_mm, wiper_rest_r, wiper_angle_r, wiper_radius_mm, 0.22
		);
		wiped = clamp(sector_l + sector_r, 0.0, 1.0);
		blade = max(
			rfx_wiper_blade(p_mm, wiper_pivot_l_mm, wiper_angle_l, wiper_radius_mm, 12.0),
			rfx_wiper_blade(p_mm, wiper_pivot_r_mm, wiper_angle_r, wiper_radius_mm, 12.0)
		);
		// La eficiencia de la goma deja residuo; la goma gastada deja estela.
		density *= 1.0 - wiped * clamp(wiper_efficiency, 0.0, 1.0);
	}
	if (density > 0.001) {
		drops = rfx_droplet_field(
			p_mm, time_s, density, max(drop_radius_mm, 0.05) * drop_scale, flow_dir,
			slide_speed_mm_s, trail_mm * drop_scale
		);
	}
	// Estelas verticales de goma gastada dentro del sector barrido.
	float streak_lines = 0.0;
	if (wiper_enabled && wiper_streak > 0.001) {
		float bands = sin(p_mm.x * 0.11 + 1.7) * 0.5 + 0.5;
		streak_lines = pow(bands, 6.0) * wiped * wiper_streak;
	}

	float droplet_mask = clamp(drops.z + drops.w * 0.5 + streak_lines * 0.4, 0.0, 1.0);
	// Refraccion leve de la escena a traves de gotas y pelicula.
	vec2 refract_offset = (drops.xy * 0.6 + vec2(0.0, drops.w * 0.25)) * 0.012
		* clamp(wetness_value + film_mm * 4.0, 0.0, 1.0);
	vec3 scene_color = textureLod(screen_tex, SCREEN_UV + refract_offset, 0.0).rgb;

	float film_alpha = clamp(base_alpha + wetness_value * 0.12 + film_mm * 1.2, 0.0, 0.85);
	float alpha = clamp(film_alpha + droplet_mask * 0.55 + blade * 0.25, 0.0, 1.0);
	vec3 tint = mix(albedo, vec3(0.75, 0.82, 0.88), droplet_mask * 0.55);
	ALBEDO = mix(scene_color * 0.35, tint, 0.55) + vec3(droplet_mask * 0.12);
	ROUGHNESS = mix(roughness_value, 0.03, droplet_mask);
	SPECULAR = 0.9;
	ALPHA = alpha;
}
