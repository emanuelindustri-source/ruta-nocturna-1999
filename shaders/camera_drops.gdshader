// camera_drops.gdshader - F3.4 (v0.3.3)
// Gotas de lluvia sobre la lente/parabrisas vistas desde la cabina. Quad de
// camara (una llamada de dibujo) con campo de gotas procedural y barrido del
// limpiaparabrisas en coordenadas de pantalla. Solo aspecto: la simulacion es
// la de F3.3 (uniforms).

shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

#include "res://shaders/rain_fx_common.gdshaderinc"

uniform float drop_density : hint_range(0.0, 1.0) = 0.0;
uniform float drop_radius_mm = 1.2;
uniform float slide_speed_mm_s = 60.0;
uniform float trail_mm = 0.45;
uniform float wetness_value : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;

uniform bool wiper_enabled = false;
uniform float wiper_sweep : hint_range(-1.0, 1.0) = 0.0;
uniform float wiper_wear : hint_range(0.0, 1.0) = 0.0;
uniform float wiper_efficiency = 0.94;
// H1 (F4.4): mascara del parabrisas proyectada desde su malla real. El quad de
// gotas de camara solo existe dentro del poligono visible; al girar la vista
// hacia la puerta el poligono sale de pantalla y las gotas desaparecen.
uniform bool mask_enabled = false;
uniform int mask_count = 0;
uniform vec2 mask_points[8];
uniform float mask_feather : hint_range(0.0, 0.2) = 0.015;
// Depuracion de lookdev (F3.4): 1.0 pinta el quad en rojo plano para validar
// colocacion y mezcla antes de depurar el campo de gotas. Siempre 0 en juego.
uniform float debug_flat : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (debug_flat > 0.5) {
		ALBEDO = vec3(1.0, 0.0, 0.0);
		ALPHA = 0.6;
	} else {
		if (mask_enabled) {
			bool inside = false;
			for (int i = 0; i < 8; i++) {
				if (i >= mask_count) {
					break;
				}
				vec2 a = mask_points[i];
				vec2 b = mask_points[(i + 1) % mask_count];
				if ((a.y > UV.y) != (b.y > UV.y)) {
					float x_cross = (b.x - a.x) * (UV.y - a.y) / (b.y - a.y) + a.x;
					if (UV.x < x_cross) {
						inside = !inside;
					}
				}
			}
			if (!inside) {
				discard;
			}
		}
		// Pantalla completa en mm aproximados (720p de referencia).
		vec2 p_mm = UV * vec2(320.0, 180.0);
		float time_s = TIME + time_offset;
		float density = drop_density;
		float swept = 0.0;
		if (wiper_enabled) {
			// Sector de barrido en pantalla: angulo desde la base inferior.
			vec2 pivot = vec2(160.0, -120.0);
			vec2 rel = p_mm - pivot;
			float angle = atan(rel.x, rel.y);
			float blade_angle = wiper_sweep * 1.05;
			// Zona ya recorrida desde el reposo hasta el angulo actual.
			float from_rest = 0.0;
			float to_now = blade_angle;
			float inside = smoothstep(min(from_rest, to_now) - 0.04, min(from_rest, to_now) + 0.06, angle)
				* (1.0 - smoothstep(max(from_rest, to_now) - 0.06, max(from_rest, to_now) + 0.04, angle));
			swept = clamp(inside, 0.0, 1.0);
			density *= 1.0 - swept * clamp(wiper_efficiency, 0.0, 1.0);
		}
		vec4 drops = vec4(0.0);
		if (density > 0.001) {
			drops = rfx_droplet_field(
				p_mm, time_s, density, max(drop_radius_mm, 0.05), vec2(0.0, -1.0),
				slide_speed_mm_s, trail_mm
			);
		}
		float streaks = 0.0;
		if (wiper_enabled && wiper_wear > 0.001) {
			streaks = pow(sin(p_mm.x * 0.14 + 0.6) * 0.5 + 0.5, 8.0) * swept * wiper_wear * 0.5;
		}
		float mask = clamp(drops.z * 0.85 + drops.w * 0.4 + streaks, 0.0, 1.0);
		// Borde sombreado de la gota + destello puntual (sin texturas externas).
		float rim = drops.z * (1.0 - drops.z) * 4.0;
		vec3 color = vec3(0.62, 0.7, 0.78) * (0.25 + 0.5 * wetness_value) + vec3(rim * 0.35);
		ALBEDO = color;
		ALPHA = mask * clamp(0.35 + 0.45 * wetness_value, 0.0, 0.9);
	}
}
