// wet_paint.gdshader - F3.4 (v0.3.3)
// Pintura, plastico y cromo del Esteem bajo lluvia.
//
// Consume el ESTADO de los modelos de F3.3 por uniforms (wetness/film de
// SurfaceWetnessModel, densidad/radio/desliz de DropletFlowModel): no simula.
// La fusion visual de gotas es procedural (rain_fx_common) tal como declara
// droplets.coalescence_note del contrato rain_surface_fx.json.

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/rain_fx_common.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.62, 0.58, 0.5);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.38;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.5;

// Estado de F3.3 (SurfaceWetnessModel).
uniform float wetness_value : hint_range(0.0, 1.0) = 0.0;
uniform float film_mm = 0.0;

// Estado de F3.3 (DropletFlowModel.get_instances / contadores).
uniform float drop_density : hint_range(0.0, 1.0) = 0.0;
uniform float drop_radius_mm = 1.0;
uniform float drop_scale = 2.4;
uniform float slide_speed_mm_s = 0.0;
uniform float trail_mm = 0.35;
uniform float runoff_rate = 0.0;

uniform vec2 flow_dir = vec2(0.0, -1.0);
uniform vec2 surface_size_m = vec2(1.0, 1.0);
uniform vec3 axis_u = vec3(1.0, 0.0, 0.0);
uniform vec3 axis_v = vec3(0.0, 1.0, 0.0);
uniform float time_offset = 0.0;

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
	if (drop_density > 0.001) {
		drops = rfx_droplet_field(
			p_mm, time_s, drop_density, max(drop_radius_mm, 0.05) * drop_scale, flow_dir,
			slide_speed_mm_s, trail_mm * drop_scale
		);
	}
	// La pelicula moja oscurece la albedo (absorcion) y afina la especular.
	float film_factor = clamp(film_mm * 6.0, 0.0, 0.5);
	vec3 wet_albedo = albedo * (1.0 - film_factor * 0.6);
	float wet_rough = mix(roughness_value, max(roughness_value * 0.25, 0.04), clamp(wetness_value, 0.0, 1.0));
	// Las gotas son mas lisas que la superficie, concentran el brillo y
	// oscurecen ligeramente su interior (fusion visual de vecinas).
	float droplet_gloss = drops.z * 0.8 + drops.w * 0.35;
	float final_rough = clamp(mix(wet_rough, 0.03, droplet_gloss), 0.02, 1.0);
	float droplet_shade = drops.z * (1.0 - drops.z) * 4.0;

	// Perturbacion de normal por gotas (base ortonormal derivada de axis_*).
	vec3 base_normal = normalize(world_normal);
	vec3 tangent = normalize(axis_u - base_normal * dot(base_normal, axis_u));
	vec3 bitangent = normalize(axis_v - base_normal * dot(base_normal, axis_v));
	vec3 perturbed = normalize(
		base_normal + (tangent * drops.x + bitangent * drops.y) * (0.35 + 0.45 * clamp(wetness_value, 0.0, 1.0))
	);
	NORMAL = normalize((VIEW_MATRIX * vec4(perturbed, 0.0)).xyz);

	ALBEDO = wet_albedo;
	ROUGHNESS = final_rough;
	METALLIC = metallic_value;
	SPECULAR = clamp(specular_value + droplet_gloss * 0.4 + wetness_value * 0.25, 0.0, 1.0);
	// Escurrido: finas estelas mas oscuras en el sentido del flujo; borde
	// brillante de la gota para que se lea a distancia.
	ALBEDO *= 1.0 - drops.w * 0.18 * (0.5 + runoff_rate) - drops.z * 0.12;
	ALBEDO += vec3(droplet_shade * 0.08);
}
