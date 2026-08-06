extends Node3D
class_name PrototypeHollowSpireSpellTrial

signal feather_stage_completed
signal ride_stage_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const AirflowBodyScene: PackedScene = preload(
	"res://scenes/actors/props/airflow_test_body.tscn"
)

enum TrialStage {
	FEATHER_AND_STONE,
	RIDE_CURRENT,
	COMPLETE,
}

@export_group("Trial")
@export var completion_flag: String = "hollow_spire_spell_trial_complete"
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Wind Well casts."
)

var environment_root: Node3D
var mechanisms_root: Node3D
var player: CharacterBody3D
var featherstone: FieldResponsiveBody
var anchorstone: FieldResponsiveBody
var feather_goal: Area3D
var mastery_goal: Area3D
var feather_gate: MechanismSlidingGate

var stage: TrialStage = TrialStage.FEATHER_AND_STONE
var trial_complete: bool = false
var initial_player_transform: Transform3D
var feather_goal_entries: int = 0
var mastery_goal_entries: int = 0

var stone_material: StandardMaterial3D
var dark_stone_material: StandardMaterial3D
var air_material: StandardMaterial3D
var feather_material: StandardMaterial3D
var anchor_material: StandardMaterial3D
var goal_material: StandardMaterial3D
var mastery_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("hollow_spire_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_feather_stage()
	_build_ride_stage()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.FEATHER_AND_STONE)
	_show_message(
		"The Hollow Spire: Wind Well creates persistent lift without damage. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_wind_well")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "HollowSpireEnvironment"
	add_child(environment_root)
	mechanisms_root = Node3D.new()
	mechanisms_root.name = "HollowSpireMechanisms"
	add_child(mechanisms_root)


func _build_materials() -> void:
	stone_material = _make_material(
		Color(0.14, 0.17, 0.22),
		0.22,
		0.78
	)
	dark_stone_material = _make_material(
		Color(0.055, 0.07, 0.1),
		0.34,
		0.72
	)
	air_material = _make_emissive_material(
		Color(0.86, 0.36, 0.68, 0.28),
		Color(1.0, 0.4, 0.76),
		2.4
	)
	feather_material = _make_emissive_material(
		Color(0.66, 0.86, 0.96, 0.84),
		Color(0.36, 0.78, 1.0),
		1.8
	)
	anchor_material = _make_material(
		Color(0.17, 0.2, 0.28),
		0.84,
		0.28
	)
	goal_material = _make_emissive_material(
		Color(0.5, 0.84, 1.0, 0.42),
		Color(0.42, 0.88, 1.0),
		2.8
	)
	mastery_material = _make_emissive_material(
		Color(0.76, 0.48, 0.12, 0.76),
		Color(1.0, 0.72, 0.14),
		3.5
	)


func _build_environment() -> void:
	_create_static_box(
		"SpireLowerFloor",
		Vector3(0.0, -0.5, 14.0),
		Vector3(14.0, 1.0, 40.0),
		stone_material
	)
	_create_static_box(
		"SpireLeftWall",
		Vector3(-7.5, 6.0, 14.0),
		Vector3(1.0, 13.0, 40.0),
		dark_stone_material
	)
	_create_static_box(
		"SpireRightWall",
		Vector3(7.5, 6.0, 14.0),
		Vector3(1.0, 13.0, 40.0),
		dark_stone_material
	)
	_create_static_box(
		"SpireBackWall",
		Vector3(0.0, 6.0, -6.0),
		Vector3(14.0, 13.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"SpireFrontWall",
		Vector3(0.0, 6.0, 34.0),
		Vector3(14.0, 13.0, 1.0),
		dark_stone_material
	)

	_create_static_box(
		"FeatherDividerLeft",
		Vector3(-4.8, 6.0, 14.0),
		Vector3(5.0, 12.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"FeatherDividerRight",
		Vector3(4.8, 6.0, 14.0),
		Vector3(5.0, 12.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"FeatherDividerLintel",
		Vector3(0.0, 8.5, 14.0),
		Vector3(4.6, 7.0, 1.0),
		dark_stone_material
	)

	_create_static_box(
		"AscentBarrier",
		Vector3(0.0, 3.0, 27.0),
		Vector3(14.0, 6.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"UpperLanding",
		Vector3(0.0, 6.5, 30.5),
		Vector3(14.0, 1.0, 7.0),
		stone_material
	)
	_create_static_box(
		"UpperLeftRail",
		Vector3(-6.7, 8.0, 30.5),
		Vector3(0.5, 2.0, 7.0),
		dark_stone_material
	)
	_create_static_box(
		"UpperRightRail",
		Vector3(6.7, 8.0, 30.5),
		Vector3(0.5, 2.0, 7.0),
		dark_stone_material
	)

	_create_label(
		"THE HOLLOW SPIRE",
		Vector3(0.0, 4.8, -3.7),
		Color(0.98, 0.58, 0.84),
		34
	)
	_create_label(
		"A current lifts. Weight decides how far.",
		Vector3(0.0, 3.9, -0.8),
		Color(0.76, 0.86, 0.96),
		22
	)
	_create_label(
		"I • FEATHER AND STONE",
		Vector3(0.0, 4.0, 2.0),
		Color(0.98, 0.54, 0.82),
		27
	)
	_create_label(
		"II • RIDE THE CURRENT",
		Vector3(0.0, 4.0, 17.0),
		Color(0.98, 0.54, 0.82),
		27
	)
	_create_label(
		"PLACE • ENTER • STEER",
		Vector3(0.0, 10.0, 31.5),
		Color(1.0, 0.82, 0.3),
		25
	)

	for channel_z: float in [6.5, 22.5]:
		var channel := MeshInstance3D.new()
		channel.name = "AirChannel" + str(roundi(channel_z * 10.0))
		channel.position = Vector3(0.0, 0.035, channel_z)
		var channel_mesh := CylinderMesh.new()
		channel_mesh.top_radius = 2.9
		channel_mesh.bottom_radius = 2.9
		channel_mesh.height = 0.05
		channel_mesh.radial_segments = 32
		channel.mesh = channel_mesh
		channel.material_override = air_material
		environment_root.add_child(channel)


func _build_feather_stage() -> void:
	featherstone = _spawn_airflow_body(
		"Featherstone",
		"Featherstone",
		Vector3(-1.0, 0.05, 6.5),
		2.0,
		feather_material,
		"2 KG • FEATHERSTONE"
	)
	featherstone.add_to_group("hollow_spire_featherstone")
	anchorstone = _spawn_airflow_body(
		"Anchorstone",
		"Anchor Stone",
		Vector3(1.0, 0.05, 6.5),
		18.0,
		anchor_material,
		"18 KG • ANCHOR"
	)
	anchorstone.add_to_group("hollow_spire_anchorstone")

	# Keep the first lesson purely vertical: the elevated catch sits directly
	# above the Featherstone, so Wind Well alone demonstrates the mass contrast.
	feather_goal = _create_goal_area(
		"FeatherstoneCatch",
		Vector3(-1.0, 5.3, 6.5),
		Vector3(3.2, 2.4, 3.2),
		goal_material,
		"FEATHERSTONE CATCH"
	)
	feather_goal.body_entered.connect(_on_feather_goal_body_entered)

	for post_x: float in [-2.55, 0.55]:
		_create_static_box(
			"CatchPost" + str(roundi(post_x * 100.0)),
			Vector3(post_x, 3.0, 6.5),
			Vector3(0.18, 6.0, 0.18),
			stone_material
		)
	_create_static_box(
		"CatchCrown",
		Vector3(-1.0, 6.0, 6.5),
		Vector3(3.3, 0.18, 0.18),
		stone_material
	)

	feather_gate = GateScene.instantiate() as MechanismSlidingGate
	feather_gate.name = "FeatherTrialGate"
	feather_gate.display_name = "Feather and Stone Gate"
	feather_gate.position = Vector3(0.0, 0.0, 14.0)
	feather_gate.scale = Vector3(1.22, 1.0, 1.0)
	feather_gate.open_offset = Vector3(0.0, 4.8, 0.0)
	feather_gate.transition_seconds = 0.52
	mechanisms_root.add_child(feather_gate)
	var gate_label: Label3D = feather_gate.get_node_or_null(
		"StateLabel"
	) as Label3D
	if gate_label != null:
		gate_label.visible = false


func _build_ride_stage() -> void:
	mastery_goal = Area3D.new()
	mastery_goal.name = "WindWellMasteryGoal"
	mastery_goal.position = Vector3(0.0, 8.2, 31.0)
	mastery_goal.collision_layer = 0
	mastery_goal.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 2.8, 5.0)
	collision.shape = shape
	mastery_goal.add_child(collision)
	mechanisms_root.add_child(mastery_goal)
	mastery_goal.body_entered.connect(_on_mastery_goal_body_entered)

	var pad := MeshInstance3D.new()
	pad.name = "WindWellMasteryPad"
	pad.position = Vector3(0.0, 7.06, 31.0)
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.4
	pad_mesh.bottom_radius = 2.4
	pad_mesh.height = 0.12
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.material_override = mastery_material
	environment_root.add_child(pad)


func _spawn_airflow_body(
	node_name: String,
	body_label_value: String,
	position_value: Vector3,
	mass_kg: float,
	material: Material,
	label_text: String
) -> FieldResponsiveBody:
	var body: FieldResponsiveBody = (
		AirflowBodyScene.instantiate() as FieldResponsiveBody
	)
	body.name = node_name
	body.body_label = body_label_value
	body.position = position_value
	body.mass_override_kg = mass_kg
	body.gravity_strength = 20.0
	var response: AirflowResponse = body.get_node_or_null(
		"AirflowResponse"
	) as AirflowResponse
	if response != null:
		response.mass_override_kg = mass_kg
		response.maximum_acceleration = 24.0
	var mesh: MeshInstance3D = body.get_node_or_null("Body") as MeshInstance3D
	if mesh != null:
		mesh.material_override = material
	var label := Label3D.new()
	label.name = "OfferingLabel"
	label.position = Vector3(0.0, 1.7, 0.0)
	label.text = label_text
	label.font_size = 22
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = Color(0.84, 0.92, 1.0)
	body.add_child(label)
	mechanisms_root.add_child(body)
	return body


func _on_feather_goal_body_entered(body: Node3D) -> void:
	if stage != TrialStage.FEATHER_AND_STONE:
		return
	if not body.is_in_group("hollow_spire_featherstone"):
		return
	feather_goal_entries += 1
	feather_gate.set_gate_open(true, false, {
		"reason": "featherstone_lifted",
	})
	feather_stage_completed.emit()
	_set_stage(TrialStage.RIDE_CURRENT)
	_show_message(
		"The Featherstone rises while the anchor resists. Place Wind Well before the broken ascent, enter the current, and steer onto the upper landing."
	)


func _on_mastery_goal_body_entered(body: Node3D) -> void:
	if stage != TrialStage.RIDE_CURRENT or trial_complete:
		return
	if not body.is_in_group("player"):
		return
	mastery_goal_entries += 1
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	ride_stage_completed.emit()
	trial_completed.emit()
	_show_message(
		"Wind Well mastery recorded: lift light objects, create vertical routes, and steer through persistent airflow."
	)


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.FEATHER_AND_STONE:
			GameState.set_objective(
				"Place Wind Well beneath the two stones. Lift the 2 kg Featherstone into the elevated catch while the 18 kg anchor resists."
			)
		TrialStage.RIDE_CURRENT:
			GameState.set_objective(
				"Place Wind Well before the broken ascent. Enter the updraft and steer onto the upper landing."
			)
		TrialStage.COMPLETE:
			GameState.set_objective(
				"Hollow Spire Spell Trial complete."
			)


func _equip_wind_well() -> void:
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
		if ability != null and ability.get_spell_id() == "wind_well":
			caster.call("select_ability", index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	GameState.set_flag(completion_flag, false)
	var caster: Node = (
		player.get_node_or_null("AbilityCaster")
		if player != null
		else null
	)
	if caster != null and caster.has_method("cancel_ground_targeting"):
		caster.call("cancel_ground_targeting", false)
	for well: Node in get_tree().get_nodes_in_group("wind_well_effects"):
		if well != null and is_instance_valid(well):
			if well.has_method("finish_well"):
				well.call("finish_well")
			else:
				well.queue_free()
	if featherstone != null:
		featherstone.reset_body()
	if anchorstone != null:
		anchorstone.reset_body()
	if feather_gate != null:
		feather_gate.reset_target()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	feather_goal_entries = 0
	mastery_goal_entries = 0
	_set_stage(TrialStage.FEATHER_AND_STONE)
	var manager: Node = get_node_or_null("AirflowManager")
	if manager != null and manager.has_method("refresh_registered_fields"):
		manager.call_deferred("refresh_registered_fields")
	call_deferred("_equip_wind_well")
	trial_reset.emit()
	_show_message("Hollow Spire trial reset.")


func _create_goal_area(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material,
	label_text: String
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
	mechanisms_root.add_child(area)

	var ring := MeshInstance3D.new()
	ring.name = node_name + "Visual"
	ring.position = position_value
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(size_value.x * 0.38, 0.2)
	torus.outer_radius = maxf(size_value.x * 0.44, 0.3)
	torus.rings = 28
	torus.ring_segments = 10
	ring.mesh = torus
	ring.material_override = material
	environment_root.add_child(ring)
	_create_label(
		label_text,
		position_value + Vector3.UP * 1.7,
		Color(0.72, 0.92, 1.0),
		21
	)
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
	var material := _make_material(albedo, 0.26, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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


func get_debug_data() -> Dictionary:
	return {
		"hollow_spire_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"feather_position": featherstone.global_position if featherstone != null else Vector3.ZERO,
		"anchor_position": anchorstone.global_position if anchorstone != null else Vector3.ZERO,
		"feather_gate_open": feather_gate.active if feather_gate != null else false,
		"feather_goal_entries": feather_goal_entries,
		"mastery_goal_entries": mastery_goal_entries,
		"active_wind_wells": get_tree().get_nodes_in_group("wind_well_effects").size(),
	}
