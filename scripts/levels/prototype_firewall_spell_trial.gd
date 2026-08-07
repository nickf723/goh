extends Node3D
class_name PrototypeFirewallSpellTrial

signal floor_script_completed
signal corner_script_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)

enum TrialStage {
	FLOOR_SCRIPT,
	CORNER_SCRIPT,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = "ember_scriptorium_firewall_trial_complete"
@export_range(1.0, 20.0, 0.5) var floor_required_length: float = 4.5
@export_range(1.0, 20.0, 0.5) var corner_required_length: float = 5.5
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Firewall attempts."
)

var environment_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D
var initial_player_transform: Transform3D
var floor_gate: MechanismSlidingGate
var corner_gate: MechanismSlidingGate
var mastery_area: Area3D

var stage: TrialStage = TrialStage.FLOOR_SCRIPT
var trial_complete: bool = false
var last_firewall_serial: int = 0
var floor_completion_count: int = 0
var corner_completion_count: int = 0
var rejected_path_count: int = 0
var last_path_length: float = 0.0
var last_surface_sequence: Array[String] = []
var last_transition_count: int = 0

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var ember_material: StandardMaterial3D
var guide_material: StandardMaterial3D
var gold_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("ember_scriptorium_firewall_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
		last_firewall_serial = int(player.get_meta("firewall_serial", 0))
	_build_roots()
	_build_materials()
	_build_environment()
	_build_floor_script()
	_build_corner_script()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.FLOOR_SCRIPT)
	_show_message(
		"The Ember Scriptorium: draw with the laser, then release to make the line rise. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_firewall")
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var serial: int = int(player.get_meta("firewall_serial", 0))
	if serial == last_firewall_serial:
		return
	last_firewall_serial = serial
	_consume_firewall_path()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "EmberScriptoriumEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "EmberScriptoriumActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(Color(0.055, 0.047, 0.05), 0.24, 0.78)
	wall_material = _make_material(Color(0.032, 0.032, 0.044), 0.48, 0.54)
	ember_material = _make_emissive_material(
		Color(0.62, 0.08, 0.015, 0.94),
		Color(1.0, 0.12, 0.01),
		3.8
	)
	guide_material = _make_emissive_material(
		Color(0.66, 0.26, 0.03, 0.84),
		Color(1.0, 0.42, 0.04),
		2.6
	)
	gold_material = _make_emissive_material(
		Color(0.68, 0.47, 0.07, 0.94),
		Color(1.0, 0.76, 0.1),
		3.7
	)


func _build_environment() -> void:
	_create_static_box(
		"ScriptoriumFloor",
		Vector3(0.0, -0.5, 17.0),
		Vector3(14.0, 1.0, 52.0),
		floor_material
	)
	_create_static_box(
		"ScriptoriumLeftWall",
		Vector3(-7.5, 3.0, 17.0),
		Vector3(1.0, 7.0, 52.0),
		wall_material
	)
	_create_static_box(
		"ScriptoriumRightWall",
		Vector3(7.5, 3.0, 17.0),
		Vector3(1.0, 7.0, 52.0),
		wall_material
	)
	_create_static_box(
		"ScriptoriumBackWall",
		Vector3(0.0, 3.0, -9.0),
		Vector3(14.0, 7.0, 1.0),
		wall_material
	)
	_create_static_box(
		"ScriptoriumFrontWall",
		Vector3(0.0, 3.0, 43.0),
		Vector3(14.0, 7.0, 1.0),
		wall_material
	)

	_create_label(
		"THE EMBER SCRIPTORIUM",
		Vector3(0.0, 5.0, -5.6),
		Color(1.0, 0.54, 0.18),
		34
	)
	_create_label(
		"A line remembers every surface it touches.",
		Vector3(0.0, 4.0, -2.7),
		Color(0.92, 0.69, 0.46),
		20
	)
	_create_label(
		"I • THE FLAT SCRIPT",
		Vector3(0.0, 4.1, 0.0),
		Color(1.0, 0.4, 0.12),
		27
	)
	_create_label(
		"II • THE TURNED SCRIPT",
		Vector3(0.0, 4.1, 15.0),
		Color(1.0, 0.4, 0.12),
		27
	)


func _build_floor_script() -> void:
	for guide_data: Dictionary in [
		{"name": "FloorGuideA", "position": Vector3(-2.6, 0.06, 3.0)},
		{"name": "FloorGuideB", "position": Vector3(0.0, 0.06, 5.3)},
		{"name": "FloorGuideC", "position": Vector3(2.6, 0.06, 7.6)},
	]:
		_create_visual_box(
			str(guide_data.get("name", "FloorGuide")),
			guide_data.get("position", Vector3.ZERO) as Vector3,
			Vector3(2.3, 0.08, 0.34),
			guide_material
		)
	_create_label(
		"HOLD CAST • TRACE THE FLOOR • RELEASE",
		Vector3(0.0, 3.0, 8.4),
		Color(1.0, 0.72, 0.36),
		18
	)
	floor_gate = _spawn_gate_with_dividers(
		"FloorScriptGate",
		"Flat Script Gate",
		Vector3(0.0, 0.0, 11.0)
	)


func _build_corner_script() -> void:
	# The alcove is one continuous architectural corner: floor into a vertical
	# panel, then around the upper edge onto the underside of the ceiling slab.
	_create_static_box(
		"TurnedScriptWall",
		Vector3(0.0, 2.25, 25.0),
		Vector3(9.0, 5.5, 0.8),
		wall_material
	)
	_create_static_box(
		"TurnedScriptCeiling",
		Vector3(0.0, 5.0, 21.5),
		Vector3(9.0, 0.6, 7.8),
		wall_material
	)

	_create_visual_box(
		"CornerFloorGuide",
		Vector3(0.0, 0.07, 21.6),
		Vector3(4.5, 0.09, 0.34),
		ember_material
	)
	_create_visual_box(
		"CornerWallGuide",
		Vector3(0.0, 2.45, 24.56),
		Vector3(4.5, 0.34, 4.2),
		ember_material
	)
	_create_visual_box(
		"CornerCeilingGuide",
		Vector3(0.0, 4.66, 21.7),
		Vector3(4.5, 0.09, 0.34),
		ember_material
	)
	_create_label(
		"FLOOR → WALL → CEILING",
		Vector3(0.0, 3.4, 19.0),
		Color(1.0, 0.72, 0.32),
		20
	)
	_create_label(
		"The corner bridge should bend the flame, not break it.",
		Vector3(0.0, 2.8, 27.0),
		Color(0.92, 0.66, 0.42),
		17
	)
	corner_gate = _spawn_gate_with_dividers(
		"CornerScriptGate",
		"Turned Script Gate",
		Vector3(0.0, 0.0, 32.0)
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"FirewallMasteryArea",
		Vector3(0.0, 1.0, 39.0),
		Vector3(7.0, 2.4, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_body_entered)
	_create_visual_box(
		"FirewallMasterySeal",
		Vector3(0.0, 0.08, 39.0),
		Vector3(5.0, 0.12, 3.2),
		gold_material
	)
	_create_label(
		"TRACE • TURN • IGNITE",
		Vector3(0.0, 3.8, 40.5),
		Color(1.0, 0.82, 0.28),
		26
	)


func _consume_firewall_path() -> void:
	last_path_length = float(player.get_meta("firewall_path_length", 0.0))
	last_transition_count = int(
		player.get_meta("firewall_surface_transitions", 0)
	)
	last_surface_sequence.clear()
	var sequence_value: Variant = player.get_meta(
		"firewall_surface_sequence",
		[]
	)
	if sequence_value is Array:
		for raw_value: Variant in sequence_value as Array:
			last_surface_sequence.append(str(raw_value))
	var points: Array[Vector3] = _get_firewall_points()

	match stage:
		TrialStage.FLOOR_SCRIPT:
			_try_complete_floor_script(points)
		TrialStage.CORNER_SCRIPT:
			_try_complete_corner_script(points)
		_:
			pass


func _try_complete_floor_script(points: Array[Vector3]) -> void:
	var floor_points: int = 0
	var points_in_room: int = 0
	var normals: Array[Vector3] = _get_firewall_normals()
	for point_index: int in range(mini(points.size(), normals.size())):
		if normals[point_index].y >= 0.68:
			floor_points += 1
		var point: Vector3 = points[point_index]
		if point.z >= -1.0 and point.z <= 9.5 and absf(point.x) <= 5.5:
			points_in_room += 1
	var required_points: int = maxi(int(ceil(float(points.size()) * 0.7)), 2)
	var valid: bool = (
		last_path_length >= floor_required_length
		and points.size() >= 2
		and floor_points >= required_points
		and points_in_room >= required_points
		and not last_surface_sequence.has("ceiling")
	)
	if not valid:
		rejected_path_count += 1
		_show_message(
			"The Flat Script needs one longer line etched across the marked floor."
		)
		return
	floor_completion_count += 1
	floor_gate.set_gate_open(
		true,
		false,
		{"reason": "floor_firewall_confirmed"}
	)
	_set_stage(TrialStage.CORNER_SCRIPT)
	floor_script_completed.emit()
	_show_message(
		"Flat Script accepted. Now carry one uninterrupted trace from floor to wall to ceiling."
	)


func _try_complete_corner_script(points: Array[Vector3]) -> void:
	var floor_index: int = last_surface_sequence.find("floor")
	var wall_index: int = last_surface_sequence.find("wall")
	var ceiling_index: int = last_surface_sequence.find("ceiling")
	var points_in_alcove: int = 0
	for point: Vector3 in points:
		if (
			point.z >= 18.0
			and point.z <= 26.0
			and absf(point.x) <= 5.5
			and point.y >= -0.2
			and point.y <= 5.2
		):
			points_in_alcove += 1
	var required_points: int = maxi(int(ceil(float(points.size()) * 0.55)), 3)
	var ordered_surfaces: bool = (
		floor_index >= 0
		and wall_index > floor_index
		and ceiling_index > wall_index
	)
	var valid: bool = (
		last_path_length >= corner_required_length
		and last_transition_count >= 2
		and ordered_surfaces
		and points_in_alcove >= required_points
	)
	if not valid:
		rejected_path_count += 1
		_show_message(
			"The Turned Script must remain continuous: FLOOR → WALL → CEILING."
		)
		return
	corner_completion_count += 1
	corner_gate.set_gate_open(
		true,
		false,
		{"reason": "corner_firewall_confirmed"}
	)
	_set_stage(TrialStage.MASTERY)
	corner_script_completed.emit()
	_show_message(
		"The flame turns both edges without breaking. The mastery seal is open."
	)


func _on_mastery_area_body_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Firewall mastered: TRACE • TURN • IGNITE.")


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.FLOOR_SCRIPT:
			_set_objective(
				"Firewall: hold Cast, trace a long floor line, then release."
			)
		TrialStage.CORNER_SCRIPT:
			_set_objective(
				"Firewall: draw one continuous path from floor to wall to ceiling."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Firewall: enter the gold mastery seal beyond the second gate."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Ember Scriptorium complete: TRACE • TURN • IGNITE."
			)


func _equip_firewall() -> void:
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
		if ability != null and ability.get_spell_id() == "firewall":
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	floor_completion_count = 0
	corner_completion_count = 0
	rejected_path_count = 0
	last_path_length = 0.0
	last_transition_count = 0
	last_surface_sequence.clear()
	GameState.set_flag(completion_flag, false)
	_clear_firewall_effects()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		player.visible = true
		last_firewall_serial = int(player.get_meta("firewall_serial", 0))
	if floor_gate != null:
		floor_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if corner_gate != null:
		corner_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	_restore_player_resources()
	_set_stage(TrialStage.FLOOR_SCRIPT)
	call_deferred("_equip_firewall")
	trial_reset.emit()


func _clear_firewall_effects() -> void:
	for effect: Node in get_tree().get_nodes_in_group("firewall_effects"):
		if effect.has_method("finish_firewall"):
			effect.call("finish_firewall", "trial_reset")


func _get_firewall_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var value: Variant = player.get_meta("firewall_path_points", [])
	if value is Array:
		for raw_point: Variant in value as Array:
			if raw_point is Vector3:
				result.append(raw_point as Vector3)
	return result


func _get_firewall_normals() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var value: Variant = player.get_meta("firewall_path_normals", [])
	if value is Array:
		for raw_normal: Variant in value as Array:
			if raw_normal is Vector3:
				result.append(raw_normal as Vector3)
	return result


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
	body.add_to_group("firewall_drawable_surface")
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
	label.visibility_range_end = 44.0
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
	var material: StandardMaterial3D = _make_material(albedo, 0.32, 0.44)
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
		"firewall_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"floor_completions": floor_completion_count,
		"corner_completions": corner_completion_count,
		"rejected_paths": rejected_path_count,
		"last_path_length": snappedf(last_path_length, 0.01),
		"last_surface_sequence": last_surface_sequence.duplicate(),
		"last_transition_count": last_transition_count,
		"last_firewall_serial": last_firewall_serial,
		"floor_gate_open": (
			floor_gate != null and floor_gate.is_mechanism_active()
		),
		"corner_gate_open": (
			corner_gate != null and corner_gate.is_mechanism_active()
		),
	}
