// rain_streaks.gdshader - F3.4 (v0.3.3)
// Estrellas de lluvia para GPUParticles3D. Una sola llamada de dibujo por
// sistema; cuadrados billboard en Y (manual, como exige Godot 4) con alfa
// suave y sin profundidad de escritura, dentro del presupuesto
// budgets.*.gpu del contrato.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform vec4 streak_color : source_color = vec4(0.72, 0.82, 0.92, 0.75);
uniform float stretch = 2.2;

void vertex() {
	// Billboard en Y alrededor del origen de la particula (Godot 4 no tiene
	// render mode de billboard; se construye la base aqui).
	mat4 model = MODEL_MATRIX;
	vec3 scale = vec3(length(model[0].xyz), length(model[1].xyz), length(model[2].xyz));
	vec3 origin = model[3].xyz;
	vec3 to_camera = INV_VIEW_MATRIX[3].xyz - origin;
	to_camera.y = 0.0;
	float len = length(to_camera);
	vec3 forward = to_camera / max(len, 0.001);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, forward));
	VERTEX = vec3(VERTEX.x * scale.x, VERTEX.y * scale.y * stretch, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), vec4(origin, 1.0)
	);
	// Con skip_vertex_transform el motor no calcula POSITION: hay que
	// proyectar a mano desde la base billboard construida arriba.
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	float along = abs(UV.y - 0.5) * 2.0;
	float across = abs(UV.x - 0.5) * 2.0;
	float alpha = (1.0 - smoothstep(0.25, 1.0, along)) * (1.0 - smoothstep(0.55, 1.0, across));
	ALBEDO = streak_color.rgb;
	// COLOR.a transporta el desvanecimiento por vida util de la particula.
	ALPHA = alpha * streak_color.a * COLOR.a;
}
