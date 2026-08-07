extends Node3D
class_name PrototypeLightningSparkSpellTrial

signal fan_stage_completed
signal flank_stage_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const TargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)

enum TrialStage {
	FORKED_FAN,
	BROKEN_SIGHTLINE,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = (
	"forked_conduit_spell_trial_complete"
)
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Lightning Spark casts."
)

var environment_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D
var initial_player_transform: Transform3D

var fan_targets: Array[CombatTrainingTarget] = []
var fan_witness: CombatTrainingTarget
var flank_target: CombatTrainingTarget
var fan_gate: MechanismSlidingGate
var flank_gate: MechanismSlidingGate
var mastery_area: Area3D

var stage: TrialStage = TrialStage.FORKED_FAN
var completed_fan_target_ids: Dictionary = {}
var fan_completion_count: int = 0
var flank_completion_count: int = 0
var trial_complete: bool = false

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var lightning_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var witness_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("forked_conduit_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_fan_stage()
	_build_flank_stage()
	_build_mastery_landing()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.FORKED_FAN)
	_show_message(
		"Forked Conduit: stand on the indigo mark and catch all three conductors in one close lightning fan. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_lightning_spark")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "ForkedConduitEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "ForkedConduitActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(
		Color(0.06, 0.075, 0.11),
		0.32,
		0.72
	)
	wall_material = _make_material(
		Color(0.025, 0.04, 0.075),
		0.56,
		0.48
	)
	lightning_material = _make_emissive_material(
		Color(0.09, 0.22, 0.72, 0.86),
		Color(0.16, 0.48, 1.0),
		3.4
	)
	gold_material = _make_emissive_material(
		Color(0.68, 0.48, 0.1, 0.88),
		Color(1.0, 0.78, 0.16),
		3.8
	)
	witness_material = _make_emissive_material(
		Color(0.16, 0.28, 0.5, 0.42),
		Color(0.2, 0.46, 0.92),
		1.1
	)


func _build_environment() -> void:
	_create_static_box(
		"ForkedConduitFloor",
		Vector3(0.0, -0.5, 16.0),
		Vector3(18.0, 1.0, 44.0),
		floor_material
	)
	_create_static_box(
		"ForkedConduitLeftWall",
		Vector3(-9.5, 2.5, 16.0),
		Vector3(1.0, 6.0, 44.0),
		wall_material
	)
	_create_static_box(
		"ForkedConduitRightWall",
		Vector3(9.5, 2.5, 16.0),
		Vector3(1.0, 6.0, 44.0),
		wall_material
	)
	_create_static_box(
		"ForkedConduitBackWall",
		Vector3(0.0, 2.5, -6.0),
		Vector3(18.0, 6.0, 1.0),
		wall_material
	)
	_create_static_box(
		"ForkedConduitFrontWall",
		Vector3(0.0, 2.5, 38.0),
		Vector3(18.0, 6.0, 1.0),
		wall_material
	)

	for divider_z: float in [10.0, 25.0]:
		_create_static_box(
			"ConduitDividerLeft" + str(roundi(divider_z)),
			Vector3(-6.0, 2.2, divider_z),
			Vector3(7.0, 5.4, 0.8),
			wall_material
		)
		_create_static_box(
			"ConduitDividerRight" + str(roundi(divider_z)),
			Vector3(6.0, 2.2, divider_z),
			Vector3(7.0, 5.4, 0.8),
			wall_material
		)

	_create_label(
		"THE FORKED CONDUIT",
		Vector3(0.0, 4.8, -3.8),
		Color(0.58, 0.76, 1.0),
		34
	)
	_create_label(
		"One spark. Many paths.",
		Vector3(0.0, 3.8, -1.2),
		Color(0.66, 0.78, 0.96),
		22
	)
	_create_label(
		"I • FORKED FAN",
		Vector3(0.0, 4.0, 1.0),
		Color(0.44, 0.7, 1.0),
		28
	)
	_create_label(
		"II • BROKEN SIGHTLINE",
		Vector3(0.0, 4.0, 13.0),
		Color(0.44, 0.7, 1.0),
		28
	)

	_create_floor_mark(
		"FanCastingMark",
		Vector3(0.0, 0.04, 2.0),
		2.0,
		lightning_material
	)
	_create_label(
		"CENTER THE FAN • THREE CONDUCTORS • ONE CAST",
		Vector3(0.0, 3.0, 7.8),
		Color(0.68, 0.84, 1.0),
		18
	)

	_create_static_box(
		"BrokenSightlineShield",
		Vector3(0.0, 1.6, 18.0),
		Vector3(4.4, 3.2, 1.1),
		wall_material
	)
	_create_label(
		"THE SHIELD BLOCKS THE CENTER • FLANK LEFT OR RIGHT",
		Vector3(0.0, 3.6, 20.2),
		Color(0.68, 0.84, 1.0),
		18
	)


func _build_fan_stage() -> void:
	for target_data: Dictionary in [
		{"name": "LeftForkConductor", "label": "LEFT CONDUCTOR", "position": Vector3(-1.6, 0.0, 6.2)},
		{"name": "CenterForkConductor", "label": "CENTER CONDUCTOR", "position": Vector3(0.0, 0.0, 6.5)},
		{"name": "RightForkConductor", "label": "RIGHT CONDUCTOR", "position": Vector3(1.6, 0.0, 6.2)},
	]:
		var target: CombatTrainingTarget = _spawn_target(
			str(target_data.get("name", "ForkConductor")),
			str(target_data.get("label", "CONDUCTOR")),
			target_data.get("position", Vector3.ZERO) as Vector3,
			2
		)
		fan_targets.append(target)
		var hit_receiver: Node = target.get_node_or_null("HitReceiver")
		if hit_receiver != null:
			hit_receiver.health_depleted.connect(
				_on_fan_target_depleted.bind(target)
			)

	fan_witness = _spawn_target(
		"OutsideConeWitness",
		"OUTSIDE-CONE WITNESS",
		Vector3(3.0, 0.0, 4.6),
		12
	)
	_tint_target(fan_witness, witness_material)
	fan_gate = _spawn_gate(
		"ForkedFanGate",
		"Forked Fan Gate",
		Vector3(0.0, 0.0, 10.0)
	)


func _build_flank_stage() -> void:
	flank_target = _spawn_target(
		"ShieldedConductor",
		"SHIELDED CONDUCTOR",
		Vector3(0.0, 0.0, 21.0),
		2
	)
	var hit_receiver: Node = flank_target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.health_depleted.connect(_on_flank_target_depleted)
	flank_gate = _spawn_gate(
		"BrokenSightlineGate",
		"Broken Sightline Gate",
		Vector3(0.0, 0.0, 25.0)
	)


func _build_mastery_landing() -> void:
	mastery_area = Area3D.new()
	mastery_area.name = "LightningSparkMasteryArea"
	mastery_area.position = Vector3(0.0, 1.0, 32.0)
	mastery_area.collision_layer = 0
	mastery_area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 2.4, 4.0)
	collision.shape = shape
	mastery_area.add_child(collision)
	actors_root.add_child(mastery_area)
	mastery_area.body_entered.connect(_on_mastery_area_body_entered)

	_create_floor_mark(
		"LightningSparkMasteryPad",
		Vector3(0.0, 0.06, 32.0),
		2.4,
		gold_material
	)
	_create_label(
		"FAN • FLANK • INTERRUPT",
		Vector3(0.0, 3.8, 34.0),
		Color(1.0, 0.82, 0.28),
		26
	)


func _on_fan_target_depleted(target: CombatTrainingTarget) -> void:
	if stage != TrialStage.FORKED_FAN or target == null:
		return
	var target_id: int = target.get_instance_id()
	if completed_fan_target_ids.has(target_id):
		return
	completed_fan_target_ids[target_id] = true
	if completed_fan_target_ids.size() < fan_targets.size():
		return
	fan_completion_count += 1
	fan_gate.set_gate_open(true, false, {"reason": "forked_fan_complete"})
	_set_stage(TrialStage.BROKEN_SIGHTLINE)
	fan_stage_completed.emit()
	_show_message(
		"The forked fan closes three circuits at once. The next conductor is near, but stone blocks the center line."
	)


func _on_flank_target_depleted() -> void:
	if stage != TrialStage.BROKEN_SIGHTLINE:
		return
	flank_completion_count += 1
	flank_gate.set_gate_open(true, false, {"reason": "flank_complete"})
	_set_stage(TrialStage.MASTERY)
	flank_stage_completed.emit()
	_show_message(
		"Sightline restored. Lightning Spark rewards close angles, not firing through architecture."
	)


func _on_mastery_area_body_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message(
		"Lightning Spark mastered: FAN • FLANK • INTERRUPT."
	)


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.FORKED_FAN:
			_set_objective(
				"Lightning Spark: stand on the indigo mark and hit all three conductors with one cone burst."
			)
		TrialStage.BROKEN_SIGHTLINE:
			_set_objective(
				"Lightning Spark: flank around the stone shield and burst the nearby conductor."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Lightning Spark: enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Forked Conduit complete: FAN • FLANK • INTERRUPT."
			)


func _equip_lightning_spark() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster == null:
		return
	var loadout_value: Variant = ability_caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "lightning_spark":
			ability_caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	completed_fan_target_ids.clear()
	fan_completion_count = 0
	flank_completion_count = 0
	trial_complete = false
	GameState.set_flag(completion_flag, false)
	for target: CombatTrainingTarget in fan_targets:
		if target != null and is_instance_valid(target):
			target.reset_target()
	if fan_witness != null:
		fan_witness.reset_target()
	if flank_target != null:
		flank_target.reset_target()
	if fan_gate != null:
		fan_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if flank_gate != null:
		flank_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	for effect: Node in get_tree().get_nodes_in_group("lightning_spark_effects"):
		if is_instance_valid(effect):
			effect.queue_free()
	for haptic: Node in get_tree().get_nodes_in_group("controller_haptic_patterns"):
		if haptic.has_method("cancel_pattern"):
			haptic.call("cancel_pattern", true, "trial_reset")
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.FORKED_FAN)
	call_deferred("_equip_lightning_spark")
	trial_reset.emit()


func _spawn_target(
	node_name: String,
	label: String,
	position_value: Vector3,
	health: int
) -> CombatTrainingTarget:
	var target := TargetScene.instantiate() as CombatTrainingTarget
	target.name = node_name
	target.target_label = label
	target.position = position_value
	actors_root.add_child(target)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.set("target_name", label)
		hit_receiver.set("max_health", health)
		hit_receiver.set("current_health", health)
		hit_receiver.set("max_stance", 8)
		hit_receiver.set("current_stance", 8)
	return target


func _spawn_gate(
	node_name: String,
	label: String,
	position_value: Vector3
) -> MechanismSlidingGate:
	var gate := GateScene.instantiate() as MechanismSlidingGate
	gate.name = node_name
	gate.display_name = label
	gate.position = position_value
	gate.scale = Vector3(1.75, 1.0, 1.0)
	gate.open_offset = Vector3(0.0, 4.4, 0.0)
	actors_root.add_child(gate)
	var state_label := gate.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		state_label.visible = false
	return gate


func _tint_target(
	target: CombatTrainingTarget,
	material: Material
) -> void:
	if target == null:
		return
	for mesh: Node in target.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material


func _create_floor_mark(
	node_name: String,
	position_value: Vector3,
	radius: float,
	material: Material
) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.name = node_name
	mark.position = position_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh.radial_segments = 32
	mark.mesh = mesh
	mark.material_override = material
	environment_root.add_child(mark)
	return mark


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
	label.visibility_range_end = 40.0
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
	var material := _make_material(albedo, 0.42, 0.34)
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func _get_target_health(target: CombatTrainingTarget) -> int:
	if target == null:
		return -1
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	return int(hit_receiver.get("current_health")) if hit_receiver != null else -1


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
	var fan_health: Array[int] = []
	for target: CombatTrainingTarget in fan_targets:
		fan_health.append(_get_target_health(target))
	return {
		"forked_conduit_spell_trial": true,
		"stage": TrialStage.keys()[stage],
		"fan_health": fan_health,
		"fan_completed": completed_fan_target_ids.size(),
		"fan_witness_health": _get_target_health(fan_witness),
		"flank_health": _get_target_health(flank_target),
		"fan_gate_open": fan_gate.active if fan_gate != null else false,
		"flank_gate_open": flank_gate.active if flank_gate != null else false,
		"fan_completion_count": fan_completion_count,
		"flank_completion_count": flank_completion_count,
		"complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
	}
