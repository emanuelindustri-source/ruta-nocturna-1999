class_name RainFxController
extends Node3D
## Servicio de escena de la lluvia de producción (F3.4).
##
## Consume la matemática de F3.3 (`RainSurfaceSpec`, `SurfaceWetnessModel`,
## `DropletFlowModel`, `WiperKinematics`, `PuddleModel`) y la proyecta a
## uniforms de los shaders `shaders/wet_*.gdshader`. NO simula: los modelos
## de F3.3 siguen siendo la única fuente de humedad, gotas, barrido y charcos.
##
## No es un autoload: se instancia en las escenas (rebanada, cabina). WeatherManager
## sigue siendo el único autoload de clima; F4.4 inyectará lluvia real con
## `set_weather()`. Mientras tanto las escenas usan valores de lookdev declarados
## aquí y en la escena, nunca en el contrato.

const SPEC_PATH := "res://data/schemas/rain_surface_fx.json"
const WEATHER_CONTRACT_PATH := "res://data/schemas/world_weather.json"
const EXTERIOR_SPEC_PATH := "res://data/vehicle/exterior_spec.json"
const SHADER_PAINT := "res://shaders/wet_paint.gdshader"
const SHADER_GLASS := "res://shaders/wet_glass.gdshader"
const SHADER_ROAD := "res://shaders/wet_road.gdshader"

## Nodos del GLB del exterior -> panel del contrato rain_surface_fx.json.
const PANEL_BINDINGS := {
	"windshield": "windshield",
	"rear_window": "rear_window",
	"window_front_left": "side_glass",
	"window_front_right": "side_glass",
	"window_rear_left": "side_glass",
	"window_rear_right": "side_glass",
	"hood": "hood",
	"trunk_lid": "trunk_lid",
	"body_shell": "doors_and_fenders",
	"canopy": "doors_and_fenders",
	"door_front_left": "doors_and_fenders",
	"door_front_right": "doors_and_fenders",
	"door_rear_left": "doors_and_fenders",
	"door_rear_right": "doors_and_fenders",
	"bumper_front": "bumpers_and_trim",
	"bumper_front_intake": "bumpers_and_trim",
	"bumper_rear": "bumpers_and_trim",
	"grille": "bumpers_and_trim",
	"molding_left": "bumpers_and_trim",
	"molding_right": "bumpers_and_trim",
	"wiper_left": "bumpers_and_trim",
	"wiper_right": "bumpers_and_trim",
	"mirror_left_shell": "mirrors",
	"mirror_right_shell": "mirrors",
}

@export var vehicle_root_path: NodePath = NodePath("../EsteemExterior")
@export var road_paths: Array[NodePath] = [NodePath("../Road"), NodePath("../ShoulderLeft"), NodePath("../ShoulderRight")]
@export var camera_path: NodePath = NodePath("../Camera3D")
## Marco de coordenadas del parabrisas (corners_m de exterior_spec). En cabina
## es la raíz de la escena; las gotas solo se dibujan dentro de ese polígono.
@export var windshield_frame_path: NodePath = NodePath("..")
@export var bind_vehicle := true
@export var bind_road := true
@export var camera_drops := false
@export var enable_vfx := true
@export var wiper_mode := "low"
## Lookdev hasta que F4.4 conecte WeatherManager.
@export var demo_rain := 0.85
@export var demo_humidity := 0.92
@export var demo_wind_mps := 8.0
@export var demo_temperature_c := 19.0
@export var demo_wind_direction := Vector3(0.0, 0.0, 1.0)
## Zonas de charco visibles: (x_m, z_m, radio_m) en espacio de mundo; se
## emparejan en orden con PuddleModel.get_zone_ids().
@export var puddle_zones: Array[Vector3] = []
@export var manual_mode := false

var spec: RainSurfaceSpec
var wetness: SurfaceWetnessModel
var droplets_glass: DropletFlowModel
var droplets_paint: DropletFlowModel
var wipers: WiperKinematics
var puddles: PuddleModel
var errors: PackedStringArray = []

var warmup_done := false
var warmup_ms := 0.0
var fx_active := false

var _materials: Array[Dictionary] = []
var _road_materials: Array[ShaderMaterial] = []
var _wiper_pivots: Array[Node3D] = []
var _wiper_nodes: Array[Node3D] = []
var _wiper_basis_normals: Array[Vector3] = []
var _vfx: Node3D = null
var _camera: Camera3D = null
var _camera_overlay: MeshInstance3D = null
var _env := {"rain": 0.0, "humidity": 0.6, "wind": 2.0, "temperature": 19.0}
var _camera_mask: Dictionary = {}
var _windshield_corners: Array = []
var _mask_polygon := PackedVector2Array()
var _using_windshield_mesh := false


func _ready() -> void:
	configure()
	if not manual_mode:
		set_process(true)
	else:
		set_process(false)


func configure() -> bool:
	errors.clear()
	spec = RainSurfaceSpec.new()
	if not spec.load_spec():
		errors.append_array(spec.errors)
		return false
	wetness = SurfaceWetnessModel.new()
	if not wetness.configure(spec):
		errors.append_array(wetness.errors)
		return false
	droplets_glass = DropletFlowModel.new()
	if not droplets_glass.configure(spec, "glass", "windshield"):
		errors.append_array(droplets_glass.errors)
		return false
	droplets_paint = DropletFlowModel.new()
	if not droplets_paint.configure(spec, "paint", "hood"):
		errors.append_array(droplets_paint.errors)
		return false
	wipers = WiperKinematics.new()
	if not wipers.configure(spec):
		errors.append_array(wipers.errors)
		return false
	puddles = PuddleModel.new()
	if not puddles.configure(spec, true):
		errors.append_array(puddles.errors)
		return false
	wipers.set_mode(wiper_mode)
	_camera = get_node_or_null(camera_path) as Camera3D
	if bind_vehicle:
		_bind_vehicle()
		_bind_wipers()
	if bind_road:
		_bind_road()
	if enable_vfx:
		_setup_vfx()
	if camera_drops:
		_load_camera_mask()
		_setup_camera_overlay()
	set_weather(demo_rain, demo_humidity, demo_wind_mps, demo_temperature_c)
	var warmup := RainFxWarmup.run(self)
	warmup_done = bool(warmup.get("done", false))
	warmup_ms = float(warmup.get("ms", 0.0))
	fx_active = warmup_done
	print(
		"[RAINFX] READY panels=%d materials=%d road=%d wipers=%d puddle_zones=%d warmup=%s"
		% [
			wetness.panels.size(), _materials.size(), _road_materials.size(), _wiper_pivots.size(),
			puddle_zones.size(), str(warmup_done),
		]
	)
	_update_uniforms()
	return errors.is_empty()


## Fuente de lluvia: F4.4 conecta WeatherManager aquí. Sin lluvia real todavía.
func set_weather(rain: float, humidity: float, wind_mps: float, temperature_c: float) -> void:
	_env["rain"] = clampf(rain, 0.0, 1.0)
	_env["humidity"] = clampf(humidity, 0.0, 1.0)
	_env["wind"] = clampf(wind_mps, 0.0, 25.0)
	_env["temperature"] = temperature_c


func get_weather() -> Dictionary:
	return _env.duplicate()


func _process(delta: float) -> void:
	if manual_mode:
		return
	step_models(delta)
	_update_uniforms()
	_update_wiper_meshes()
	_update_vfx()


## Paso manual para pruebas deterministas (rain_fx_test.gd).
func step_models(delta: float) -> void:
	var rain := float(_env["rain"])
	wetness.step(delta, rain, float(_env["humidity"]), float(_env["wind"]), float(_env["temperature"]))
	droplets_glass.step(delta, wetness.get_wetness("windshield"), rain, float(_env["wind"]))
	droplets_paint.step(delta, wetness.get_wetness("hood"), rain, float(_env["wind"]))
	wipers.step(delta, droplets_glass)
	puddles.step(
		delta, rain, float(_env["humidity"]), float(_env["wind"]), float(_env["temperature"]),
		wetness.get_absorber_runoff()
	)


## Refresco público para pruebas en modo manual.
func refresh_uniforms() -> void:
	_update_uniforms()
	_update_wiper_meshes()


# --- Binding de materiales --------------------------------------------------


func _bind_vehicle() -> void:
	_materials.clear()
	var vehicle := get_node_or_null(vehicle_root_path) as Node3D
	if vehicle == null:
		errors.append("vehicle_root:%s" % vehicle_root_path)
		return
	for node_name in PANEL_BINDINGS:
		var panel_id: String = PANEL_BINDINGS[node_name]
		var mesh_instance := _find_mesh(vehicle, node_name)
		if mesh_instance == null:
			continue
		var panel: Dictionary = wetness.get_panel(panel_id)
		if panel.is_empty():
			continue
		var class_id := str(panel.get("class_id", "paint"))
		var base := mesh_instance.get_active_material(0)
		var material := _make_surface_material(class_id, panel, mesh_instance, base)
		if material == null:
			continue
		mesh_instance.material_override = material
		_materials.append({
			"node": mesh_instance,
			"material": material,
			"panel_id": panel_id,
			"class_id": class_id,
			"is_glass": class_id == "glass",
			"is_windshield": node_name == "windshield",
			"basis": _surface_basis(mesh_instance, panel),
		})
	print("[RAINFX] Materiales de superficie aplicados: %d" % _materials.size())


func _make_surface_material(
	class_id: String, panel: Dictionary, mesh_instance: MeshInstance3D, base: Material
) -> ShaderMaterial:
	var is_glass := class_id == "glass"
	var shader := load(SHADER_GLASS if is_glass else SHADER_PAINT) as Shader
	if shader == null:
		errors.append("shader:%s" % (SHADER_GLASS if is_glass else SHADER_PAINT))
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	var albedo := Color(0.5, 0.5, 0.5)
	var roughness := 0.5
	var metallic := 0.0
	var specular := 0.5
	if base is StandardMaterial3D:
		var std := base as StandardMaterial3D
		albedo = std.albedo_color
		roughness = std.roughness
		metallic = std.metallic
		specular = std.metallic_specular
	material.set_shader_parameter("albedo", Vector3(albedo.r, albedo.g, albedo.b))
	material.set_shader_parameter("roughness_value", roughness)
	material.set_shader_parameter("metallic_value", metallic)
	material.set_shader_parameter("specular_value", specular)
	material.set_shader_parameter("surface_size_m", panel.get("surface_size_m", Vector2.ONE))
	# Desfase determinista por superficie (sin RNG: la semilla es el id).
	material.set_shader_parameter("time_offset", float(str(panel.get("id", "")).hash() % 997) * 0.041)
	var basis := _surface_basis(mesh_instance, panel)
	material.set_shader_parameter("axis_u", basis["u"])
	material.set_shader_parameter("axis_v", basis["v"])
	material.set_shader_parameter("flow_dir", basis["flow"])
	return material


func _surface_basis(mesh_instance: MeshInstance3D, panel: Dictionary) -> Dictionary:
	# Base ortonormal (u, v) en espacio de objeto: u = derecha del vehículo
	# proyectada, v = arriba (o atrás en capó/techo) proyectada. La normal se
	# obtiene de la malla. El flujo real es la proyección de gravedad + viento.
	var mesh := mesh_instance.mesh
	var normal := Vector3.UP
	var best_area := 0.0
	if mesh is ArrayMesh:
		var faces := (mesh as ArrayMesh).get_faces()
		var index := 0
		var acc := Vector3.ZERO
		while index + 2 < faces.size():
			var a := faces[index]
			var b := faces[index + 1]
			var c := faces[index + 2]
			var cross := (b - a).cross(c - a)
			var area := cross.length()
			if area > best_area:
				best_area = area
				normal = cross.normalized()
			acc += cross
			index += 3
		if best_area <= 0.0 and acc.length_squared() > 0.0:
			normal = acc.normalized()
	var to_obj := mesh_instance.global_transform.basis.inverse()
	var right: Vector3 = to_obj * Vector3.RIGHT
	var up_hint: Vector3 = to_obj * (Vector3(0.0, 1.0, 0.0) if float(panel.get("flow_dir", [0.0, -1.0])[1]) < 0.0 else Vector3(0.0, 0.0, 1.0))
	var u := right - normal * normal.dot(right)
	if u.length_squared() < 0.01:
		u = up_hint - normal * normal.dot(up_hint)
	u = u.normalized()
	var v := normal.cross(u)
	if v.length_squared() < 0.0001:
		v = up_hint
	v = v.normalized()
	if v.dot(up_hint) < 0.0:
		v = -v
	# Flujo: gravedad + deriva de viento, proyectado sobre el plano.
	var wind_dir := demo_wind_direction.normalized()
	var flow_world := Vector3(0.0, -1.0, 0.0) + wind_dir * float(_env.get("wind", 2.0)) * 0.35
	var flow_obj: Vector3 = to_obj * flow_world
	var flow := Vector2(flow_obj.dot(u), flow_obj.dot(v))
	if flow.length_squared() < 0.0004:
		flow = Vector2(0.0, -1.0)
	else:
		flow = flow.normalized()
	return {"u": u, "v": v, "n": normal, "flow": flow}


func _bind_road() -> void:
	_road_materials.clear()
	for path in road_paths:
		var mesh_instance := get_node_or_null(path) as MeshInstance3D
		if mesh_instance == null:
			continue
		var base := mesh_instance.get_active_material(0)
		var material := ShaderMaterial.new()
		material.shader = load(SHADER_ROAD) as Shader
		var albedo := Color(0.2, 0.21, 0.22)
		var roughness := 0.92
		if base is StandardMaterial3D:
			albedo = (base as StandardMaterial3D).albedo_color
			roughness = (base as StandardMaterial3D).roughness
		material.set_shader_parameter("albedo", Vector3(albedo.r, albedo.g, albedo.b))
		material.set_shader_parameter("roughness_value", roughness)
		material.set_shader_parameter("puddle_count", 0)
		mesh_instance.material_override = material
		_road_materials.append(material)


func _bind_wipers() -> void:
	_wiper_pivots.clear()
	_wiper_nodes.clear()
	_wiper_basis_normals.clear()
	var vehicle := get_node_or_null(vehicle_root_path) as Node3D
	if vehicle == null:
		return
	var wiper_entries: Array = spec.section("wiper").get("wipers", [])
	var windshield := _find_mesh(vehicle, "windshield")
	var plane_normal := Vector3(0.0, 0.6, -0.85)
	if windshield != null and windshield.mesh is ArrayMesh:
		var faces := (windshield.mesh as ArrayMesh).get_faces()
		if faces.size() >= 3:
			var computed := (faces[1] - faces[0]).cross(faces[2] - faces[0])
			if computed.length_squared() > 0.000001:
				plane_normal = (windshield.global_transform.basis * computed).normalized()
	# Normal de giro: u × v con u = derecha y v = arriba (convención del contrato).
	var u_world: Vector3 = (vehicle.global_transform.basis * Vector3.RIGHT).normalized()
	var v_world: Vector3 = (plane_normal.cross(u_world)).normalized()
	if v_world.dot(Vector3.UP) < 0.0:
		v_world = -v_world
	var basis_normal: Vector3 = u_world.cross(v_world).normalized()
	for entry in wiper_entries:
		if not (entry is Dictionary):
			continue
		var node_hint := str(entry.get("node_hint", ""))
		var wiper_node := _find_mesh(vehicle, node_hint)
		if wiper_node == null:
			continue
		var pivot_values: Array = entry.get("pivot_m", [0.0, 1.0, -0.7])
		var pivot_local := Vector3(
			float(pivot_values[0]), float(pivot_values[1]), float(pivot_values[2])
		)
		var pivot := Node3D.new()
		pivot.name = "%s_pivot_rainfx" % node_hint
		var parent := wiper_node.get_parent()
		parent.add_child(pivot)
		pivot.global_position = vehicle.to_global(pivot_local)
		wiper_node.reparent(pivot, true)
		_wiper_pivots.append(pivot)
		_wiper_nodes.append(wiper_node)
		# La rotación se aplica en el espacio del padre del pivote.
		_wiper_basis_normals.append(parent.global_transform.basis.inverse() * basis_normal)
	print("[RAINFX] Escobillas animadas: %d" % _wiper_pivots.size())


func _find_mesh(root: Node, node_name: String) -> MeshInstance3D:
	if root.name == node_name and root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found := _find_mesh(child, node_name)
		if found != null:
			return found
	return null


# --- Uniforms ---------------------------------------------------------------


func _droplet_stats(field: DropletFlowModel) -> Dictionary:
	var instances := field.get_instances()
	var active := field.count
	var radius_sum := 0.0
	var speed_sum := 0.0
	var sliding := 0.0
	var sample := mini(active, 256)
	for index in range(sample):
		var cursor := index * 6
		radius_sum += instances[cursor + 2]
		var speed := Vector2(instances[cursor + 3], instances[cursor + 4]).length()
		speed_sum += speed
		if int(instances[cursor + 5]) == DropletFlowModel.STATE_SLIDING:
			sliding += 1.0
	var capacity := maxf(1.0, float(field.max_droplets))
	return {
		# Mapeo de lookdev: la densidad visual representa la población de gotas
		# del modelo (F3.3) con la curva del campo procedural; no es simulación.
		"density": clampf(float(active) / capacity * 12.0, 0.0, 1.0),
		"radius_mm": maxf(0.35, radius_sum / maxf(1.0, float(sample))),
		"speed_mm_s": speed_sum / maxf(1.0, float(sample)) * 1000.0,
		"sliding": sliding / maxf(1.0, float(sample)),
		"runoff_ml": field.get_runoff_ml(),
	}


func _update_uniforms() -> void:
	var glass_stats := _droplet_stats(droplets_glass)
	var paint_stats := _droplet_stats(droplets_paint)
	for entry in _materials:
		var material: ShaderMaterial = entry["material"]
		var panel_id: String = entry["panel_id"]
		var profile_id := "glass" if entry["is_glass"] else "paint"
		var stats := glass_stats if entry["is_glass"] else paint_stats
		var profile := spec.droplet_profile(profile_id)
		var wetness_value := wetness.get_wetness(panel_id)
		var nucleation := float(profile.get("nucleation_wetness", 0.1))
		var gate := clampf(
			(wetness_value - nucleation) / maxf(0.001, 1.0 - nucleation), 0.0, 1.0
		)
		material.set_shader_parameter("wetness_value", wetness_value)
		material.set_shader_parameter("film_mm", wetness.get_film_mm(panel_id))
		material.set_shader_parameter("drop_density", float(stats["density"]) * gate)
		material.set_shader_parameter("drop_radius_mm", maxf(0.15, float(stats["radius_mm"])))
		material.set_shader_parameter("slide_speed_mm_s", float(stats["speed_mm_s"]))
		material.set_shader_parameter("trail_mm", float(profile.get("trail_width_mm", 0.35)))
		material.set_shader_parameter("runoff_rate", clampf(float(stats["runoff_ml"]) * 0.4, 0.0, 1.0))
		if entry["is_windshield"]:
			var entries: Array = spec.section("wiper").get("wipers", [])
			var left: Dictionary = entries[0] if entries.size() > 0 else {}
			var right: Dictionary = entries[1] if entries.size() > 1 else {}
			material.set_shader_parameter("wiper_enabled", true)
			material.set_shader_parameter("wiper_angle_l", deg_to_rad(wipers.get_angle(0)))
			material.set_shader_parameter("wiper_angle_r", deg_to_rad(wipers.get_angle(1)))
			material.set_shader_parameter("wiper_rest_l", deg_to_rad(float(left.get("rest_angle_deg", 180.0))))
			material.set_shader_parameter("wiper_rest_r", deg_to_rad(float(right.get("rest_angle_deg", 0.0))))
			material.set_shader_parameter(
				"wiper_radius_mm", float(left.get("blade_length_m", 0.46)) * 1000.0
			)
			material.set_shader_parameter("wiper_wear", wipers.get_wear())
			material.set_shader_parameter("wiper_streak", wipers.get_streak_factor())
			material.set_shader_parameter("wiper_efficiency", wipers.get_clearing_efficiency())
			_set_windshield_pivots(material)
	for material in _road_materials:
		material.set_shader_parameter("wetness_value", wetness.get_wetness("asphalt_crown"))
		material.set_shader_parameter("film_mm", wetness.get_film_mm("asphalt_crown"))
		material.set_shader_parameter("rain_intensity", float(_env["rain"]))
		_set_puddle_uniforms(material)
	if _camera != null and camera_drops:
		_update_camera_drops(glass_stats)


func _set_windshield_pivots(material: ShaderMaterial) -> void:
	# Pivotes en mm del espacio absoluto de la superficie (mismo marco que el
	# campo de gotas del shader: proyección sobre axis_u/axis_v del parabrisas).
	var entries: Array = spec.section("wiper").get("wipers", [])
	var basis := {}
	var windshield: MeshInstance3D = null
	for entry in _materials:
		if entry["is_windshield"]:
			basis = entry["basis"]
			windshield = entry["node"]
			break
	if basis.is_empty() or windshield == null:
		return
	var u: Vector3 = basis["u"]
	var v: Vector3 = basis["v"]
	var vehicle := get_node_or_null(vehicle_root_path) as Node3D
	if vehicle == null:
		return
	var pivots_mm: Array[Vector2] = []
	for index in range(mini(2, entries.size())):
		var entry: Dictionary = entries[index]
		var pivot_values: Array = entry.get("pivot_m", [0.0, 1.0, -0.7])
		var pivot_world := vehicle.to_global(
			Vector3(float(pivot_values[0]), float(pivot_values[1]), float(pivot_values[2]))
		)
		var pivot_obj: Vector3 = (windshield as MeshInstance3D).to_local(pivot_world)
		pivots_mm.append(Vector2(pivot_obj.dot(u), pivot_obj.dot(v)) * 1000.0)
	if pivots_mm.size() == 2:
		material.set_shader_parameter("wiper_pivot_l_mm", pivots_mm[0])
		material.set_shader_parameter("wiper_pivot_r_mm", pivots_mm[1])


func _set_puddle_uniforms(material: ShaderMaterial) -> void:
	var zone_ids := puddles.get_zone_ids()
	var packed := PackedVector4Array()
	var count := 0
	for index in range(mini(zone_ids.size(), 24)):
		if index >= puddle_zones.size():
			continue
		var zone := puddles.get_zone(zone_ids[index])
		if zone.is_empty():
			continue
		var depth := float(zone["depth_mm"])
		if depth <= 0.0 or not bool(zone["visible"]):
			continue
		var position := puddle_zones[index]
		var archetype: Dictionary = zone["archetype"]
		var capacity := maxf(0.001, float(archetype.get("capacity_mm", 1.0)))
		var radius := sqrt(maxf(0.01, float(zone["area_m2"])) / PI)
		packed.append(Vector4(position.x, position.z, radius, clampf(depth / capacity, 0.0, 1.0)))
		count += 1
	material.set_shader_parameter("puddles", packed)
	material.set_shader_parameter("puddle_count", count)


func _update_camera_drops(stats: Dictionary) -> void:
	var overlay := _camera_overlay
	if overlay == null:
		return
	var material := overlay.material_override as ShaderMaterial
	if material == null:
		return
	var wetness_value := wetness.get_wetness("windshield")
	material.set_shader_parameter("wetness_value", wetness_value)
	material.set_shader_parameter("drop_density", float(stats["density"]))
	material.set_shader_parameter("drop_radius_mm", maxf(0.6, float(stats["radius_mm"]) * 3.0))
	material.set_shader_parameter("slide_speed_mm_s", float(stats["speed_mm_s"]))
	material.set_shader_parameter("trail_mm", 0.45)
	var entries: Array = spec.section("wiper").get("wipers", [])
	var left: Dictionary = entries[0] if not entries.is_empty() else {}
	var rest := float(left.get("rest_angle_deg", 180.0))
	var sweep := float(left.get("sweep_delta_deg", -100.0))
	var angle := wipers.get_angle(0)
	var progress := clampf((angle - rest) / (sweep if absf(sweep) > 0.01 else 1.0), 0.0, 1.0)
	material.set_shader_parameter("wiper_enabled", wipers.get_mode() != "off")
	material.set_shader_parameter("wiper_sweep", progress * 2.0 - 1.0)
	material.set_shader_parameter("wiper_wear", wipers.get_wear())
	material.set_shader_parameter("wiper_efficiency", wipers.get_clearing_efficiency())
	if _using_windshield_mesh:
		overlay.visible = wetness_value > 0.02 or float(_env["rain"]) > 0.02
		return
	_update_camera_mask(material)
	var has_mask := _mask_polygon.size() >= 3
	var mask_active := bool(_camera_mask.get("enabled", true)) and has_mask
	overlay.visible = mask_active and (wetness_value > 0.02 or float(_env["rain"]) > 0.02)


## Calcula el polígono del parabrisas proyectado y lo envía al shader (H1).
func _update_camera_mask(material: ShaderMaterial) -> void:
	_mask_polygon = PackedVector2Array()
	material.set_shader_parameter("mask_enabled", false)
	material.set_shader_parameter("mask_count", 0)
	if not bool(_camera_mask.get("enabled", true)) or _camera == null or _windshield_corners.is_empty():
		return
	var frame := get_node_or_null(windshield_frame_path) as Node3D
	if frame == null:
		frame = get_parent() as Node3D
	var screen := WindshieldMask.project_corners(_camera, frame, _windshield_corners)
	if screen.size() < 3:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var max_points := mini(
		int(_camera_mask.get("max_points", 8)), WindshieldMask.MAX_POINTS
	)
	_mask_polygon = WindshieldMask.convex_hull_uv(screen, viewport_size, max_points)
	if _mask_polygon.size() < 3:
		return
	var packed := PackedVector2Array()
	packed.resize(WindshieldMask.MAX_POINTS)
	for index in range(WindshieldMask.MAX_POINTS):
		packed[index] = _mask_polygon[index] if index < _mask_polygon.size() else Vector2.ZERO
	material.set_shader_parameter("mask_points", packed)
	material.set_shader_parameter("mask_count", _mask_polygon.size())
	material.set_shader_parameter("mask_feather", float(_camera_mask.get("feather", 0.015)))
	material.set_shader_parameter("mask_enabled", true)


func _load_camera_mask() -> void:
	_camera_mask = {}
	_windshield_corners = []
	var contract := _read_json(WEATHER_CONTRACT_PATH)
	_camera_mask = contract.get("camera_mask", {}).duplicate(true)
	var exterior := _read_json(EXTERIOR_SPEC_PATH)
	for panel in exterior.get("glass_panels", []):
		if str(panel.get("id", "")) == "windshield":
			_windshield_corners = panel.get("corners_m", []).duplicate(true)
			break
	if _camera_mask.is_empty():
		_camera_mask = {"enabled": true, "max_points": 8, "feather": 0.015}
	print(
		"[RAINFX] MASK enabled=%s corners=%d max_points=%d"
		% [str(bool(_camera_mask.get("enabled", false))), _windshield_corners.size(), int(_camera_mask.get("max_points", 8))]
	)


## Estado de la máscara para pruebas y QA (H1).
func get_camera_mask() -> Dictionary:
	var vertices := 0
	if _using_windshield_mesh and _camera_overlay != null and _camera_overlay.mesh is ArrayMesh:
		var arrays: Array = (_camera_overlay.mesh as ArrayMesh).surface_get_arrays(0)
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			vertices = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return {
		"polygon": _mask_polygon,
		"points": _mask_polygon.size(),
		"corners": _windshield_corners.size(),
		"enabled": bool(_camera_mask.get("enabled", false)),
		"mode": "windshield_mesh" if _using_windshield_mesh else "screen_mask",
		"mesh_vertices": vertices,
		"overlay_visible": _camera_overlay.visible if _camera_overlay != null else false,
	}


# --- Animación de escobillas ------------------------------------------------


func _update_wiper_meshes() -> void:
	for index in range(_wiper_pivots.size()):
		var pivot := _wiper_pivots[index]
		if pivot == null:
			continue
		var entries: Array = spec.section("wiper").get("wipers", [])
		if index >= entries.size():
			continue
		var entry: Dictionary = entries[index]
		var rest := float(entry.get("rest_angle_deg", 0.0))
		var delta_deg := wipers.get_angle(index) - rest
		var normal := _wiper_basis_normals[index]
		pivot.basis = Basis(normal, deg_to_rad(delta_deg))


# --- VFX --------------------------------------------------------------------


func _setup_vfx() -> void:
	var vfx_script := load("res://src/weather/rain_vfx.gd") as Script
	if vfx_script == null:
		errors.append("rain_vfx.gd")
		return
	_vfx = Node3D.new()
	_vfx.name = "RainVFX"
	_vfx.set_script(vfx_script)
	add_child(_vfx)
	_vfx.call("build", _camera)


func _update_vfx() -> void:
	if _vfx == null:
		return
	_vfx.call("update_fx", float(_env["rain"]), float(_env["wind"]), _camera)


## Gotas sobre el parabrisas (cabina): malla real del panel con profundidad.
## Si no hay esquinas disponibles, cae al quad de cámara con máscara de pantalla.
func _setup_camera_overlay() -> void:
	if _windshield_corners.size() == 4:
		_setup_windshield_mesh()
		return
	var overlay := MeshInstance3D.new()
	overlay.name = "CameraDrops"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 1.4)
	overlay.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/camera_drops.gdshader") as Shader
	material.set_shader_parameter("time_offset", 7.3)
	material.set_shader_parameter("mask_enabled", false)
	material.set_shader_parameter("mask_count", 0)
	overlay.material_override = material
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _camera != null:
		_camera.add_child(overlay)
		overlay.position = Vector3(0.0, 0.0, -0.6)
	else:
		add_child(overlay)
	_camera_overlay = overlay


## Malla de gotas sobre la geometría real del parabrisas: el salpicadero y los
## pilares la ocluyen con el depth buffer, así que nunca hay gotas «dentro» del
## habitáculo. Sustituye la máscara de pantalla de H1 cuando hay esquinas.
func _setup_windshield_mesh() -> void:
	var frame := get_node_or_null(windshield_frame_path) as Node3D
	if frame == null:
		frame = get_parent() as Node3D
	if frame == null:
		return
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	for corner in _windshield_corners:
		vertices.append(Vector3(float(corner[0]), float(corner[1]), float(corner[2])))
	uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var normal := (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).normalized()
	for _index in range(4):
		normals.append(normal)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var overlay := MeshInstance3D.new()
	overlay.name = "WindshieldDrops"
	overlay.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/camera_drops.gdshader") as Shader
	material.set_shader_parameter("time_offset", 7.3)
	material.set_shader_parameter("mask_enabled", false)
	material.set_shader_parameter("mask_count", 0)
	overlay.material_override = material
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(overlay)
	overlay.top_level = true
	overlay.global_transform = frame.global_transform
	_camera_overlay = overlay
	_using_windshield_mesh = true
	print("[RAINFX] WindshieldDrops vertices=4 depth_test=true")


# --- Medición (F3.4 deja evidencia; la medición completa en ruta/dispositivo es F3.5) ---


func get_perf_snapshot() -> Dictionary:
	return {
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
	}


## Proyección de coste GPU de los VFX añadidos (estimación documentada; la
## medición GPU real en dispositivo es F3.5/F10.1).
func estimate_gpu_budget() -> Dictionary:
	var added_draw_calls := 0
	var overdraw_layers := 0
	var fill_percent := 0.0
	if enable_vfx:
		added_draw_calls += 2  # estrellas de lluvia + salpicaduras
		overdraw_layers += 2
		fill_percent += 3.0
	if camera_drops:
		added_draw_calls += 1  # quad de gotas sobre cámara
		overdraw_layers += 1
		fill_percent += 3.0
	return {
		"added_draw_calls": added_draw_calls,
		"overdraw_layers": overdraw_layers,
		"fill_percent": fill_percent,
	}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
