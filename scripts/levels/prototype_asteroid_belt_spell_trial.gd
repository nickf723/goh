extends Node3D
class_name PrototypeAsteroidBeltSpellTrial

signal spacing_stage_completed
signal drift_stage_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const CombatTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)

enum TrialStage {
	EXACT_ORBIT,
	ORBITAL_DRIFT,
	MASTERY,
	COMPLETE,
}

@export_group("Trial")
@export var completion_flag: String = "orbital_gallery_spell_trial_complete"
@export_range(5.0, 60.0, 1.0) var moving_target_updates_per_second: float = 30.0
@export_range(0.1, 3.0, 0.05) var moving_target_angular_speed: float = 0.82
@export_range(1.0, 8.0, 0.1) var moving_target_half_width: float = 4.6

var environment_root: Node3D
var mechanisms_root: Node3D
var player: CharacterBody3D
var orbit_target: CombatTrainingTarget
var inner_witness: CombatTrainingTarget
var outer_witness: CombatTrainingTarget
var moving_target: CombatTrainingTarget
var spacing_gate: MechanismSlidingGate
var mastery_gate: MechanismSlidingGate
var mastery_goal: Area3D

var stage: TrialStage = TrialStage.EXACT_ORBIT
var trial_complete: bool = false
var initial_player_transform: Transform3D
var moving_target_origin: Vector3 = Vector3.ZERO
var moving_elapsed: float = 0.0
var moving_update_accumulator: float = 0.0
var spacing_completions: int = 0
var drift_completions: int = 0
var mastery_entries: int = 0

var stone_material: StandardMaterial3D
var dark_stone_material: StandardMaterial3D
var space_material: StandardMaterial3D
var safe_material: StandardMaterial3D
var contact_material: StandardMaterial3D
var mastery_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("orbital_gallery_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_exact_orbit_stage()
	_build_orbital_drift_stage()
	_build_mastery_stage()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.EXACT_ORBIT)
	_show_message(
		"The Orbital Gallery: Asteroid Belt protects a distance, not Grace's entire body. Stand on the central mark and let the orbit find the middle target."
	)
	call_deferred("_equip_asteroid_belt")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _process(delta: float) -> void:
	if stage != TrialStage.ORBITAL_DRIFT or moving_target == null:
		return
	moving_update_accumulator += maxf(delta, 0.0)
	var update_interval: float = 1.0 / maxf(
		moving_target_updates_per_second,
		1.0
	)
	if moving_update_accumulator < update_interval:
		return
	var step: float = moving_update_accumulator
	moving_update_accumulator = fmod(
		moving_update_accumulator,
		update_interval
	)
	moving_elapsed += step
	moving_target.global_position = (
		moving_target_origin
		+ Vector3.RIGHT
		* sin(moving_elapsed * moving_target_angular_speed)
		* moving_target_half_width
	)


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "OrbitalGalleryEnvironment"
	add_child(environment_root)
	mechanisms_root = Node3D.new()
	mechanisms_root.name = "OrbitalGalleryMechanisms"
	add_child(mechanisms_root)


func _build_materials() -> void:
	stone_material = _make_material(
		Color(0.11, 0.12, 0.18),
		0.2,
		0.8
	)
	dark_stone_material = _make_material(
		Color(0.035, 0.04, 0.075),
		0.3,
		0.76
	)
	space_material = _make_emissive_material(
		Color(0.32, 0.12, 0.58, 0.52),
		Color(0.58, 0.24, 1.0),
		2.4
	)
	safe_material = _make_emissive_material(
		Color(0.18, 0.34, 0.56, 0.4),
		Color(0.24, 0.66, 1.0),
		1.7
	)
	contact_material = _make_emissive_material(
		Color(0.62, 0.32, 0.1, 0.58),
		Color(1.0, 0.58, 0.12),
		2.8
	)
	mastery_material = _make_emissive_material(
		Color(0.76, 0.5, 0.12, 0.74),
		Color(1.0, 0.74, 0.18),
		3.5
	)


func _build_environment() -> void:
	_create_static_box(
		"GalleryFloor",
		Vector3(0.0, -0.5, 14.0),
		Vector3(16.0, 1.0, 40.0),
		stone_material
	)
	_create_static_box(
		"GalleryLeftWall",
		Vector3(-8.5, 4.0, 14.0),
		Vector3(1.0, 9.0, 40.0),
		dark_stone_material
	)
	_create_static_box(
		"GalleryRightWall",
		Vector3(8.5, 4.0, 14.0),
		Vector3(1.0, 9.0, 40.0),
		dark_stone_material
	)
	_create_static_box(
		"GalleryBackWall",
		Vector3(0.0, 4.0, -6.0),
		Vector3(16.0, 9.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"GalleryFrontWall",
		Vector3(0.0, 4.0, 34.0),
		Vector3(16.0, 9.0, 1.0),
		dark_stone_material
	)

	_create_static_box(
		"SpacingDividerLeft",
		Vector3(-5.2, 4.0, 11.0),
		Vector3(6.0, 9.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"SpacingDividerRight",
		Vector3(5.2, 4.0, 11.0),
		Vector3(6.0, 9.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"SpacingDividerLintel",
		Vector3(0.0, 7.0, 11.0),
		Vector3(4.4, 3.0, 1.0),
		dark_stone_material
	)

	_create_static_box(
		"DriftDividerLeft",
		Vector3(-5.2, 4.0, 25.0),
		Vector3(6.0, 9.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"DriftDividerRight",
		Vector3(5.2, 4.0, 25.0),
		Vector3(6.0, 9.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"DriftDividerLintel",
		Vector3(0.0, 7.0, 25.0),
		Vector3(4.4, 3.0, 1.0),
		dark_stone_material
	)

	_create_label(
		"THE ORBITAL GALLERY",
		Vector3(0.0, 4.9, -3.8),
		Color(0.78, 0.58, 1.0),
		34
	)
	_create_label(
		"Space is not only where you stand. It is the distance you keep.",
		Vector3(0.0, 3.9, -1.1),
		Color(0.76, 0.82, 0.96),
		21
	)
	_create_label(
		"I • THE EXACT ORBIT",
		Vector3(0.0, 4.0, 1.0),
		Color(0.72, 0.48, 1.0),
		27
	)
	_create_label(
		"II • ORBITAL DRIFT",
		Vector3(0.0, 4.0, 14.0),
		Color(0.72, 0.48, 1.0),
		27
	)
	_create_label(
		"POSITION • ORBIT • REPEL",
		Vector3(0.0, 4.5, 30.0),
		Color(1.0, 0.82, 0.3),
		25
	)


func _build_exact_orbit_stage() -> void:
	_create_orbit_guide(
		"CastCenter",
		Vector3(0.0, 0.04, 4.0),
		0.72,
		space_material,
		"CAST FROM HERE"
	)
	_create_orbit_guide(
		"InnerSafeGuide",
		Vector3(0.0, 0.045, 4.0),
		1.35,
		safe_material,
		"INNER • SAFE"
	)
	_create_orbit_guide(
		"ContactGuide",
		Vector3(0.0, 0.05, 4.0),
		2.75,
		contact_material,
		"ORBIT • CONTACT"
	)
	_create_orbit_guide(
		"OuterSafeGuide",
		Vector3(0.0, 0.055, 4.0),
		5.2,
		safe_material,
		"OUTER • SAFE"
	)

	inner_witness = _spawn_target(
		"InnerWitness",
		"INNER WITNESS",
		Vector3(-1.35, 0.05, 4.0),
		30,
		safe_material
	)
	orbit_target = _spawn_target(
		"OrbitTarget",
		"ORBIT TARGET",
		Vector3(2.75, 0.05, 4.0),
		6,
		contact_material
	)
	outer_witness = _spawn_target(
		"OuterWitness",
		"OUTER WITNESS",
		Vector3(5.2, 0.05, 4.0),
		30,
		safe_material
	)
	var orbit_receiver: Node = orbit_target.get_node_or_null("HitReceiver")
	if orbit_receiver != null:
		var callback := Callable(self, "_on_orbit_target_depleted")
		if not orbit_receiver.is_connected("health_depleted", callback):
			orbit_receiver.connect("health_depleted", callback)

	spacing_gate = GateScene.instantiate() as MechanismSlidingGate
	spacing_gate.name = "ExactOrbitGate"
	spacing_gate.display_name = "Exact Orbit Gate"
	spacing_gate.position = Vector3(0.0, 0.0, 11.0)
	spacing_gate.scale = Vector3(1.24, 1.0, 1.0)
	spacing_gate.open_offset = Vector3(0.0, 4.8, 0.0)
	spacing_gate.transition_seconds = 0.5
	mechanisms_root.add_child(spacing_gate)
	_hide_gate_label(spacing_gate)


func _build_orbital_drift_stage() -> void:
	_create_orbit_guide(
		"DriftPositionGuide",
		Vector3(0.0, 0.04, 18.0),
		2.75,
		space_material,
		"MOVE THE ORBIT INTO ITS PATH"
	)
	moving_target = _spawn_target(
		"DriftingMoonTarget",
		"DRIFTING MOON",
		Vector3(0.0, 0.05, 18.0),
		4,
		contact_material
	)
	moving_target_origin = moving_target.global_position
	var moving_receiver: Node = moving_target.get_node_or_null("HitReceiver")
	if moving_receiver != null:
		var callback := Callable(self, "_on_moving_target_depleted")
		if not moving_receiver.is_connected("health_depleted", callback):
			moving_receiver.connect("health_depleted", callback)

	mastery_gate = GateScene.instantiate() as MechanismSlidingGate
	mastery_gate.name = "OrbitalDriftGate"
	mastery_gate.display_name = "Orbital Drift Gate"
	mastery_gate.position = Vector3(0.0, 0.0, 25.0)
	mastery_gate.scale = Vector3(1.24, 1.0, 1.0)
	mastery_gate.open_offset = Vector3(0.0, 4.8, 0.0)
	mastery_gate.transition_seconds = 0.5
	mechanisms_root.add_child(mastery_gate)
	_hide_gate_label(mastery_gate)


func _build_mastery_stage() -> void:
	mastery_goal = Area3D.new()
	mastery_goal.name = "AsteroidBeltMasteryGoal"
	mastery_goal.position = Vector3(0.0, 1.0, 30.0)
	mastery_goal.collision_layer = 0
	mastery_goal.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 2.6, 4.0)
	collision.shape = shape
	mastery_goal.add_child(collision)
	mechanisms_root.add_child(mastery_goal)
	mastery_goal.body_entered.connect(_on_mastery_goal_body_entered)

	var pad := MeshInstance3D.new()
	pad.name = "AsteroidBeltMasteryPad"
	pad.position = Vector3(0.0, 0.06, 30.0)
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.5
	pad_mesh.bottom_radius = 2.5
	pad_mesh.height = 0.12
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.material_override = mastery_material
	environment_root.add_child(pad)


func _spawn_target(
	node_name: String,
	label_text: String,
	position_value: Vector3,
	health: int,
	material: Material
) -> CombatTrainingTarget:
	var target: CombatTrainingTarget = (
		CombatTargetScene.instantiate() as CombatTrainingTarget
	)
	target.name = node_name
	target.target_label = label_text
	target.position = position_value
	mechanisms_root.add_child(target)
	target.set_physics_process(false)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.set("hit_mode", 2)
		hit_receiver.set("max_health", health)
		hit_receiver.set("current_health", health)
		hit_receiver.set("max_stance", 0)
		hit_receiver.set("current_stance", 0)
		hit_receiver.set("regenerates_stance", false)
		hit_receiver.set("disappears_when_defeated", false)
	var body: MeshInstance3D = target.get_node_or_null(
		"VisualRoot/Body"
	) as MeshInstance3D
	if body != null:
		body.material_override = material
	return target


func _on_orbit_target_depleted() -> void:
	if stage != TrialStage.EXACT_ORBIT:
		return
	spacing_completions += 1
	spacing_gate.set_gate_open(true, false, {
		"reason": "exact_orbit_complete",
	})
	spacing_stage_completed.emit()
	_set_stage(TrialStage.ORBITAL_DRIFT)
	_show_message(
		"The inner and outer witnesses remain beyond the rocks. Follow the Drifting Moon and place Grace so the moving orbit crosses its path."
	)


func _on_moving_target_depleted() -> void:
	if stage != TrialStage.ORBITAL_DRIFT:
		return
	drift_completions += 1
	mastery_gate.set_gate_open(true, false, {
		"reason": "orbital_drift_complete",
	})
	drift_stage_completed.emit()
	_set_stage(TrialStage.MASTERY)
	_show_message(
		"The belt moved with Grace and caught the Drifting Moon. Enter the mastery seal."
	)


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
		"Asteroid Belt mastery recorded: occupy the correct distance, move the orbit with Grace, and repel anything crossing the ring."
	)


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	set_process(stage == TrialStage.ORBITAL_DRIFT)
	match stage:
		TrialStage.EXACT_ORBIT:
			GameState.set_objective(
				"Stand on the central mark and cast Asteroid Belt. Defeat only the target at the orbit radius."
			)
		TrialStage.ORBITAL_DRIFT:
			GameState.set_objective(
				"Track the Drifting Moon. Reposition Grace so Asteroid Belt's moving ring intersects it."
			)
		TrialStage.MASTERY:
			GameState.set_objective(
				"Pass through the opened gate and enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			GameState.set_objective(
				"Orbital Gallery Spell Trial complete."
			)


func _equip_asteroid_belt() -> void:
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
		if ability != null and ability.get_spell_id() == "asteroid_belt":
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
	for belt: Node in get_tree().get_nodes_in_group("asteroid_belt_effects"):
		if belt != null and is_instance_valid(belt):
			if belt.has_method("finish_belt"):
				belt.call("finish_belt", "trial_reset")
			else:
				belt.queue_free()

	for target: CombatTrainingTarget in [
		inner_witness,
		orbit_target,
		outer_witness,
		moving_target,
	]:
		if target != null and is_instance_valid(target):
			target.reset_target()
			target.set_physics_process(false)
	if moving_target != null:
		moving_target.global_position = moving_target_origin
	if spacing_gate != null:
		spacing_gate.reset_target()
	if mastery_gate != null:
		mastery_gate.reset_target()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	moving_elapsed = 0.0
	moving_update_accumulator = 0.0
	spacing_completions = 0
	drift_completions = 0
	mastery_entries = 0
	_set_stage(TrialStage.EXACT_ORBIT)
	call_deferred("_equip_asteroid_belt")
	trial_reset.emit()
	_show_message("Orbital Gallery trial reset.")


func _create_orbit_guide(
	node_name: String,
	position_value: Vector3,
	radius_value: float,
	material: Material,
	label_text: String
) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	ring.position = position_value
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visibility_range_end = 36.0
	ring.visibility_range_end_margin = 4.0
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius_value - 0.06, 0.08)
	torus.outer_radius = radius_value + 0.06
	torus.rings = 40
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = material
	environment_root.add_child(ring)
	_create_label(
		label_text,
		position_value + Vector3(0.0, 0.5, -radius_value),
		Color(0.82, 0.86, 1.0),
		18
	)
	return ring


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
	var material := _make_material(albedo, 0.24, 0.44)
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


func get_target_health(target: CombatTrainingTarget) -> int:
	if target == null:
		return -1
	var receiver: Node = target.get_node_or_null("HitReceiver")
	return int(receiver.get("current_health")) if receiver != null else -1


func get_debug_data() -> Dictionary:
	return {
		"orbital_gallery_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"orbit_target_health": get_target_health(orbit_target),
		"inner_witness_health": get_target_health(inner_witness),
		"outer_witness_health": get_target_health(outer_witness),
		"moving_target_health": get_target_health(moving_target),
		"moving_target_position": moving_target.global_position if moving_target != null else Vector3.ZERO,
		"spacing_gate_open": spacing_gate.active if spacing_gate != null else false,
		"mastery_gate_open": mastery_gate.active if mastery_gate != null else false,
		"active_belts": get_tree().get_nodes_in_group("asteroid_belt_effects").size(),
		"spacing_completions": spacing_completions,
		"drift_completions": drift_completions,
		"mastery_entries": mastery_entries,
	}
