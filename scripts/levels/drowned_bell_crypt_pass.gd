extends Node
class_name DrownedBellCryptPass

const BuilderScript = preload("res://scripts/environment/authored_environment_builder.gd")
const ChapelPalette = preload("res://data/environment_palettes/drowned_chapel_palette.tres")
const StoryInteractableScript = preload("res://scripts/interaction/story_interactable.gd")
const SwimmingWaterVolumeScript = preload("res://scripts/water/swimming_water_volume.gd")
const SwimmingExitAnchorScript = preload("res://scripts/quality/swimming_exit_anchor_3d.gd")
const GuidanceTargetScript = preload("res://scripts/quality/quest_guidance_target_3d.gd")
const RecoveryVolumeScript = preload("res://scripts/quality/playable_recovery_volume_3d.gd")
const WorldStateVariantScript = preload("res://scripts/quests/world_state_variant.gd")
const QuestRewardBundleScript = preload("res://scripts/quests/quest_reward_bundle.gd")
const EchoListenerScene: PackedScene = preload("res://scenes/actors/enemies/echo_listener.tscn")

const QUEST_ID := "the_drowned_bell"
const FLAG_CRYPT_OPENED := "drowned_bell_crypt_opened"
const FLAG_CRYPT_ENTERED := "drowned_bell_crypt_entered"
const FLAG_CREATURE_REVEALED := "drowned_bell_listener_revealed"
const FLAG_CREATURE_PROVOKED := "drowned_bell_listener_provoked"
const FLAG_CALMED := "drowned_bell_listener_calmed"
const FLAG_FREED := "drowned_bell_listener_freed"
const FLAG_FOUGHT := "drowned_bell_listener_fought"
const FLAG_CALL_RESOLVED := "drowned_bell_call_resolved"
const FLAG_RECORD_RECOVERED := "drowned_bell_burial_record_recovered"
const FLAG_RETURN_CALM := "drowned_bell_return_calm"
const FLAG_RETURN_FREE := "drowned_bell_return_free"
const FLAG_RETURN_FOUGHT := "drowned_bell_return_fought"
const FLAG_COMPLETE := "drowned_bell_complete"
const FLAG_TUNING_PLATE := "drowned_bell_tuning_plate_recovered"

const TUNING_PLATE_ITEM := "drowned_bell_tuning_plate"
const BURIAL_RECORD_ITEM := "drowned_bell_burial_register"
const MARSH_TOKEN_ITEM := "orin_marsh_pass_token"

var mission: Node3D
var world: Node3D
var builder: AuthoredEnvironmentBuilder
var crypt_state: RefCounted
var crypt_root: Node3D
var sealed_visuals: Node3D
var resolved_visuals: Node3D
var playable_space: Node3D
var door_blocker: StaticBody3D
var escape_blocker: StaticBody3D
var drained_walkway: StaticBody3D
var passage_water: Area3D
var water_exit_anchors: Array[Node3D] = []
var crypt_threshold: Area3D
var observation_point: Area3D
var sequence_stone: Area3D
var false_resonator: Area3D
var burial_record: Area3D
var creature: EchoListenerActor
var ferryman: Area3D
var completion_layer: CanvasLayer
var completion_summary: RichTextLabel
var completion_pending: bool = false
var installed: bool = false
var install_attempts: int = 0
var build_stats: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("drowned_bell_crypt_pass")
	call_deferred("_install")


func _unhandled_input(event: InputEvent) -> void:
	if completion_layer == null or not completion_layer.visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		completion_layer.visible = false
		get_viewport().set_input_as_handled()


func _install() -> void:
	if installed:
		return
	mission = get_parent() as Node3D
	if mission == null:
		return
	world = mission.get_node_or_null("World") as Node3D
	if world == null:
		return

	var environment_pass: Node = mission.get_node_or_null("EnvironmentPass")
	var playability_pass: Node = mission.get_node_or_null("PlayabilityPass")
	var environment_ready: bool = environment_pass == null or bool(environment_pass.get("installed"))
	var playability_ready: bool = playability_pass == null or bool(playability_pass.get("installed"))
	if not environment_ready or not playability_ready:
		install_attempts += 1
		if install_attempts < 60:
			call_deferred("_install")
		return

	installed = true
	_build_crypt_environment()
	_build_story_flow()
	_build_creature()
	_build_passage_water()
	_extend_playable_space()
	_configure_existing_crypt_seal()
	_configure_guidance()
	_configure_orin_dialogue()
	_build_completion_screen()
	_apply_saved_state()


func _build_crypt_environment() -> void:
	crypt_root = Node3D.new()
	crypt_root.name = "BellBelowV3"
	crypt_root.add_to_group("authored_environment_root")
	crypt_root.set_meta("environment_pass", "drowned_bell_crypt_v3")
	world.add_child(crypt_root)
	builder = BuilderScript.new(crypt_root, ChapelPalette) as AuthoredEnvironmentBuilder
	crypt_state = WorldStateVariantScript.new()

	var descent: Node3D = builder.add_root(crypt_root, "CryptDescent")
	door_blocker = builder.add_static_box(
		descent,
		"CryptDoorBlocker",
		Vector3(3.25, 3.15, 0.42),
		Vector3(-1.8, 1.55, 36.18),
		"stone_dark"
	)
	builder.add_static_box(descent, "ThresholdLanding", Vector3(3.4, 0.52, 2.0), Vector3(-1.8, -0.26, 37.35), "stone_wet")
	builder.add_stair_run(
		descent,
		"BurialStair",
		Vector3(-1.8, -4.65, 45.35),
		Vector3.FORWARD,
		9,
		3.05,
		0.92,
		4.65,
		"stone_wet",
		true
	)
	builder.add_static_box(descent, "StairWestWall", Vector3(0.5, 5.2, 9.3), Vector3(-3.65, -2.0, 41.25), "stone_dark", Vector3.ZERO, true)
	builder.add_static_box(descent, "StairEastWall", Vector3(0.5, 5.2, 9.3), Vector3(0.05, -2.0, 41.25), "stone_dark", Vector3.ZERO, true)
	builder.add_visual_box(descent, "StairCeiling", Vector3(4.2, 0.4, 9.0), Vector3(-1.8, 2.7, 41.2), "stone_dark")
	builder.add_static_box(descent, "LowerLanding", Vector3(4.2, 0.55, 3.0), Vector3(-1.8, -4.92, 45.8), "stone_wet")

	var passage: Node3D = builder.add_root(crypt_root, "CollapsedBurialPassage")
	builder.add_static_box(passage, "PassageFloor", Vector3(4.8, 0.5, 9.4), Vector3(-1.8, -7.05, 50.7), "stone_dark")
	builder.add_static_box(passage, "PassageWestWall", Vector3(0.5, 4.8, 9.4), Vector3(-4.0, -4.85, 50.7), "stone_dark", Vector3.ZERO, true)
	builder.add_static_box(passage, "PassageEastWall", Vector3(0.5, 4.8, 9.4), Vector3(0.4, -4.85, 50.7), "stone_dark", Vector3.ZERO, true)
	builder.add_static_box(passage, "PassageCeiling", Vector3(4.8, 0.5, 9.4), Vector3(-1.8, -2.15, 50.7), "stone_dark")
	for index: int in range(4):
		var niche_z: float = 47.5 + float(index) * 2.15
		builder.add_visual_box(passage, "GraveMarker%02d" % index, Vector3(0.12, 1.0, 1.2), Vector3(-3.68, -4.9, niche_z), "stone_secondary")
		builder.add_visual_torus(passage, "PassageRipple%02d" % index, 0.36, 0.4, Vector3(-1.8, -3.05, niche_z), "accent_cool", Vector3(PI / 2.0, 0.0, 0.0), 0.34, 0.28, "resonance")
	builder.add_stair_run(
		passage,
		"ChamberExitSteps",
		Vector3(-1.8, -6.78, 53.7),
		Vector3.BACK,
		5,
		3.0,
		0.68,
		2.1,
		"stone_wet",
		true
	)

	var chamber: Node3D = builder.add_root(crypt_root, "ListenerChamber")
	builder.add_static_box(chamber, "ChamberFloor", Vector3(14.4, 0.6, 14.0), Vector3(0.0, -4.98, 62.0), "stone_wet")
	builder.add_static_box(chamber, "WestWall", Vector3(0.65, 6.4, 14.0), Vector3(-7.15, -1.75, 62.0), "stone_primary")
	builder.add_static_box(chamber, "EastWall", Vector3(0.65, 6.4, 14.0), Vector3(7.15, -1.75, 62.0), "stone_primary")
	builder.add_static_box(chamber, "FrontWallWest", Vector3(5.2, 6.0, 0.65), Vector3(-4.65, -1.95, 55.2), "stone_primary")
	builder.add_static_box(chamber, "FrontWallEast", Vector3(5.2, 6.0, 0.65), Vector3(4.65, -1.95, 55.2), "stone_primary")
	builder.add_archway(chamber, "PassageArch", Vector3(-1.8, -4.68, 55.2), 3.0, 3.1, 0.72, 0.58, "stone_secondary")
	builder.add_static_box(chamber, "BackWallWest", Vector3(5.55, 6.4, 0.65), Vector3(-4.45, -1.75, 68.9), "stone_primary")
	builder.add_static_box(chamber, "BackWallEast", Vector3(5.55, 6.4, 0.65), Vector3(4.45, -1.75, 68.9), "stone_primary")
	builder.add_static_box(chamber, "BackLintel", Vector3(3.35, 2.8, 0.65), Vector3(0.0, 0.05, 68.9), "stone_secondary")
	builder.add_archway(chamber, "EscapeArch", Vector3(0.0, -4.68, 68.85), 3.0, 3.0, 0.72, 0.58, "stone_secondary")
	escape_blocker = builder.add_static_box(chamber, "EscapeBlocker", Vector3(3.1, 3.0, 0.42), Vector3(0.0, -3.2, 68.62), "stone_dark")

	for position_value: Vector3 in [Vector3(-4.8, -4.68, 58.0), Vector3(4.8, -4.68, 58.0), Vector3(-4.8, -4.68, 65.7), Vector3(4.8, -4.68, 65.7)]:
		builder.add_pillar(chamber, "ChamberPillar_%s_%s" % [str(position_value.x).replace(".", "_"), str(position_value.z).replace(".", "_")], position_value, 5.5, 0.38, "stone_secondary")
	builder.add_visual_box(chamber, "BrokenVaultBeamA", Vector3(11.5, 0.32, 0.48), Vector3(0.0, 1.1, 59.1), "stone_secondary", Vector3(0.0, 0.0, 0.06))
	builder.add_visual_box(chamber, "BrokenVaultBeamB", Vector3(10.2, 0.32, 0.48), Vector3(0.7, 1.0, 65.1), "stone_secondary", Vector3(0.0, 0.0, -0.08))
	builder.add_visual_box(chamber, "CentralPoolBed", Vector3(7.0, 0.18, 6.4), Vector3(0.0, -4.58, 62.0), "stone_dark")
	for index: int in range(6):
		var angle: float = float(index) * TAU / 6.0
		var niche_position := Vector3(cos(angle) * 5.9, -2.9, 62.0 + sin(angle) * 5.15)
		builder.add_visual_box(chamber, "MemorialNiche%02d" % index, Vector3(1.15, 1.45, 0.18), niche_position, "stone_dark", Vector3(0.0, -angle + PI * 0.5, 0.0))

	sealed_visuals = builder.add_root(crypt_root, "UnresolvedResonance")
	resolved_visuals = builder.add_root(crypt_root, "ResolvedSilence")
	resolved_visuals.visible = false
	builder.add_visual_box(sealed_visuals, "EchoPool", Vector3(7.2, 0.12, 6.6), Vector3(0.0, -4.42, 62.0), "water_surface", Vector3.ZERO, 0.82, 0.25, "water")
	for index: int in range(5):
		builder.add_visual_torus(sealed_visuals, "FalseNoteRing%02d" % index, 0.72 + float(index) * 0.58, 0.78 + float(index) * 0.58, Vector3(0.0, -4.25 + float(index) * 0.03, 62.0), "accent_mystic", Vector3(PI / 2.0, 0.0, 0.0), 0.42 - float(index) * 0.045, 0.52, "false_note")
	builder.add_visual_box(resolved_visuals, "ExposedPoolFloor", Vector3(7.2, 0.16, 6.6), Vector3(0.0, -4.42, 62.0), "stone_wet")
	builder.add_visual_box(resolved_visuals, "OpenEscapePath", Vector3(3.0, 0.32, 8.0), Vector3(0.0, -4.72, 72.5), "stone_wet")
	builder.add_visual_torus(resolved_visuals, "TrueToneRing", 2.2, 2.28, Vector3(0.0, -4.2, 62.0), "accent_cool", Vector3(PI / 2.0, 0.0, 0.0), 0.38, 0.35, "true_tone")
	drained_walkway = builder.add_static_box(crypt_root, "DrainedPassageWalkway", Vector3(3.2, 0.38, 9.0), Vector3(-1.8, -4.82, 50.6), "stone_wet")
	_set_body_enabled(drained_walkway, false)

	builder.add_point_light(crypt_root, "CryptMoonGlow", Vector3(-1.8, -1.0, 49.5), "accent_cool", 0.55, 10.0, false)
	builder.add_point_light(sealed_visuals, "FalseNoteLight", Vector3(0.0, -2.0, 62.0), "accent_mystic", 1.1, 11.0, true)
	builder.add_point_light(resolved_visuals, "QuietToneLight", Vector3(0.0, -2.1, 62.0), "accent_cool", 0.82, 12.0, true)
	builder.add_point_light(resolved_visuals, "EscapeLight", Vector3(0.0, -2.7, 69.7), "accent_warm", 0.58, 8.0, false)

	var sealed_nodes: Array[Node] = [sealed_visuals]
	var resolved_nodes: Array[Node] = [resolved_visuals]
	crypt_state.call("register_variant", "unresolved", sealed_nodes)
	crypt_state.call("register_variant", "resolved", resolved_nodes)
	build_stats = builder.get_build_stats()


func _build_story_flow() -> void:
	crypt_threshold = _make_story_point("CryptThreshold", Vector3(-1.8, -4.35, 45.7), "Enter the bell crypt", FLAG_CRYPT_OPENED, FLAG_CRYPT_ENTERED)
	crypt_threshold.connect("activated", _on_crypt_threshold_activated)
	builder.add_visual_torus(crypt_threshold, "ThresholdTone", 0.9, 0.98, Vector3(0.0, 0.08, 0.0), "accent_cool", Vector3(PI / 2.0, 0.0, 0.0), 0.52, 0.4, "quest_accent")

	observation_point = _make_story_point("ListenerObservation", Vector3(-1.8, -4.35, 56.5), "Listen before approaching", FLAG_CRYPT_ENTERED, FLAG_CREATURE_REVEALED)
	observation_point.connect("activated", _on_observation_activated)
	builder.add_visual_torus(observation_point, "ListeningCircle", 1.15, 1.23, Vector3(0.0, 0.08, 0.0), "accent_cool", Vector3(PI / 2.0, 0.0, 0.0), 0.48, 0.38, "quest_accent")

	sequence_stone = _make_story_point("TrueSequenceStone", Vector3(-4.35, -4.38, 61.1), "Play the true two-note burial sequence", FLAG_CREATURE_REVEALED, FLAG_CALL_RESOLVED)
	sequence_stone.connect("activated", _on_sequence_activated)
	builder.add_static_box(crypt_root, "TrueSequencePedestal", Vector3(2.0, 1.0, 1.6), Vector3(-4.35, -4.48, 61.1), "stone_secondary")
	builder.add_visual_box(sequence_stone, "TuningPlateSocket", Vector3(1.05, 0.12, 0.72), Vector3(0.0, 0.68, 0.0), "accent_warm", Vector3.ZERO, 0.95, 0.5, "true_sequence")
	for index: int in range(2):
		builder.add_visual_torus(sequence_stone, "TrueNote%02d" % index, 0.42 + float(index) * 0.25, 0.47 + float(index) * 0.25, Vector3(0.0, 0.78 + float(index) * 0.07, 0.0), "accent_cool", Vector3(PI / 2.0, 0.0, 0.0), 0.58, 0.45, "true_note")

	false_resonator = _make_story_point("FalseNoteResonator", Vector3(4.35, -4.38, 61.1), "Shatter the corrupted false-note resonator", FLAG_CREATURE_REVEALED, FLAG_CALL_RESOLVED)
	false_resonator.connect("activated", _on_resonator_activated)
	builder.add_static_box(crypt_root, "FalseResonatorPedestal", Vector3(2.0, 1.0, 1.6), Vector3(4.35, -4.48, 61.1), "stone_secondary")
	builder.add_visual_cylinder(false_resonator, "ResonatorCore", 0.32, 0.48, 1.2, Vector3(0.0, 1.0, 0.0), "accent_mystic", Vector3.ZERO, 0.78, 1.25, "false_note")
	for index: int in range(3):
		builder.add_visual_torus(false_resonator, "CorruptionRing%02d" % index, 0.52 + float(index) * 0.2, 0.57 + float(index) * 0.2, Vector3(0.0, 1.0 + float(index) * 0.07, 0.0), "accent_mystic", Vector3(PI / 2.0, 0.0, 0.0), 0.42, 0.75, "false_note")

	burial_record = _make_story_point("DrownedBurialRegister", Vector3(0.0, -4.32, 66.55), "Recover the drowned burial register", FLAG_CALL_RESOLVED, FLAG_RECORD_RECOVERED)
	burial_record.connect("activated", _on_record_recovered)
	builder.add_static_box(crypt_root, "RegisterLectern", Vector3(2.2, 1.1, 1.55), Vector3(0.0, -4.5, 66.55), "stone_secondary")
	builder.add_visual_box(burial_record, "RegisterBook", Vector3(1.35, 0.16, 0.92), Vector3(0.0, 0.72, 0.0), "accent_warm", Vector3(0.0, 0.0, -0.08), 0.95, 0.34, "quest_evidence")


func _build_creature() -> void:
	creature = EchoListenerScene.instantiate() as EchoListenerActor
	creature.name = "TheListener"
	creature.position = Vector3(0.0, -4.25, 62.0)
	crypt_root.add_child(creature)
	creature.provoked.connect(_on_creature_provoked)
	creature.defeated.connect(_on_creature_defeated)


func _build_passage_water() -> void:
	passage_water = Area3D.new()
	passage_water.name = "CryptSwimPassage"
	passage_water.position = Vector3(-1.8, -5.25, 50.6)
	passage_water.set_script(SwimmingWaterVolumeScript)
	passage_water.set("surface_height_offset", 2.1)
	passage_water.set("current_velocity", Vector3(0.0, 0.0, 0.34))
	passage_water.set("water_label", "Collapsed Burial Passage")
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.25, 4.0, 9.0)
	collision.shape = shape
	passage_water.add_child(collision)
	crypt_root.add_child(passage_water)
	builder.add_visual_box(passage_water, "PassageWater", Vector3(4.25, 0.12, 9.0), Vector3(0.0, 2.06, 0.0), "water_surface", Vector3.ZERO, 0.94, 0.16, "water")
	builder.add_visual_box(passage_water, "PassageDepth", Vector3(4.1, 0.08, 8.8), Vector3(0.0, -1.55, 0.0), "water_deep", Vector3.ZERO, 0.82, 0.0, "water_depth")
	for index: int in range(5):
		builder.add_visual_box(passage_water, "CurrentRibbon%02d" % index, Vector3(0.12, 0.025, 1.1), Vector3(-0.65 + float(index % 2) * 1.3, 2.16, -3.0 + float(index) * 1.45), "water_highlight", Vector3.ZERO, 0.55, 0.25, "current_marker")
	_make_water_exit("CryptPassageUpperExit", Vector3(-1.8, -4.18, 45.45), "STAIRS")
	_make_water_exit("CryptPassageChamberExit", Vector3(-1.8, -4.1, 56.0), "CHAMBER")


func _extend_playable_space() -> void:
	playable_space = mission.get_node_or_null("PlayableSpace") as Node3D
	if playable_space == null:
		return
	playable_space.set("bounds_center", Vector3(0.0, -1.5, 30.0))
	playable_space.set("bounds_size", Vector3(38.0, 30.0, 96.0))
	playable_space.set("minimum_recovery_y", -12.0)
	var recovery_volume := Area3D.new()
	recovery_volume.name = "CryptVoidRecovery"
	recovery_volume.position = Vector3(0.0, -13.8, 55.0)
	recovery_volume.set_script(RecoveryVolumeScript)
	recovery_volume.set("recovery_reason", "fell beneath the bell crypt")
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(36.0, 3.0, 48.0)
	collision.shape = shape
	recovery_volume.add_child(collision)
	playable_space.add_child(recovery_volume)
	builder.add_static_box(crypt_root, "CryptSafetyCatch", Vector3(34.0, 0.45, 46.0), Vector3(0.0, -15.6, 55.0), "stone_dark", Vector3.ZERO, false, false, "safety")


func _configure_existing_crypt_seal() -> void:
	var crypt_seal: Area3D = mission.get_node_or_null("SubmergedCryptSeal") as Area3D
	if crypt_seal == null:
		return
	crypt_seal.set("blocked_flag", FLAG_CRYPT_OPENED)
	if not crypt_seal.is_connected("activated", Callable(self, "_on_crypt_seal_activated")):
		crypt_seal.connect("activated", _on_crypt_seal_activated)
	var guidance: Node = crypt_seal.get_node_or_null("QuestGuidance")
	if guidance != null and guidance.has_method("set_rules"):
		guidance.call("set_rules", FLAG_TUNING_PLATE, FLAG_CRYPT_OPENED)


func _configure_guidance() -> void:
	_add_guidance(crypt_threshold, "DESCEND", FLAG_CRYPT_OPENED, FLAG_CRYPT_ENTERED, false, 2.7)
	_add_guidance(observation_point, "LISTEN", FLAG_CRYPT_ENTERED, FLAG_CREATURE_REVEALED, false, 2.7)
	_add_guidance(sequence_stone, "TRUE CALL", FLAG_CREATURE_REVEALED, FLAG_CALL_RESOLVED, false, 2.9)
	_add_guidance(false_resonator, "FALSE NOTE", FLAG_CREATURE_REVEALED, FLAG_CALL_RESOLVED, true, 2.9)
	_add_guidance(burial_record, "BURIAL RECORD", FLAG_CALL_RESOLVED, FLAG_RECORD_RECOVERED, false, 2.8)
	ferryman = mission.get_node_or_null("FerrymanOrin") as Area3D
	if ferryman != null:
		_add_guidance(ferryman, "RETURN TO ORIN", FLAG_RECORD_RECOVERED, FLAG_COMPLETE, false, 3.1, "CryptReturnGuidance")


func _configure_orin_dialogue() -> void:
	ferryman = mission.get_node_or_null("FerrymanOrin") as Area3D
	if ferryman == null:
		return
	var existing: Variant = ferryman.get("conversation_data")
	if not existing is Dictionary:
		return
	var data: Dictionary = (existing as Dictionary).duplicate(true)
	var nodes: Dictionary = data.get("nodes", {})
	nodes["crypt_open"] = {
		"speaker": "Orin",
		"text": "The altar opened? Then the old burial stair still exists. The lower passage flooded before the nave did. Keep one hand on the stone when you swim it."
	}
	nodes["resolved_without_record"] = {
		"speaker": "Orin",
		"text": "The bell has gone quiet, but do not leave the dead unnamed. The burial register should be in the keeper's chamber below. Bring it back if the water spared it."
	}
	nodes["return_calm"] = {
		"speaker": "Orin",
		"text": "So it was alive, and it learned our burial call because the chapel was the only voice it had. You answered with the true notes instead of a blade. That matters.",
		"choices": [{"id": "report_calm", "text": "Give Orin the burial register and explain how the Listener escaped.", "relationship_delta": 4}]
	}
	nodes["return_free"] = {
		"speaker": "Orin",
		"text": "The resonator trapped it in a loop, then. Breaking the false note was rough medicine, but the creature finally heard silence and found its own way out.",
		"choices": [{"id": "report_free", "text": "Give Orin the burial register and describe the shattered resonator.", "relationship_delta": 3}]
	}
	nodes["return_fought"] = {
		"speaker": "Orin",
		"text": "A frightened animal can still kill. I will not pretend the crypt gave you an easy choice. At least the false signal is finished, and the names below are no longer lost.",
		"choices": [{"id": "report_fought", "text": "Give Orin the burial register and recount the fight.", "relationship_delta": 0}]
	}
	nodes["after"] = {
		"speaker": "Orin",
		"text": _post_quest_orin_text()
	}
	data["nodes"] = nodes

	var rules: Array = [
		{"requires_flag": FLAG_COMPLETE, "node": "after"},
		{"requires_flag": FLAG_RETURN_CALM, "blocked_by_flag": FLAG_COMPLETE, "node": "return_calm"},
		{"requires_flag": FLAG_RETURN_FREE, "blocked_by_flag": FLAG_COMPLETE, "node": "return_free"},
		{"requires_flag": FLAG_RETURN_FOUGHT, "blocked_by_flag": FLAG_COMPLETE, "node": "return_fought"},
		{"requires_flag": FLAG_CALL_RESOLVED, "blocked_by_flag": FLAG_RECORD_RECOVERED, "node": "resolved_without_record"},
		{"requires_flag": FLAG_CRYPT_OPENED, "blocked_by_flag": FLAG_CALL_RESOLVED, "node": "crypt_open"},
	]
	var old_rules: Variant = data.get("entry_rules", [])
	if old_rules is Array:
		for rule_variant: Variant in old_rules:
			if not rule_variant is Dictionary:
				continue
			var rule: Dictionary = rule_variant as Dictionary
			if str(rule.get("node", "")) == "after":
				continue
			rules.append(rule.duplicate(true))
	data["entry_rules"] = rules
	ferryman.call("configure", data)
	if not ferryman.is_connected("choice_selected", Callable(self, "_on_orin_choice")):
		ferryman.connect("choice_selected", _on_orin_choice)
	if not ferryman.is_connected("conversation_finished", Callable(self, "_on_orin_finished")):
		ferryman.connect("conversation_finished", _on_orin_finished)


func _build_completion_screen() -> void:
	completion_layer = CanvasLayer.new()
	completion_layer.name = "DrownedBellCompletion"
	completion_layer.layer = 70
	completion_layer.visible = false
	completion_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	mission.add_child(completion_layer)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.035, 0.05, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	completion_layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720.0, 390.0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "THE DROWNED BELL  •  COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	completion_summary = RichTextLabel.new()
	completion_summary.bbcode_enabled = true
	completion_summary.fit_content = true
	completion_summary.custom_minimum_size = Vector2(650.0, 245.0)
	completion_summary.add_theme_font_size_override("normal_font_size", 20)
	box.add_child(completion_summary)
	var hint := Label.new()
	hint.text = "A / Enter / Interact  Close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	box.add_child(hint)


func _apply_saved_state() -> void:
	if GameState.get_flag(FLAG_CRYPT_OPENED):
		_open_crypt(false)
		if GameState.has_key_item(TUNING_PLATE_ITEM):
			GameState.remove_key_item(TUNING_PLATE_ITEM)
	if GameState.get_flag(FLAG_CREATURE_REVEALED) and not GameState.get_flag(FLAG_CALL_RESOLVED):
		creature.set_revealed(true)
	if GameState.get_flag(FLAG_CALL_RESOLVED):
		_apply_resolved_world(false)
		creature.set_revealed(false)
	if GameState.get_flag(FLAG_RECORD_RECOVERED):
		_ensure_return_route_flag()
	_configure_orin_dialogue()
	_refresh_recovery_anchor()


func _on_crypt_seal_activated(_interactable: Node) -> void:
	if GameState.get_flag(FLAG_CRYPT_OPENED):
		return
	GameState.set_flag(FLAG_CRYPT_OPENED, true)
	GameState.remove_key_item(TUNING_PLATE_ITEM)
	_open_crypt(true)
	_set_quest_stage("Descend beneath the altar and follow the burial stair.")
	_update_mission_hud("CRYPT OPENED  •  The tuning plate turns twice. A stair descends beneath the altar.")


func _on_crypt_threshold_activated(_interactable: Node) -> void:
	GameState.set_flag(FLAG_CRYPT_ENTERED, true)
	_set_quest_stage("Swim the collapsed burial passage and listen inside the lower chamber.")
	_update_mission_hud("THE BELL BELOW  •  The false high note is louder beneath the chapel.")
	_refresh_recovery_anchor()


func _on_observation_activated(_interactable: Node) -> void:
	GameState.set_flag(FLAG_CREATURE_REVEALED, true)
	creature.set_revealed(true)
	_set_quest_stage("Answer the true burial call, silence the false resonator, or defend yourself.")
	_update_mission_hud("THE LISTENER  •  A blind amphibious creature is answering every vibration through the stone.")
	_refresh_recovery_anchor()


func _on_sequence_activated(_interactable: Node) -> void:
	_resolve_call("calmed")


func _on_resonator_activated(_interactable: Node) -> void:
	_resolve_call("freed")


func _on_creature_provoked(_creature: EchoListenerActor) -> void:
	GameState.set_flag(FLAG_CREATURE_PROVOKED, true)
	_update_mission_hud("THE LISTENER IS AGITATED  •  Its throat pulse is dangerous, but the two mechanisms remain reachable.")


func _on_creature_defeated(_creature: EchoListenerActor) -> void:
	_resolve_call("fought")


func _resolve_call(route: String) -> void:
	if GameState.get_flag(FLAG_CALL_RESOLVED):
		return
	match route:
		"calmed":
			GameState.set_flag(FLAG_CALMED, true)
			GameState.complete_quest_optional(QUEST_ID, "listener_calmed")
			creature.calm_and_escape("calmed", Vector3(0.0, -4.5, 73.5))
		"freed":
			GameState.set_flag(FLAG_FREED, true)
			GameState.complete_quest_optional(QUEST_ID, "false_resonator_destroyed")
			creature.calm_and_escape("freed", Vector3(0.0, -4.5, 73.5))
		"fought":
			GameState.set_flag(FLAG_FOUGHT, true)
		_:
			return
	GameState.set_flag(FLAG_CALL_RESOLVED, true)
	_apply_resolved_world(true)
	_set_quest_stage("Recover the drowned burial register from the opened keeper's alcove.")
	var route_message: String = _resolution_status(route)
	_update_mission_hud(route_message)
	_refresh_recovery_anchor()


func _on_record_recovered(_interactable: Node) -> void:
	if GameState.get_flag(FLAG_RECORD_RECOVERED):
		return
	GameState.set_flag(FLAG_RECORD_RECOVERED, true)
	GameState.add_key_item(BURIAL_RECORD_ITEM, {
		"name": "Drowned Chapel Burial Register",
		"kind": "Recovered Record",
		"description": "A water-stained register preserving the chapel's names and its true two-note burial cadence.",
		"source": "The Drowned Bell",
	})
	_ensure_return_route_flag()
	_configure_orin_dialogue()
	_set_quest_stage("Return the burial register to Ferryman Orin.")
	_update_mission_hud("BURIAL REGISTER RECOVERED  •  The names survived the flood. Return to Orin.")
	_refresh_recovery_anchor()


func _on_orin_choice(choice_id: String, _npc: Node) -> void:
	match choice_id:
		"report_calm":
			_complete_quest("calmed")
		"report_free":
			_complete_quest("freed")
		"report_fought":
			_complete_quest("fought")


func _on_orin_finished(_npc: Node) -> void:
	if not completion_pending:
		return
	completion_pending = false
	call_deferred("_show_completion_screen")


func _complete_quest(route: String) -> void:
	if GameState.get_flag(FLAG_COMPLETE):
		return
	GameState.set_flag(FLAG_COMPLETE, true)
	GameState.complete_quest(QUEST_ID, "The Drowned Bell is silent. Continue along the marsh road when ready.")
	var reward_bundle: RefCounted = QuestRewardBundleScript.new({
		"key_items": [{
			"id": MARSH_TOKEN_ITEM,
			"data": {
				"name": "Orin's Marsh-Passage Token",
				"kind": "Quest Reward",
				"description": "A stamped copper token recognized by ferrymen who work the drowned roads.",
				"source": "The Drowned Bell",
			},
		}],
		"flags": ["drowned_bell_aftermath_ready"],
	})
	reward_bundle.call("apply")
	GameState.add_experience(75)
	_apply_resolved_world(false)
	_configure_orin_dialogue()
	completion_pending = true
	_update_mission_hud("QUEST COMPLETE  •  Marsh-passage token acquired  •  Experience +75")
	_refresh_recovery_anchor()
	completion_summary.text = _completion_text(route)


func _open_crypt(play_feedback: bool) -> void:
	_set_body_enabled(door_blocker, false)
	var crypt_shadow: Node3D = world.find_child("CryptShadow", true, false) as Node3D
	if crypt_shadow != null:
		crypt_shadow.visible = false
	var crypt_seal: Area3D = mission.get_node_or_null("SubmergedCryptSeal") as Area3D
	if crypt_seal != null and crypt_seal.has_method("set_active"):
		crypt_seal.call("set_active", false)
	if play_feedback:
		_spawn_resonance_ring(Vector3(-1.8, 1.0, 35.8), Color(0.98, 0.67, 0.24, 0.75), 3.3)
	_refresh_recovery_anchor()


func _apply_resolved_world(animate: bool) -> void:
	crypt_state.call("apply", "resolved")
	_set_body_enabled(escape_blocker, false)
	_set_body_enabled(drained_walkway, true)
	if passage_water != null:
		passage_water.monitoring = false
		passage_water.monitorable = false
		passage_water.visible = false
	for anchor: Node3D in water_exit_anchors:
		if anchor != null and is_instance_valid(anchor):
			anchor.set("enabled", false)
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		var swimming: Node = player.get_node_or_null("SwimmingController")
		if swimming != null and swimming.has_method("reset_swimming"):
			swimming.call("reset_swimming")
	var chapel_state_variant: Variant = mission.get("chapel_state")
	if chapel_state_variant is RefCounted:
		(chapel_state_variant as RefCounted).call("apply", "quiet")
	sequence_stone.call("set_active", false)
	false_resonator.call("set_active", false)
	if animate:
		_spawn_resonance_ring(Vector3(0.0, -4.0, 62.0), Color(0.38, 0.84, 1.0, 0.72), 6.5)
		_animate_bell_once()


func _animate_bell_once() -> void:
	var bell: Node3D = world.find_child("Bell", true, false) as Node3D
	if bell == null:
		return
	var original_rotation: Vector3 = bell.rotation
	var tween: Tween = bell.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(bell, "rotation:z", original_rotation.z + 0.28, 0.18)
	tween.tween_property(bell, "rotation:z", original_rotation.z - 0.2, 0.24)
	tween.tween_property(bell, "rotation:z", original_rotation.z, 0.22)


func _ensure_return_route_flag() -> void:
	if GameState.get_flag(FLAG_CALMED):
		GameState.set_flag(FLAG_RETURN_CALM, true)
	elif GameState.get_flag(FLAG_FREED):
		GameState.set_flag(FLAG_RETURN_FREE, true)
	elif GameState.get_flag(FLAG_FOUGHT):
		GameState.set_flag(FLAG_RETURN_FOUGHT, true)


func _refresh_recovery_anchor() -> void:
	if playable_space == null or not playable_space.has_method("set_active_recovery_transform"):
		return
	var recovery_position := Vector3(0.0, 1.0, -10.0)
	var anchor_id: String = "shore"
	if GameState.get_flag(FLAG_COMPLETE):
		recovery_position = Vector3(-3.5, 1.0, -3.0)
		anchor_id = "orin_camp"
	elif GameState.get_flag(FLAG_CALL_RESOLVED) or GameState.get_flag(FLAG_CREATURE_REVEALED):
		recovery_position = Vector3(-1.8, -4.15, 56.2)
		anchor_id = "listener_chamber"
	elif GameState.get_flag(FLAG_CRYPT_ENTERED):
		recovery_position = Vector3(-1.8, -4.15, 45.6)
		anchor_id = "crypt_landing"
	elif GameState.get_flag(FLAG_CRYPT_OPENED):
		recovery_position = Vector3(-1.8, 0.8, 37.2)
		anchor_id = "crypt_threshold"
	playable_space.call("set_active_recovery_transform", Transform3D(Basis.IDENTITY, recovery_position), anchor_id)


func _make_story_point(node_name: String, position_value: Vector3, prompt: String, required: String, blocked: String) -> Area3D:
	var point := Area3D.new()
	point.name = node_name
	point.position = position_value
	point.set_script(StoryInteractableScript)
	point.set("prompt_text", prompt)
	point.set("required_flag", required)
	point.set("blocked_flag", blocked)
	crypt_root.add_child(point)
	return point


func _make_water_exit(node_name: String, position_value: Vector3, label: String) -> void:
	var anchor := Node3D.new()
	anchor.name = node_name
	anchor.position = position_value
	anchor.set_script(SwimmingExitAnchorScript)
	anchor.set("marker_text", label)
	anchor.set("activation_radius", 3.0)
	anchor.set("maximum_vertical_distance", 2.8)
	anchor.set("require_facing", false)
	anchor.set("show_marker", true)
	crypt_root.add_child(anchor)
	anchor.call("set_water_volume", passage_water)
	water_exit_anchors.append(anchor)


func _add_guidance(
	target: Node3D,
	label: String,
	required: String,
	blocked: String,
	optional: bool,
	height: float,
	node_name: String = "QuestGuidance"
) -> void:
	if target == null or target.get_node_or_null(node_name) != null:
		return
	var guidance := Node3D.new()
	guidance.name = node_name
	guidance.set_script(GuidanceTargetScript)
	guidance.set("marker_text", label)
	guidance.set("required_flag", required)
	guidance.set("blocked_flag", blocked)
	guidance.set("optional_target", optional)
	guidance.set("show_distance", true)
	guidance.set("marker_height", height)
	target.add_child(guidance)
	target.set_meta("quality_requires_guidance", true)


func _set_body_enabled(body: StaticBody3D, enabled: bool) -> void:
	if body == null:
		return
	body.visible = enabled
	body.collision_layer = 1 if enabled else 0
	body.collision_mask = 1 if enabled else 0
	var collision: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", not enabled)


func _set_quest_stage(objective: String) -> void:
	if not GameState.get_quest(QUEST_ID).is_empty():
		GameState.set_quest_stage(QUEST_ID, 4, objective)
	else:
		GameState.set_objective(objective)


func _update_mission_hud(status: String) -> void:
	if mission != null and mission.has_method("refresh_hud"):
		mission.call("refresh_hud", status)


func _spawn_resonance_ring(position_value: Vector3, color: Color, final_scale: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "CryptResonanceBurst"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.7
	mesh.outer_radius = 0.78
	mesh.rings = 28
	mesh.ring_segments = 10
	ring.mesh = mesh
	ring.rotation.x = PI / 2.0
	ring.position = position_value
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 1.6
	ring.material_override = material
	world.add_child(ring)
	var tween: Tween = ring.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3.ONE * final_scale, 0.75)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.75)
	tween.finished.connect(ring.queue_free)


func _resolution_status(route: String) -> String:
	match route:
		"calmed":
			return "TRUE CALL ANSWERED  •  The Listener repeats two low notes, then follows the opened waterway."
		"freed":
			return "FALSE NOTE SHATTERED  •  The resonator breaks and the Listener flees into the quiet passage."
		"fought":
			return "ECHO SILENCED  •  The Listener falls and the corrupted resonator cracks with it."
	return "THE BELL BELOW IS QUIET."


func _post_quest_orin_text() -> String:
	if GameState.get_flag(FLAG_CALMED):
		return "The marsh carries only the true bell now. Somewhere below the reeds, your Listener may still be answering it in two soft notes."
	if GameState.get_flag(FLAG_FREED):
		return "The chapel is quiet, and the eastern culvert is open again. Whatever lived below has the whole marsh to choose from now."
	if GameState.get_flag(FLAG_FOUGHT):
		return "The chapel is quiet. I have copied the recovered names before the damp takes them again."
	return "The marsh is quiet again. I had forgotten how silence carries across open water."


func _completion_text(route: String) -> String:
	var resolution_line: String = "The Listener was calmed with the chapel's true two-note burial call."
	if route == "freed":
		resolution_line = "The corrupted resonator was shattered, freeing the Listener from the repeating false note."
	elif route == "fought":
		resolution_line = "The frightened Listener was defeated after answering the false note with violence."
	return (
		"[center][font_size=22]" + resolution_line + "[/font_size][/center]\n\n"
		+ "• The drowned burial register was returned to Orin.\n"
		+ "• The chapel bell rang once in its correct voice.\n"
		+ "• The lower passage drained and the crypt route remains open.\n"
		+ "• Orin's Marsh-Passage Token was added to Key Items.\n"
		+ "• Experience +75"
	)


func _show_completion_screen() -> void:
	if completion_layer == null or completion_summary == null:
		return
	completion_layer.visible = true


func get_debug_data() -> Dictionary:
	return {
		"installed": installed,
		"crypt_opened": GameState.get_flag(FLAG_CRYPT_OPENED),
		"crypt_entered": GameState.get_flag(FLAG_CRYPT_ENTERED),
		"listener_revealed": GameState.get_flag(FLAG_CREATURE_REVEALED),
		"call_resolved": GameState.get_flag(FLAG_CALL_RESOLVED),
		"record_recovered": GameState.get_flag(FLAG_RECORD_RECOVERED),
		"complete": GameState.get_flag(FLAG_COMPLETE),
		"resolution": "calmed" if GameState.get_flag(FLAG_CALMED) else ("freed" if GameState.get_flag(FLAG_FREED) else ("fought" if GameState.get_flag(FLAG_FOUGHT) else "none")),
		"water_exits": water_exit_anchors.size(),
		"build_stats": build_stats.duplicate(true),
	}
