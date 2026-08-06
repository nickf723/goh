extends Node3D
class_name PrototypeRimeArmorySpellTrial

signal line_stage_completed
signal lodge_stage_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const CombatTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)

enum TrialStage {
	LONG_POINT,
	LODGED_EDGE,
	MASTERY,
	COMPLETE,
}

@export_group("Trial")
@export var completion_flag: String = "rime_armory_spell_trial_complete"
@export_range(0.02, 0.5, 0.01) var lodge_scan_interval: float = 0.08

var environment_root: Node3D
var mechanisms_root: Node3D
var player: CharacterBody3D
var line_targets: Array[CombatTrainingTarget] = []
var line_gate: MechanismSlidingGate
var mastery_gate: MechanismSlidingGate
var mastery_goal: Area3D
var anchor_plate: StaticBody3D

var stage: TrialStage = TrialStage.LONG_POINT
var trial_complete: bool = false
var initial_player_transform: Transform3D
var defeated_line_targets: Dictionary = {}
var anchor_lodge_count: int = 0
var mastery_entries: int = 0
var lodge_scan_remaining: float = 0.0

var stone_material: StandardMaterial3D
var dark_stone_material: StandardMaterial3D
var ice_material: StandardMaterial3D
var target_material: StandardMaterial3D
var anchor_material: StandardMaterial3D
var mastery_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("rime_armory_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_long_point_stage()
	_build_lodged_edge_stage()
	_build_mastery_stage()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.LONG_POINT)
	_show_message(
		"The Rime Armory: Ice Lance is a full crystalline spear. "
		+ "Pierce a line, then lodge the lance into the marked anchor."
	)
	call_deferred("_equip_ice_lance")


func _process(delta: float) -> void:
	if stage != TrialStage.LODGED_EDGE:
		return
	lodge_scan_remaining -= maxf(delta, 0.0)
	if lodge_scan_remaining > 0.0:
		return
	lodge_scan_remaining = maxf(lodge_scan_interval, 0.02)
	_scan_for_anchor_lance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "RimeArmoryEnvironment"
	add_child(environment_root)
	mechanisms_root = Node3D.new()
	mechanisms_root.name = "RimeArmoryMechanisms"
	add_child(mechanisms_root)


func _build_materials() -> void:
	stone_material = _make_material(
		Color(0.13, 0.16, 0.22),
		0.22,
		0.74
	)
	dark_stone_material = _make_material(
		Color(0.045, 0.065, 0.1),
		0.3,
		0.78
	)
	ice_material = _make_emissive_material(
		Color(0.34, 0.76, 0.94, 0.62),
		Color(0.48, 0.9, 1.0),
		2.4
	)
	target_material = _make_emissive_material(
		Color(0.2, 0.48, 0.66, 0.78),
		Color(0.32, 0.82, 1.0),
		1.8
	)
	anchor_material = _make_emissive_material(
		Color(0.5, 0.78, 0.96, 0.72),
		Color(0.64, 0.94, 1.0),
		3.2
	)
	mastery_material = _make_emissive_material(
		Color(0.72, 0.48, 0.14, 0.78),
		Color(1.0, 0.74, 0.18),
		3.5
	)


func _build_environment() -> void:
	_create_static_box(
		"ArmoryFloor",
		Vector3(0.0, -0.5, 16.0),
		Vector3(14.0, 1.0, 44.0),
		stone_material
	)
	_create_static_box(
		"ArmoryLeftWall",
		Vector3(-7.5, 4.0, 16.0),
		Vector3(1.0, 9.0, 44.0),
		dark_stone_material
	)
	_create_static_box(
		"ArmoryRightWall",
		Vector3(7.5, 4.0, 16.0),
		Vector3(1.0, 9.0, 44.0),
		dark_stone_material
	)
	_create_static_box(
		"ArmoryBackWall",
		Vector3(0.0, 4.0, -6.0),
		Vector3(14.0, 9.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"ArmoryFrontWall",
		Vector3(0.0, 4.0, 38.0),
		Vector3(14.0, 9.0, 1.0),
		dark_stone_material
	)

	_create_label(
		"THE RIME ARMORY",
		Vector3(0.0, 4.8, -3.8),
		Color(0.7, 0.92, 1.0),
		34
	)
	_create_label(
		"An arrow strikes one point. A lance owns the whole line.",
		Vector3(0.0, 3.9, -1.2),
		Color(0.72, 0.82, 0.94),
		21
	)
	_create_label(
		"I • THE LONG POINT",
		Vector3(0.0, 4.0, 2.0),
		Color(0.56, 0.9, 1.0),
		27
	)
	_create_label(
		"II • THE LODGED EDGE",
		Vector3(0.0, 4.0, 18.0),
		Color(0.56, 0.9, 1.0),
		27
	)
	_create_label(
		"PIERCE • EMBED • ENDURE",
		Vector3(0.0, 4.5, 34.0),
		Color(1.0, 0.82, 0.3),
		25
	)

	# Thin floor inlays make the intended firing lines readable without turning
	# the room into another debug laboratory.
	for path_z: float in [8.5, 23.0]:
		var inlay := MeshInstance3D.new()
		inlay.name = "IceLine" + str(roundi(path_z * 10.0))
		inlay.position = Vector3(0.0, 0.025, path_z)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.18, 0.04, 11.0)
		inlay.mesh = mesh
		inlay.material_override = ice_material
		environment_root.add_child(inlay)


func _build_long_point_stage() -> void:
	var target_z_values: Array[float] = [5.5, 8.6, 11.7]
	for index: int in range(target_z_values.size()):
		var target: CombatTrainingTarget = (
			CombatTargetScene.instantiate() as CombatTrainingTarget
		)
		target.name = "RimeLineTarget" + str(index + 1)
		target.target_label = "LANCE MARK " + str(index + 1)
		target.position = Vector3(0.0, 0.05, target_z_values[index])
		_configure_line_target(target, index)
		mechanisms_root.add_child(target)
		line_targets.append(target)
		var body_mesh: MeshInstance3D = target.get_node_or_null(
			"VisualRoot/Body"
		) as MeshInstance3D
		if body_mesh != null:
			body_mesh.material_override = target_material

	line_gate = GateScene.instantiate() as MechanismSlidingGate
	line_gate.name = "LongPointGate"
	line_gate.display_name = "Long Point Gate"
	line_gate.position = Vector3(0.0, 0.0, 15.0)
	line_gate.scale = Vector3(1.25, 1.0, 1.0)
	line_gate.open_offset = Vector3(0.0, 4.8, 0.0)
	line_gate.transition_seconds = 0.48
	mechanisms_root.add_child(line_gate)
	_hide_gate_label(line_gate)


func _configure_line_target(
	target: CombatTrainingTarget,
	index: int
) -> void:
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver == null:
		return
	hit_receiver.set("hit_mode", 2)
	hit_receiver.set("max_health", 2)
	hit_receiver.set("current_health", 2)
	hit_receiver.set("max_stance", 0)
	hit_receiver.set("current_stance", 0)
	hit_receiver.set("regenerates_stance", false)
	hit_receiver.set("disappears_when_defeated", false)
	var callback: Callable = Callable(
		self,
		"_on_line_target_depleted"
	).bind(index)
	if not hit_receiver.is_connected("health_depleted", callback):
		hit_receiver.connect("health_depleted", callback)


func _build_lodged_edge_stage() -> void:
	anchor_plate = _create_static_box(
		"RimeAnchorPlate",
		Vector3(0.0, 2.2, 23.5),
		Vector3(4.2, 4.2, 0.65),
		anchor_material
	)
	anchor_plate.set_meta("ice_lance_anchor", true)
	anchor_plate.add_to_group("ice_lance_anchor_surfaces")

	var anchor_ring := MeshInstance3D.new()
	anchor_ring.name = "RimeAnchorRing"
	anchor_ring.position = Vector3(0.0, 2.2, 23.12)
	anchor_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.0
	ring_mesh.outer_radius = 1.18
	ring_mesh.rings = 30
	ring_mesh.ring_segments = 10
	anchor_ring.mesh = ring_mesh
	anchor_ring.material_override = ice_material
	environment_root.add_child(anchor_ring)
	_create_label(
		"LODGE THE LANCE",
		Vector3(0.0, 4.9, 23.0),
		Color(0.72, 0.94, 1.0),
		22
	)

	mastery_gate = GateScene.instantiate() as MechanismSlidingGate
	mastery_gate.name = "LodgedEdgeGate"
	mastery_gate.display_name = "Lodged Edge Gate"
	mastery_gate.position = Vector3(0.0, 0.0, 28.5)
	mastery_gate.scale = Vector3(1.25, 1.0, 1.0)
	mastery_gate.open_offset = Vector3(0.0, 4.8, 0.0)
	mastery_gate.transition_seconds = 0.48
	mechanisms_root.add_child(mastery_gate)
	_hide_gate_label(mastery_gate)


func _build_mastery_stage() -> void:
	mastery_goal = Area3D.new()
	mastery_goal.name = "RimeArmoryMasteryGoal"
	mastery_goal.position = Vector3(0.0, 1.0, 34.0)
	mastery_goal.collision_layer = 0
	mastery_goal.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.4
	shape.height = 2.0
	collision.shape = shape
	mastery_goal.add_child(collision)
	mechanisms_root.add_child(mastery_goal)
	mastery_goal.body_entered.connect(_on_mastery_goal_body_entered)

	var pad := MeshInstance3D.new()
	pad.name = "RimeArmoryMasteryPad"
	pad.position = Vector3(0.0, 0.08, 34.0)
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.35
	pad_mesh.bottom_radius = 2.35
	pad_mesh.height = 0.12
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.material_override = mastery_material
	environment_root.add_child(pad)


func _on_line_target_depleted(index: int) -> void:
	if stage != TrialStage.LONG_POINT:
		return
	defeated_line_targets[index] = true
	if defeated_line_targets.size() < line_targets.size():
		return
	line_gate.set_gate_open(true, false, {
		"reason": "three_targets_pierced",
	})
	line_stage_completed.emit()
	_set_stage(TrialStage.LODGED_EDGE)
	_show_message(
		"One spear carried through the entire line. Now drive Ice Lance into the glowing anchor and leave the solid spear embedded."
	)


func _scan_for_anchor_lance() -> void:
	for lance: Node in get_tree().get_nodes_in_group("ice_lance_lodged"):
		if lance == null or not is_instance_valid(lance):
			continue
		if str(lance.get_meta("ice_lance_lodge_surface", "")) != anchor_plate.name:
			continue
		anchor_lodge_count += 1
		mastery_gate.set_gate_open(true, false, {
			"reason": "ice_lance_lodged_in_anchor",
		})
		lodge_stage_completed.emit()
		_set_stage(TrialStage.MASTERY)
		_show_message(
			"The lance remains as temporary solid terrain. Cross the opened gate and claim mastery before the crystal finally shatters."
		)
		return


func _on_mastery_goal_body_entered(body: Node3D) -> void:
	if stage != TrialStage.MASTERY or trial_complete:
		return
	if not body.is_in_group("player"):
		return
	mastery_entries += 1
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message(
		"Ice Lance mastery recorded: pierce the line, drive with force, and leave a temporary spear in the world."
	)


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.LONG_POINT:
			GameState.set_objective(
				"Align Grace with all three marks and cast one Ice Lance through the complete line."
			)
		TrialStage.LODGED_EDGE:
			GameState.set_objective(
				"Cast Ice Lance into the glowing Rime Anchor. The spear must lodge in the hard surface."
			)
		TrialStage.MASTERY:
			GameState.set_objective(
				"The lodged lance is solid temporary terrain. Continue through the opened gate to the mastery seal."
			)
		TrialStage.COMPLETE:
			GameState.set_objective(
				"Rime Armory Spell Trial complete."
			)


func _equip_ice_lance() -> void:
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
		if ability != null and ability.get_spell_id() == "ice_lance":
			caster.call("select_ability", index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	GameState.set_flag(completion_flag, false)
	for lance: Node in get_tree().get_nodes_in_group("ice_lance_projectiles"):
		if lance != null and is_instance_valid(lance):
			lance.queue_free()
	for target: CombatTrainingTarget in line_targets:
		if target != null and is_instance_valid(target):
			target.reset_target()
	if line_gate != null:
		line_gate.reset_target()
	if mastery_gate != null:
		mastery_gate.reset_target()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	defeated_line_targets.clear()
	anchor_lodge_count = 0
	mastery_entries = 0
	lodge_scan_remaining = 0.0
	_set_stage(TrialStage.LONG_POINT)
	call_deferred("_equip_ice_lance")
	trial_reset.emit()
	_show_message("Rime Armory trial reset.")


func _hide_gate_label(gate: MechanismSlidingGate) -> void:
	if gate == null:
		return
	var label: Label3D = gate.get_node_or_null("StateLabel") as Label3D
	if label != null:
		label.visible = false


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
	label.visibility_range_end = 52.0
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
	var material := _make_material(albedo, 0.22, 0.3)
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
		"rime_armory_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"line_targets_defeated": defeated_line_targets.size(),
		"line_target_count": line_targets.size(),
		"line_gate_open": line_gate.active if line_gate != null else false,
		"anchor_lodge_count": anchor_lodge_count,
		"mastery_gate_open": mastery_gate.active if mastery_gate != null else false,
		"mastery_entries": mastery_entries,
		"active_lances": get_tree().get_nodes_in_group("ice_lance_projectiles").size(),
		"lodged_lances": get_tree().get_nodes_in_group("ice_lance_lodged").size(),
	}
