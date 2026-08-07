extends Node3D
class_name PrototypeBoulderSpellTrial

signal flat_run_completed(cast_serial: int, impact_speed: float)
signal gravity_run_completed(cast_serial: int, supported_mass_kg: float)
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)
const HitReceiverScript = preload(
	"res://scripts/combat/hit_receiver.gd"
)

enum TrialStage {
	FLAT_MOMENTUM,
	GRAVITY_RUN,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = "momentum_quarry_boulder_trial_complete"
@export_range(0.02, 0.5, 0.01) var evaluation_interval: float = 0.08
@export_range(0.5, 20.0, 0.1) var required_flat_impact_speed: float = 3.0
@export_range(1.0, 1000.0, 1.0) var required_plate_mass_kg: float = 120.0
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Boulder casts."
)

var environment_root: Node3D = null
var actors_root: Node3D = null
var player: CharacterBody3D = null
var initial_player_transform: Transform3D

var flat_target: CharacterBody3D = null
var initial_flat_target_transform: Transform3D
var flat_gate: MechanismSlidingGate = null
var gravity_gate: MechanismSlidingGate = null
var mass_plate: PressurePlateSwitch = null
var mastery_area: Area3D = null

var stage: TrialStage = TrialStage.FLAT_MOMENTUM
var trial_complete: bool = false
var evaluation_remaining: float = 0.0
var flat_success_serial: int = 0
var flat_success_speed: float = 0.0
var gravity_success_serial: int = 0
var gravity_success_mass: float = 0.0
var gravity_cast_serial_baseline: int = 0

var floor_material: StandardMaterial3D = null
var wall_material: StandardMaterial3D = null
var earth_material: StandardMaterial3D = null
var target_material: StandardMaterial3D = null
var gold_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("momentum_quarry_spell_trial")
	add_to_group("boulder_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_flat_stage()
	_build_gravity_stage()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.FLAT_MOMENTUM)
	set_process(true)
	_show_message(
		"Momentum Quarry: roll one Boulder across the flat impact mark, then let gravity carry a fresh Boulder down the long grade. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_boulder")


func _process(delta: float) -> void:
	evaluation_remaining -= maxf(delta, 0.0)
	if evaluation_remaining > 0.0:
		return
	evaluation_remaining = maxf(evaluation_interval, 0.02)
	if stage == TrialStage.FLAT_MOMENTUM:
		_evaluate_flat_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "MomentumQuarryEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "MomentumQuarryActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(
		Color(0.12, 0.095, 0.07, 1.0),
		0.04,
		0.92
	)
	wall_material = _make_material(
		Color(0.07, 0.055, 0.04, 1.0),
		0.02,
		0.96
	)
	earth_material = _make_emissive_material(
		Color(0.46, 0.26, 0.08, 0.94),
		Color(0.94, 0.48, 0.08),
		2.8
	)
	target_material = _make_emissive_material(
		Color(0.33, 0.22, 0.1, 0.96),
		Color(0.88, 0.52, 0.14),
		1.45
	)
	gold_material = _make_emissive_material(
		Color(0.68, 0.46, 0.08, 0.96),
		Color(1.0, 0.78, 0.14),
		3.7
	)


func _build_environment() -> void:
	_create_static_box(
		"FlatQuarryFloor",
		Vector3(0.0, -0.5, 1.0),
		Vector3(12.0, 1.0, 22.0),
		floor_material
	)
	_create_static_box(
		"FlatLeftWall",
		Vector3(-6.5, 2.25, 1.0),
		Vector3(1.0, 5.5, 22.0),
		wall_material
	)
	_create_static_box(
		"FlatRightWall",
		Vector3(6.5, 2.25, 1.0),
		Vector3(1.0, 5.5, 22.0),
		wall_material
	)
	_create_static_box(
		"QuarryBackWall",
		Vector3(0.0, 2.25, -10.5),
		Vector3(12.0, 5.5, 1.0),
		wall_material
	)

	_create_static_box(
		"GravityGrade",
		Vector3(0.0, -2.1, 22.5),
		Vector3(12.0, 1.0, 21.0),
		floor_material,
		Vector3(12.0, 0.0, 0.0)
	)
	_create_static_box(
		"LowerQuarryFloor",
		Vector3(0.0, -4.7, 38.0),
		Vector3(12.0, 1.0, 18.0),
		floor_material
	)
	_create_static_box(
		"LowerLeftWall",
		Vector3(-6.5, -2.0, 38.0),
		Vector3(1.0, 6.5, 18.0),
		wall_material
	)
	_create_static_box(
		"LowerRightWall",
		Vector3(6.5, -2.0, 38.0),
		Vector3(1.0, 6.5, 18.0),
		wall_material
	)
	_create_static_box(
		"QuarryFrontWall",
		Vector3(0.0, -2.0, 47.5),
		Vector3(12.0, 6.5, 1.0),
		wall_material
	)

	_create_label(
		"THE MOMENTUM QUARRY",
		Vector3(0.0, 5.2, -7.2),
		Color(1.0, 0.68, 0.2),
		34
	)
	_create_label(
		"Motion is the timer.",
		Vector3(0.0, 4.1, -4.8),
		Color(0.88, 0.72, 0.48),
		22
	)
	_create_label(
		"I • FLAT MOMENTUM",
		Vector3(0.0, 4.2, -1.4),
		Color(1.0, 0.62, 0.12),
		27
	)
	_create_label(
		"II • THE LONG GRADE",
		Vector3(0.0, 4.0, 12.4),
		Color(1.0, 0.62, 0.12),
		27
	)

	_create_visual_box(
		"FlatCastingMark",
		Vector3(0.0, 0.06, -5.0),
		Vector3(3.2, 0.12, 1.4),
		earth_material
	)
	_create_visual_box(
		"GradeCastingMark",
		Vector3(0.0, 0.06, 11.8),
		Vector3(3.2, 0.12, 1.4),
		earth_material
	)


func _build_flat_stage() -> void:
	flat_target = _create_impact_target(
		"FlatMomentumTarget",
		"FLAT IMPACT",
		Vector3(0.0, 1.0, 4.3)
	)
	initial_flat_target_transform = flat_target.transform
	_create_label(
		"ONE BOULDER • ONE IMPACT • LET THE FLAT FLOOR STOP IT",
		Vector3(0.0, 3.2, 5.6),
		Color(0.94, 0.78, 0.44),
		17
	)
	flat_gate = _spawn_gate_with_dividers(
		"FlatMomentumGate",
		"Flat Momentum Gate",
		Vector3(0.0, 0.0, 9.5),
		0.0
	)


func _build_gravity_stage() -> void:
	mass_plate = PressurePlateScene.instantiate() as PressurePlateSwitch
	mass_plate.name = "BoulderMassPlate"
	mass_plate.position = Vector3(0.0, -4.15, 33.5)
	mass_plate.display_name = "160 kg Momentum Plate"
	mass_plate.accept_any_physics_body = true
	mass_plate.default_non_rigid_body_mass_kg = 70.0
	mass_plate.maximum_reported_mass_kg = 200.0
	mass_plate.show_weight_in_label = true
	actors_root.add_child(mass_plate)
	mass_plate.mechanism_value_changed.connect(
		_on_mass_plate_value_changed
	)
	_create_label(
		"CAST FROM THE TOP • GRAVITY MUST CARRY 120 KG TO THE PLATE",
		Vector3(0.0, -0.9, 31.5),
		Color(0.94, 0.78, 0.44),
		17
	)
	gravity_gate = _spawn_gate_with_dividers(
		"GravityRunGate",
		"Gravity Run Gate",
		Vector3(0.0, -4.2, 39.0),
		-4.2
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"BoulderMasteryArea",
		Vector3(0.0, -3.4, 44.0),
		Vector3(7.0, 2.6, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_entered)
	_create_visual_box(
		"BoulderMasterySeal",
		Vector3(0.0, -4.12, 44.0),
		Vector3(5.2, 0.14, 3.2),
		gold_material
	)
	_create_label(
		"MASS • MOMENTUM • GRADE",
		Vector3(0.0, -0.3, 45.4),
		Color(1.0, 0.84, 0.28),
		26
	)


func _evaluate_flat_run() -> void:
	if flat_target == null or not is_instance_valid(flat_target):
		return
	var serial: int = int(
		flat_target.get_meta("boulder_last_cast_serial", 0)
	)
	var impact_speed: float = float(
		flat_target.get_meta("boulder_last_impact_speed", 0.0)
	)
	if serial <= 0 or impact_speed < required_flat_impact_speed:
		return

	flat_success_serial = serial
	flat_success_speed = impact_speed
	flat_gate.set_gate_open(
		true,
		false,
		{"reason": "flat_boulder_impact"}
	)
	_set_stage(TrialStage.GRAVITY_RUN)
	flat_run_completed.emit(serial, impact_speed)
	_show_message(
		"Flat momentum confirmed. The first Boulder will crumble only after its motion settles. Cast a fresh Boulder from the top of the grade."
	)


func _on_mass_plate_value_changed(
	value: float,
	packet: Dictionary
) -> void:
	if stage != TrialStage.GRAVITY_RUN:
		return
	if value < required_plate_mass_kg:
		return
	var matching_boulder: Node = _find_plate_boulder(packet)
	if matching_boulder == null:
		return
	var serial: int = int(
		matching_boulder.get_meta("boulder_cast_serial", 0)
	)
	if serial <= gravity_cast_serial_baseline:
		return

	gravity_success_serial = serial
	gravity_success_mass = value
	gravity_gate.set_gate_open(
		true,
		false,
		{"reason": "rolling_boulder_mass_plate"}
	)
	_set_stage(TrialStage.MASTERY)
	gravity_run_completed.emit(serial, value)
	_show_message(
		"The grade kept the Boulder alive until 160 kg crossed the plate. Motion, not age, governs its lifetime."
	)


func _find_plate_boulder(packet: Dictionary) -> Node:
	var body_rows_value: Variant = packet.get("body_masses", [])
	if not body_rows_value is Array:
		return null
	for row_value: Variant in body_rows_value as Array:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		var body_name: String = str(row.get("name", ""))
		for candidate: Node in get_tree().get_nodes_in_group(
			"earth_boulder_effects"
		):
			if (
				candidate != null
				and is_instance_valid(candidate)
				and str(candidate.name) == body_name
			):
				return candidate
	return null


func _on_mastery_area_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Boulder mastered: MASS • MOMENTUM • GRADE.")


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.FLAT_MOMENTUM:
			_set_objective(
				"Boulder: stand on the first earth mark and roll one Boulder into the Flat Impact target."
			)
		TrialStage.GRAVITY_RUN:
			gravity_cast_serial_baseline = (
				int(player.get_meta("boulder_cast_serial", 0))
				if player != null
				else 0
			)
			_set_objective(
				"Boulder: cast a fresh Boulder from the top mark and let the grade carry it onto the 120 kg plate."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Boulder: cross the lower gate and enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Momentum Quarry complete: MASS • MOMENTUM • GRADE."
			)


func _equip_boulder() -> void:
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
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "boulder":
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	flat_success_serial = 0
	flat_success_speed = 0.0
	gravity_success_serial = 0
	gravity_success_mass = 0.0
	gravity_cast_serial_baseline = 0
	GameState.set_flag(completion_flag, false)
	_clear_boulders()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		player.set_meta("boulder_cast_serial", 0)
		player.remove_meta("boulder_last_spawn_position")
	if flat_target != null:
		flat_target.transform = initial_flat_target_transform
		flat_target.velocity = Vector3.ZERO
		flat_target.remove_meta("boulder_last_cast_serial")
		flat_target.remove_meta("boulder_last_impact_speed")
		flat_target.remove_meta("boulder_last_impact_energy")
		flat_target.remove_meta("boulder_last_impact_count")
		var hit_receiver: Node = flat_target.get_node_or_null("HitReceiver")
		if hit_receiver != null:
			if hit_receiver.has_method("reset_health"):
				hit_receiver.call("reset_health")
			if hit_receiver.has_method("reset_stance"):
				hit_receiver.call("reset_stance")
	if mass_plate != null:
		mass_plate.reset_target()
	if flat_gate != null:
		flat_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if gravity_gate != null:
		gravity_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	_restore_player_resources()
	_set_stage(TrialStage.FLAT_MOMENTUM)
	call_deferred("_equip_boulder")
	trial_reset.emit()


func _clear_boulders() -> void:
	for boulder: Node in get_tree().get_nodes_in_group(
		"earth_boulder_effects"
	):
		if boulder == null or not is_instance_valid(boulder):
			continue
		if boulder.has_method("reset_target"):
			boulder.call("reset_target")
		else:
			boulder.queue_free()


func _restore_player_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _create_impact_target(
	node_name: String,
	display_name_value: String,
	position_value: Vector3
) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = node_name
	target.position = position_value
	target.collision_layer = 1
	target.collision_mask = 1
	target.add_to_group("boulder_trial_targets")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.9
	shape.height = 2.2
	collision.shape = shape
	target.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.name = "TargetVisual"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.9
	mesh.height = 2.2
	visual.mesh = mesh
	visual.material_override = target_material
	target.add_child(visual)
	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", display_name_value)
	hit_receiver.set("hit_mode", 2)
	hit_receiver.set("max_health", 80)
	hit_receiver.set("current_health", 80)
	hit_receiver.set("max_stance", 50)
	hit_receiver.set("current_stance", 50)
	hit_receiver.set("regenerates_stance", false)
	target.add_child(hit_receiver)
	actors_root.add_child(target)
	_create_label_under(
		target,
		display_name_value,
		Vector3(0.0, 1.85, 0.0),
		Color(1.0, 0.74, 0.24),
		16
	)
	return target


func _spawn_gate_with_dividers(
	node_name: String,
	display_name_value: String,
	position_value: Vector3,
	divider_center_y: float
) -> MechanismSlidingGate:
	var gate: MechanismSlidingGate = GateScene.instantiate() as MechanismSlidingGate
	gate.name = node_name
	gate.display_name = display_name_value
	gate.position = position_value
	gate.scale = Vector3(1.3, 1.0, 1.0)
	gate.open_offset = Vector3(0.0, 4.5, 0.0)
	gate.transition_seconds = 0.45
	actors_root.add_child(gate)
	var state_label: Label3D = gate.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		state_label.visible = false
	_create_static_box(
		node_name + "LeftDivider",
		Vector3(-4.7, divider_center_y + 2.2, position_value.z),
		Vector3(5.0, 5.4, 0.8),
		wall_material
	)
	_create_static_box(
		node_name + "RightDivider",
		Vector3(4.7, divider_center_y + 2.2, position_value.z),
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
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation_degrees = rotation_value
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
	label.outline_size = 5
	environment_root.add_child(label)
	return label


func _create_label_under(
	parent: Node3D,
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
	label.outline_size = 5
	parent.add_child(label)
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
	emission_energy: float
) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color, 0.18, 0.58)
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	return material


func _set_objective(text_value: String) -> void:
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
	return {
		"boulder_trial": true,
		"stage": TrialStage.keys()[stage],
		"trial_complete": trial_complete,
		"flat_success_serial": flat_success_serial,
		"flat_success_speed": flat_success_speed,
		"gravity_success_serial": gravity_success_serial,
		"gravity_success_mass": gravity_success_mass,
		"gravity_serial_baseline": gravity_cast_serial_baseline,
		"plate_mass": (
			mass_plate.get_mechanism_value() if mass_plate != null else 0.0
		),
		"active_boulders": get_tree().get_node_count_in_group(
			"earth_boulder_effects"
		),
		"completion_flag": completion_flag,
	}
