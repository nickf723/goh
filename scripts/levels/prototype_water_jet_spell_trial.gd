extends Node3D
class_name PrototypeWaterJetSpellTrial

signal pressure_lane_completed
signal counterflow_ascent_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)

enum TrialStage {
	PRESSURE_LANE,
	COUNTERFLOW_ASCENT,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = "pressureworks_water_jet_trial_complete"
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Water Jet attempts."
)

var environment_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D
var initial_player_transform: Transform3D
var pressure_crate: RigidBody3D
var initial_crate_transform: Transform3D
var pressure_goal: Area3D
var upper_arrival: Area3D
var mastery_area: Area3D
var pressure_gate: MechanismSlidingGate
var ascent_gate: MechanismSlidingGate

var stage: TrialStage = TrialStage.PRESSURE_LANE
var trial_complete: bool = false
var pressure_completion_count: int = 0
var ascent_completion_count: int = 0
var launch_serial_at_stage_start: int = 0
var last_arrival_launch_serial: int = 0

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var water_material: StandardMaterial3D
var pressure_material: StandardMaterial3D
var gold_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("pressureworks_water_jet_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_pressure_lane()
	_build_counterflow_ascent()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.PRESSURE_LANE)
	_show_message(
		"The Pressureworks: sustain the jet to drive cargo, then turn its reaction force beneath Grace. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_water_jet")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "PressureworksEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "PressureworksActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(Color(0.04, 0.065, 0.09), 0.28, 0.7)
	wall_material = _make_material(Color(0.025, 0.04, 0.065), 0.52, 0.48)
	water_material = _make_emissive_material(
		Color(0.035, 0.3, 0.72, 0.88),
		Color(0.06, 0.52, 1.0),
		2.6
	)
	pressure_material = _make_emissive_material(
		Color(0.12, 0.62, 0.94, 0.92),
		Color(0.28, 0.84, 1.0),
		3.2
	)
	gold_material = _make_emissive_material(
		Color(0.7, 0.49, 0.07, 0.94),
		Color(1.0, 0.76, 0.1),
		3.8
	)


func _build_environment() -> void:
	_create_static_box(
		"PressureworksLowerFloor",
		Vector3(0.0, -0.5, 10.0),
		Vector3(14.0, 1.0, 42.0),
		floor_material
	)
	_create_static_box(
		"PressureworksRaisedPlatform",
		Vector3(0.0, 2.0, 31.0),
		Vector3(14.0, 4.0, 18.0),
		wall_material
	)
	_create_static_box(
		"PressureworksLeftWall",
		Vector3(-7.5, 3.0, 17.0),
		Vector3(1.0, 7.0, 54.0),
		wall_material
	)
	_create_static_box(
		"PressureworksRightWall",
		Vector3(7.5, 3.0, 17.0),
		Vector3(1.0, 7.0, 54.0),
		wall_material
	)
	_create_static_box(
		"PressureworksBackWall",
		Vector3(0.0, 3.0, -10.0),
		Vector3(14.0, 7.0, 1.0),
		wall_material
	)
	_create_static_box(
		"PressureworksFrontWall",
		Vector3(0.0, 5.0, 44.0),
		Vector3(14.0, 11.0, 1.0),
		wall_material
	)

	_create_label(
		"THE PRESSUREWORKS",
		Vector3(0.0, 5.0, -6.2),
		Color(0.54, 0.82, 1.0),
		34
	)
	_create_label(
		"Pressure moves the obstacle. Reaction moves the caster.",
		Vector3(0.0, 4.0, -3.1),
		Color(0.68, 0.84, 0.98),
		20
	)
	_create_label(
		"I • THE PRESSURE LANE",
		Vector3(0.0, 4.1, 0.0),
		Color(0.42, 0.74, 1.0),
		27
	)
	_create_label(
		"II • COUNTERFLOW ASCENT",
		Vector3(0.0, 4.1, 15.5),
		Color(0.42, 0.74, 1.0),
		27
	)

	_create_visual_box(
		"PressureLaneChannel",
		Vector3(0.0, 0.035, 5.2),
		Vector3(4.5, 0.05, 11.5),
		water_material
	)
	_create_visual_box(
		"CounterflowLaunchPad",
		Vector3(0.0, 0.055, 18.2),
		Vector3(5.0, 0.09, 4.0),
		pressure_material
	)
	_create_visual_box(
		"UpperWaterChannel",
		Vector3(0.0, 4.035, 28.0),
		Vector3(4.4, 0.05, 10.0),
		water_material
	)


func _build_pressure_lane() -> void:
	pressure_crate = RigidBody3D.new()
	pressure_crate.name = "PressureCrate"
	pressure_crate.position = Vector3(0.0, 0.7, 3.0)
	pressure_crate.mass = 12.0
	pressure_crate.linear_damp = 1.1
	pressure_crate.angular_damp = 5.0
	pressure_crate.axis_lock_angular_x = true
	pressure_crate.axis_lock_angular_y = true
	pressure_crate.axis_lock_angular_z = true
	var crate_collision := CollisionShape3D.new()
	var crate_shape := BoxShape3D.new()
	crate_shape.size = Vector3(1.4, 1.4, 1.4)
	crate_collision.shape = crate_shape
	pressure_crate.add_child(crate_collision)
	var crate_visual := MeshInstance3D.new()
	crate_visual.name = "PressureCrateVisual"
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(1.4, 1.4, 1.4)
	crate_visual.mesh = crate_mesh
	crate_visual.material_override = pressure_material
	pressure_crate.add_child(crate_visual)
	actors_root.add_child(pressure_crate)
	initial_crate_transform = pressure_crate.transform

	pressure_goal = _create_trigger_area(
		"PressureCrateBasin",
		Vector3(0.0, 1.0, 9.2),
		Vector3(4.2, 2.2, 2.2)
	)
	pressure_goal.body_entered.connect(_on_pressure_goal_body_entered)
	_create_visual_box(
		"PressureCrateBasinVisual",
		Vector3(0.0, 0.07, 9.2),
		Vector3(4.0, 0.12, 2.0),
		gold_material
	)
	_create_label(
		"HOLD THE JET • DRIVE THE 12 kg CARGO",
		Vector3(0.0, 3.1, 8.8),
		Color(0.7, 0.9, 1.0),
		18
	)
	pressure_gate = _spawn_gate_with_dividers(
		"PressureLaneGate",
		"Pressure Lane Gate",
		Vector3(0.0, 0.0, 12.0)
	)


func _build_counterflow_ascent() -> void:
	_create_label(
		"AIM INTO THE BLUE PAD • HOLD PRESSURE • RISE",
		Vector3(0.0, 3.1, 18.0),
		Color(0.7, 0.9, 1.0),
		18
	)
	_create_label(
		"The ledge has no stairs. The nozzle has opinions.",
		Vector3(0.0, 5.2, 22.1),
		Color(0.62, 0.78, 0.94),
		17
	)
	upper_arrival = _create_trigger_area(
		"CounterflowArrival",
		Vector3(0.0, 5.0, 26.0),
		Vector3(8.0, 2.2, 5.0)
	)
	upper_arrival.body_entered.connect(_on_upper_arrival_body_entered)
	_create_visual_box(
		"CounterflowArrivalVisual",
		Vector3(0.0, 4.07, 26.0),
		Vector3(7.5, 0.12, 4.5),
		gold_material
	)
	ascent_gate = _spawn_gate_with_dividers(
		"CounterflowGate",
		"Counterflow Gate",
		Vector3(0.0, 4.0, 32.0)
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"WaterJetMasteryArea",
		Vector3(0.0, 5.0, 38.0),
		Vector3(7.0, 2.4, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_body_entered)
	_create_visual_box(
		"WaterJetMasterySeal",
		Vector3(0.0, 4.08, 38.0),
		Vector3(5.0, 0.12, 3.2),
		gold_material
	)
	_create_label(
		"PRESSURE • PIN • PROPEL",
		Vector3(0.0, 7.8, 39.4),
		Color(1.0, 0.82, 0.28),
		26
	)


func _on_pressure_goal_body_entered(body: Node) -> void:
	if body != pressure_crate or stage != TrialStage.PRESSURE_LANE:
		return
	pressure_completion_count += 1
	pressure_crate.linear_velocity = Vector3.ZERO
	pressure_crate.angular_velocity = Vector3.ZERO
	pressure_crate.freeze = true
	pressure_gate.set_gate_open(
		true,
		false,
		{"reason": "water_jet_pressure_cargo"}
	)
	_set_stage(TrialStage.COUNTERFLOW_ASCENT)
	pressure_lane_completed.emit()
	_show_message(
		"Pressure lane complete. Aim Water Jet into the launch pad and ride the reaction force upward."
	)


func _on_upper_arrival_body_entered(body: Node) -> void:
	if body != player or stage != TrialStage.COUNTERFLOW_ASCENT:
		return
	var current_serial: int = int(
		player.get_meta("water_jet_self_launch_serial", 0)
	)
	last_arrival_launch_serial = current_serial
	if current_serial <= launch_serial_at_stage_start:
		_show_message(
			"The upper conductor requires a Water Jet self-launch, not ordinary climbing."
		)
		return
	ascent_completion_count += 1
	ascent_gate.set_gate_open(
		true,
		false,
		{"reason": "water_jet_counterflow_launch"}
	)
	_set_stage(TrialStage.MASTERY)
	counterflow_ascent_completed.emit()
	_show_message(
		"Counterflow confirmed. Preserve the landing and claim the mastery seal."
	)


func _on_mastery_area_body_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Water Jet mastered: PRESSURE • PIN • PROPEL.")


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.PRESSURE_LANE:
			_set_objective(
				"Water Jet: sustain the stream until the 12 kg cargo reaches the gold basin."
			)
		TrialStage.COUNTERFLOW_ASCENT:
			launch_serial_at_stage_start = int(
				player.get_meta("water_jet_self_launch_serial", 0)
			) if player != null else 0
			_set_objective(
				"Water Jet: aim into the blue floor pad and launch Grace onto the raised platform."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Water Jet: cross the upper gate and enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Pressureworks complete: PRESSURE • PIN • PROPEL."
			)


func _equip_water_jet() -> void:
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
		if ability != null and ability.get_spell_id() == "water_jet":
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	pressure_completion_count = 0
	ascent_completion_count = 0
	last_arrival_launch_serial = 0
	GameState.set_flag(completion_flag, false)
	_clear_water_jet_effects()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		player.set_meta("water_jet_mana_debt", 0.0)
		player.set_meta("water_jet_self_launch_serial", 0)
		player.set_meta("water_jet_self_launch_speed", 0.0)
	if pressure_crate != null:
		pressure_crate.freeze = false
		pressure_crate.transform = initial_crate_transform
		pressure_crate.linear_velocity = Vector3.ZERO
		pressure_crate.angular_velocity = Vector3.ZERO
		pressure_crate.sleeping = false
	if pressure_gate != null:
		pressure_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if ascent_gate != null:
		ascent_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	_restore_player_resources()
	_set_stage(TrialStage.PRESSURE_LANE)
	call_deferred("_equip_water_jet")
	trial_reset.emit()


func _clear_water_jet_effects() -> void:
	for effect: Node in get_tree().get_nodes_in_group("water_jet_effects"):
		if effect.has_method("finish_channel"):
			effect.call("finish_channel", "trial_reset")


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
	body.add_to_group("water_jet_recoil_surface")
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
	var material: StandardMaterial3D = _make_material(albedo, 0.3, 0.42)
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
	return {
		"water_jet_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"pressure_completions": pressure_completion_count,
		"ascent_completions": ascent_completion_count,
		"launch_serial_at_stage_start": launch_serial_at_stage_start,
		"last_arrival_launch_serial": last_arrival_launch_serial,
		"pressure_gate_open": (
			pressure_gate != null and pressure_gate.is_mechanism_active()
		),
		"ascent_gate_open": (
			ascent_gate != null and ascent_gate.is_mechanism_active()
		),
		"crate_position": (
			pressure_crate.global_position
			if pressure_crate != null
			else Vector3.ZERO
		),
	}
