extends Node3D
class_name PrototypeBubbleBreakwaterSpellTrial

signal impact_stage_completed
signal rebound_stage_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const CombatTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)

enum TrialStage {
	ONE_HIT,
	REBOUND,
	MASTERY,
	COMPLETE,
}

@export_group("Trial")
@export var completion_flag: String = "bubble_breakwater_spell_trial_complete"
@export_range(2.0, 30.0, 1.0) var scheduler_updates_per_second: float = 10.0
@export_range(0.1, 3.0, 0.05) var impact_arming_seconds: float = 0.75
@export_range(0.5, 4.0, 0.05) var trigger_radius: float = 1.35
@export_range(2.5, 8.0, 0.05) var rebound_required_distance: float = 3.65

var environment_root: Node3D
var mechanisms_root: Node3D
var player: CharacterBody3D
var bubble_controller: PlayerBubbleShieldController
var defense_controller: Node
var impact_gate: MechanismSlidingGate
var rebound_gate: MechanismSlidingGate
var rebound_target: CombatTrainingTarget
var mastery_goal: Area3D
var first_impact_source: Node3D
var second_impact_source: Node3D
var first_emitter_visual: MeshInstance3D
var second_emitter_visual: MeshInstance3D

var stage: TrialStage = TrialStage.ONE_HIT
var trial_complete: bool = false
var initial_player_transform: Transform3D
var rebound_target_origin: Vector3 = Vector3.ZERO
var scheduler_accumulator: float = 0.0
var armed_activation_id: int = -1
var fired_activation_id: int = -1
var arming_remaining: float = 0.0
var impact_completions: int = 0
var rebound_completions: int = 0
var mastery_entries: int = 0
var last_defense_result: Dictionary = {}

var stone_material: StandardMaterial3D
var dark_stone_material: StandardMaterial3D
var water_material: StandardMaterial3D
var pressure_material: StandardMaterial3D
var mastery_material: StandardMaterial3D

const FIRST_CENTER := Vector3(0.0, 0.0, 4.0)
const SECOND_CENTER := Vector3(0.0, 0.0, 18.0)


func _ready() -> void:
	add_to_group("bubble_breakwater_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
		bubble_controller = player.get_node_or_null(
			"BubbleShieldController"
		) as PlayerBubbleShieldController
		defense_controller = player.get_node_or_null(
			"PlayerDefenseController"
		)
	_build_roots()
	_build_materials()
	_build_environment()
	_build_one_hit_stage()
	_build_rebound_stage()
	_build_mastery_stage()
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.ONE_HIT)
	_show_message(
		"The Bubble Breakwater: cast Bubble inside the blue mark. "
		+ "The pressure pulse will test the ward automatically."
	)
	call_deferred("_equip_bubble")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _process(delta: float) -> void:
	scheduler_accumulator += maxf(delta, 0.0)
	var interval: float = 1.0 / maxf(
		scheduler_updates_per_second,
		1.0
	)
	if scheduler_accumulator < interval:
		return
	var step: float = scheduler_accumulator
	scheduler_accumulator = fmod(scheduler_accumulator, interval)

	match stage:
		TrialStage.ONE_HIT:
			_advance_impact_stage(
				step,
				FIRST_CENTER,
				first_impact_source,
				first_emitter_visual
			)
		TrialStage.REBOUND:
			_advance_impact_stage(
				step,
				SECOND_CENTER,
				second_impact_source,
				second_emitter_visual
			)
			_check_rebound_completion()
		_:
			pass


func _advance_impact_stage(
	delta: float,
	center: Vector3,
	impact_source: Node3D,
	emitter_visual: MeshInstance3D
) -> void:
	if (
		player == null
		or bubble_controller == null
		or defense_controller == null
	):
		return
	var player_offset: Vector3 = player.global_position - center
	player_offset.y = 0.0
	var inside_mark: bool = player_offset.length() <= trigger_radius
	var bubble_active: bool = bubble_controller.is_bubble_active()
	if not inside_mark or not bubble_active:
		armed_activation_id = -1
		fired_activation_id = -1
		arming_remaining = impact_arming_seconds
		_set_emitter_charge(emitter_visual, 0.0)
		return

	var activation_id: int = bubble_controller.activation_count
	if activation_id != armed_activation_id:
		armed_activation_id = activation_id
		arming_remaining = impact_arming_seconds
		fired_activation_id = -1
	if fired_activation_id == activation_id:
		_set_emitter_charge(emitter_visual, 0.0)
		return

	arming_remaining = maxf(arming_remaining - delta, 0.0)
	var charge_ratio: float = 1.0 - clampf(
		arming_remaining / maxf(impact_arming_seconds, 0.05),
		0.0,
		1.0
	)
	_set_emitter_charge(emitter_visual, charge_ratio)
	if arming_remaining > 0.0:
		return

	fired_activation_id = activation_id
	_fire_pressure_hit(impact_source)
	_set_emitter_charge(emitter_visual, 0.0)


func _fire_pressure_hit(impact_source: Node3D) -> void:
	if defense_controller == null:
		return
	var payload := DamagePayload.new()
	payload.amount = 8
	payload.stance_damage = 7
	payload.element = "water"
	payload.source_name = "Breakwater Pressure"
	payload.hit_type = "trial_impact"
	payload.tags = [
		"water",
		"pressure",
		"impact",
		"trial",
		"player_attack",
	]
	var result_value: Variant = defense_controller.call(
		"resolve_incoming_attack",
		payload,
		impact_source
	)
	last_defense_result = (
		(result_value as Dictionary).duplicate(true)
		if result_value is Dictionary
		else {}
	)
	if str(last_defense_result.get("outcome", "")) != "bubble_absorbed":
		_show_message(
			"The pressure reached Grace. Reform Bubble inside the marked ring."
		)
		return

	if stage == TrialStage.ONE_HIT:
		impact_completions += 1
		impact_gate.set_gate_open(true, false, {
			"reason": "bubble_negated_pressure",
		})
		impact_stage_completed.emit()
		_set_stage(TrialStage.REBOUND)
		_show_message(
			"No health, stance, or stagger passed through. In the next chamber, place the target inside Bubble's burst radius."
		)


func _check_rebound_completion() -> void:
	if stage != TrialStage.REBOUND or rebound_target == null:
		return
	var offset: Vector3 = rebound_target.global_position - SECOND_CENTER
	offset.y = 0.0
	if offset.length() < rebound_required_distance:
		return
	rebound_completions += 1
	rebound_gate.set_gate_open(true, false, {
		"reason": "bubble_rebound_complete",
	})
	rebound_stage_completed.emit()
	_set_stage(TrialStage.MASTERY)
	_show_message(
		"The ward turned defense into distance. Enter the mastery seal."
	)


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "BubbleBreakwaterEnvironment"
	add_child(environment_root)
	mechanisms_root = Node3D.new()
	mechanisms_root.name = "BubbleBreakwaterMechanisms"
	add_child(mechanisms_root)


func _build_materials() -> void:
	stone_material = _make_material(
		Color(0.1, 0.14, 0.2),
		0.18,
		0.82
	)
	dark_stone_material = _make_material(
		Color(0.025, 0.05, 0.09),
		0.28,
		0.76
	)
	water_material = _make_emissive_material(
		Color(0.08, 0.4, 0.72, 0.5),
		Color(0.08, 0.62, 1.0),
		2.2
	)
	pressure_material = _make_emissive_material(
		Color(0.3, 0.72, 0.92, 0.64),
		Color(0.38, 0.88, 1.0),
		3.0
	)
	mastery_material = _make_emissive_material(
		Color(0.72, 0.48, 0.12, 0.76),
		Color(1.0, 0.74, 0.18),
		3.4
	)


func _build_environment() -> void:
	_create_static_box(
		"BreakwaterFloor",
		Vector3(0.0, -0.5, 14.0),
		Vector3(16.0, 1.0, 40.0),
		stone_material
	)
	_create_static_box(
		"BreakwaterLeftWall",
		Vector3(-8.5, 4.0, 14.0),
		Vector3(1.0, 9.0, 40.0),
		dark_stone_material
	)
	_create_static_box(
		"BreakwaterRightWall",
		Vector3(8.5, 4.0, 14.0),
		Vector3(1.0, 9.0, 40.0),
		dark_stone_material
	)
	_create_static_box(
		"BreakwaterBackWall",
		Vector3(0.0, 4.0, -6.0),
		Vector3(16.0, 9.0, 1.0),
		dark_stone_material
	)
	_create_static_box(
		"BreakwaterFrontWall",
		Vector3(0.0, 4.0, 34.0),
		Vector3(16.0, 9.0, 1.0),
		dark_stone_material
	)

	for divider_z: float in [11.0, 25.0]:
		_create_static_box(
			"DividerLeft" + str(roundi(divider_z)),
			Vector3(-5.2, 4.0, divider_z),
			Vector3(6.0, 9.0, 1.0),
			dark_stone_material
		)
		_create_static_box(
			"DividerRight" + str(roundi(divider_z)),
			Vector3(5.2, 4.0, divider_z),
			Vector3(6.0, 9.0, 1.0),
			dark_stone_material
		)
		_create_static_box(
			"DividerLintel" + str(roundi(divider_z)),
			Vector3(0.0, 7.0, divider_z),
			Vector3(4.4, 3.0, 1.0),
			dark_stone_material
		)

	_create_label(
		"THE BUBBLE BREAKWATER",
		Vector3(0.0, 4.9, -3.8),
		Color(0.56, 0.86, 1.0),
		34
	)
	_create_label(
		"A wall resists force. A bubble returns it.",
		Vector3(0.0, 3.9, -1.1),
		Color(0.72, 0.84, 0.96),
		21
	)
	_create_label(
		"I • ONE CLEAN HIT",
		Vector3(0.0, 4.0, 1.0),
		Color(0.48, 0.82, 1.0),
		27
	)
	_create_label(
		"II • THE REBOUND",
		Vector3(0.0, 4.0, 15.0),
		Color(0.48, 0.82, 1.0),
		27
	)
	_create_label(
		"NEGATE • BURST • REPOSITION",
		Vector3(0.0, 4.5, 30.0),
		Color(1.0, 0.82, 0.3),
		25
	)


func _build_one_hit_stage() -> void:
	_create_trigger_mark("OneHitMark", FIRST_CENTER, water_material)
	first_impact_source = Node3D.new()
	first_impact_source.name = "FirstPressureEmitter"
	first_impact_source.position = FIRST_CENTER + Vector3(0.0, 1.0, -2.7)
	mechanisms_root.add_child(first_impact_source)
	first_emitter_visual = _create_emitter_visual(
		first_impact_source,
		pressure_material
	)

	impact_gate = GateScene.instantiate() as MechanismSlidingGate
	impact_gate.name = "OneHitGate"
	impact_gate.display_name = "One Clean Hit Gate"
	impact_gate.position = Vector3(0.0, 0.0, 11.0)
	impact_gate.scale = Vector3(1.24, 1.0, 1.0)
	impact_gate.open_offset = Vector3(0.0, 4.8, 0.0)
	impact_gate.transition_seconds = 0.5
	mechanisms_root.add_child(impact_gate)
	_hide_gate_label(impact_gate)


func _build_rebound_stage() -> void:
	_create_trigger_mark("ReboundMark", SECOND_CENTER, water_material)
	second_impact_source = Node3D.new()
	second_impact_source.name = "SecondPressureEmitter"
	second_impact_source.position = SECOND_CENTER + Vector3(0.0, 1.0, -2.7)
	mechanisms_root.add_child(second_impact_source)
	second_emitter_visual = _create_emitter_visual(
		second_impact_source,
		pressure_material
	)

	rebound_target = CombatTargetScene.instantiate() as CombatTrainingTarget
	rebound_target.name = "ReboundTarget"
	rebound_target.target_label = "REBOUND TARGET"
	rebound_target.position = SECOND_CENTER + Vector3(2.4, 0.05, 0.0)
	mechanisms_root.add_child(rebound_target)
	rebound_target_origin = rebound_target.global_position
	var receiver: Node = rebound_target.get_node_or_null("HitReceiver")
	if receiver != null:
		receiver.set("hit_mode", 2)
		receiver.set("max_health", 30)
		receiver.set("current_health", 30)
		receiver.set("max_stance", 0)
		receiver.set("current_stance", 0)
		receiver.set("regenerates_stance", false)
		receiver.set("disappears_when_defeated", false)
	rebound_target.set_physics_process(false)

	rebound_gate = GateScene.instantiate() as MechanismSlidingGate
	rebound_gate.name = "ReboundGate"
	rebound_gate.display_name = "Rebound Gate"
	rebound_gate.position = Vector3(0.0, 0.0, 25.0)
	rebound_gate.scale = Vector3(1.24, 1.0, 1.0)
	rebound_gate.open_offset = Vector3(0.0, 4.8, 0.0)
	rebound_gate.transition_seconds = 0.5
	mechanisms_root.add_child(rebound_gate)
	_hide_gate_label(rebound_gate)


func _build_mastery_stage() -> void:
	mastery_goal = Area3D.new()
	mastery_goal.name = "BubbleMasteryGoal"
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
	pad.name = "BubbleMasteryPad"
	pad.position = Vector3(0.0, 0.06, 30.0)
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.5
	pad_mesh.bottom_radius = 2.5
	pad_mesh.height = 0.12
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.material_override = mastery_material
	environment_root.add_child(pad)


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
		"Bubble mastery recorded: erase one hit, then spend the impact as space-making force."
	)


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	armed_activation_id = -1
	fired_activation_id = -1
	arming_remaining = impact_arming_seconds
	scheduler_accumulator = 0.0
	set_process(stage in [TrialStage.ONE_HIT, TrialStage.REBOUND])
	if rebound_target != null:
		rebound_target.set_physics_process(stage == TrialStage.REBOUND)
	match stage:
		TrialStage.ONE_HIT:
			GameState.set_objective(
				"Stand inside the first blue mark, cast Bubble, and let the pressure pulse strike it."
			)
		TrialStage.REBOUND:
			GameState.set_objective(
				"Stand in the second mark and cast Bubble. Use its burst to drive the Rebound Target beyond the outer ring."
			)
		TrialStage.MASTERY:
			GameState.set_objective(
				"Pass through the opened gate and enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			GameState.set_objective(
				"Bubble Breakwater Spell Trial complete."
			)


func _equip_bubble() -> void:
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
		if ability != null and ability.get_spell_id() == "bubble":
			caster.call("select_ability", index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	GameState.set_flag(completion_flag, false)
	if bubble_controller != null:
		bubble_controller.reset_target()
	if defense_controller != null and defense_controller.has_method(
		"reset_defense"
	):
		defense_controller.call("reset_defense")
	if rebound_target != null:
		rebound_target.reset_target()
		rebound_target.global_position = rebound_target_origin
		rebound_target.set_physics_process(false)
	if impact_gate != null:
		impact_gate.reset_target()
	if rebound_gate != null:
		rebound_gate.reset_target()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	impact_completions = 0
	rebound_completions = 0
	mastery_entries = 0
	last_defense_result.clear()
	_set_stage(TrialStage.ONE_HIT)
	call_deferred("_equip_bubble")
	trial_reset.emit()
	_show_message("Bubble Breakwater trial reset.")


func _create_trigger_mark(
	node_name: String,
	position_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	ring.position = position_value + Vector3.UP * 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visibility_range_end = 36.0
	ring.visibility_range_end_margin = 4.0
	var mesh := TorusMesh.new()
	mesh.inner_radius = trigger_radius - 0.07
	mesh.outer_radius = trigger_radius + 0.07
	mesh.rings = 36
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.material_override = material
	environment_root.add_child(ring)
	return ring


func _create_emitter_visual(
	parent_node: Node3D,
	material: Material
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = "PressureEmitterVisual"
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 0.52
	mesh.height = 1.04
	mesh.radial_segments = 16
	mesh.rings = 8
	visual.mesh = mesh
	visual.material_override = material
	parent_node.add_child(visual)
	return visual


func _set_emitter_charge(
	visual: MeshInstance3D,
	ratio: float
) -> void:
	if visual == null:
		return
	var resolved: float = clampf(ratio, 0.0, 1.0)
	visual.scale = Vector3.ONE * lerpf(1.0, 1.35, resolved)
	visual.transparency = lerpf(0.28, 0.0, resolved)


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
	var material := _make_material(albedo, 0.2, 0.42)
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
	var rebound_offset: float = 0.0
	if rebound_target != null:
		var offset: Vector3 = rebound_target.global_position - SECOND_CENTER
		offset.y = 0.0
		rebound_offset = offset.length()
	return {
		"bubble_breakwater_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"bubble_active": (
			bubble_controller.is_bubble_active()
			if bubble_controller != null
			else false
		),
		"impact_gate_open": impact_gate.active if impact_gate != null else false,
		"rebound_gate_open": rebound_gate.active if rebound_gate != null else false,
		"rebound_distance": snappedf(rebound_offset, 0.01),
		"impact_completions": impact_completions,
		"rebound_completions": rebound_completions,
		"mastery_entries": mastery_entries,
		"last_defense_result": last_defense_result.duplicate(true),
		"scheduler_hz": scheduler_updates_per_second,
		"processing": is_processing(),
	}
