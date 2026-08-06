extends Node3D
class_name PrototypeColdForgeSpellTrial

signal fading_lock_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const ElevatorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_value_elevator.tscn"
)

enum TrialStage {
	FADING_LOCK,
	BOILER_LIFT,
	COMPLETE,
}

@export_group("Fading Lock")
@export var fading_required_temperature_c: float = 150.0
@export_range(0.1, 10.0, 0.05) var fading_hold_seconds: float = 1.25

@export_group("Boiler Lift")
@export var boiler_minimum_temperature_c: float = -35.0
@export var boiler_full_height_temperature_c: float = 150.0
@export var boiler_lift_height: float = 5.5

@export_group("Trial")
@export var completion_flag: String = "cold_forge_spell_trial_complete"
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between sustained casts."
)

var environment_root: Node3D
var mechanisms_root: Node3D
var signal_root: Node

var player: CharacterBody3D
var fading_target: Area3D
var fading_thermal: ThermalState
var fading_source: ThermalMechanismSource
var fading_requirement: SustainedHeatLock
var fading_gate: MechanismSlidingGate
var fading_gate_adapter: MechanismOutputAdapter
var fading_label: Label3D

var boiler_target: Area3D
var boiler_thermal: ThermalState
var boiler_source: ThermalMechanismSource
var boiler_elevator: MechanismValueElevator
var boiler_label: Label3D
var completion_area: Area3D

var thermal_presentations: Dictionary = {}
var stage: TrialStage = TrialStage.FADING_LOCK
var trial_complete: bool = false
var fading_progress: float = 0.0
var initial_player_transform: Transform3D
var presentation_updates: int = 0

var cold_stone_material: StandardMaterial3D
var dark_iron_material: StandardMaterial3D
var brass_material: StandardMaterial3D
var frost_material: StandardMaterial3D
var hot_channel_material: StandardMaterial3D
var completion_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("cold_forge_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_fading_lock()
	_build_boiler_lift()
	_build_completion_landing()
	_connect_runtime_signals()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.FADING_LOCK)
	_show_message(
		"Cold Forge trial: Firebolt supplies a burst. Flamethrower supplies sustained heat. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_flamethrower")
	call_deferred("_refresh_all_presentation")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "ColdForgeEnvironment"
	add_child(environment_root)
	mechanisms_root = Node3D.new()
	mechanisms_root.name = "ColdForgeMechanisms"
	add_child(mechanisms_root)
	signal_root = Node.new()
	signal_root.name = "ColdForgeSignalNetwork"
	add_child(signal_root)


func _build_materials() -> void:
	cold_stone_material = _make_material(
		Color(0.075, 0.1, 0.14),
		0.12,
		0.88
	)
	dark_iron_material = _make_material(
		Color(0.09, 0.11, 0.14),
		0.72,
		0.32
	)
	brass_material = _make_material(
		Color(0.47, 0.31, 0.1),
		0.82,
		0.24
	)
	frost_material = _make_emissive_material(
		Color(0.12, 0.34, 0.58, 0.72),
		Color(0.04, 0.42, 0.9),
		1.6
	)
	hot_channel_material = _make_emissive_material(
		Color(0.64, 0.2, 0.03, 0.78),
		Color(1.0, 0.22, 0.02),
		3.0
	)
	completion_material = _make_emissive_material(
		Color(0.65, 0.45, 0.08, 0.8),
		Color(1.0, 0.72, 0.12),
		3.6
	)


func _build_environment() -> void:
	_create_static_box(
		"ForgeFloor",
		Vector3(0.0, -0.5, 20.0),
		Vector3(18.0, 1.0, 54.0),
		cold_stone_material
	)
	_create_static_box(
		"ForgeLeftWall",
		Vector3(-9.5, 2.5, 20.0),
		Vector3(1.0, 6.0, 54.0),
		dark_iron_material
	)
	_create_static_box(
		"ForgeRightWall",
		Vector3(9.5, 2.5, 20.0),
		Vector3(1.0, 6.0, 54.0),
		dark_iron_material
	)
	_create_static_box(
		"ForgeBackWall",
		Vector3(0.0, 2.5, -7.0),
		Vector3(18.0, 6.0, 1.0),
		dark_iron_material
	)
	_create_static_box(
		"ForgeFrontWall",
		Vector3(0.0, 2.5, 47.0),
		Vector3(18.0, 6.0, 1.0),
		dark_iron_material
	)

	_create_static_box(
		"FadingDividerLeft",
		Vector3(-6.35, 2.1, 14.0),
		Vector3(7.3, 5.2, 0.8),
		dark_iron_material
	)
	_create_static_box(
		"FadingDividerRight",
		Vector3(6.35, 2.1, 14.0),
		Vector3(7.3, 5.2, 0.8),
		dark_iron_material
	)

	_create_static_box(
		"UpperLanding",
		Vector3(0.0, 5.25, 39.0),
		Vector3(18.0, 0.5, 14.0),
		cold_stone_material
	)
	_create_static_box(
		"LiftLeftRail",
		Vector3(-2.8, 3.0, 29.0),
		Vector3(0.28, 6.5, 0.28),
		brass_material
	)
	_create_static_box(
		"LiftRightRail",
		Vector3(2.8, 3.0, 29.0),
		Vector3(0.28, 6.5, 0.28),
		brass_material
	)

	_create_label(
		"THE COLD FORGE",
		Vector3(0.0, 4.8, -3.5),
		Color(0.62, 0.82, 1.0),
		34
	)
	_create_label(
		"A spark fades. A stream endures.",
		Vector3(0.0, 3.9, 3.2),
		Color(0.64, 0.76, 0.9),
		24
	)
	_create_label(
		"I • FADING LOCK",
		Vector3(0.0, 4.1, 10.6),
		Color(0.55, 0.8, 1.0),
		28
	)
	_create_label(
		"II • BOILER LIFT",
		Vector3(0.0, 4.6, 21.0),
		Color(0.74, 0.56, 0.24),
		28
	)


func _build_fading_lock() -> void:
	var target_data: Dictionary = _create_thermal_target(
		"FadingSeal",
		mechanisms_root,
		Vector3(0.0, 1.4, 7.2),
		Vector3(2.7, 2.7, 0.8),
		-35.0,
		-35.0,
		10.0,
		2.0,
		"FROZEN SEAL"
	)
	fading_target = target_data["target"] as Area3D
	fading_thermal = target_data["thermal"] as ThermalState
	fading_label = target_data["label"] as Label3D

	fading_source = ThermalMechanismSource.new()
	fading_source.name = "FadingSealTemperature"
	fading_source.mechanism_id = "cold_forge_fading_seal_temperature"
	fading_source.display_name = "Fading Seal Temperature"
	fading_source.thermal_state_path = NodePath()
	fading_source.minimum_value = -50.0
	fading_source.maximum_value = 250.0
	fading_source.active_threshold_c = fading_required_temperature_c
	signal_root.add_child(fading_source)
	fading_source.bind_thermal_state(fading_thermal)

	fading_requirement = SustainedHeatLock.new()
	fading_requirement.name = "FadingSealSustainedHeat"
	fading_requirement.mechanism_id = "cold_forge_fading_seal_sustained_heat"
	fading_requirement.display_name = "Sustained Fading Seal Heat"
	fading_requirement.required_temperature_c = fading_required_temperature_c
	fading_requirement.required_hold_seconds = fading_hold_seconds
	fading_requirement.reset_progress_below_threshold = true
	fading_requirement.latch_when_completed = true
	signal_root.add_child(fading_requirement)
	fading_requirement.bind_source(fading_source)

	fading_gate = GateScene.instantiate() as MechanismSlidingGate
	fading_gate.name = "FadingLockGate"
	fading_gate.display_name = "Cold Forge Inner Gate"
	fading_gate.position = Vector3(0.0, 0.0, 14.0)
	fading_gate.open_offset = Vector3(0.0, 4.5, 0.0)
	fading_gate.transition_seconds = 0.55
	mechanisms_root.add_child(fading_gate)
	var gate_label: Label3D = fading_gate.get_node_or_null(
		"StateLabel"
	) as Label3D
	if gate_label != null:
		gate_label.visible = false

	fading_gate_adapter = MechanismOutputAdapter.new()
	fading_gate_adapter.name = "FadingGateOutput"
	fading_gate_adapter.mechanism_id = "cold_forge_fading_gate_output"
	fading_gate_adapter.display_name = "Fading Gate Output"
	signal_root.add_child(fading_gate_adapter)
	fading_gate_adapter.bind_source(fading_requirement)
	fading_gate_adapter.bind_target(fading_gate)


func _build_boiler_lift() -> void:
	boiler_elevator = ElevatorScene.instantiate() as MechanismValueElevator
	boiler_elevator.name = "BoilerLift"
	boiler_elevator.display_name = "Boiler Lift"
	boiler_elevator.position = Vector3(0.0, 0.25, 29.0)
	boiler_elevator.input_minimum = boiler_minimum_temperature_c
	boiler_elevator.input_maximum = boiler_full_height_temperature_c
	boiler_elevator.starts_value = boiler_minimum_temperature_c
	boiler_elevator.movement_offset = Vector3(0.0, boiler_lift_height, 0.0)
	boiler_elevator.transition_seconds = 0.08
	mechanisms_root.add_child(boiler_elevator)
	var elevator_state_label: Label3D = boiler_elevator.get_node_or_null(
		"StateLabel"
	) as Label3D
	if elevator_state_label != null:
		elevator_state_label.visible = false

	var target_data: Dictionary = _create_thermal_target(
		"BoilerCore",
		boiler_elevator,
		Vector3(0.0, 1.15, -1.25),
		Vector3(1.7, 1.7, 0.85),
		-35.0,
		-35.0,
		12.0,
		1.35,
		"BOILER CORE"
	)
	boiler_target = target_data["target"] as Area3D
	boiler_thermal = target_data["thermal"] as ThermalState
	boiler_label = target_data["label"] as Label3D

	boiler_source = ThermalMechanismSource.new()
	boiler_source.name = "BoilerTemperature"
	boiler_source.mechanism_id = "cold_forge_boiler_temperature"
	boiler_source.display_name = "Boiler Temperature"
	boiler_source.thermal_state_path = NodePath()
	boiler_source.minimum_value = boiler_minimum_temperature_c
	boiler_source.maximum_value = boiler_full_height_temperature_c
	boiler_source.active_threshold_c = 25.0
	signal_root.add_child(boiler_source)
	boiler_source.bind_thermal_state(boiler_thermal)


func _build_completion_landing() -> void:
	completion_area = Area3D.new()
	completion_area.name = "ColdForgeCompletionArea"
	completion_area.position = Vector3(0.0, 6.1, 39.5)
	completion_area.collision_layer = 0
	completion_area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 2.0, 5.0)
	collision.shape = shape
	completion_area.add_child(collision)
	mechanisms_root.add_child(completion_area)

	var pad := MeshInstance3D.new()
	pad.name = "MasteryPad"
	pad.position = Vector3(0.0, 5.56, 39.5)
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.2
	pad_mesh.bottom_radius = 2.2
	pad_mesh.height = 0.12
	pad.mesh = pad_mesh
	pad.material_override = completion_material
	environment_root.add_child(pad)
	_create_label(
		"SUSTAIN • AIM • ENDURE",
		Vector3(0.0, 7.1, 42.0),
		Color(1.0, 0.72, 0.18),
		26
	)


func _connect_runtime_signals() -> void:
	if fading_requirement != null:
		fading_requirement.heat_progress_changed.connect(
			_on_fading_heat_progress
		)
		fading_requirement.heat_requirement_completed.connect(
			_on_fading_lock_completed
		)
	if boiler_source != null:
		boiler_source.mechanism_signal_changed.connect(
			_on_boiler_temperature_signal
		)
	if boiler_elevator != null:
		boiler_elevator.elevator_fraction_changed.connect(
			_on_boiler_fraction_changed
		)
	if completion_area != null:
		completion_area.body_entered.connect(
			_on_completion_area_body_entered
		)


func _on_fading_heat_progress(
	temperature_c: float,
	held_seconds: float,
	required_seconds: float,
	progress: float
) -> void:
	fading_progress = progress
	if fading_label != null:
		fading_label.text = (
			"FROZEN SEAL\n"
			+ str(roundi(temperature_c))
			+ " °C • HOLD "
			+ str(snappedf(held_seconds, 0.1))
			+ " / "
			+ str(snappedf(required_seconds, 0.1))
			+ " s"
		)


func _on_fading_lock_completed() -> void:
	if stage != TrialStage.FADING_LOCK:
		return
	fading_lock_completed.emit()
	_set_stage(TrialStage.BOILER_LIFT)
	_show_message(
		"The frozen seal yields. Stand on the boiler platform and keep its core hot as it rises."
	)


func _on_boiler_temperature_signal(
	_mechanism_id: String,
	_active: bool,
	packet: Dictionary
) -> void:
	if boiler_elevator == null:
		return
	var temperature_c: float = float(
		packet.get(
			"temperature_c",
			boiler_source.get_mechanism_value()
		)
	)
	boiler_elevator.set_elevator_value(
		temperature_c,
		true,
		packet
	)
	_refresh_boiler_label()


func _on_boiler_fraction_changed(_fraction: float) -> void:
	_refresh_boiler_label()


func _on_completion_area_body_entered(body: Node3D) -> void:
	if trial_complete or not body.is_in_group("player"):
		return
	if stage != TrialStage.BOILER_LIFT:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	_show_message(
		"Flamethrower mastery recorded: sustained heat can overpower active cooling and drive thermal machinery."
	)
	trial_completed.emit()


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.FADING_LOCK:
			GameState.set_objective(
				"Equip Flamethrower and hold Cast on the frozen seal until it remains above "
				+ str(roundi(fading_required_temperature_c))
				+ " °C."
			)
		TrialStage.BOILER_LIFT:
			GameState.set_objective(
				"Ride the boiler lift. Keep the moving boiler core hot until you can step onto the upper landing."
			)
		TrialStage.COMPLETE:
			GameState.set_objective(
				"Cold Forge Spell Trial complete."
			)


func _equip_flamethrower() -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("select_ability"):
		return
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for index: int in range(loadout.equipped_abilities.size()):
		var ability: AbilityDefinition = loadout.equipped_abilities[index]
		if ability != null and ability.get_spell_id() == "flamethrower":
			caster.call("select_ability", index, false)
			return


func _create_thermal_target(
	node_name: String,
	parent_node: Node3D,
	position_value: Vector3,
	size_value: Vector3,
	starting_temperature_c: float,
	ambient_temperature_c: float,
	heat_capacity_j_per_c: float,
	ambient_conductance: float,
	label_text: String
) -> Dictionary:
	var target := Area3D.new()
	target.name = node_name
	target.position = position_value
	target.collision_layer = 1
	target.collision_mask = 0
	target.monitorable = true
	target.add_to_group("flamethrower_thermal_targets")
	target.add_to_group("lab_resettable")

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	target.add_child(collision)

	var visual := MeshInstance3D.new()
	visual.name = "ThermalVisual"
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = _make_thermal_material()
	target.add_child(visual)

	var thermal := ThermalState.new()
	thermal.name = "ThermalState"
	thermal.starting_temperature_c = starting_temperature_c
	thermal.ambient_temperature_c = ambient_temperature_c
	thermal.minimum_temperature_c = -100.0
	thermal.maximum_temperature_c = 600.0
	thermal.passive_ambient_exchange = true
	thermal.ambient_conductance_j_per_second_c = ambient_conductance
	thermal.heat_capacity_override_j_per_c = heat_capacity_j_per_c
	thermal.fire_energy_j_per_intensity = 180.0
	thermal.ice_energy_j_per_intensity = 180.0
	target.add_child(thermal)

	var payload_receiver := PayloadReceiver.new()
	payload_receiver.name = "PayloadReceiver"
	target.add_child(payload_receiver)

	var label := Label3D.new()
	label.name = "ThermalLabel"
	label.position = Vector3(0.0, size_value.y * 0.62, 0.0)
	label.text = label_text
	label.font_size = 22
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = Color(0.72, 0.88, 1.0)
	target.add_child(label)

	parent_node.add_child(target)
	_register_thermal_presentation(thermal, visual, label, label_text)
	return {
		"target": target,
		"thermal": thermal,
		"visual": visual,
		"label": label,
	}


func _register_thermal_presentation(
	thermal: ThermalState,
	visual: MeshInstance3D,
	label: Label3D,
	base_label: String
) -> void:
	thermal_presentations[thermal.get_instance_id()] = {
		"thermal": thermal,
		"visual": visual,
		"label": label,
		"base_label": base_label,
	}
	var callback := Callable(
		self,
		"_on_thermal_temperature_changed"
	).bind(thermal)
	if not thermal.temperature_changed.is_connected(callback):
		thermal.temperature_changed.connect(callback)
	_refresh_thermal_presentation(thermal)


func _on_thermal_temperature_changed(
	_temperature_c: float,
	_delta_c: float,
	_source_name: String,
	thermal: ThermalState
) -> void:
	_refresh_thermal_presentation(thermal)


func _refresh_thermal_presentation(thermal: ThermalState) -> void:
	if thermal == null:
		return
	var data_value: Variant = thermal_presentations.get(
		thermal.get_instance_id(),
		{}
	)
	if not data_value is Dictionary:
		return
	var data: Dictionary = data_value as Dictionary
	var visual: MeshInstance3D = data.get("visual") as MeshInstance3D
	var label: Label3D = data.get("label") as Label3D
	var temperature_c: float = thermal.temperature_c
	var heat_ratio: float = clampf(
		inverse_lerp(-35.0, 180.0, temperature_c),
		0.0,
		1.0
	)
	var cold_color := Color(0.08, 0.34, 0.72, 0.88)
	var hot_color := Color(1.0, 0.22, 0.025, 0.92)
	var display_color: Color = cold_color.lerp(hot_color, heat_ratio)
	if visual != null:
		var material: StandardMaterial3D = (
			visual.material_override as StandardMaterial3D
		)
		if material != null:
			material.albedo_color = display_color
			material.emission = Color(
				display_color.r,
				display_color.g,
				display_color.b
			)
			material.emission_energy_multiplier = 0.6 + heat_ratio * 3.4
	if label != null and label != fading_label and label != boiler_label:
		label.text = (
			str(data.get("base_label", "THERMAL TARGET"))
			+ "\n"
			+ str(roundi(temperature_c))
			+ " °C"
		)
	presentation_updates += 1
	_refresh_boiler_label()


func _refresh_boiler_label() -> void:
	if boiler_label == null or boiler_thermal == null or boiler_elevator == null:
		return
	boiler_label.text = (
		"BOILER CORE\n"
		+ str(roundi(boiler_thermal.temperature_c))
		+ " °C • LIFT "
		+ str(roundi(boiler_elevator.current_fraction * 100.0))
		+ "%"
	)


func _refresh_all_presentation() -> void:
	for data_value: Variant in thermal_presentations.values():
		if data_value is Dictionary:
			var thermal: ThermalState = (
				(data_value as Dictionary).get("thermal") as ThermalState
			)
			_refresh_thermal_presentation(thermal)
	if fading_requirement != null:
		_on_fading_heat_progress(
			fading_thermal.temperature_c,
			fading_requirement.held_seconds,
			fading_requirement.required_hold_seconds,
			fading_requirement.get_mechanism_value()
		)
	_refresh_boiler_label()


func reset_trial() -> void:
	trial_complete = false
	GameState.set_flag(completion_flag, false)
	if fading_thermal != null:
		fading_thermal.reset_target()
	if boiler_thermal != null:
		boiler_thermal.reset_target()
	if fading_source != null:
		fading_source.publish_temperature("trial_reset", true)
	if boiler_source != null:
		boiler_source.publish_temperature("trial_reset", true)
	if fading_requirement != null:
		fading_requirement.reset_target()
	if fading_gate != null:
		fading_gate.reset_target()
	if fading_gate_adapter != null:
		fading_gate_adapter.apply_target_state()
	if boiler_elevator != null:
		boiler_elevator.reset_target()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		var flamethrower: Node = player.get_node_or_null(
			"FlamethrowerController"
		)
		if flamethrower != null and flamethrower.has_method("reset_target"):
			flamethrower.call("reset_target")
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	fading_progress = 0.0
	_set_stage(TrialStage.FADING_LOCK)
	_refresh_all_presentation()
	trial_reset.emit()
	_show_message("Cold Forge trial reset.")


func _create_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	environment_root.add_child(body)
	return body


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
	label.outline_size = 8
	label.modulate = color
	label.visibility_range_end = 45.0
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
	var material := _make_material(albedo, 0.42, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func _make_thermal_material() -> StandardMaterial3D:
	var material := _make_material(Color(0.08, 0.34, 0.72), 0.72, 0.24)
	material.emission_enabled = true
	material.emission = Color(0.04, 0.24, 0.72)
	material.emission_energy_multiplier = 0.6
	return material


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"cold_forge_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"fading_temperature_c": (
			fading_thermal.temperature_c
			if fading_thermal != null
			else 0.0
		),
		"fading_progress": fading_progress,
		"fading_gate_open": (
			fading_gate.active
			if fading_gate != null
			else false
		),
		"boiler_temperature_c": (
			boiler_thermal.temperature_c
			if boiler_thermal != null
			else 0.0
		),
		"boiler_lift_fraction": (
			boiler_elevator.current_fraction
			if boiler_elevator != null
			else 0.0
		),
		"presentation_updates": presentation_updates,
	}
