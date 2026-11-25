class_name LightningDirector
extends Node3D
## Rayos y truenos de F4.4: servicio de escena, no autoload.
##
## Escucha `EventBus.weather_lightning` (publicado por WeatherManager) y produce
## un destello de luz + un flash de pantalla accesible y un trueno sintetizado en
## runtime. No depende de AudioDirector ni de WeatherManager: solo consume el bus
## y el contrato `world.weather` para sus parámetros.
##
## Presupuesto: una luz (sin sombras) y un CanvasItem; 0 triángulos añadidos.

const CONTRACT_PATH := "res://data/schemas/world_weather.json"

var config: Dictionary = {}
var flash_light: DirectionalLight3D
var flash_overlay: ColorRect
var bolt_mesh: MeshInstance3D
var thunder_player: AudioStreamPlayer
var thunder_stream: AudioStreamWAV
var errors: PackedStringArray = []

var _flash_timer := 0.0
var _flash_duration := 0.18
var _double_timer := -1.0
var _double_gap := 0.09
var _pending: Array[Dictionary] = []
var _thunder_played := 0
var _max_flash_energy := 9.0
var _reduce_flashes := false
var _screen_alpha := 0.32
var _rng := RandomNumberGenerator.new()
var _seed := 1999


func _ready() -> void:
	_rng.seed = _seed
	_load_config()
	_reduce_flashes = bool(SettingsManager.get_value("accessibility", "reduce_flashes", false))
	_build_nodes()
	EventBus.weather_lightning.connect(_on_weather_lightning)
	print(
		"[LIGHTNING] ready lightning=%s thunder_samples=%d reduce_flashes=%s"
		% [
			str(bool(config.get("enabled", false))),
			thunder_stream.data.size() if thunder_stream != null else 0,
			str(_reduce_flashes),
		]
	)


func _load_config() -> void:
	if not FileAccess.file_exists(CONTRACT_PATH):
		errors.append("world_weather.json no disponible")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not (parsed is Dictionary):
		errors.append("world_weather.json inválido")
		return
	var document := parsed as Dictionary
	config = document.get("lightning", {}).duplicate(true)
	_flash_duration = float(config.get("flash_duration_s", 0.18))
	_double_gap = float(config.get("double_flash_gap_s", 0.09))
	_max_flash_energy = float(config.get("light_energy", 9.0))
	_screen_alpha = float(config.get("screen_flash_alpha", 0.32))


func _build_nodes() -> void:
	flash_light = DirectionalLight3D.new()
	flash_light.name = "LightningFlash"
	flash_light.light_color = Color(0.86, 0.9, 1.0)
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	flash_light.rotation_degrees = Vector3(-58.0, 32.0, 0.0)
	add_child(flash_light)

	var layer := CanvasLayer.new()
	layer.name = "LightningOverlay"
	add_child(layer)
	flash_overlay = ColorRect.new()
	flash_overlay.name = "ScreenFlash"
	flash_overlay.color = Color(0.82, 0.88, 1.0, 0.0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_overlay.offset_left = 0.0
	flash_overlay.offset_top = 0.0
	flash_overlay.offset_right = 0.0
	flash_overlay.offset_bottom = 0.0
	layer.add_child(flash_overlay)

	bolt_mesh = MeshInstance3D.new()
	bolt_mesh.name = "LightningBolt"
	bolt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt_mesh.visible = false
	var bolt_material := StandardMaterial3D.new()
	bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_material.albedo_color = Color(0.86, 0.93, 1.0, 1.0)
	bolt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bolt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bolt_material.no_depth_test = true
	bolt_mesh.material_override = bolt_material
	add_child(bolt_mesh)

	thunder_stream = build_thunder_stream()
	thunder_player = AudioStreamPlayer.new()
	thunder_player.name = "Thunder"
	thunder_player.stream = thunder_stream
	thunder_player.volume_db = -6.0
	add_child(thunder_player)


## Trueno procedural determinista: ruido filtrado con graves, un crack inicial
## y caída exponencial. Sin samples, sin APIs de audio de pago.
func build_thunder_stream() -> AudioStreamWAV:
	var thunder: Dictionary = config.get("thunder", {})
	var sample_rate := int(thunder.get("sample_rate", 22050))
	var duration := float(thunder.get("duration_s", 2.6))
	var rumble_hz := float(thunder.get("rumble_hz", 42.0))
	var crack_hz := float(thunder.get("crack_hz", 180.0))
	var decay := float(thunder.get("decay", 2.4))
	var gain := float(thunder.get("gain", 0.62))
	var sample_count := maxi(1, int(sample_rate * duration))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 41
	var lp := 0.0
	var lp2 := 0.0
	var phase_rumble := 0.0
	var phase_crack := 0.0
	for index in range(sample_count):
		var t := float(index) / float(sample_rate)
		var envelope := exp(-t * decay) * (1.0 - exp(-t * 90.0))
		var noise := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.035)
		lp2 = lerpf(lp2, lp, 0.08)
		phase_rumble += TAU * rumble_hz * (1.0 - 0.25 * t / duration) / float(sample_rate)
		phase_crack += TAU * crack_hz / float(sample_rate)
		var rumble := sin(phase_rumble) * 0.55 + sin(phase_rumble * 2.03) * 0.2
		var crack := sin(phase_crack) * exp(-t * 9.0) * 0.55
		var value := (lp2 * 1.8 + rumble * 0.6 + crack) * envelope * gain
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		data[index * 2] = sample & 0xFF
		data[index * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _on_weather_lightning(strike: Dictionary) -> void:
	trigger(strike)


## Dispara el destello y programa el trueno. Público para QA y pruebas.
func trigger(strike: Dictionary) -> void:
	if not bool(config.get("enabled", false)):
		return
	_flash_duration = float(strike.get("flash_duration_s", _flash_duration))
	_flash_timer = _flash_duration
	_flash_energy = float(strike.get("energy", _max_flash_energy))
	_double_gap = float(strike.get("gap_s", _double_gap))
	_double_timer = _double_gap if bool(strike.get("double_flash", false)) else -1.0
	_build_bolt(int(strike.get("index", 0)))
	_pending.append({
		"delay_s": float(strike.get("delay_s", 2.0)),
		"distance_km": float(strike.get("distance_km", 2.0)),
		"index": int(strike.get("index", 0)),
	})


var _flash_energy := 0.0


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		var ratio := _flash_timer / maxf(0.001, _flash_duration)
		apply_flash(_flash_energy * ratio)
	else:
		apply_flash(0.0)
	if _double_timer >= 0.0:
		_double_timer -= delta
		if _double_timer <= 0.0:
			_double_timer = -1.0
			_flash_timer = _flash_duration * 0.65
			apply_flash(_flash_energy * 0.8)
	for index in range(_pending.size() - 1, -1, -1):
		_pending[index]["delay_s"] = float(_pending[index]["delay_s"]) - delta
		if float(_pending[index]["delay_s"]) <= 0.0:
			_play_thunder(_pending[index])
			_pending.remove_at(index)
	if bolt_mesh != null:
		bolt_mesh.visible = _flash_timer > 0.0


## Rayo visible: una cinta procedural con 10 segmentos y tres ramas. Una sola
## llamada de dibujo y ~80 triángulos; no hay textura ni malla externa.
func _build_bolt(strike_index: int) -> void:
	if bolt_mesh == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		# Pruebas headless y QA sin cámara activa: rayo de referencia al frente.
		var fallback_basis := Basis.IDENTITY
		var fallback_origin := Vector3(0.0, 0.0, -150.0)
		_build_bolt_geometry(fallback_origin, fallback_basis, strike_index)
		return
	_build_bolt_geometry(camera.global_position + camera.global_transform.basis * Vector3(0.0, 0.0, -150.0), camera.global_transform.basis, strike_index)


func _build_bolt_geometry(origin: Vector3, basis: Basis, strike_index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 907 + strike_index * 37
	var mesh := ImmediateMesh.new()
	var material := bolt_mesh.material_override as Material
	var start := origin + basis * Vector3(-55.0, 85.0, 0.0)
	var end := origin + basis * Vector3(35.0, -55.0, 0.0)
	var right := basis.x.normalized()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	_add_bolt_ribbon(mesh, start, end, right, rng, 1.6, 11)
	for branch in range(3):
		var t := 0.25 + 0.22 * float(branch)
		var joint := start.lerp(end, t) + basis * Vector3(rng.randf_range(-8.0, 8.0), 0.0, 0.0)
		var tip := joint + basis * Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(-38.0, 12.0), 0.0)
		_add_bolt_ribbon(mesh, joint, tip, right, rng, 0.8, 5)
	mesh.surface_end()
	bolt_mesh.mesh = mesh
	bolt_mesh.visible = true


func _add_bolt_ribbon(
	mesh: ImmediateMesh, from: Vector3, to: Vector3, right: Vector3,
	rng: RandomNumberGenerator, width: float, segments: int
) -> void:
	var previous := from
	for index in range(1, segments + 1):
		var t := float(index) / float(segments)
		var point := from.lerp(to, t)
		if index < segments:
			var jitter := right * rng.randf_range(-4.5, 4.5) + Vector3.UP * rng.randf_range(-4.0, 4.0)
			point += jitter
		var half_previous := right * width * (1.0 - 0.35 * float(index - 1) / float(segments))
		var half_point := right * width * (1.0 - 0.35 * float(index) / float(segments))
		mesh.surface_add_vertex(previous - half_previous)
		mesh.surface_add_vertex(previous + half_previous)
		mesh.surface_add_vertex(point + half_point)
		mesh.surface_add_vertex(previous - half_previous)
		mesh.surface_add_vertex(point + half_point)
		mesh.surface_add_vertex(point - half_point)
		previous = point


func apply_flash(energy: float) -> void:
	if flash_light != null:
		flash_light.light_energy = maxf(0.0, energy)
	if flash_overlay != null:
		var factor := 1.0
		if _reduce_flashes:
			var reduced := float(
				config.get("accessibility_cue", {}).get("reduced_flash_alpha", 0.08)
			)
			factor = reduced / maxf(0.001, _screen_alpha)
		var alpha := clampf(energy / maxf(0.001, _max_flash_energy), 0.0, 1.0)
		flash_overlay.color = Color(0.82, 0.88, 1.0, alpha * _screen_alpha * factor)


func _play_thunder(entry: Dictionary) -> void:
	if thunder_player == null or thunder_stream == null:
		return
	var distance := clampf(float(entry.get("distance_km", 2.0)), 0.0, 10.0)
	thunder_player.volume_db = lerpf(-4.0, -22.0, distance / 10.0)
	thunder_player.pitch_scale = clampf(1.12 - distance * 0.04, 0.72, 1.12)
	thunder_player.play()
	_thunder_played += 1


func get_stats() -> Dictionary:
	return {
		"flashes": _thunder_played + _pending.size(),
		"thunder_played": _thunder_played,
		"pending_thunder": _pending.size(),
		"flash_energy": flash_light.light_energy if flash_light != null else 0.0,
		"screen_alpha": flash_overlay.color.a if flash_overlay != null else 0.0,
		"bolt_visible": bolt_mesh.visible if bolt_mesh != null else false,
		"bolt_built": bolt_mesh != null and bolt_mesh.mesh != null,
		"reduce_flashes": _reduce_flashes,
		"thunder_bytes": thunder_stream.data.size() if thunder_stream != null else 0,
		"errors": errors.size(),
	}
