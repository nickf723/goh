extends Node

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)
const SpellAudioScript = preload(
	"res://scripts/presentation/presentation_audio_spells.gd"
)
const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const VineScene: PackedScene = preload(
	"res://scenes/actions/life_vine_grapple.tscn"
)
const DeathHexCurseScene: PackedScene = preload(
	"res://scenes/actions/death_hex_curse.tscn"
)
const WraithProjectileScene: PackedScene = preload(
	"res://scenes/actions/death_wraith_projectile.tscn"
)
const WraithSpiritScene: PackedScene = preload(
	"res://scenes/actions/death_pursuer_spirit.tscn"
)

const ELEMENTS: Array[String] = [
	"water", "earth", "fire", "air",
	"ice", "metal", "lightning", "poison",
	"life", "death", "body", "soul",
	"dreams", "sound", "space", "time",
]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var director: GamePresentationDirector = PresentationServiceScript.get_or_create(get_tree())
	validate_director_contract(director)
	validate_audio_vocabulary()
	validate_haptic_vocabulary()
	await validate_player_caster_contract()
	validate_reference_runtime_contracts()
	validate_reference_spell_events(director)
	_finish()


func validate_director_contract(director: GamePresentationDirector) -> void:
	_expect(director != null, "spell-aware presentation director exists")
	if director == null:
		return
	_expect(director.has_method("present_spell"), "director exposes spell lifecycle presentation")
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("spell_lifecycle_presentation", false)), "director advertises spell lifecycle support")
	var phases: Array = data.get("spell_phases", []) as Array
	for phase: String in ["prepare", "release", "travel", "manifest", "latch", "sustain", "resolve", "handoff", "cancel"]:
		_expect(phases.has(phase), "director publishes phase " + phase)


func validate_audio_vocabulary() -> void:
	var audio: SpellPresentationAudio = SpellAudioScript.new() as SpellPresentationAudio
	add_child(audio)
	for phase_cue: String in [
		"spell_prepare", "spell_release", "spell_travel", "spell_manifest",
		"spell_latch", "spell_sustain", "spell_resolve", "spell_handoff", "spell_cancel",
	]:
		var phase_stream: AudioStreamWAV = audio.get_cue_stream(phase_cue)
		_expect(phase_stream != null and phase_stream.data.size() > 100, "audio cue exists for " + phase_cue)
	for element: String in ELEMENTS:
		var stream: AudioStreamWAV = audio.get_cue_stream("element_" + element)
		_expect(stream != null and stream.data.size() > 100, "elemental casting accent exists for " + element)
	audio.queue_free()


func validate_haptic_vocabulary() -> void:
	for preset_id: String in ["spell_prepare", "spell_release", "spell_manifest", "spell_latch", "spell_resolve"]:
		var preset: Dictionary = GameFeedback.get_preset(preset_id)
		var haptic_value: Variant = preset.get("haptic", {})
		_expect(haptic_value is Dictionary and not (haptic_value as Dictionary).is_empty(), "haptic preset exists for " + preset_id)


func validate_player_caster_contract() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	await get_tree().process_frame
	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "player still installs AbilityCaster")
	if caster != null and caster.has_method("get_debug_data"):
		var data: Dictionary = caster.call("get_debug_data")
		_expect(bool(data.get("spell_presentation_lifecycle", false)), "production player caster routes through lifecycle presentation")
	player.queue_free()
	await get_tree().process_frame


func validate_reference_runtime_contracts() -> void:
	var vine: Node = VineScene.instantiate()
	_expect(vine is LifeVineGrappleTargeted, "Vine Grapple keeps its targeted gameplay runtime")
	if vine != null:
		var vine_data: Dictionary = vine.call("get_debug_data") if vine.has_method("get_debug_data") else {}
		_expect(vine_data.has("presentation_lifecycle"), "Vine Grapple declares latch/sustain presentation")
		vine.queue_free()

	var curse: Node = DeathHexCurseScene.instantiate()
	_expect(curse is DeathHexCurse, "Death Hex presented curse remains a DeathHexCurse")
	_expect(curse is DeathHexCursePresented, "Death Hex scene uses presented curse subclass")
	if curse != null:
		curse.queue_free()

	var wraith_projectile: Node = WraithProjectileScene.instantiate()
	_expect(wraith_projectile is DeathWraithProjectile, "Wraith projectile preserves gameplay base class")
	_expect(wraith_projectile is DeathWraithProjectilePresented, "Wraith projectile uses handoff presentation subclass")
	if wraith_projectile != null:
		wraith_projectile.queue_free()

	var spirit: Node = WraithSpiritScene.instantiate()
	_expect(spirit is DeathPursuerSpirit, "Wraith spirit preserves gameplay base class")
	_expect(spirit is DeathPursuerSpiritPresented, "Wraith spirit uses sustain/pass presentation subclass")
	if spirit != null:
		spirit.queue_free()


func validate_reference_spell_events(director: GamePresentationDirector) -> void:
	if director == null or not director.has_method("present_spell"):
		return
	var actor := Node3D.new()
	actor.name = "PresentationGrace"
	add_child(actor)

	var rows: Array[Dictionary] = [
		{"phase": "release", "spell_id": "firebolt", "spell_name": "Firebolt", "element": "fire", "delivery_type": "projectile", "expected": ["spell_release", "element_fire"]},
		{"phase": "manifest", "spell_id": "sprout", "spell_name": "Plant Summon", "element": "life", "delivery_type": "ground_summon", "expected": ["spell_manifest", "element_life"]},
		{"phase": "latch", "spell_id": "vine_grapple", "spell_name": "Vine Grapple", "element": "life", "delivery_type": "channeled_tether", "expected": ["spell_latch"]},
		{"phase": "manifest", "spell_id": "death_hex", "spell_name": "Death Hex", "element": "death", "delivery_type": "projectile_curse", "expected": ["spell_manifest", "element_death"]},
		{"phase": "handoff", "spell_id": "wraith_pursuit", "spell_name": "Wraith Pursuit", "element": "death", "delivery_type": "projectile_spirit_pursuit", "expected": ["spell_handoff", "element_death"]},
	]

	for row: Dictionary in rows:
		var context: Dictionary = row.duplicate(true)
		context.erase("expected")
		context["actor"] = actor
		context["position"] = Vector3.ZERO
		context["suppress_haptics"] = true
		context["suppress_visual"] = true
		var value: Variant = director.call("present_spell", context)
		var event: Dictionary = value as Dictionary if value is Dictionary else {}
		_expect(str(event.get("event_type", "")) == "spell", "reference preview records a spell event")
		_expect(str(event.get("phase", "")) == str(row.get("phase", "")), "reference preview keeps lifecycle phase")
		_expect(str(event.get("spell_id", "")) == str(row.get("spell_id", "")), "reference preview keeps spell identity")
		_expect(not event.has("actor"), "spell telemetry does not retain live actor references")
		_expect(str(event.get("actor_name", "")) == "PresentationGrace", "spell telemetry stores safe actor name")
		var cues: Array[String] = _event_audio_cues(event)
		for expected_cue: String in row.get("expected", []) as Array:
			_expect(cues.has(expected_cue), str(row.get("spell_name", "Spell")) + " includes " + expected_cue)

	actor.queue_free()


func _event_audio_cues(event: Dictionary) -> Array[String]:
	var cues: Array[String] = []
	var value: Variant = event.get("audio", [])
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				var cue: String = str((raw as Dictionary).get("cue", ""))
				if cue != "":
					cues.append(cue)
	elif value is Dictionary:
		var cue: String = str((value as Dictionary).get("cue", ""))
		if cue != "":
			cues.append(cue)
	return cues


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SPELL_PRESENTATION_LIFECYCLE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SPELL_PRESENTATION_LIFECYCLE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
