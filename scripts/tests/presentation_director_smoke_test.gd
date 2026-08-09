extends Node

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)
const PresentationAudioScript = preload(
	"res://scripts/presentation/presentation_audio.gd"
)
const TagComponentScript = preload(
	"res://scripts/core/tag_component.gd"
)
const WoodenCrateScene: PackedScene = preload(
	"res://scenes/actors/interactables/breakable_wooden_crate.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var director: GamePresentationDirector = validate_service_contract()
	validate_audio_contract()
	await validate_material_and_impact_contract(director)
	await validate_reaction_layering_contract(director)
	await validate_breakable_material_contract(director)
	validate_telemetry_contract(director)
	_finish()


func validate_service_contract() -> GamePresentationDirector:
	var first: GamePresentationDirector = PresentationServiceScript.get_or_create(get_tree())
	var second: GamePresentationDirector = PresentationServiceScript.get_or_create(get_tree())
	_expect(first != null, "presentation service creates the shared director")
	_expect(first == second, "presentation service reuses one persistent director")
	if first != null:
		var data: Dictionary = first.get_debug_data()
		_expect(bool(data.get("presentation_director", false)), "director advertises its debug contract")
		_expect(not bool(data.get("telemetry_stores_live_nodes", true)), "director telemetry is object-free")
	return first


func validate_audio_contract() -> void:
	var audio: PresentationAudio = PresentationAudioScript.new() as PresentationAudio
	add_child(audio)
	var metal: AudioStreamWAV = audio.get_cue_stream("impact_metal")
	var death: AudioStreamWAV = audio.get_cue_stream("element_death")
	_expect(metal != null, "metal impact cue can be synthesized")
	_expect(death != null, "Death accent cue can be synthesized")
	if metal != null:
		_expect(metal.format == AudioStreamWAV.FORMAT_16_BITS, "procedural cues use 16-bit PCM")
		_expect(metal.mix_rate == 22050, "procedural cues use the authored sample rate")
		_expect(metal.data.size() > 100, "procedural cues contain PCM data")
	_expect(audio.get_cue_stream("impact_metal") == metal, "procedural cue streams are cached")
	audio.queue_free()


func validate_material_and_impact_contract(
	director: GamePresentationDirector
) -> void:
	if director == null:
		return
	var target := Node3D.new()
	target.name = "TaggedMetalTarget"
	var tags: Node = TagComponentScript.new()
	tags.name = "TagComponent"
	tags.set("tags", Array[String](["prop", "metal", "conductive"]))
	target.add_child(tags)
	add_child(target)
	await get_tree().process_frame

	_expect(director.infer_material(target) == "metal", "TagComponent material tags feed presentation inference")
	var event: Dictionary = director.present_impact({
		"target": target,
		"element": "death",
		"damage": 4,
		"stance_damage": 3,
		"suppress_haptics": true,
		"source_name": "Presentation Smoke",
	})
	_expect(str(event.get("event_type", "")) == "impact", "impact produces a semantic event")
	_expect(str(event.get("material", "")) == "metal", "impact keeps inferred metal material")
	_expect(str(event.get("element", "")) == "death", "impact keeps elemental identity")
	_expect(str(event.get("target_name", "")) == "TaggedMetalTarget", "telemetry stores the target name")
	_expect(not event.has("target"), "telemetry does not retain the target Node")
	var cues: Array[String] = _event_audio_cues(event)
	_expect(cues.has("impact_metal"), "metal impact layers the metal contact cue")
	_expect(cues.has("element_death"), "Death impact layers the Death accent cue")

	target.queue_free()
	await get_tree().process_frame
	var history: Array[Dictionary] = director.event_history
	var stale_safe: bool = true
	for row: Dictionary in history:
		if row.has("target") or row.has("actor"):
			stale_safe = false
	_expect(stale_safe, "destroyed targets leave no live Node references in presentation history")


func validate_reaction_layering_contract(
	director: GamePresentationDirector
) -> void:
	if director == null:
		return
	var target := Node3D.new()
	target.name = "WeaponReactionTarget"
	target.set_meta("presentation_material", "flesh")
	add_child(target)
	var payload := DamagePayload.new()
	payload.amount = 4
	payload.stance_damage = 6
	payload.element = "neutral"
	payload.source_name = "Test Sword"
	payload.tags = ["weapon", "melee", "heavy"]

	var event: Dictionary = director.present_reaction({
		"target": target,
		"payload": payload,
		"reaction": "STAGGER",
		"impact": 9.0,
		"direction": Vector3.BACK,
		"element": "neutral",
		"suppress_haptics": true,
	})
	_expect(str(event.get("tier", "")) == "heavy", "Stagger resolves as a heavy presentation tier")
	_expect(bool(event.get("weapon_owned_temporal_feedback", false)), "weapon reactions preserve WeaponController temporal ownership")
	_expect(not bool(event.get("hit_stop", true)), "director does not duplicate weapon hit stop")
	_expect(not bool(event.get("camera", true)), "director does not duplicate weapon camera impact")
	target.queue_free()
	await get_tree().process_frame


func validate_breakable_material_contract(
	director: GamePresentationDirector
) -> void:
	if director == null:
		return
	var crate: Node = WoodenCrateScene.instantiate()
	add_child(crate)
	await get_tree().process_frame
	_expect(crate.has_method("get_presentation_material"), "shared BreakableProp exposes presentation material")
	if crate.has_method("get_presentation_material"):
		_expect(str(crate.call("get_presentation_material")) == "wood", "wooden crate resolves wood from existing gameplay tags")
	var event: Dictionary = director.present_break({
		"target": crate,
		"material": "wood",
		"suppress_haptics": true,
		"suppress_camera": true,
	})
	_expect(str(event.get("material", "")) == "wood", "break presentation keeps material identity")
	var audio_value: Variant = event.get("audio", {})
	var break_cue: String = (
		str((audio_value as Dictionary).get("cue", ""))
		if audio_value is Dictionary
		else ""
	)
	_expect(break_cue == "break_wood", "wood destruction selects the wood break cue")
	crate.queue_free()
	await get_tree().process_frame


func validate_telemetry_contract(director: GamePresentationDirector) -> void:
	if director == null:
		return
	var data: Dictionary = director.get_debug_data()
	var event_counts_value: Variant = data.get("event_counts", {})
	var counts: Dictionary = (
		(event_counts_value as Dictionary).duplicate(true)
		if event_counts_value is Dictionary
		else {}
	)
	_expect(int(counts.get("impact", 0)) >= 1, "director counts impact events")
	_expect(int(counts.get("reaction", 0)) >= 1, "director counts reaction events")
	_expect(int(counts.get("break", 0)) >= 1, "director counts break events")
	_expect(int(data.get("history_size", 0)) <= 24, "presentation history stays bounded")


func _event_audio_cues(event: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var value: Variant = event.get("audio", [])
	if value is Dictionary:
		var cue: String = str((value as Dictionary).get("cue", ""))
		if cue != "":
			result.append(cue)
	elif value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				var cue: String = str((raw as Dictionary).get("cue", ""))
				if cue != "":
					result.append(cue)
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("PRESENTATION_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PRESENTATION_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
