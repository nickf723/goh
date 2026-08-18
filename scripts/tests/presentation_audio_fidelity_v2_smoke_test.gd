extends Node

const AudioScript = preload(
	"res://scripts/presentation/presentation_audio_fidelity_v2.gd"
)
const DirectorScript = preload(
	"res://scripts/presentation/presentation_director_audio_fidelity_v2.gd"
)
const CombatPlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player_combat_v2.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	await _validate_audio_fidelity()
	_finish()


func _validate_audio_fidelity() -> void:
	var audio: PresentationAudio = AudioScript.new() as PresentationAudio
	_expect(audio != null, "fidelity audio class instantiates as PresentationAudio")
	if audio == null:
		return
	add_child(audio)
	await get_tree().process_frame

	var stone: AudioStreamWAV = audio.get_cue_stream("footstep_stone")
	_expect(stone != null, "stone footstep stream is generated")
	if stone != null:
		_expect(stone.mix_rate == 44100, "fidelity cues synthesize at 44.1 kHz")
		_expect(stone.data.size() > 3000, "stone footstep contains a real transient waveform")

	# Cue count selects a deterministic waveform variant without changing the
	# semantic cue ID used by gameplay and presentation callers.
	audio.cue_counts["footstep_stone"] = 0
	var variant_a: AudioStreamWAV = audio.get_cue_stream("footstep_stone")
	audio.cue_counts["footstep_stone"] = 1
	var variant_b: AudioStreamWAV = audio.get_cue_stream("footstep_stone")
	_expect(variant_a != null and variant_b != null, "multiple footstep variants generate")
	if variant_a != null and variant_b != null:
		_expect(variant_a.data != variant_b.data, "repeated semantic cues rotate waveform variants")

	for cue_id: String in [
		"footstep_wood",
		"footstep_metal",
		"weapon_swing_sword",
		"weapon_swing_axe",
		"weapon_swing_staff",
		"weapon_swing_fast",
		"weapon_swing_heavy",
		"weapon_swing_flexible",
		"weapon_release_bow",
		"weapon_throw_light",
		"spell_release",
		"impact_metal",
	]:
		var stream: AudioStreamWAV = audio.get_cue_stream(cue_id)
		_expect(stream != null, "fidelity cue generates: " + cue_id)
		if stream != null:
			_expect(stream.mix_rate == 44100, "fidelity sample rate holds for " + cue_id)

	var audio_debug: Dictionary = audio.get_debug_data()
	_expect(bool(audio_debug.get("audio_fidelity_v2", false)), "audio reports fidelity V2")
	_expect(int(audio_debug.get("waveform_variants", 0)) == 4, "audio reports four waveform variants")
	_expect(bool(audio_debug.get("material_footsteps", false)), "audio reports material footsteps")
	_expect(bool(audio_debug.get("weapon_motion_cues", false)), "audio reports weapon motion cues")

	var director: GamePresentationDirector = (
		DirectorScript.new() as GamePresentationDirector
	)
	_expect(director != null, "fidelity Director instantiates as GamePresentationDirector")
	if director != null:
		director.name = "TestPresentationDirector"
		add_child(director)
		await get_tree().process_frame
		var actor := Node3D.new()
		actor.name = "AudioTestActor"
		add_child(actor)
		var footstep: Dictionary = director.present_movement("footstep", {
			"actor": actor,
			"position": Vector3.ZERO,
			"material": "wood",
			"strength": 0.24,
		})
		_expect(bool(footstep.get("material_specific_footstep", false)), "Director routes footsteps by material")
		var footstep_audio: Dictionary = footstep.get("audio", {}) as Dictionary
		_expect(str(footstep_audio.get("cue", "")) == "footstep_wood", "wood footsteps use wood cue")

		var weapon_motion: Dictionary = director.present("weapon_motion", {
			"actor": actor,
			"position": Vector3.ZERO,
			"weapon_class": "axe",
			"input_kind": "heavy",
			"attack_id": "test_axe_heavy",
			"intensity": 0.8,
			"tags": ["heavy", "cleave"],
		})
		_expect(str(weapon_motion.get("cue", "")) == "weapon_swing_axe", "axe motion resolves axe-specific whoosh")
		_expect(not bool(weapon_motion.get("camera", true)), "weapon motion audio does not steal camera authority")
		_expect(not bool(weapon_motion.get("hit_stop", true)), "weapon motion audio does not steal hit-stop authority")
		actor.queue_free()
		director.queue_free()

	_expect(CombatPlayerScene != null, "combat player preloads with weapon motion audio presenter")
	if CombatPlayerScene != null:
		var player: Node = CombatPlayerScene.instantiate()
		_expect(player != null, "combat player instantiates")
		if player != null:
			_expect(
				player.get_node_or_null("WeaponMotionAudioPresenter") != null,
				"live combat player contains weapon motion audio presenter"
			)
			player.queue_free()

	audio.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("PRESENTATION_AUDIO_FIDELITY_V2_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PRESENTATION_AUDIO_FIDELITY_V2_SMOKE_TEST: " + failure)
	get_tree().quit(1)
