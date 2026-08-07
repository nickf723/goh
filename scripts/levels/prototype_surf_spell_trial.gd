extends Node3D
class_name PrototypeSurfSpellTrial

signal momentum_stage_completed
signal hazard_stage_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const SurfaceHazardScript = preload(
	"res://scripts/hazards/surface_hazard_area.gd"
)

enum TrialStage {
	MOMENTUM_RUN,
	HAZARD_SLALOM,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = "riptide_causeway_spell_trial_complete"
@export_range(2.0, 30.0, 0.1) var required_gate_speed: float = 9.5
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Surf attempts."
)

var environment_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D
var initial_player_transform: Transform3D

var momentum_gate: MechanismSlidingGate
var hazard_gate: MechanismSlidingGate
var momentum_trigger: Area3D
var hazard_finish_trigger: Area3D
var mastery_area: Area3D
var lava_hazard: SurfaceHazardArea
var spike_hazard: SurfaceHazardArea

var stage: TrialStage = TrialStage.MOMENTUM_RUN
var trial_complete: bool = false
var momentum_completion_count: int = 0
var hazard_completion_count: int = 0
var negated_hazard_types: Dictionary = {}
var last_speed_at_gate: float = 0.0

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var water_material: StandardMaterial3D
var lava_material: StandardMaterial3D
var spike_material: StandardMaterial3D
var gold_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("riptide_causeway_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_momentum_stage()
	_build_hazard_stage()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.MOMENTUM_RUN)
	_show_message(
		"Riptide Causeway: cast Surf, keep moving, and carry the wave through the speed gate. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_surf")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "RiptideCausewayEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "RiptideCausewayActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(Color(0.055, 0.08, 0.11), 0.25, 0.76)
	wall_material = _make_material(Color(0.025, 0.045, 0.07), 0.48, 0.54)
	water_material = _make_emissive_material(
		Color(0.05, 0.34, 0.68, 0.78),
		Color(0.06, 0.54, 1.0),
		2.6
	)
	lava_material = _make_emissive_material(
		Color(0.72, 0.12, 0.015, 0.92),
		Color(1.0, 0.18, 0.015),
		4.0
	)
	spike_material = _make_emissive_material(
		Color(0.28, 0.36, 0.46, 0.96),
		Color(0.22, 0.48, 0.86),
		1.4
	)
	gold_material = _make_emissive_material(
		Color(0.66, 0.46, 0.08, 0.9),
		Color(1.0, 0.76, 0.12),
		3.6
	)


func _build_environment() -> void:
	_create_static_box(
		"CausewayFloor",
		Vector3(0.0, -0.5, 18.0),
		Vector3(14.0, 1.0, 52.0),
		floor_material
	)
	_create_static_box(
		"CausewayLeftWall",
		Vector3(-7.5, 2.5, 18.0),
		Vector3(1.0, 6.0, 52.0),
		wall_material
	)
	_create_static_box(
		"CausewayRightWall",
		Vector3(7.5, 2.5, 18.0),
		Vector3(1.0, 6.0, 52.0),
		wall_material
	)
	_create_static_box(
		"CausewayBackWall",
		Vector3(0.0, 2.5, -8.0),
		Vector3(14.0, 6.0, 1.0),
		wall_material
	)
	_create_static_box(
		"CausewayFrontWall",
		Vector3(0.0, 2.5, 44.0),
		Vector3(14.0, 6.0, 1.0),
		wall_material
	)

	for divider_z: float in [12.0, 34.0]:
		_create_static_box(
			"CausewayDividerLeft" + str(roundi(divider_z)),
			Vector3(-5.2, 2.2, divider_z),
			Vector3(4.6, 5.4, 0.8),
			wall_material
		)
		_create_static_box(
			"CausewayDividerRight" + str(roundi(divider_z)),
			Vector3(5.2, 2.2, divider_z),
			Vector3(4.6, 5.4, 0.8),
			wall_material
		)

	_create_label(
		"THE RIPTIDE CAUSEWAY",
		Vector3(0.0, 4.8, -5.2),
		Color(0.58, 0.82, 1.0),
		34
	)
	_create_label(
		"The wave lives only while its rider commits.",
		Vector3(0.0, 3.8, -2.2),
		Color(0.66, 0.8, 0.94),
		21
	)
	_create_label(
		"I • MOMENTUM RUN",
		Vector3(0.0, 4.0, 1.0),
		Color(0.44, 0.76, 1.0),
		28
	)
	_create_label(
		"II • HAZARD SLALOM",
		Vector3(0.0, 4.0, 15.0),
		Color(0.44, 0.76, 1.0),
		28
	)

	_create_floor_channel(
		"MomentumWaterChannel",
		Vector3(0.0, 0.035, 5.0),
		Vector3(8.5, 0.05, 11.0),
		water_material
	)
	_create_floor_channel(
		"HazardWaterChannel",
		Vector3(0.0, 0.035, 28.5),
		Vector3(10.8, 0.05, 12.0),
		water_material
	)


func _build_momentum_stage() -> void:
	momentum_trigger = _create_trigger_area(
		"MomentumSpeedGate",
		Vector3(0.0, 1.0, 9.0),
		Vector3(8.0, 2.4, 2.0)
	)
	momentum_trigger.body_entered.connect(_on_momentum_trigger_entered)
	_create_floor_channel(
		"MomentumThreshold",
		Vector3(0.0, 0.07, 9.0),
		Vector3(8.0, 0.08, 0.35),
		gold_material
	)
	_create_label(
		"CAST • ACCELERATE • CROSS ABOVE 9.5 m/s",
		Vector3(0.0, 3.0, 9.8),
		Color(0.72, 0.9, 1.0),
		18
	)
	momentum_gate = _spawn_gate(
		"MomentumGate",
		"Momentum Gate",
		Vector3(0.0, 0.0, 12.0)
	)


func _build_hazard_stage() -> void:
	lava_hazard = _spawn_surface_hazard(
		"LavaRun",
		"Lava Run",
		"lava",
		"fire",
		Vector3(0.0, 0.45, 19.5),
		Vector3(11.0, 1.2, 5.0),
		8,
		4
	)
	lava_hazard.hazard_negated.connect(
		_on_hazard_negated.bind("lava")
	)
	_create_floor_channel(
		"LavaSurfaceVisual",
		Vector3(0.0, 0.06, 19.5),
		Vector3(11.0, 0.08, 5.0),
		lava_material
	)

	spike_hazard = _spawn_surface_hazard(
		"SpikeRun",
		"Spike Run",
		"spikes",
		"neutral",
		Vector3(0.0, 0.45, 27.0),
		Vector3(11.0, 1.2, 5.0),
		6,
		5
	)
	spike_hazard.hazard_negated.connect(
		_on_hazard_negated.bind("spikes")
	)
	_build_spike_visuals(Vector3(0.0, 0.0, 27.0), Vector2(10.5, 4.6))

	for pylon_data: Dictionary in [
		{"name": "SlalomPylonA", "position": Vector3(-2.8, 1.0, 22.6)},
		{"name": "SlalomPylonB", "position": Vector3(2.8, 1.0, 25.0)},
		{"name": "SlalomPylonC", "position": Vector3(-2.6, 1.0, 29.0)},
	]:
		_create_static_box(
			str(pylon_data.get("name", "SlalomPylon")),
			pylon_data.get("position", Vector3.ZERO) as Vector3,
			Vector3(1.8, 2.0, 1.2),
			wall_material
		)

	hazard_finish_trigger = _create_trigger_area(
		"HazardFinishGate",
		Vector3(0.0, 1.0, 32.0),
		Vector3(10.0, 2.4, 2.0)
	)
	hazard_finish_trigger.body_entered.connect(_on_hazard_finish_entered)
	_create_label(
		"SKIM LAVA • SKIM SPIKES • DO NOT STOP",
		Vector3(0.0, 3.2, 31.2),
		Color(0.72, 0.9, 1.0),
		18
	)
	hazard_gate = _spawn_gate(
		"HazardGate",
		"Hazard Slalom Gate",
		Vector3(0.0, 0.0, 34.0)
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"SurfMasteryArea",
		Vector3(0.0, 1.0, 40.0),
		Vector3(7.0, 2.4, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_body_entered)
	_create_floor_channel(
		"SurfMasteryPad",
		Vector3(0.0, 0.07, 40.0),
		Vector3(5.0, 0.12, 3.2),
		gold_material
	)
	_create_label(
		"DRIVE • GLIDE • KEEP MOVING",
		Vector3(0.0, 3.8, 41.6),
		Color(1.0, 0.82, 0.28),
		26
	)


func _on_momentum_trigger_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MOMENTUM_RUN:
		return
	var controller: Node = player.get_node_or_null("SurfController")
	if (
		controller == null
		or not controller.has_method("is_surf_active")
		or not bool(controller.call("is_surf_active"))
	):
		_show_message("The threshold answers only to an active Surf wave.")
		return
	last_speed_at_gate = Vector3(
		player.velocity.x,
		0.0,
		player.velocity.z
	).length()
	if last_speed_at_gate + 0.01 < required_gate_speed:
		_show_message(
			"The wave reaches only "
			+ str(snappedf(last_speed_at_gate, 0.1))
			+ " m/s. Keep accelerating."
		)
		return
	momentum_completion_count += 1
	momentum_gate.set_gate_open(true, false, {"reason": "surf_speed_confirmed"})
	negated_hazard_types.clear()
	_set_stage(TrialStage.HAZARD_SLALOM)
	momentum_stage_completed.emit()
	_show_message(
		"Momentum confirmed. Carry Surf through both surface hazards and bend around the pylons."
	)


func _on_hazard_negated(
	body: Node,
	_result: Dictionary,
	hazard_id: String
) -> void:
	if body != player or stage != TrialStage.HAZARD_SLALOM:
		return
	negated_hazard_types[hazard_id] = true


func _on_hazard_finish_entered(body: Node) -> void:
	if body != player or stage != TrialStage.HAZARD_SLALOM:
		return
	var controller: Node = player.get_node_or_null("SurfController")
	var active_surf: bool = (
		controller != null
		and controller.has_method("is_surf_active")
		and bool(controller.call("is_surf_active"))
	)
	if not active_surf:
		_show_message("The wave collapsed before the end of the hazard run.")
		return
	if not negated_hazard_types.has("lava") or not negated_hazard_types.has("spikes"):
		_show_message("Surf must skim both the lava and the spike floor.")
		return
	hazard_completion_count += 1
	hazard_gate.set_gate_open(true, false, {"reason": "hazards_skimmed"})
	_set_stage(TrialStage.MASTERY)
	hazard_stage_completed.emit()
	_show_message(
		"Both hazards passed. Release movement to collapse the wave, then claim mastery."
	)


func _on_mastery_area_body_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Surf mastered: DRIVE • GLIDE • KEEP MOVING.")


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.MOMENTUM_RUN:
			_set_objective(
				"Surf: cast, keep moving, and cross the gold line above 9.5 m/s."
			)
		TrialStage.HAZARD_SLALOM:
			_set_objective(
				"Surf: skim the lava and spikes while steering around the pylons."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Surf: let the wave collapse, then enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Riptide Causeway complete: DRIVE • GLIDE • KEEP MOVING."
			)


func _equip_surf() -> void:
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
		if ability != null and ability.get_spell_id() == "surf":
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	momentum_completion_count = 0
	hazard_completion_count = 0
	negated_hazard_types.clear()
	last_speed_at_gate = 0.0
	GameState.set_flag(completion_flag, false)
	if player != null:
		var controller: Node = player.get_node_or_null("SurfController")
		if controller != null and controller.has_method("reset_target"):
			controller.call("reset_target")
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		player.set_physics_process(true)
	if momentum_gate != null:
		momentum_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if hazard_gate != null:
		hazard_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if lava_hazard != null:
		lava_hazard.reset_target()
	if spike_hazard != null:
		spike_hazard.reset_target()
	_restore_player_resources()
	_set_stage(TrialStage.MOMENTUM_RUN)
	call_deferred("_equip_surf")
	trial_reset.emit()


func _restore_player_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _spawn_surface_hazard(
	node_name: String,
	display_name_value: String,
	hazard_type_value: String,
	element_value: String,
	position_value: Vector3,
	size_value: Vector3,
	health_damage_value: int,
	stance_damage_value: int
) -> SurfaceHazardArea:
	var hazard: SurfaceHazardArea = SurfaceHazardScript.new() as SurfaceHazardArea
	hazard.name = node_name
	hazard.display_name = display_name_value
	hazard.hazard_type = hazard_type_value
	hazard.element = element_value
	hazard.health_damage = health_damage_value
	hazard.stance_damage = stance_damage_value
	hazard.position = position_value
	hazard.collision_layer = 0
	hazard.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	hazard.add_child(collision)
	actors_root.add_child(hazard)
	return hazard


func _spawn_gate(
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


func _build_spike_visuals(center: Vector3, size_value: Vector2) -> void:
	var spike_mesh := BoxMesh.new()
	spike_mesh.size = Vector3(0.18, 0.72, 0.18)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = spike_mesh
	var columns: int = 9
	var rows: int = 4
	multimesh.instance_count = columns * rows
	var instance_index: int = 0
	for row_index: int in range(rows):
		for column_index: int in range(columns):
			var x_ratio: float = (
				0.5 if columns <= 1 else float(column_index) / float(columns - 1)
			)
			var z_ratio: float = (
				0.5 if rows <= 1 else float(row_index) / float(rows - 1)
			)
			var position_value := Vector3(
				lerpf(-size_value.x * 0.5, size_value.x * 0.5, x_ratio),
				0.26,
				lerpf(-size_value.y * 0.5, size_value.y * 0.5, z_ratio)
			)
			var rotation := Basis(Vector3.FORWARD, deg_to_rad(18.0))
			rotation = Basis(Vector3.UP, float(column_index % 3) * 0.35) * rotation
			multimesh.set_instance_transform(
				instance_index,
				Transform3D(rotation, position_value)
			)
			instance_index += 1
	var visual := MultiMeshInstance3D.new()
	visual.name = "SpikeFloorVisual"
	visual.position = center
	visual.multimesh = multimesh
	visual.material_override = spike_material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	environment_root.add_child(visual)


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


func _create_floor_channel(
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
	label.visibility_range_end = 42.0
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
	var material: StandardMaterial3D = _make_material(albedo, 0.34, 0.42)
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
	var controller: Node = (
		player.get_node_or_null("SurfController")
		if player != null
		else null
	)
	return {
		"surf_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"momentum_completions": momentum_completion_count,
		"hazard_completions": hazard_completion_count,
		"last_speed_at_gate": snappedf(last_speed_at_gate, 0.01),
		"negated_hazards": negated_hazard_types.keys(),
		"surf": (
			controller.call("get_debug_data")
			if controller != null and controller.has_method("get_debug_data")
			else {}
		),
		"lava": lava_hazard.get_debug_data() if lava_hazard != null else {},
		"spikes": spike_hazard.get_debug_data() if spike_hazard != null else {},
	}
