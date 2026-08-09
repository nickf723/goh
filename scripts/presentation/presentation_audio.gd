extends Node
class_name PresentationAudio

const SAMPLE_RATE: int = 22050
const MAX_LIVE_PLAYERS: int = 20

var stream_cache: Dictionary = {}
var live_players: Array[AudioStreamPlayer3D] = []
var cue_counts: Dictionary = {}
var last_cue_id: String = "none"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("presentation_audio")
	add_to_group("debuggable")


func play_cue(
	cue_id: String,
	world_position: Vector3,
	intensity: float = 0.5,
	pitch_variation: float = 0.04
) -> Dictionary:
	var normalized: String = cue_id.strip_edges().to_lower()
	if normalized == "":
		return {}
	var stream: AudioStreamWAV = get_cue_stream(normalized)
	if stream == null:
		return {}

	_cleanup_players()
	while live_players.size() >= MAX_LIVE_PLAYERS:
		var oldest: AudioStreamPlayer3D = live_players.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

	var player := AudioStreamPlayer3D.new()
	player.name = "PresentationCue_" + normalized
	player.stream = stream
	player.volume_db = lerpf(-13.0, -2.5, clampf(intensity, 0.0, 1.0))
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.unit_size = 5.0
	player.max_distance = 28.0
	player.attenuation_filter_cutoff_hz = 12500.0
	var scene_root: Node = get_tree().current_scene if get_tree() != null else null
	if scene_root == null:
		return {}
	scene_root.add_child(player)
	player.global_position = world_position
	live_players.append(player)
	player.play()
	var duration: float = get_cue_duration(normalized) / maxf(player.pitch_scale, 0.1)
	get_tree().create_timer(duration + 0.08, true, false, true).timeout.connect(
		func() -> void:
			if is_instance_valid(player):
				player.queue_free()
	)

	last_cue_id = normalized
	cue_counts[normalized] = int(cue_counts.get(normalized, 0)) + 1
	return {
		"cue": normalized,
		"intensity": snappedf(clampf(intensity, 0.0, 1.0), 0.01),
		"position": world_position,
		"pitch": snappedf(player.pitch_scale, 0.01),
	}


func get_cue_stream(cue_id: String) -> AudioStreamWAV:
	if stream_cache.has(cue_id):
		return stream_cache[cue_id] as AudioStreamWAV
	var profile: Dictionary = _get_cue_profile(cue_id)
	var stream: AudioStreamWAV = _build_wave(profile)
	stream_cache[cue_id] = stream
	return stream


func get_cue_duration(cue_id: String) -> float:
	return float(_get_cue_profile(cue_id).get("duration", 0.16))


func _get_cue_profile(cue_id: String) -> Dictionary:
	match cue_id:
		"impact_metal":
			return _profile(0.24, [690.0, 1120.0, 1760.0], 0.06, 0.004, 5.2, 0.72)
		"impact_stone":
			return _profile(0.18, [112.0, 178.0], 0.48, 0.003, 8.5, 0.78)
		"impact_wood":
			return _profile(0.16, [178.0, 315.0], 0.34, 0.003, 10.0, 0.72)
		"impact_glass":
			return _profile(0.28, [1260.0, 1910.0, 2570.0], 0.08, 0.002, 5.8, 0.6)
		"impact_flesh":
			return _profile(0.13, [82.0, 132.0], 0.36, 0.002, 15.0, 0.7)
		"impact_soft":
			return _profile(0.12, [126.0, 214.0], 0.22, 0.002, 14.0, 0.58)
		"reaction_resist":
			return _profile(0.11, [420.0, 610.0], 0.12, 0.002, 18.0, 0.48)
		"reaction_stagger":
			return _profile(0.2, [74.0, 118.0, 232.0], 0.32, 0.002, 8.0, 0.82)
		"reaction_launch":
			return _profile(0.26, [64.0, 104.0, 360.0], 0.26, 0.002, 6.0, 0.88)
		"reaction_break":
			return _profile(0.3, [58.0, 96.0, 510.0], 0.38, 0.002, 5.0, 0.92)
		"footstep":
			return _profile(0.09, [92.0, 150.0], 0.42, 0.001, 22.0, 0.32)
		"landing":
			return _profile(0.16, [58.0, 94.0], 0.48, 0.002, 11.0, 0.64)
		"jump":
			return _profile(0.1, [150.0, 236.0], 0.22, 0.002, 17.0, 0.34)
		"break_wood":
			return _profile(0.3, [118.0, 225.0, 390.0], 0.58, 0.002, 7.5, 0.84)
		"break_stone":
			return _profile(0.34, [62.0, 103.0, 168.0], 0.66, 0.002, 6.0, 0.9)
		"break_metal":
			return _profile(0.36, [205.0, 630.0, 1210.0], 0.34, 0.002, 5.0, 0.86)
		"break_glass":
			return _profile(0.38, [980.0, 1570.0, 2410.0, 3140.0], 0.3, 0.001, 6.5, 0.78)
		"element_fire":
			return _profile(0.16, [185.0, 370.0], 0.52, 0.003, 8.0, 0.34)
		"element_water":
			return _profile(0.18, [240.0, 405.0], 0.34, 0.004, 7.0, 0.3)
		"element_ice":
			return _profile(0.22, [910.0, 1450.0], 0.08, 0.002, 6.0, 0.3)
		"element_lightning":
			return _profile(0.13, [760.0, 1880.0, 3220.0], 0.36, 0.001, 13.0, 0.32)
		"element_life":
			return _profile(0.18, [290.0, 510.0], 0.18, 0.004, 6.8, 0.28)
		"element_death":
			return _profile(0.24, [72.0, 146.0, 292.0], 0.16, 0.006, 4.8, 0.34)
		"element_space":
			return _profile(0.24, [214.0, 427.0, 854.0], 0.08, 0.008, 4.6, 0.3)
		"element_sound":
			return _profile(0.2, [440.0, 660.0, 880.0], 0.04, 0.003, 5.6, 0.28)
		_:
			return _profile(0.15, [160.0, 280.0], 0.24, 0.003, 10.0, 0.44)


func _profile(
	duration: float,
	frequencies: Array,
	noise_mix: float,
	attack: float,
	decay: float,
	amplitude: float
) -> Dictionary:
	return {
		"duration": duration,
		"frequencies": frequencies,
		"noise_mix": noise_mix,
		"attack": attack,
		"decay": decay,
		"amplitude": amplitude,
	}


func _build_wave(profile: Dictionary) -> AudioStreamWAV:
	var duration: float = maxf(float(profile.get("duration", 0.15)), 0.02)
	var frequencies: Array = profile.get("frequencies", [180.0]) as Array
	var noise_mix: float = clampf(float(profile.get("noise_mix", 0.2)), 0.0, 1.0)
	var attack: float = maxf(float(profile.get("attack", 0.002)), 0.0001)
	var decay: float = maxf(float(profile.get("decay", 8.0)), 0.1)
	var amplitude: float = clampf(float(profile.get("amplitude", 0.5)), 0.0, 0.95)
	var sample_count: int = maxi(roundi(duration * float(SAMPLE_RATE)), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var salt: int = sample_count + frequencies.size() * 31

	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var attack_envelope: float = clampf(time / attack, 0.0, 1.0)
		var decay_envelope: float = exp(-decay * time)
		var tonal: float = 0.0
		if not frequencies.is_empty():
			for frequency_value: Variant in frequencies:
				var frequency: float = float(frequency_value)
				tonal += sin(TAU * frequency * time)
			tonal /= float(frequencies.size())
		var noise: float = _deterministic_noise(index, salt)
		var mixed: float = lerpf(tonal, noise, noise_mix)
		var sample: float = clampf(
			mixed * attack_envelope * decay_envelope * amplitude,
			-1.0,
			1.0
		)
		var signed_sample: int = clampi(roundi(sample * 32767.0), -32768, 32767)
		var packed: int = signed_sample & 0xFFFF
		bytes[index * 2] = packed & 0xFF
		bytes[index * 2 + 1] = (packed >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func _deterministic_noise(index: int, salt: int) -> float:
	var value: float = sin(float(index * 17 + salt * 37) * 12.9898) * 43758.5453
	var fraction: float = value - floor(value)
	return fraction * 2.0 - 1.0


func _cleanup_players() -> void:
	var valid: Array[AudioStreamPlayer3D] = []
	for player: AudioStreamPlayer3D in live_players:
		if player != null and is_instance_valid(player) and not player.is_queued_for_deletion():
			valid.append(player)
	live_players = valid


func get_debug_data() -> Dictionary:
	_cleanup_players()
	return {
		"procedural_audio": true,
		"sample_rate": SAMPLE_RATE,
		"cached_cues": stream_cache.size(),
		"live_players": live_players.size(),
		"last_cue": last_cue_id,
		"cue_counts": cue_counts.duplicate(true),
	}
