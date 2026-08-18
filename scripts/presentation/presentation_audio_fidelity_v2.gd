extends "res://scripts/presentation/presentation_audio_spells.gd"
class_name PresentationAudioFidelityV2

# Higher-fidelity procedural audio behind the existing semantic cue IDs.
# Gameplay and presentation callers do not change. This layer improves the
# disposable synthesized stand-ins until authored recordings replace them.

const FIDELITY_SAMPLE_RATE: int = 44100
const VARIANT_COUNT: int = 4

var last_variant_index: int = 0
var last_fidelity_cue: String = "none"


func get_cue_stream(cue_id: String) -> AudioStreamWAV:
	var normalized: String = cue_id.strip_edges().to_lower()
	if normalized == "":
		return null
	var variant: int = int(cue_counts.get(normalized, 0)) % VARIANT_COUNT
	var cache_key: String = normalized + "#v" + str(variant)
	if stream_cache.has(cache_key):
		last_variant_index = variant
		last_fidelity_cue = normalized
		return stream_cache[cache_key] as AudioStreamWAV

	var profile: Dictionary = _get_cue_profile(normalized).duplicate(true)
	profile["cue_id"] = normalized
	profile["variant"] = variant
	var stream: AudioStreamWAV = _build_wave(profile)
	stream_cache[cache_key] = stream
	last_variant_index = variant
	last_fidelity_cue = normalized
	return stream


func _get_cue_profile(cue_id: String) -> Dictionary:
	match cue_id:
		"footstep_stone":
			return _fidelity_profile(0.115, [92.0, 164.0], 0.58, 0.001, 21.0, 0.30, 74.0, 0.82, 0.82)
		"footstep_wood":
			return _fidelity_profile(0.12, [126.0, 248.0], 0.42, 0.001, 19.0, 0.29, 104.0, 0.68, 0.60)
		"footstep_metal":
			return _fidelity_profile(0.145, [420.0, 760.0, 1210.0], 0.18, 0.001, 13.0, 0.27, 132.0, 0.76, 0.90)
		"footstep_glass":
			return _fidelity_profile(0.15, [760.0, 1280.0, 1950.0], 0.12, 0.001, 12.0, 0.23, 148.0, 0.58, 0.96)
		"footstep_flesh", "footstep_soft":
			return _fidelity_profile(0.11, [72.0, 118.0], 0.62, 0.001, 24.0, 0.25, 56.0, 0.54, 0.24)

		"weapon_swing_sword":
			return _fidelity_profile(0.22, [235.0, 470.0], 0.72, 0.004, 10.0, 0.43, 92.0, 0.46, 0.88, 1.10, 0.90)
		"weapon_swing_axe":
			return _fidelity_profile(0.27, [92.0, 184.0, 310.0], 0.68, 0.006, 8.0, 0.55, 62.0, 0.72, 0.54, 1.04, 0.82)
		"weapon_swing_staff":
			return _fidelity_profile(0.23, [126.0, 252.0, 410.0], 0.58, 0.004, 9.5, 0.42, 88.0, 0.62, 0.66, 1.08, 0.88)
		"weapon_swing_fast":
			return _fidelity_profile(0.145, [390.0, 720.0], 0.78, 0.002, 16.0, 0.34, 138.0, 0.42, 0.98, 1.14, 0.94)
		"weapon_swing_heavy":
			return _fidelity_profile(0.30, [68.0, 136.0, 236.0], 0.64, 0.008, 7.0, 0.60, 48.0, 0.80, 0.48, 1.02, 0.78)
		"weapon_swing_flexible":
			return _fidelity_profile(0.235, [310.0, 620.0, 1240.0], 0.82, 0.002, 11.0, 0.44, 94.0, 0.72, 0.98, 1.22, 0.86)
		"weapon_release_bow":
			return _fidelity_profile(0.20, [168.0, 336.0, 760.0], 0.28, 0.001, 13.0, 0.42, 96.0, 0.84, 0.82, 1.16, 0.90)
		"weapon_throw_light":
			return _fidelity_profile(0.17, [310.0, 620.0], 0.68, 0.002, 14.0, 0.36, 112.0, 0.42, 0.94, 1.16, 0.92)

	var profile: Dictionary = super._get_cue_profile(cue_id).duplicate(true)
	profile["cue_id"] = cue_id
	_decorate_existing_profile(profile, cue_id)
	return profile


func _fidelity_profile(
	duration: float,
	frequencies: Array,
	noise_mix: float,
	attack: float,
	decay: float,
	amplitude: float,
	body_frequency: float,
	transient_strength: float,
	brightness: float,
	sweep_start: float = 1.0,
	sweep_end: float = 0.88
) -> Dictionary:
	var profile: Dictionary = _profile(
		duration,
		frequencies,
		noise_mix,
		attack,
		decay,
		amplitude
	)
	profile["body_frequency"] = body_frequency
	profile["body_strength"] = 0.28
	profile["body_decay"] = decay * 0.64
	profile["transient_strength"] = transient_strength
	profile["transient_decay"] = maxf(decay * 4.0, 22.0)
	profile["brightness"] = brightness
	profile["sweep_start"] = sweep_start
	profile["sweep_end"] = sweep_end
	profile["soft_clip"] = 1.28
	return profile


func _decorate_existing_profile(profile: Dictionary, cue_id: String) -> void:
	var brightness: float = 0.58
	var transient_strength: float = 0.52
	var body_frequency: float = 82.0
	var body_strength: float = 0.22
	var sweep_start: float = 1.02
	var sweep_end: float = 0.92

	if cue_id.contains("metal"):
		brightness = 0.90
		body_frequency = 118.0
		transient_strength = 0.76
		body_strength = 0.18
	elif cue_id.contains("glass") or cue_id.contains("ice"):
		brightness = 0.98
		body_frequency = 148.0
		transient_strength = 0.64
		body_strength = 0.12
	elif cue_id.contains("stone") or cue_id.contains("earth"):
		brightness = 0.38
		body_frequency = 61.0
		transient_strength = 0.80
		body_strength = 0.34
	elif cue_id.contains("wood"):
		brightness = 0.52
		body_frequency = 96.0
		transient_strength = 0.68
		body_strength = 0.31
	elif cue_id.contains("flesh") or cue_id.contains("body"):
		brightness = 0.22
		body_frequency = 52.0
		transient_strength = 0.48
		body_strength = 0.38
	elif cue_id.contains("lightning") or cue_id.contains("sound"):
		brightness = 1.0
		body_frequency = 124.0
		transient_strength = 0.86
		body_strength = 0.10
		sweep_start = 1.18
		sweep_end = 0.84
	elif cue_id.contains("space") or cue_id.contains("dream"):
		brightness = 0.72
		body_frequency = 46.0
		transient_strength = 0.30
		body_strength = 0.30
		sweep_start = 0.88
		sweep_end = 1.12
	elif cue_id.contains("spell_prepare") or cue_id.contains("sustain"):
		brightness = 0.62
		body_frequency = 72.0
		transient_strength = 0.20
		body_strength = 0.22
		sweep_start = 0.92
		sweep_end = 1.08
	elif cue_id.contains("spell_release") or cue_id.contains("resolve"):
		brightness = 0.82
		body_frequency = 74.0
		transient_strength = 0.72
		body_strength = 0.24
		sweep_start = 1.12
		sweep_end = 0.86
	elif cue_id == "landing" or cue_id.contains("break") or cue_id.contains("stagger"):
		brightness = 0.36
		body_frequency = 54.0
		transient_strength = 0.82
		body_strength = 0.36

	profile["body_frequency"] = body_frequency
	profile["body_strength"] = body_strength
	profile["body_decay"] = maxf(float(profile.get("decay", 8.0)) * 0.62, 2.0)
	profile["transient_strength"] = transient_strength
	profile["transient_decay"] = maxf(float(profile.get("decay", 8.0)) * 4.2, 20.0)
	profile["brightness"] = brightness
	profile["sweep_start"] = sweep_start
	profile["sweep_end"] = sweep_end
	profile["soft_clip"] = 1.22


func _build_wave(profile: Dictionary) -> AudioStreamWAV:
	var duration: float = maxf(float(profile.get("duration", 0.15)), 0.02)
	var frequencies: Array = profile.get("frequencies", [180.0]) as Array
	var noise_mix: float = clampf(float(profile.get("noise_mix", 0.2)), 0.0, 1.0)
	var attack: float = maxf(float(profile.get("attack", 0.002)), 0.0001)
	var decay: float = maxf(float(profile.get("decay", 8.0)), 0.1)
	var amplitude: float = clampf(float(profile.get("amplitude", 0.5)), 0.0, 0.95)
	var body_frequency: float = maxf(float(profile.get("body_frequency", 72.0)), 12.0)
	var body_strength: float = clampf(float(profile.get("body_strength", 0.22)), 0.0, 1.0)
	var body_decay: float = maxf(float(profile.get("body_decay", decay * 0.62)), 0.1)
	var transient_strength: float = clampf(float(profile.get("transient_strength", 0.5)), 0.0, 1.2)
	var transient_decay: float = maxf(float(profile.get("transient_decay", 30.0)), 1.0)
	var brightness: float = clampf(float(profile.get("brightness", 0.58)), 0.0, 1.0)
	var sweep_start: float = maxf(float(profile.get("sweep_start", 1.0)), 0.1)
	var sweep_end: float = maxf(float(profile.get("sweep_end", 0.9)), 0.1)
	var soft_clip: float = maxf(float(profile.get("soft_clip", 1.2)), 0.1)
	var variant: int = clampi(int(profile.get("variant", 0)), 0, VARIANT_COUNT - 1)
	var cue_id: String = str(profile.get("cue_id", "cue"))

	var sample_count: int = maxi(roundi(duration * float(FIDELITY_SAMPLE_RATE)), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var salt: int = sample_count + frequencies.size() * 31 + cue_id.hash() + variant * 997
	var variant_detune: float = 1.0 + (float(variant) - 1.5) * 0.007
	var low_noise: float = 0.0
	var cutoff_hz: float = lerpf(680.0, 11800.0, brightness)
	var filter_alpha: float = 1.0 - exp(-TAU * cutoff_hz / float(FIDELITY_SAMPLE_RATE))
	var clip_normalizer: float = maxf(tanh(soft_clip), 0.001)

	for index: int in range(sample_count):
		var time: float = float(index) / float(FIDELITY_SAMPLE_RATE)
		var normalized_time: float = clampf(time / duration, 0.0, 1.0)
		var attack_envelope: float = clampf(time / attack, 0.0, 1.0)
		var decay_envelope: float = exp(-decay * time)
		var sweep: float = lerpf(sweep_start, sweep_end, normalized_time)

		var tonal: float = 0.0
		if not frequencies.is_empty():
			for frequency_value: Variant in frequencies:
				var frequency: float = float(frequency_value) * variant_detune
				tonal += sin(TAU * frequency * time * sweep)
			tonal /= float(frequencies.size())

		var raw_noise: float = _deterministic_noise(index, salt)
		low_noise += (raw_noise - low_noise) * filter_alpha
		var bright_noise: float = raw_noise - low_noise
		var colored_noise: float = lerpf(low_noise, bright_noise * 1.65, brightness)
		var transient: float = raw_noise * exp(-transient_decay * time) * transient_strength
		var body: float = (
			sin(TAU * body_frequency * variant_detune * time)
			* exp(-body_decay * time)
			* body_strength
		)
		var mixed: float = lerpf(tonal, colored_noise, noise_mix)
		mixed = mixed * attack_envelope * decay_envelope + transient + body
		var sample: float = tanh(mixed * amplitude * soft_clip) / clip_normalizer
		sample = clampf(sample, -1.0, 1.0)
		var signed_sample: int = clampi(roundi(sample * 32767.0), -32768, 32767)
		var packed: int = signed_sample & 0xFFFF
		bytes[index * 2] = packed & 0xFF
		bytes[index * 2 + 1] = (packed >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = FIDELITY_SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func get_fidelity_version() -> int:
	return 2


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["audio_fidelity_v2"] = true
	data["fidelity_sample_rate"] = FIDELITY_SAMPLE_RATE
	data["waveform_variants"] = VARIANT_COUNT
	data["last_variant"] = last_variant_index
	data["last_fidelity_cue"] = last_fidelity_cue
	data["material_footsteps"] = true
	data["weapon_motion_cues"] = true
	return data
