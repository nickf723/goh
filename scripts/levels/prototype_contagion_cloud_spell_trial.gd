extends Node3D
class_name PrototypeContagionCloudSpellTrial

signal procession_completed(cast_serial: int)
signal outpace_completed(cast_serial: int)
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const StatusReceiverScript = preload(
	"res://scripts/combat/status_receiver.gd"
)
const HitReceiverScript = preload(
	"res://scripts/combat/hit_receiver.gd"
)

enum TrialStage {
	UNBROKEN_FRONT,
	OUTPACE_THE_PLUME,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = (
	"pestilent_procession_contagion_cloud_trial_complete"
)
@export_range(0.05, 1.0, 0.01) var evaluation_interval: float = 0.12
@export_range(0.5, 12.0, 0.1) var minimum_race_cloud_distance: float = 3.0
@export_range(0.0, 1.0, 0.05) var minimum_race_alignment_dot: float = 0.78
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between cloud casts."
)

var environment_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D
var initial_player_transform: Transform3D

var procession_targets: Array[CharacterBody3D] = []
var initial_target_transforms: Array[Transform3D] = []
var procession_gate: MechanismSlidingGate
var race_gate: MechanismSlidingGate
var race_finish_area: Area3D
var mastery_area: Area3D

var stage: TrialStage = TrialStage.UNBROKEN_FRONT
var trial_complete: bool = false
var evaluation_remaining: float = 0.0
var procession_completion_count: int = 0
var race_completion_count: int = 0
var procession_serial: int = 0
var race_serial_baseline: int = 0
var successful_race_serial: int = 0
var last_race_failure: String = "none"
var lane_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var race_finish_z: float = 31.0

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var poison_material: StandardMaterial3D
var target_material: StandardMaterial3D
var race_material: StandardMaterial3D
var gold_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("pestilent_procession_spell_trial")
	add_to_group("contagion_cloud_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_unbroken_front()
	_build_outpace_course()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.UNBROKEN_FRONT)
	set_process(true)
	_show_message(
		"The Pestilent Procession: send one cloud through every witness, then prove that Grace can outrun the same slow front. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_contagion_cloud")


func _process(delta: float) -> void:
	evaluation_remaining -= maxf(delta, 0.0)
	if evaluation_remaining > 0.0:
		return
	evaluation_remaining = maxf(evaluation_interval, 0.05)
	if stage == TrialStage.UNBROKEN_FRONT:
		_evaluate_procession()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "PestilentProcessionEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "PestilentProcessionActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(Color(0.045, 0.065, 0.05), 0.22, 0.76)
	wall_material = _make_material(Color(0.025, 0.04, 0.032), 0.42, 0.58)
	poison_material = _make_emissive_material(
		Color(0.22, 0.58, 0.08, 0.9),
		Color(0.48, 1.0, 0.12),
		2.7
	)
	target_material = _make_emissive_material(
		Color(0.18, 0.36, 0.12, 0.95),
		Color(0.34, 0.8, 0.18),
		1.35
	)
	race_material = _make_emissive_material(
		Color(0.1, 0.46, 0.22, 0.9),
		Color(0.18, 0.92, 0.42),
		2.25
	)
	gold_material = _make_emissive_material(
		Color(0.68, 0.48, 0.07, 0.94),
		Color(1.0, 0.76, 0.1),
		3.7
	)


func _build_environment() -> void:
	_create_static_box(
		"ProcessionFloor",
		Vector3(0.0, -0.5, 18.0),
		Vector3(14.0, 1.0, 54.0),
		floor_material
	)
	_create_static_box(
		"ProcessionLeftWall",
		Vector3(-7.5, 3.0, 18.0),
		Vector3(1.0, 7.0, 54.0),
		wall_material
	)
	_create_static_box(
		"ProcessionRightWall",
		Vector3(7.5, 3.0, 18.0),
		Vector3(1.0, 7.0, 54.0),
		wall_material
	)
	_create_static_box(
		"ProcessionBackWall",
		Vector3(0.0, 3.0, -9.0),
		Vector3(14.0, 7.0, 1.0),
		wall_material
	)
	_create_static_box(
		"ProcessionFrontWall",
		Vector3(0.0, 3.0, 45.0),
		Vector3(14.0, 7.0, 1.0),
		wall_material
	)

	_create_label(
		"THE PESTILENT PROCESSION",
		Vector3(0.0, 5.0, -5.7),
		Color(0.56, 1.0, 0.24),
		34
	)
	_create_label(
		"The cloud does not stop to admire its work.",
		Vector3(0.0, 4.0, -2.9),
		Color(0.68, 0.9, 0.54),
		20
	)
	_create_label(
		"I • THE UNBROKEN FRONT",
		Vector3(0.0, 4.2, 0.0),
		Color(0.52, 0.96, 0.22),
		27
	)
	_create_label(
		"II • OUTPACE THE PLUME",
		Vector3(0.0, 4.2, 17.5),
		Color(0.52, 0.96, 0.22),
		27
	)

	_create_visual_box(
		"ProcessionLane",
		Vector3(0.0, 0.035, 6.5),
		Vector3(5.0, 0.05, 14.0),
		poison_material
	)
	_create_visual_box(
		"RaceLane",
		Vector3(0.0, 0.035, 25.0),
		Vector3(5.0, 0.05, 15.0),
		race_material
	)


func _build_unbroken_front() -> void:
	var target_positions: Array[Vector3] = [
		Vector3(0.0, 1.0, 2.5),
		Vector3(0.0, 1.0, 6.5),
		Vector3(0.0, 1.0, 10.5),
	]
	var target_names: Array[String] = [
		"First Witness",
		"Second Witness",
		"Third Witness",
	]
	for target_index: int in range(target_positions.size()):
		var target: CharacterBody3D = _create_poison_target(
			"ProcessionWitness" + str(target_index + 1),
			target_names[target_index],
			target_positions[target_index]
		)
		procession_targets.append(target)
		initial_target_transforms.append(target.transform)

	_create_label(
		"ONE CLOUD • THREE WITNESSES • NO IMPACT DISSIPATION",
		Vector3(0.0, 3.1, 11.1),
		Color(0.72, 0.96, 0.56),
		17
	)
	procession_gate = _spawn_gate_with_dividers(
		"ProcessionGate",
		"Unbroken Front Gate",
		Vector3(0.0, 0.0, 14.0)
	)


func _build_outpace_course() -> void:
	_create_visual_box(
		"RaceStartMark",
		Vector3(0.0, 0.075, 18.5),
		Vector3(5.0, 0.12, 1.0),
		poison_material
	)
	_create_label(
		"CAST FORWARD HERE • RUN PAST YOUR OWN CLOUD",
		Vector3(0.0, 3.0, 18.5),
		Color(0.72, 0.96, 0.56),
		17
	)
	race_finish_area = _create_trigger_area(
		"OutpaceFinish",
		Vector3(0.0, 1.0, race_finish_z),
		Vector3(8.0, 2.4, 2.0)
	)
	race_finish_area.body_entered.connect(_on_race_finish_entered)
	_create_visual_box(
		"OutpaceFinishMark",
		Vector3(0.0, 0.075, race_finish_z),
		Vector3(7.5, 0.12, 1.3),
		gold_material
	)
	_create_label(
		"REACH THIS LINE BEFORE THE ACTIVE CLOUD",
		Vector3(0.0, 3.0, race_finish_z),
		Color(1.0, 0.82, 0.28),
		17
	)
	race_gate = _spawn_gate_with_dividers(
		"OutpaceGate",
		"Outpace Gate",
		Vector3(0.0, 0.0, 34.0)
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"ContagionCloudMasteryArea",
		Vector3(0.0, 1.0, 40.0),
		Vector3(7.0, 2.4, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_entered)
	_create_visual_box(
		"ContagionCloudMasterySeal",
		Vector3(0.0, 0.08, 40.0),
		Vector3(5.0, 0.14, 3.2),
		gold_material
	)
	_create_label(
		"CAST • CONTAMINATE • OUTPACE",
		Vector3(0.0, 4.2, 41.4),
		Color(1.0, 0.82, 0.28),
		26
	)


func _evaluate_procession() -> void:
	if procession_targets.size() < 3:
		return
	var shared_serial: int = 0
	for target: CharacterBody3D in procession_targets:
		if target == null or not is_instance_valid(target):
			return
		var serial: int = int(
			target.get_meta("contagion_cloud_last_serial", 0)
		)
		if serial <= 0:
			return
		if shared_serial == 0:
			shared_serial = serial
		elif serial != shared_serial:
			return
	if shared_serial <= 0:
		return
	procession_serial = shared_serial
	procession_completion_count += 1
	procession_gate.set_gate_open(
		true,
		false,
		{"reason": "one_cloud_poisoned_three_witnesses"}
	)
	_set_stage(TrialStage.OUTPACE_THE_PLUME)
	procession_completed.emit(shared_serial)
	_show_message(
		"The cloud crossed all three witnesses without disappearing. Cast a fresh cloud down the green lane and run past it."
	)


func _on_race_finish_entered(body: Node) -> void:
	if body != player or stage != TrialStage.OUTPACE_THE_PLUME:
		return
	var cloud: ContagionCloud = _find_latest_player_cloud(
		race_serial_baseline
	)
	if cloud == null:
		last_race_failure = "no_new_cloud"
		_show_message("Cast a fresh Contagion Cloud from the race mark first.")
		return
	var cloud_debug: Dictionary = cloud.get_debug_data()
	var cloud_direction: Vector3 = cloud_debug.get(
		"direction",
		Vector3.ZERO
	) as Vector3
	if cloud_direction.length_squared() <= 0.0001 or (
		cloud_direction.normalized().dot(lane_direction)
		< minimum_race_alignment_dot
	):
		last_race_failure = "wrong_direction"
		_show_message("The race cloud must travel forward through the marked lane.")
		return
	var cloud_distance: float = float(
		cloud_debug.get("distance_travelled", 0.0)
	)
	if cloud_distance < minimum_race_cloud_distance:
		last_race_failure = "cloud_not_established"
		_show_message("Let the cloud establish a moving front before crossing the finish.")
		return
	if not bool(cloud_debug.get("active", false)):
		last_race_failure = "cloud_expired"
		_show_message("The race requires an active cloud, not its memory.")
		return
	if cloud.global_position.z >= race_finish_z - 0.35:
		last_race_failure = "cloud_arrived_first"
		_show_message("The cloud reached the line first. Cast again and run sooner.")
		return

	successful_race_serial = int(cloud_debug.get("cast_serial", 0))
	race_completion_count += 1
	last_race_failure = "none"
	race_gate.set_gate_open(
		true,
		false,
		{"reason": "player_outpaced_active_cloud"}
	)
	_set_stage(TrialStage.MASTERY)
	outpace_completed.emit(successful_race_serial)
	_show_message(
		"Grace outran the active front. The cloud remains behind on its own timer."
	)


func _on_mastery_area_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Contagion Cloud mastered: CAST • CONTAMINATE • OUTPACE.")


func _find_latest_player_cloud(
	minimum_serial_exclusive: int
) -> ContagionCloud:
	var selected: ContagionCloud
	var selected_serial: int = minimum_serial_exclusive
	for candidate: Node in get_tree().get_nodes_in_group(
		"contagion_cloud_effects"
	):
		if not candidate is ContagionCloud:
			continue
		var cloud: ContagionCloud = candidate as ContagionCloud
		if not cloud.belongs_to_source(player):
			continue
		var serial: int = int(
			cloud.get_debug_data().get("cast_serial", 0)
		)
		if serial <= selected_serial:
			continue
		selected = cloud
		selected_serial = serial
	return selected


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.UNBROKEN_FRONT:
			_set_objective(
				"Contagion Cloud: poison all three witnesses with one moving cloud."
			)
		TrialStage.OUTPACE_THE_PLUME:
			race_serial_baseline = int(
				player.get_meta("contagion_cloud_serial", 0)
			) if player != null else 0
			_set_objective(
				"Contagion Cloud: cast forward from the green mark and reach the gold line before the active cloud."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Contagion Cloud: cross the open gate and enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Pestilent Procession complete: CAST • CONTAMINATE • OUTPACE."
			)


func _equip_contagion_cloud() -> void:
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
		if ability != null and ability.get_spell_id() == "contagion_cloud":
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	procession_completion_count = 0
	race_completion_count = 0
	procession_serial = 0
	race_serial_baseline = 0
	successful_race_serial = 0
	last_race_failure = "none"
	GameState.set_flag(completion_flag, false)
	_clear_contagion_clouds()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		player.set_meta("contagion_cloud_serial", 0)
		player.remove_meta("contagion_cloud_last_direction")
	for target_index: int in range(procession_targets.size()):
		var target: CharacterBody3D = procession_targets[target_index]
		if target == null or not is_instance_valid(target):
			continue
		if target_index < initial_target_transforms.size():
			target.transform = initial_target_transforms[target_index]
		target.velocity = Vector3.ZERO
		target.remove_meta("contagion_cloud_last_serial")
		target.remove_meta("contagion_cloud_last_source_id")
		target.remove_meta("contagion_cloud_last_tick_msec")
		var status_receiver: Node = target.get_node_or_null("StatusReceiver")
		if status_receiver != null and status_receiver.has_method(
			"clear_all_statuses"
		):
			status_receiver.call("clear_all_statuses")
		var hit_receiver: Node = target.get_node_or_null("HitReceiver")
		if hit_receiver != null:
			if hit_receiver.has_method("reset_health"):
				hit_receiver.call("reset_health")
			if hit_receiver.has_method("reset_stance"):
				hit_receiver.call("reset_stance")
	if procession_gate != null:
		procession_gate.set_gate_open(
			false,
			true,
			{"reason": "trial_reset"}
		)
	if race_gate != null:
		race_gate.set_gate_open(
			false,
			true,
			{"reason": "trial_reset"}
		)
	_restore_player_resources()
	_set_stage(TrialStage.UNBROKEN_FRONT)
	call_deferred("_equip_contagion_cloud")
	trial_reset.emit()


func _clear_contagion_clouds() -> void:
	for cloud: Node in get_tree().get_nodes_in_group(
		"contagion_cloud_effects"
	):
		if cloud.has_method("finish_cloud"):
			cloud.call("finish_cloud", "trial_reset")


func _restore_player_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _create_poison_target(
	node_name: String,
	display_name: String,
	position_value: Vector3
) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = node_name
	target.position = position_value
	target.collision_layer = 1
	target.collision_mask = 1
	target.add_to_group("contagion_trial_targets")
	target.add_to_group("contagion_cloud_pass_through")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 2.0
	collision.shape = shape
	target.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.name = "WitnessVisual"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.55
	mesh.height = 2.0
	visual.mesh = mesh
	visual.material_override = target_material
	target.add_child(visual)
	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", display_name)
	hit_receiver.set("hit_mode", 2)
	hit_receiver.set("max_health", 20)
	hit_receiver.set("current_health", 20)
	hit_receiver.set("max_stance", 10)
	hit_receiver.set("current_stance", 10)
	hit_receiver.set("regenerates_stance", false)
	target.add_child(hit_receiver)
	var status_receiver: Node = StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	target.add_child(status_receiver)
	actors_root.add_child(target)
	_create_label_under(
		target,
		display_name.to_upper(),
		Vector3(0.0, 1.8, 0.0),
		Color(0.68, 0.94, 0.52),
		15
	)
	return target


func _spawn_gate_with_dividers(
	node_name: String,
	display_name_value: String,
	position_value: Vector3
) -> MechanismSlidingGate:
	var gate: MechanismSlidingGate = GateScene.instantiate() as MechanismSlidingGate
	gate.name = node_name
	gate.display_name = display_name_value
	gate.position = position_value
	gate.scale = Vector3(1.35, 1.0, 1.0)
	gate.open_offset = Vector3(0.0, 4.5, 0.0)
	gate.transition_seconds = 0.45
	actors_root.add_child(gate)
	var state_label: Label3D = gate.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		state_label.visible = false
	var divider_root := Node3D.new()
	divider_root.name = node_name + "Dividers"
	divider_root.position = position_value
	environment_root.add_child(divider_root)
	_create_static_box_under(
		divider_root,
		node_name + "LeftDivider",
		Vector3(-5.2, 2.2, 0.0),
		Vector3(4.6, 5.4, 0.8),
		wall_material
	)
	_create_static_box_under(
		divider_root,
		node_name + "RightDivider",
		Vector3(5.2, 2.2, 0.0),
		Vector3(4.6, 5.4, 0.8),
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
	return _create_static_box_under(
		environment_root,
		node_name,
		position_value,
		size_value,
		material
	)


func _create_static_box_under(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.add_to_group("contagion_cloud_blocker")
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
	parent.add_child(body)
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
	label.font_size = font_size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	label.visibility_range_end = 48.0
	label.visibility_range_end_margin = 4.0
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
	label.font_size = font_size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = color
	parent.add_child(label)
	return label


func _make_material(
	color: Color,
	metallic: float,
	roughness: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive_material(
	albedo: Color,
	emission_color: Color,
	energy: float
) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(albedo, 0.28, 0.46)
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func _set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text)


func get_debug_data() -> Dictionary:
	var target_serials: Array[int] = []
	var target_statuses: Array[bool] = []
	for target: CharacterBody3D in procession_targets:
		target_serials.append(int(
			target.get_meta("contagion_cloud_last_serial", 0)
		) if target != null else 0)
		var receiver: Node = (
			target.get_node_or_null("StatusReceiver")
			if target != null
			else null
		)
		target_statuses.append(
			receiver != null
			and receiver.has_method("has_status")
			and bool(receiver.call("has_status", "poisoned"))
		)
	return {
		"contagion_cloud_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"procession_completions": procession_completion_count,
		"race_completions": race_completion_count,
		"procession_serial": procession_serial,
		"race_serial_baseline": race_serial_baseline,
		"successful_race_serial": successful_race_serial,
		"last_race_failure": last_race_failure,
		"target_serials": target_serials,
		"target_poisoned_now": target_statuses,
		"procession_gate_open": (
			procession_gate != null
			and procession_gate.is_mechanism_active()
		),
		"race_gate_open": (
			race_gate != null and race_gate.is_mechanism_active()
		),
	}
