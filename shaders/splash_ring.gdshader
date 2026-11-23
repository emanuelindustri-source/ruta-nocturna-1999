// splash_ring.gdshader - F3.4 (v0.3.3)
// Salpicaduras de impacto sobre la via para GPUParticles3D. Un anillo suave
// aditivo por particula, con billboard manual a la camara (Godot 4); sin
// profundidad de escritura y sin simulacion (la lluvia es la de F3.3; esto
// solo la representa).

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform vec4 ring_color : source_color = vec4(0.72, 0.8, 0.88, 0.5);
uniform float ring_thickness : hint_range(0.01, 0.5) = 0.12;

void vertex() {
	// Billboard completo orientado a la camara, sobre el origen de la gota.
	mat4 model = MODEL_MATRIX;
	vec3 scale = vec3(length(model[0].xyz), length(model[1].xyz), length(model[2].xyz));
	vec3 origin = model[3].xyz;
	vec3 forward = normalize(INV_VIEW_MATRIX[3].xyz - origin + vec3(0.0, 0.0, 0.001));
	vec3 up_hint = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up_hint, forward));
	vec3 up = normalize(cross(forward, right));
	VERTEX = vec3(VERTEX.x * scale.x, VERTEX.y * scale.y, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), vec4(origin, 1.0)
	);
	// Con skip_vertex_transform el motor no calcula POSITION: hay que
	// proyectar a mano desde la base billboard construida arriba.
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec2 centered = UV - 0.5;
	float radius = length(centered) * 2.0;
	float ring = (1.0 - smoothstep(1.0 - ring_thickness, 1.0, radius))
		* smoothstep(0.45, 0.75, radius);
	ALBEDO = ring_color.rgb;
	ALPHA = ring * ring_color.a * COLOR.a;
}
