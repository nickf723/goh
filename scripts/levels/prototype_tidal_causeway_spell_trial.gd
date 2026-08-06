extends Node3D
class_name PrototypeTidalCausewaySpellTrial

signal cargo_stage_completed
signal mob_stage_completed
signal enemy_stage_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const GoblinScene: PackedScene = preload(
	"res://scenes/actors/enemies/goblin_drone.tscn"
)

enum TrialStage {
	CARGO,
	MOB,
	ENEMY,
	MASTERY,
	COMPLETE,
}

@export_group("Trial")
@export var completion_flag: String = "tidal_causeway_spell_trial_complete"
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Wave casts."
)

var environment_root: Node3D
var mechanisms_root: Node3D
var player: CharacterBody3D

var cargo_light: FieldResponsiveBody
var cargo_heavy: FieldResponsiveBody
var sanctuary_mob: GenericAnimalActor
var containment_enemy: CharacterBody3D

var cargo_goal: Area3D
var mob_goal: Area3D
var enemy_goal: Area3D
var mastery_goal: Area3D

var cargo_gate: MechanismSlidingGate
var mob_gate: MechanismSlidingGate
var enemy_gate: MechanismSlidingGate

var stage: TrialStage = TrialStage.CARGO
var trial_complete: bool = false
var initial_player_transform: Transform3D
var initial_enemy_transform: Transform3D
var cargo_goal_entries: int = 0
var mob_goal_entries: int = 0
var enemy_goal_entries: int = 0

var stone_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var water_material: StandardMaterial3D
var foam_material: StandardMaterial3D
var cargo_material: StandardMaterial3D
var anchor_material: StandardMaterial3D
var sanctuary_material: StandardMaterial3D
var containment_material: StandardMaterial3D
var mastery_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("tidal_causeway_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_cargo_stage()
	_build_mob_stage()
	_build_enemy_stage()
	_build_mastery_landing()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.CARGO)
	_show_message(
		"Tidal Causeway: Wave pushes a broad front without dealing damage. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_wave")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "TidalCausewayEnvironment"
	add_child(environment_root)
	mechanisms_root = Node3D.new()
	mechanisms_root.name = "TidalCausewayActors"
	add_child(mechanisms_root)


func _build_materials() -> void:
	stone_material = _make_material(
		Color(0.12, 0.16, 0.2),
		0.16,
		0.82
	)
	wall_material = _make_material(
		Color(0.055, 0.085, 0.12),
		0.34,
		0.7
	)
	water_material = _make_emissive_material(
		Color(0.04, 0.34, 0.72, 0.68),
		Color(0.03, 0.48, 1.0),
		2.4
	)
	foam_material = _make_emissive_material(
		Color(0.68, 0.94, 1.0, 0.78),
		Color(0.55, 0.9, 1.0),
		3.2
	)
	cargo_material = _make_material(
		Color(0.19, 0.52, 0.68),
		0.46,
		0.42
	)
	anchor_material = _make_material(
		Color(0.16, 0.19, 0.24),
		0.82,
		0.24
	)
	sanctuary_material = _make_emissive_material(
		Color(0.06, 0.48, 0.46, 0.66),
		Color(0.04, 0.88, 0.72),
		2.7
	)
	containment_material = _make_emissive_material(
		Color(0.12, 0.36, 0.72, 0.68),
		Color(0.1, 0.56, 1.0),
		2.8
	)
	mastery_material = _make_emissive_material(
		Color(0.62, 0.48, 0.1, 0.78),
		Color(1.0, 0.76, 0.12),
		3.5
	)


func _build_environment() -> void:
	_create_static_box(
		"CausewayFloor",
		Vector3(0.0, -0.5, 28.0),
		Vector3(16.0, 1.0, 70.0),
		stone_material
	)
	_create_static_box(
		"CausewayLeftWall",
		Vector3(-8.5, 2.0, 28.0),
		Vector3(1.0, 5.0, 70.0),
		wall_material
	)
	_create_static_box(
		"CausewayRightWall",
		Vector3(8.5, 2.0, 28.0),
		Vector3(1.0, 5.0, 70.0),
		wall_material
	)
	_create_static_box(
		"CausewayBackWall",
		Vector3(0.0, 2.0, -7.0),
		Vector3(16.0, 5.0, 1.0),
		wall_material
	)
	_create_static_box(
		"CausewayFrontWall",
		Vector3(0.0, 2.0, 63.0),
		Vector3(16.0, 5.0, 1.0),
		wall_material
	)

	for divider_z: float in [15.0, 31.0, 47.0]:
		_create_static_box(
			"DividerLeft" + str(roundi(divider_z)),
			Vector3(-5.4, 1.9, divider_z),
			Vector3(5.2, 4.8, 0.8),
			wall_material
		)
		_create_static_box(
			"DividerRight" + str(roundi(divider_z)),
			Vector3(5.4, 1.9, divider_z),
			Vector3(5.2, 4.8, 0.8),
			wall_material
		)

	_create_label(
		"THE TIDAL CAUSEWAY",
		Vector3(0.0, 4.8, -3.8),
		Color(0.62, 0.86, 1.0),
		34
	)
	_create_label(
		"A wave moves the world without wounding it.",
		Vector3(0.0, 3.9, 0.2),
		Color(0.68, 0.82, 0.94),
		22
	)
	_create_label(
		"I • CARGO RUN",
		Vector3(0.0, 4.1, 3.0),
		Color(0.45, 0.82, 1.0),
		28
	)
	_create_label(
		"II • GENTLE CURRENT",
		Vector3(0.0, 4.1, 19.0),
		Color(0.42, 0.94, 0.78),
		28
	)
	_create_label(
		"III • BREAK THE LINE",
		Vector3(0.0, 4.1, 35.0),
		Color(0.42, 0.72, 1.0),
		28
	)

	for channel_z: float in [8.0, 24.0, 40.0]:
		var channel := MeshInstance3D.new()
		channel.name = "TidalChannel" + str(roundi(channel_z))
		channel.position = Vector3(0.0, 0.035, channel_z)
		var channel_mesh := BoxMesh.new()
		channel_mesh.size = Vector3(14.0, 0.05, 8.0)
		channel.mesh = channel_mesh
		channel.material_override = water_material
		environment_root.add_child(channel)


func _build_cargo_stage() -> void:
	cargo_light = _spawn_force_body(
		"TidalCargo",
		"Light Tidal Cargo",
		Vector3(-1.7, 0.7, 5.0),
		3.0,
		Vector3(1.25, 1.25, 1.25),
		cargo_material,
		"3 KG • CARGO"
	)
	cargo_light.add_to_group("wave_trial_cargo")
	cargo_heavy = _spawn_force_body(
		"TidalAnchor",
		"Heavy Tidal Anchor",
		Vector3(2.2, 0.85, 5.0),
		18.0,
		Vector3(1.55, 1.55, 1.55),
		anchor_material,
		"18 KG • ANCHOR"
	)
	cargo_heavy.add_to_group("wave_trial_anchor")

	cargo_goal = _create_goal_area(
		"CargoCatchBasin",
		Vector3(0.0, 1.0, 11.2),
		Vector3(6.6, 2.4, 3.2),
		water_material,
		"CARGO BASIN"
	)
	cargo_goal.body_entered.connect(_on_cargo_goal_body_entered)
	cargo_gate = _spawn_gate(
		"CargoGate",
		"Cargo Current Gate",
		Vector3(0.0, 0.0, 15.0)
	)


func _build_mob_stage() -> void:
	sanctuary_mob = GenericAnimalActor.new()
	sanctuary_mob.name = "CausewayCapybara"
	sanctuary_mob.species_id = "capybara"
	sanctuary_mob.animal_name = "Causeway Capybara"
	sanctuary_mob.personality_profile_id = "calm"
	sanctuary_mob.move_speed = 0.42
	sanctuary_mob.wander_radius = 0.35
	sanctuary_mob.position = Vector3(0.0, 0.05, 21.2)
	sanctuary_mob.set_meta("wave_push_multiplier", 0.78)
	sanctuary_mob.add_to_group("wave_trial_mob")
	mechanisms_root.add_child(sanctuary_mob)

	mob_goal = _create_goal_area(
		"MobSanctuaryPool",
		Vector3(0.0, 1.0, 27.2),
		Vector3(6.8, 2.4, 3.4),
		sanctuary_material,
		"SANCTUARY POOL"
	)
	mob_goal.body_entered.connect(_on_mob_goal_body_entered)
	mob_gate = _spawn_gate(
		"MobGate",
		"Gentle Current Gate",
		Vector3(0.0, 0.0, 31.0)
	)


func _build_enemy_stage() -> void:
	containment_enemy = GoblinScene.instantiate() as CharacterBody3D
	containment_enemy.name = "HarmlessCurrentGoblin"
	containment_enemy.position = Vector3(0.0, 0.85, 37.4)
	containment_enemy.set_meta("wave_push_multiplier", 0.82)
	containment_enemy.add_to_group("wave_trial_enemy")
	var brain: Node = containment_enemy.get_node_or_null("EnemyBrain")
	if brain != null:
		brain.set("player_group", "wave_trial_inert_target")
		brain.set("default_attack", null)
	var hit_receiver: Node = containment_enemy.get_node_or_null(
		"HitReceiver"
	)
	if hit_receiver != null:
		hit_receiver.set("disappears_when_defeated", false)
	mechanisms_root.add_child(containment_enemy)
	initial_enemy_transform = containment_enemy.transform

	enemy_goal = _create_goal_area(
		"EnemyContainmentBasin",
		Vector3(0.0, 1.0, 43.2),
		Vector3(6.6, 2.4, 3.2),
		containment_material,
		"CONTAINMENT BASIN"
	)
	enemy_goal.body_entered.connect(_on_enemy_goal_body_entered)
	enemy_gate = _spawn_gate(
		"EnemyGate",
		"Breakwater Gate",
		Vector3(0.0, 0.0, 47.0)
	)


func _build_mastery_landing() -> void:
	mastery_goal = Area3D.new()
	mastery_goal.name = "WaveMasteryGoal"
	mastery_goal.position = Vector3(0.0, 1.0, 55.5)
	mastery_goal.collision_layer = 0
	mastery_goal.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 2.4, 4.0)
	collision.shape = shape
	mastery_goal.add_child(collision)
	mechanisms_root.add_child(mastery_goal)
	mastery_goal.body_entered.connect(_on_mastery_goal_body_entered)

	var pad := MeshInstance3D.new()
	pad.name = "WaveMasteryPad"
	pad.position = Vector3(0.0, 0.06, 55.5)
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.4
	pad_mesh.bottom_radius = 2.4
	pad_mesh.height = 0.12
	pad.mesh = pad_mesh
	pad.material_override = mastery_material
	environment_root.add_child(pad)
	_create_label(
		"MOVE • GUIDE • DISPLACE",
		Vector3(0.0, 3.8, 57.8),
		Color(1.0, 0.82, 0.28),
		26
	)


func _on_cargo_goal_body_entered(body: Node3D) -> void:
	if stage != TrialStage.CARGO:
		return
	if not body.is_in_group("wave_trial_cargo"):
		return
	cargo_goal_entries += 1
	cargo_gate.set_gate_open(true, false, {
		"reason": "cargo_delivered",
	})
	cargo_stage_completed.emit()
	_set_stage(TrialStage.MOB)
	_show_message(
		"Cargo delivered. The heavier anchor resists the same current. Guide the capybara into the sanctuary pool."
	)


func _on_mob_goal_body_entered(body: Node3D) -> void:
	if stage != TrialStage.MOB:
		return
	if not body.is_in_group("wave_trial_mob"):
		return
	mob_goal_entries += 1
	mob_gate.set_gate_open(true, false, {
		"reason": "mob_guided",
	})
	mob_stage_completed.emit()
	_set_stage(TrialStage.ENEMY)
	_show_message(
		"The capybara is safe and unharmed. Push the harmless Goblin into containment without damaging it."
	)


func _on_enemy_goal_body_entered(body: Node3D) -> void:
	if stage != TrialStage.ENEMY:
		return
	if not body.is_in_group("wave_trial_enemy"):
		return
	enemy_goal_entries += 1
	enemy_gate.set_gate_open(true, false, {
		"reason": "enemy_displaced",
	})
	enemy_stage_completed.emit()
	_set_stage(TrialStage.MASTERY)
	_show_message(
		"The enemy line breaks without a wound. Reach the mastery basin."
	)


func _on_mastery_goal_body_entered(body: Node3D) -> void:
	if stage != TrialStage.MASTERY or trial_complete:
		return
	if not body.is_in_group("player"):
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	_show_message(
		"Wave mastery recorded: broad displacement can move cargo, guide living mobs, and control enemies without damage."
	)
	trial_completed.emit()


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.CARGO:
			GameState.set_objective(
				"Cast Wave to push the 3 kg cargo into the basin. Compare it with the 18 kg anchor."
			)
		TrialStage.MOB:
			GameState.set_objective(
				"Use gentle Waves to guide the capybara into the sanctuary pool. Wave deals no damage."
			)
		TrialStage.ENEMY:
			GameState.set_objective(
				"Push the harmless Goblin into the containment basin without reducing its health."
			)
		TrialStage.MASTERY:
			GameState.set_objective(
				"Reach the final mastery basin."
			)
		TrialStage.COMPLETE:
			GameState.set_objective(
				"Tidal Causeway Spell Trial complete."
			)


func _equip_wave() -> void:
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
		if ability != null and ability.get_spell_id() == "wave":
			caster.call("select_ability", index, false)
			return


func _spawn_force_body(
	node_name: String,
	body_label: String,
	position_value: Vector3,
	mass_kg: float,
	size_value: Vector3,
	material: Material,
	label_text: String
) -> FieldResponsiveBody:
	var body := FieldResponsiveBody.new()
	body.name = node_name
	body.body_label = body_label
	body.position = position_value
	body.mass_override_kg = mass_kg
	body.gravity_strength = 18.0

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

	var visual := MeshInstance3D.new()
	visual.name = "BodyVisual"
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)

	var force_receiver := ForceReceiver.new()
	force_receiver.name = "ForceReceiver"
	force_receiver.drag = 7.5
	force_receiver.max_force_speed = 9.0
	body.add_child(force_receiver)

	var payload_receiver := PayloadReceiver.new()
	payload_receiver.name = "PayloadReceiver"
	body.add_child(payload_receiver)

	var label := Label3D.new()
	label.name = "BodyLabel"
	label.position = Vector3(0.0, size_value.y * 0.72, 0.0)
	label.text = label_text
	label.font_size = 21
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = Color(0.76, 0.9, 1.0)
	body.add_child(label)

	mechanisms_root.add_child(body)
	return body


func _spawn_gate(
	node_name: String,
	display_name: String,
	position_value: Vector3
) -> MechanismSlidingGate:
	var gate: MechanismSlidingGate = (
		GateScene.instantiate() as MechanismSlidingGate
	)
	gate.name = node_name
	gate.display_name = display_name
	gate.position = position_value
	gate.scale = Vector3(1.28, 1.0, 1.0)
	gate.open_offset = Vector3(0.0, 4.5, 0.0)
	gate.transition_seconds = 0.52
	mechanisms_root.add_child(gate)
	var state_label: Label3D = gate.get_node_or_null(
		"StateLabel"
	) as Label3D
	if state_label != null:
		state_label.visible = false
	return gate


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

	var pad := MeshInstance3D.new()
	pad.name = node_name + "Visual"
	pad.position = Vector3(
		position_value.x,
		0.045,
		position_value.z
	)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_value.x, 0.08, size_value.z)
	pad.mesh = mesh
	pad.material_override = material
	environment_root.add_child(pad)
	_create_label(
		label_text,
		Vector3(position_value.x, 2.7, position_value.z),
		Color(0.72, 0.92, 1.0),
		22
	)
	return area


func reset_trial() -> void:
	trial_complete = false
	GameState.set_flag(completion_flag, false)
	for wave: Node in get_tree().get_nodes_in_group("water_wave_effects"):
		if wave != null and is_instance_valid(wave):
			wave.queue_free()
	if cargo_light != null:
		cargo_light.reset_body()
	if cargo_heavy != null:
		cargo_heavy.reset_body()
	if sanctuary_mob != null:
		sanctuary_mob.reset_actor()
	_reset_enemy()
	for gate: MechanismSlidingGate in [cargo_gate, mob_gate, enemy_gate]:
		if gate != null:
			gate.reset_target()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	cargo_goal_entries = 0
	mob_goal_entries = 0
	enemy_goal_entries = 0
	_set_stage(TrialStage.CARGO)
	call_deferred("_equip_wave")
	trial_reset.emit()
	_show_message("Tidal Causeway trial reset.")


func _reset_enemy() -> void:
	if containment_enemy == null:
		return
	containment_enemy.transform = initial_enemy_transform
	containment_enemy.velocity = Vector3.ZERO
	var force_receiver: ForceReceiver = containment_enemy.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	if force_receiver != null:
		force_receiver.reset_forces()
	var status_receiver: Node = containment_enemy.get_node_or_null(
		"StatusReceiver"
	)
	if status_receiver != null and status_receiver.has_method(
		"clear_all_statuses"
	):
		status_receiver.call("clear_all_statuses")
	var hit_receiver: Node = containment_enemy.get_node_or_null(
		"HitReceiver"
	)
	if hit_receiver != null:
		hit_receiver.set(
			"current_health",
			int(hit_receiver.get("max_health"))
		)
		hit_receiver.set(
			"current_stance",
			int(hit_receiver.get("max_stance"))
		)
	var brain: Node = containment_enemy.get_node_or_null("EnemyBrain")
	if brain != null:
		if brain.has_method("cancel_current_action"):
			brain.call("cancel_current_action", "wave trial reset")
		brain.set("player", null)
		brain.set("state", EnemyBrain.EnemyState.IDLE)


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
	label.visibility_range_end = 46.0
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
	var material := _make_material(albedo, 0.34, 0.34)
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
	var enemy_health: int = -1
	if containment_enemy != null:
		var hit_receiver: Node = containment_enemy.get_node_or_null(
			"HitReceiver"
		)
		if hit_receiver != null:
			enemy_health = int(hit_receiver.get("current_health"))
	return {
		"tidal_causeway_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"cargo_position": cargo_light.global_position if cargo_light != null else Vector3.ZERO,
		"anchor_position": cargo_heavy.global_position if cargo_heavy != null else Vector3.ZERO,
		"mob_position": sanctuary_mob.global_position if sanctuary_mob != null else Vector3.ZERO,
		"enemy_position": containment_enemy.global_position if containment_enemy != null else Vector3.ZERO,
		"enemy_health": enemy_health,
		"cargo_goal_entries": cargo_goal_entries,
		"mob_goal_entries": mob_goal_entries,
		"enemy_goal_entries": enemy_goal_entries,
		"cargo_gate_open": cargo_gate.active if cargo_gate != null else false,
		"mob_gate_open": mob_gate.active if mob_gate != null else false,
		"enemy_gate_open": enemy_gate.active if enemy_gate != null else false,
	}
