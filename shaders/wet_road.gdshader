// wet_road.gdshader - F3.4 (v0.3.3)
// Asfalto mojado y charcos visibles de la via.
//
// Consume el ESTADO de F3.3 por uniforms: wetness/film de SurfaceWetnessModel
// para la pelicula y profundidades normalizadas de PuddleModel en `puddles`
// (x_m, z_m, radio_m, profundidad_0_1). La perdida de agarre, el hidroplaneo
// y el vadeo NO se simulan aqui: son F5.1.

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/rain_fx_common.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.2, 0.21, 0.22);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float wetness_value : hint_range(0.0, 1.0) = 0.0;
uniform float film_mm = 0.0;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;

// Charcos de PuddleModel: maximo 24 zonas (budgets.pc.max_puddle_zones).
uniform vec4 puddles[24];
uniform int puddle_count = 0;
uniform vec3 sky_tint : source_color = vec3(0.10, 0.14, 0.19);
uniform vec3 light_streak_color : source_color = vec3(0.95, 0.85, 0.6);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p_m = world_pos.xz;
	// Mascara de charcos a partir de profundidades de PuddleModel.
	float puddle = 0.0;
	float depth_norm = 0.0;
	for (int i = 0; i < 24; i++) {
		if (i >= puddle_count) {
			break;
		}
		vec4 zone = puddles[i];
		float dist = length(p_m - zone.xy);
		float mask = (1.0 - smoothstep(zone.z * 0.72, zone.z, dist)) * step(0.002, zone.w);
		if (mask > puddle) {
			puddle = mask;
			depth_norm = zone.w;
		}
	}

	float film = clamp(film_mm * 5.0, 0.0, 1.0);
	float wet = clamp(max(wetness_value, film), 0.0, 1.0);
	// El asfalto mojado oscurece y brilla; el charco casi espeja.
	vec3 wet_albedo = albedo * (1.0 - film * 0.55) * (1.0 - puddle * 0.62);
	float wet_rough = mix(roughness_value, 0.1, wet);
	float puddle_rough = mix(wet_rough, 0.035, puddle * clamp(0.35 + depth_norm, 0.0, 1.0));

	// Ondas de impacto de lluvia: normal viva sobre pelicula y charcos.
	float ripple = rfx_ripple_height(p_m * 2.2, TIME + time_offset, rain_intensity);
	float ripple2 = rfx_ripple_height(p_m * 5.1 + 13.0, TIME + time_offset, rain_intensity * 0.7);
	vec3 base_normal = normalize(world_normal);
	vec3 tangent = normalize(cross(base_normal, vec3(0.0, 0.0, 1.0)) + vec3(0.001));
	vec3 bitangent = normalize(cross(base_normal, tangent));
	vec3 perturbed = normalize(
		base_normal
			+ (tangent * ripple + bitangent * ripple2) * (0.02 + 0.12 * max(puddle, film * 0.6))
	);
	NORMAL = normalize((VIEW_MATRIX * vec4(perturbed, 0.0)).xyz);

	ALBEDO = wet_albedo;
	ROUGHNESS = clamp(puddle_rough, 0.03, 1.0);
	METALLIC = 0.0;
	// Reflejo de la luz de luna/letreros alargado sobre la pelicula (lookdev).
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(base_normal, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), view_normal), 0.0, 1.0), 4.0);
	SPECULAR = clamp(0.35 + wet * 0.4 + puddle * 0.25, 0.0, 1.0);
	ALBEDO += sky_tint * fresnel * (0.12 + 0.55 * max(puddle, wet * 0.5));
	ALBEDO += light_streak_color * fresnel * fresnel * (puddle * 0.45 + wet * 0.1);
}
