// rain_fx_common.gdshaderinc - F3.4 (v0.3.3)
// Funciones GLSL compartidas de la lluvia de produccion.
//
// La simulacion vive en GDScript (F3.3: SurfaceWetnessModel, DropletFlowModel,
// WiperKinematics, PuddleModel). Este include SOLO da forma visual a los datos
// ya calculados: gotas procedurales con fusion visual entre vecinas, estelas de
// escurrido y sector barrido del limpiaparabrisas. No integra ecuaciones de
// humedad ni de charcos: recibe sus resultados por uniforms.

// --- Hash determinista -----------------------------------------------------

float rfx_hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec2 rfx_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// --- Campo de gotas --------------------------------------------------------
// Coordenadas en milimetros sobre el plano de la superficie (x derecha, y arriba
// segun el contrato). `density` fracciona celdas con gota (0..1), `radius_mm`
// escala la celda, `flow` es la direccion de escurrido unitaria (contrato:
// flow_dir + deriva de viento), `slide_mm_s` la velocidad de desliz (de
// DropletFlowModel) y `trail` el ancho de estela (profile.trail_width_mm).
//
// Devuelve: xy = perturbacion de normal en plano, z = mascara de gota,
// w = mascara de estela de escurrido.

vec4 rfx_drop_layer(
	vec2 p_mm,
	float time_s,
	float density,
	float radius_mm,
	vec2 flow,
	float slide_mm_s,
	float trail_mm,
	float seed_offset
) {
	vec2 dir = flow;
	if (length(dir) < 0.001) {
		dir = vec2(0.0, -1.0);
	}
	dir = normalize(dir);
	vec2 perp = vec2(-dir.y, dir.x);
	// Giro para que el flujo sea +y y las celdas se alarguen con la estela.
	vec2 q = vec2(dot(p_mm, perp), dot(p_mm, dir));
	float cell = max(radius_mm * 2.8, 0.35);
	vec2 g = q / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	vec2 rnd = rfx_hash22(id + seed_offset);
	float present = step(1.0 - clamp(density, 0.0, 1.0), rfx_hash11(id.x * 71.3 + id.y * 137.9 + seed_offset));
	vec2 center = (rnd - 0.5) * 0.55;
	float slide_phase = fract(time_s * slide_mm_s / cell + rnd.y);
	// Las gotas que deslizan recorren la celda hacia abajo del flujo dejando estela.
	float moving = step(0.45, rnd.x);
	float drop_y = mix(center.y, 0.75 - slide_phase * 1.5, moving);
	vec2 delta = (f - vec2(center.x, drop_y)) * vec2(1.0, 1.15);
	float dist = length(delta);
	float edge = 0.22 + 0.1 * rnd.y;
	float droplet = (1.0 - smoothstep(edge * 0.45, edge, dist)) * present;
	vec2 normal_perturb = -delta / max(edge, 0.001) * droplet * 0.9;
	float trail_width = clamp(trail_mm / max(radius_mm, 0.01) * 0.35, 0.02, 0.35);
	float trail_mask = 0.0;
	if (moving > 0.0 && present > 0.5) {
		float behind = drop_y - f.y;
		trail_mask = (1.0 - smoothstep(trail_width * 0.3, trail_width, abs(f.x - center.x)))
			* smoothstep(0.0, 0.55, behind)
			* (1.0 - smoothstep(0.4, 1.6, behind))
			* 0.55;
	}
	return vec4(normal_perturb, droplet, trail_mask);
}

// Campo combinado: gotas grandes deslizantes + gotas micro estaticas.
// La fusion visual entre vecinas sale de la estela compartida y del solape de
// celdas alargadas; no hay comparaciones O(n2) ni simulacion.
vec4 rfx_droplet_field(
	vec2 p_mm,
	float time_s,
	float density,
	float radius_mm,
	vec2 flow,
	float slide_mm_s,
	float trail_mm
) {
	vec4 large = rfx_drop_layer(p_mm, time_s, density * 0.75, radius_mm, flow, slide_mm_s, trail_mm, 0.0);
	vec4 micro = rfx_drop_layer(
		p_mm + vec2(37.0, 91.0), time_s * 0.25, density * 0.9, max(radius_mm * 0.45, 0.08), flow,
		slide_mm_s * 0.15, trail_mm * 0.5, 19.7
	);
	vec4 result;
	result.xy = large.xy * 0.75 + micro.xy * 0.45;
	result.z = clamp(large.z + micro.z * 0.7, 0.0, 1.0);
	result.w = clamp(large.w + micro.w * 0.6, 0.0, 1.0);
	return result;
}

// --- Sector del limpiaparabrisas -------------------------------------------
// Angulos en radianes medidos en el plano de la superficie: 0 = referencia de
// pivote, positivo hacia el interior del cristal. Devuelve 1 dentro del sector
// recorrido desde `angle_start` hasta `angle_now` (zona limpia del ciclo).

float rfx_wiper_sector(vec2 p_mm, vec2 pivot_mm, float angle_start, float angle_now, float radius_mm, float soft) {
	vec2 rel = p_mm - pivot_mm;
	float radius = length(rel);
	if (radius > radius_mm * 1.05) {
		return 0.0;
	}
	float angle = atan(rel.y, rel.x);
	float span = angle_now - angle_start;
	if (abs(span) < 0.0005) {
		return 0.0;
	}
	// Angulo relativo al inicio, normalizado a (-pi, pi].
	float relative = mod(angle - angle_start + 3.14159265, 6.2831853) - 3.14159265;
	float lo = min(0.0, span);
	float hi = max(0.0, span);
	float inside = smoothstep(lo, lo + soft, relative) * (1.0 - smoothstep(hi - soft, hi, relative));
	float radial = 1.0 - smoothstep(radius_mm * 0.85, radius_mm * 1.05, radius);
	return clamp(inside * radial, 0.0, 1.0);
}

// Linea de la goma: franja fina en el angulo actual del brazo.
float rfx_wiper_blade(vec2 p_mm, vec2 pivot_mm, float angle_now, float radius_mm, float width_mm) {
	vec2 rel = p_mm - pivot_mm;
	float radius = length(rel);
	if (radius > radius_mm) {
		return 0.0;
	}
	float angle = atan(rel.y, rel.x);
	float diff = abs(mod(angle - angle_now + 3.14159265, 6.2831853) - 3.14159265);
	float arc = diff * max(radius, 1.0);
	return (1.0 - smoothstep(width_mm * 0.35, width_mm, arc))
		* (1.0 - smoothstep(radius_mm * 0.82, radius_mm, radius));
}

// --- Ruido de ondas de charco ----------------------------------------------

float rfx_ripple_height(vec2 p_m, float time_s, float rain) {
	float t = time_s * 1.4;
	float h = sin(dot(p_m, vec2(12.9898, 78.233)) + t * 2.1) * 0.5;
	h += sin(dot(p_m, vec2(39.3468, 11.135)) - t * 1.7) * 0.35;
	h += sin(dot(p_m, vec2(5.1234, 91.77)) + t * 3.1) * 0.25;
	return h * rain;
}
