extends Node3D
class_name PrototypeBodyFormsSpellTrial

signal mass_stage_completed(measured_mass_kg: float)
signal passage_stage_completed(form_id: String, collision_height: float)
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)

enum TrialStage {
	MASS_CHAMBER,
	NARROW_PASSAGE,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = (
	"hall_of_measure_body_forms_trial_complete"
)
@export_range(0.02, 0.5, 0.01) var evaluation_interval: float = 0.08
@export_range(1.0, 500.0, 1.0) var required_mass_kg: float = 120.0
@export_range(0.5, 3.0, 0.05) var maximum_passage_height: float = 1.3
@export_range(-100.0, 100.0, 0.1) var passage_finish_z: float = 26.0
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between body-form casts."
)

var environment_root: Node3D = null
var actors_root: Node3D = null
var player: CharacterBody3D = null
var initial_player_transform: Transform3D

var mass_plate: PressurePlateSwitch = null
var mass_gate: MechanismSlidingGate = null
var passage_gate: MechanismSlidingGate = null
var passage_finish_area: Area3D = null
var mastery_area: Area3D = null

var stage: TrialStage = TrialStage.MASS_CHAMBER
var evaluation_remaining: float = 0.0
var trial_complete: bool = false
var mass_completion_count: int = 0
var passage_completion_count: int = 0
var reliable_gate_open_count: int = 0
var last_measured_mass_kg: float = 0.0
var last_passage_form: String = "none"
var last_passage_collision_height: float = 0.0
var last_gate_reason: String = "none"

var floor_material: StandardMaterial3D = null
var wall_material: StandardMaterial3D = null
var body_material: StandardMaterial3D = null
var grown_material: StandardMaterial3D = null
var shrunk_material: StandardMaterial3D = null
var gold_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("hall_of_measure_spell_trial")
	add_to_group("body_forms_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_mass_chamber()
	_build_narrow_passage()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.MASS_CHAMBER)
	set_process(true)
	_show_message(
		"Hall of Measure: Grow until Grace outweighs the first gate, then Shrink through the low passage. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_spell", "grow")


func _process(delta: float) -> void:
	evaluation_remaining -= maxf(delta, 0.0)
	if evaluation_remaining > 0.0:
		return
	evaluation_remaining = maxf(evaluation_interval, 0.02)
	evaluate_gate_progression_now()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func evaluate_gate_progression_now() -> bool:
	match stage:
		TrialStage.MASS_CHAMBER:
			return _evaluate_mass_chamber()
		TrialStage.NARROW_PASSAGE:
			return _evaluate_narrow_passage(false)
	return false


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "HallOfMeasureEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "HallOfMeasureActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(
		Color(0.085, 0.055, 0.09, 1.0),
		0.16,
		0.82
	)
	wall_material = _make_material(
		Color(0.055, 0.04, 0.065, 1.0),
		0.32,
		0.68
	)
	body_material = _make_emissive_material(
		Color(0.62, 0.12, 0.42, 0.88),
		Color(0.96, 0.12, 0.58),
		2.2,
		true
	)
	grown_material = _make_emissive_material(
		Color(0.78, 0.08, 0.38, 0.92),
		Color(1.0, 0.12, 0.42),
		3.0
	)
	shrunk_material = _make_emissive_material(
		Color(0.38, 0.16, 0.82, 0.9),
		Color(0.64, 0.34, 1.0),
		3.0
	)
	gold_material = _make_emissive_material(
		Color(0.68, 0.48, 0.08, 0.94),
		Color(1.0, 0.78, 0.14),
		3.7
	)


func _build_environment() -> void:
	_create_static_box(
		"HallFloor",
		Vector3(0.0, -0.5, 17.0),
		Vector3(14.0, 1.0, 50.0),
		floor_material
	)
	_create_static_box(
		"HallLeftWall",
		Vector3(-7.5, 2.5, 17.0),
		Vector3(1.0, 6.0, 50.0),
		wall_material
	)
	_create_static_box(
		"HallRightWall",
		Vector3(7.5, 2.5, 17.0),
		Vector3(1.0, 6.0, 50.0),
		wall_material
	)
	_create_static_box(
		"HallBackWall",
		Vector3(0.0, 2.5, -8.0),
		Vector3(14.0, 6.0, 1.0),
		wall_material
	)
	_create_static_box(
		"HallFrontWall",
		Vector3(0.0, 2.5, 42.0),
		Vector3(14.0, 6.0, 1.0),
		wall_material
	)

	_create_label(
		"THE HALL OF MEASURE",
		Vector3(0.0, 5.0, -5.4),
		Color(1.0, 0.46, 0.76),
		34
	)
	_create_label(
		"The same body cannot answer every room.",
		Vector3(0.0, 3.95, -3.0),
		Color(0.86, 0.72, 0.92),
		20
	)
	_create_label(
		"I • THE HEAVY ANSWER",
		Vector3(0.0, 4.2, 0.5),
		Color(1.0, 0.36, 0.66),
		27
	)
	_create_label(
		"II • THE NARROW ANSWER",
		Vector3(0.0, 4.2, 13.0),
		Color(0.72, 0.5, 1.0),
		27
	)


func _build_mass_chamber() -> void:
	_create_visual_box(
		"GrowCastingMark",
		Vector3(0.0, 0.06, -3.2),
		Vector3(3.4, 0.12, 1.4),
		grown_material
	)
	mass_plate = (
		PressurePlateScene.instantiate() as PressurePlateSwitch
	)
	mass_plate.name = "BodyMassPlate"
	mass_plate.position = Vector3(0.0, 0.0, 5.0)
	mass_plate.display_name = "120 kg Body Mass Plate"
	mass_plate.accept_any_physics_body = true
	mass_plate.default_non_rigid_body_mass_kg = 70.0
	mass_plate.maximum_reported_mass_kg = 220.0
	mass_plate.show_weight_in_label = true
	actors_root.add_child(mass_plate)
	mass_plate.mechanism_value_changed.connect(_on_mass_plate_changed)
	_create_label(
		"NORMAL 70 kg • GROW 150 kg • REQUIRED 120 kg",
		Vector3(0.0, 3.0, 5.0),
		Color(1.0, 0.72, 0.84),
		18
	)
	mass_gate = _spawn_gate_with_dividers(
		"MassGate",
		"Mass Gate",
		Vector3(0.0, 0.0, 10.5)
	)


func _build_narrow_passage() -> void:
	_create_visual_box(
		"ShrinkCastingMark",
		Vector3(0.0, 0.06, 13.8),
		Vector3(3.4, 0.12, 1.4),
		shrunk_material
	)
	_create_static_box(
		"PassageLeftBlock",
		Vector3(-3.15, 1.45, 21.0),
		Vector3(5.3, 2.9, 13.0),
		wall_material
	)
	_create_static_box(
		"PassageRightBlock",
		Vector3(3.15, 1.45, 21.0),
		Vector3(5.3, 2.9, 13.0),
		wall_material
	)
	# The roof underside sits at roughly 1.28 meters. Normal Grace is 1.92 m;
	# Shrink reduces her collision capsule to about 1.11 m.
	_create_static_box(
		"LowPassageRoof",
		Vector3(0.0, 1.64, 21.0),
		Vector3(1.55, 0.72, 13.0),
		wall_material
	)
	_create_visual_box(
		"NarrowPassageGuide",
		Vector3(0.0, 0.035, 21.0),
		Vector3(1.5, 0.07, 12.6),
		body_material
	)
	_create_label(
		"NORMAL CANNOT FIT • SHRINK AND KEEP MOVING",
		Vector3(0.0, 2.95, 21.0),
		Color(0.8, 0.68, 1.0),
		17
	)
	passage_finish_area = _create_trigger_area(
		"NarrowPassageFinish",
		Vector3(0.0, 1.0, passage_finish_z),
		Vector3(3.0, 2.5, 2.4)
	)
	passage_finish_area.body_entered.connect(
		_on_passage_finish_entered
	)
	passage_gate = _spawn_gate_with_dividers(
		"PassageGate",
		"Narrow Passage Gate",
		Vector3(0.0, 0.0, 29.5)
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"BodyFormsMasteryArea",
		Vector3(0.0, 1.0, 36.5),
		Vector3(7.0, 2.6, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_entered)
	_create_visual_box(
		"BodyFormsMasterySeal",
		Vector3(0.0, 0.06, 36.5),
		Vector3(5.2, 0.14, 3.2),
		gold_material
	)
	_create_label(
		"MASS • SCALE • ADAPT",
		Vector3(0.0, 3.8, 38.0),
		Color(1.0, 0.84, 0.28),
		25
	)


func _on_mass_plate_changed(
	_value: float,
	_packet: Dictionary
) -> void:
	_evaluate_mass_chamber()


func _evaluate_mass_chamber() -> bool:
	if (
		player == null
		or mass_plate == null
		or stage != TrialStage.MASS_CHAMBER
	):
		return false
	last_measured_mass_kg = mass_plate.get_mechanism_value()
	var controller: Node = player.get_node_or_null("BodyFormController")
	var grown: bool = (
		controller != null
		and controller.has_method("is_grown")
		and bool(controller.call("is_grown"))
	)
	if not grown or last_measured_mass_kg < required_mass_kg:
		return false
	mass_completion_count += 1
	_open_gate_reliably(mass_gate, "grown_mass_confirmed")
	_set_stage(TrialStage.NARROW_PASSAGE)
	mass_stage_completed.emit(last_measured_mass_kg)
	_show_message(
		"Grow reaches 150 kg and opens the mass gate. Shrink now: the next room rejects height instead of weight."
	)
	call_deferred("_equip_spell", "shrink")
	return true


func _on_passage_finish_entered(body: Node) -> void:
	if body != player:
		return
	_evaluate_narrow_passage(true)


func _evaluate_narrow_passage(
	arrival_signal_received: bool
) -> bool:
	if player == null or stage != TrialStage.NARROW_PASSAGE:
		return false
	if (
		not arrival_signal_received
		and player.global_position.z < passage_finish_z - 0.7
	):
		return false
	var controller: Node = player.get_node_or_null("BodyFormController")
	if controller == null or not controller.has_method("get_debug_data"):
		return false
	var form_debug: Dictionary = controller.call("get_debug_data") as Dictionary
	last_passage_form = str(form_debug.get("form", "normal"))
	last_passage_collision_height = float(
		form_debug.get("collision_height", 99.0)
	)
	if (
		last_passage_form != "shrunk"
		or last_passage_collision_height > maximum_passage_height
	):
		return false
	passage_completion_count += 1
	_open_gate_reliably(passage_gate, "shrunk_passage_confirmed")
	_set_stage(TrialStage.MASTERY)
	passage_stage_completed.emit(
		last_passage_form,
		last_passage_collision_height
	)
	_show_message(
		"Shrink clears the low passage. The finish is polled as well as signaled, so a quick dash cannot skip the door."
	)
	return true


func _on_mastery_area_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Body forms mastered: MASS • SCALE • ADAPT.")


func _open_gate_reliably(
	gate: MechanismSlidingGate,
	reason: String
) -> void:
	if gate == null:
		return
	last_gate_reason = reason
	reliable_gate_open_count += 1
	gate.set_gate_open(true, false, {
		"reason": reason,
		"reliable_retry": true,
	})
	call_deferred("_verify_gate_open", gate, reason)


func _verify_gate_open(
	gate: MechanismSlidingGate,
	reason: String
) -> void:
	if gate == null or not is_instance_valid(gate):
		return
	if not gate.is_mechanism_active():
		gate.set_gate_open(true, true, {
			"reason": reason + "_forced",
			"reliable_retry": true,
		})


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.MASS_CHAMBER:
			_set_objective(
				"Grow: become heavy enough to hold the 120 kg pressure plate."
			)
		TrialStage.NARROW_PASSAGE:
			_set_objective(
				"Shrink: reduce Grace's collision height and cross the low passage."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Body forms: cross the open gate and enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Hall of Measure complete: MASS • SCALE • ADAPT."
			)


func _equip_spell(spell_id: String) -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("select_ability"):
		return
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(
			ability_index
		)
		if ability != null and ability.get_spell_id() == spell_id:
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	mass_completion_count = 0
	passage_completion_count = 0
	reliable_gate_open_count = 0
	last_measured_mass_kg = 0.0
	last_passage_form = "none"
	last_passage_collision_height = 0.0
	last_gate_reason = "none"
	evaluation_remaining = 0.0
	GameState.set_flag(completion_flag, false)
	if player != null:
		var controller: Node = player.get_node_or_null("BodyFormController")
		if controller != null and controller.has_method("reset_target"):
			controller.call("reset_target")
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	if mass_plate != null:
		mass_plate.reset_target()
	if mass_gate != null:
		mass_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if passage_gate != null:
		passage_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	_restore_player_resources()
	_set_stage(TrialStage.MASS_CHAMBER)
	call_deferred("_equip_spell", "grow")
	trial_reset.emit()


func _restore_player_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _spawn_gate_with_dividers(
	node_name: String,
	display_name_value: String,
	position_value: Vector3
) -> MechanismSlidingGate:
	var gate: MechanismSlidingGate = (
		GateScene.instantiate() as MechanismSlidingGate
	)
	gate.name = node_name
	gate.display_name = display_name_value
	gate.position = position_value
	gate.scale = Vector3(1.3, 1.0, 1.0)
	gate.open_offset = Vector3(0.0, 4.5, 0.0)
	gate.transition_seconds = 0.45
	actors_root.add_child(gate)
	var state_label: Label3D = gate.get_node_or_null(
		"StateLabel"
	) as Label3D
	if state_label != null:
		state_label.visible = false
	_create_static_box(
		node_name + "LeftDivider",
		Vector3(-4.7, 2.2, position_value.z),
		Vector3(5.0, 5.4, 0.8),
		wall_material
	)
	_create_static_box(
		node_name + "RightDivider",
		Vector3(4.7, 2.2, position_value.z),
		Vector3(5.0, 5.4, 0.8),
		wall_material
	)
	return gate


func _create_trigger_area(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3
) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = position_value
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	area.add_child(collision)
	actors_root.add_child(area)
	return area


func _create_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	environment_root.add_child(body)
	return body


func _create_visual_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	environment_root.add_child(visual)
	return visual


func _create_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	font_size_value: int
) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = font_size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.visibility_range_end = 48.0
	label.visibility_range_end_margin = 4.0
	environment_root.add_child(label)
	return label


func _make_material(
	color: Color,
	metallic_value: float,
	roughness_value: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material


func _make_emissive_material(
	color: Color,
	emission_color: Color,
	emission_energy: float,
	transparent: bool = false
) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color, 0.2, 0.42)
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	return material


func _set_objective(text_value: String) -> void:
	if GameState.has_method("set_objective"):
		GameState.call("set_objective", text_value)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text_value)
	elif ui != null and ui.has_method("set_objective_text"):
		ui.call("set_objective_text", text_value)


func _show_message(text_value: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)
	else:
		print(text_value)


func get_debug_data() -> Dictionary:
	var controller: Node = (
		player.get_node_or_null("BodyFormController")
		if player != null
		else null
	)
	return {
		"body_forms_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"mass_completions": mass_completion_count,
		"passage_completions": passage_completion_count,
		"reliable_gate_opens": reliable_gate_open_count,
		"last_mass_kg": last_measured_mass_kg,
		"last_passage_form": last_passage_form,
		"last_passage_height": last_passage_collision_height,
		"last_gate_reason": last_gate_reason,
		"mass_plate": mass_plate.get_debug_data() if mass_plate != null else {},
		"body_form": (
			controller.call("get_debug_data")
			if controller != null and controller.has_method("get_debug_data")
			else {}
		),
		"completion_flag": GameState.get_flag(completion_flag),
	}
