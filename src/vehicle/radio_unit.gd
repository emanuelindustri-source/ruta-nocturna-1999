class_name CabinRadio
extends Node
## Radio cassette procedural de la cabina.
##
## No usa samples ni musica de terceros: genera un tono de estacion y ruido
## determinista con AudioStreamGenerator. La calidad de recepcion depende de la
## antena; apagada no suena. La musica definitiva y los buses de audio son F8.

signal state_changed(power_on: bool, band: String, station: float, volume: int)

const BAND_AM := "AM"
const BAND_FM := "FM"

var power_on := false
var band := BAND_AM
var station_index := 0
var volume_step := 4
var volume_steps := 8
var stations: Dictionary = {"AM": [], "FM": []}
var antenna_extension := 0.0
var signal_strength := 0.0
var static_level := 1.0

var _bands: Array = [BAND_AM, BAND_FM]
var _mix_rate := 22050.0
var _tone_hz := 220.0
var _static_floor := 0.03
var _static_gain := 0.28
var _signal_extended := 0.95
var _signal_retracted := 0.35
var _seek_wrap := true

var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _rng_state := 0x1A2B3C4D


func configure(radio_spec: Dictionary) -> void:
	stations = radio_spec.get("stations", {"AM": [], "FM": []}).duplicate(true)
	_bands = radio_spec.get("bands", [BAND_AM, BAND_FM]).duplicate()
	volume_steps = maxi(2, int(radio_spec.get("volume_steps", 8)))
	volume_step = clampi(int(radio_spec.get("default_volume_step", 4)), 0, volume_steps)
	_seek_wrap = bool(radio_spec.get("seek_wrap", true))
	var signal_spec: Dictionary = radio_spec.get("signal", {})
	_signal_extended = float(signal_spec.get("antenna_extended", 0.95))
	_signal_retracted = float(signal_spec.get("antenna_retracted", 0.35))
	_static_floor = float(signal_spec.get("static_floor", 0.03))
	_static_gain = float(signal_spec.get("static_gain", 0.28))
	_tone_hz = float(signal_spec.get("tone_hz", 220.0))
	_mix_rate = float(signal_spec.get("mix_rate", 22050))
	var buffer_length := float(signal_spec.get("buffer_length_s", 0.12))
	if not _bands.has(band):
		band = str(_bands[0]) if not _bands.is_empty() else BAND_AM
	station_index = 0
	_ensure_audio(buffer_length)
	_update_signal()
	_emit_state()


func _ready() -> void:
	_ensure_audio(0.12)
	_update_signal()


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	power_on = false
	signal_strength = 0.0
	static_level = 1.0
	_playback = null
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	_player = null
	_generator = null


func _process(_delta: float) -> void:
	if power_on:
		if _player != null and not _player.playing:
			_player.play()
			_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
		_fill_buffer()
	elif _player != null and _player.playing:
		_player.stop()
		_playback = null


func _ensure_audio(buffer_length: float) -> void:
	if _player != null:
		return
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = _mix_rate
	_generator.buffer_length = maxf(0.05, buffer_length)
	_player = AudioStreamPlayer.new()
	_player.name = "RadioPlayer"
	_player.stream = _generator
	_player.bus = "Master"
	_player.volume_db = -8.0
	add_child(_player)
	if is_inside_tree() and power_on:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func set_antenna_extension(value: float) -> void:
	antenna_extension = clampf(value, 0.0, 1.0)
	_update_signal()


func toggle_power() -> bool:
	set_power(not power_on)
	return power_on


func set_power(value: bool) -> void:
	power_on = value
	_update_signal()
	if power_on:
		_ensure_audio(0.12)
		if _player != null and not _player.playing:
			_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	elif _player != null and _player.playing:
		_player.stop()
		_playback = null
	_emit_state()


func cycle_band() -> String:
	if _bands.is_empty():
		return band
	var index := _bands.find(band)
	band = str(_bands[(index + 1) % _bands.size()])
	station_index = 0
	_emit_state()
	return band


func seek() -> float:
	var frequencies: Array = stations.get(band, [])
	if frequencies.is_empty():
		return 0.0
	if _seek_wrap:
		station_index = (station_index + 1) % frequencies.size()
	else:
		station_index = mini(station_index + 1, frequencies.size() - 1)
	_emit_state()
	return get_station_frequency()


func volume_up() -> int:
	volume_step = mini(volume_steps, volume_step + 1)
	_emit_state()
	return volume_step


func volume_down() -> int:
	volume_step = maxi(0, volume_step - 1)
	_emit_state()
	return volume_step


func get_station_frequency() -> float:
	var frequencies: Array = stations.get(band, [])
	if frequencies.is_empty():
		return 0.0
	return float(frequencies[clampi(station_index, 0, frequencies.size() - 1)])


func get_volume_ratio() -> float:
	return float(volume_step) / float(maxi(1, volume_steps))


func is_audio_ready() -> bool:
	return _player != null and _player.stream != null


func get_state() -> Dictionary:
	return {
		"power_on": power_on,
		"band": band,
		"station": get_station_frequency(),
		"station_index": station_index,
		"volume_step": volume_step,
		"volume_ratio": get_volume_ratio(),
		"signal_strength": signal_strength,
		"static_level": static_level,
		"antenna_extension": antenna_extension,
		"audio_ready": is_audio_ready(),
	}


func _update_signal() -> void:
	if not power_on:
		signal_strength = 0.0
		static_level = 1.0
		return
	signal_strength = lerpf(_signal_retracted, _signal_extended, antenna_extension)
	static_level = clampf(_static_floor + (1.0 - signal_strength) * _static_gain * 3.0, 0.0, 1.0)


func _fill_buffer() -> void:
	if _playback == null and _player != null and _player.playing:
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		return
	var frames := mini(_playback.get_frames_available(), 4096)
	if frames <= 0:
		return
	var volume := get_volume_ratio()
	var signal_amount := signal_strength
	var noise_amplitude := (0.012 + 0.22 * static_level) * volume
	var tone_amplitude := 0.06 * signal_amount * volume
	var phase_step := TAU * _tone_hz / _mix_rate
	for _index in range(frames):
		var noise := _randf() * 2.0 - 1.0
		var tone := sin(_phase) * tone_amplitude
		var sample := clampf(tone + noise * noise_amplitude, -0.8, 0.8)
		_playback.push_frame(Vector2(sample, sample))
		_phase = fmod(_phase + phase_step, TAU)


func _randf() -> float:
	_rng_state = int((_rng_state * 1103515245 + 12345) & 0x7FFFFFFF)
	return float(_rng_state) / 2147483647.0


func _emit_state() -> void:
	state_changed.emit(power_on, band, get_station_frequency(), volume_step)
