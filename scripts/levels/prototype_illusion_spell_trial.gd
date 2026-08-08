extends Node3D
class_name PrototypeIllusionSpellTrial

signal attention_completed
signal misdirection_completed
signal false_target_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const PlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)
const GuardScript = preload(
	"res://scripts/levels/illusion_perception_guard.gd"
)

enum TrialStage {
	ATTENTION,
	MISDIRECTION,
	FALSE_TARGET,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = "hall_of_false_faces_illusion_trial_complete"
@export_range(0.02, 0.5, 0.01) var evaluation_interval: float = 0.08
@export_range(1.0, 8.0, 0.1) var attention_displacement_required: float = 2.6
@export_range(0.5, 5.0, 0.1) var misdirection_zone_radius: float = 1.8

var player: CharacterBody3D = null
var initial_player_transform: Transform3D
var environment_root: Node3D = null
var actors_root: Node3D = null
var stage: TrialStage = TrialStage.ATTENTION
var evaluation_remaining: float = 0.0
var trial_complete: bool = false
var reliable_gate_open_count: int = 0
var last_gate_reason: String = "none"

var attention_guard: IllusionPerceptionGuard = null
var misdirection_guard: IllusionPerceptionGuard = null
var attack_guard: IllusionPerceptionGuard = null
var attention_guard_start: Vector3 = Vector3.ZERO
var attention_plate: PressurePlateSwitch = null
var attention_gate: MechanismSlidingGate = null
var misdirection_gate: MechanismSlidingGate = null
var attack_gate: MechanismSlidingGate = null
var misdirection_zone: Area3D = null
var misdirection_zone_position: Vector3 = Vector3(5.1, 1.0, 23.8)
var mastery_area: Area3D = null
var attack_baseline: int = 0

var floor_material: StandardMaterial3D = null
var wall_material: StandardMaterial3D = null
var dream_material: StandardMaterial3D = null
var danger_material: StandardMaterial3D = null
var gold_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("hall_of_false_faces_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
		player.set_meta("perception_target_kind", "grace")
	_build_roots()
	_build_materials()
	_build_environment()
	_build_attention_room()
	_build_misdirection_room()
	_build_false_target_room()
	_build_mastery_room()
	_restore_resources()
	_set_stage(TrialStage.ATTENTION)
	call_deferred("_equip_spell", "illusion")
	set_process(true)
	_show_message(
		"Hall of False Faces: place a false Grace where the sentry can see her. Perception can be fooled even when physics cannot."
	)


func _process(delta: float) -> void:
	evaluation_remaining -= maxf(delta, 0.0)
	if evaluation_remaining > 0.0:
		return
	evaluation_remaining = maxf(evaluation_interval, 0.02)
	evaluate_progression_now()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func evaluate_progression_now() -> bool:
	match stage:
		TrialStage.ATTENTION:
			return _evaluate_attention()
		TrialStage.MISDIRECTION:
			return _evaluate_misdirection()
		TrialStage.FALSE_TARGET:
			return _evaluate_false_target()
	return false


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "FalseFacesEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "FalseFacesActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(Color(0.035, 0.03, 0.08), 0.15, 0.78)
	wall_material = _make_material(Color(0.055, 0.045, 0.12), 0.28, 0.62)
	dream_material = _make_emissive(
		Color(0.2, 0.12, 0.56, 0.86),
		Color(0.34, 0.2, 1.0),
		2.7
	)
	danger_material = _make_emissive(
		Color(0.42, 0.09, 0.3, 0.88),
		Color(0.9, 0.12, 0.62),
		2.4
	)
	gold_material = _make_emissive(
		Color(0.7, 0.5, 0.08, 0.94),
		Color(1.0, 0.8, 0.18),
		3.5
	)


func _build_environment() -> void:
	_create_static_box(
		"Floor",
		Vector3(0.0, -0.5, 22.0),
		Vector3(16.0, 1.0, 62.0),
		floor_material
	)
	_create_static_box("LeftWall", Vector3(-8.5, 2.5, 22.0), Vector3(1.0, 6.0, 62.0), wall_material)
	_create_static_box("RightWall", Vector3(8.5, 2.5, 22.0), Vector3(1.0, 6.0, 62.0), wall_material)
	_create_static_box("BackWall", Vector3(0.0, 2.5, -9.0), Vector3(16.0, 6.0, 1.0), wall_material)
	_create_static_box("FrontWall", Vector3(0.0, 2.5, 53.0), Vector3(16.0, 6.0, 1.0), wall_material)
	_create_label("THE HALL OF FALSE FACES", Vector3(0.0, 5.0, -5.8), Color(0.68, 0.56, 1.0), 34)
	_create_label("Perception is a targetable surface.", Vector3(0.0, 4.0, -3.3), Color(0.78, 0.72, 1.0), 19)


func _build_attention_room() -> void:
	_create_label("I • ATTENTION", Vector3(0.0, 4.0, 0.8), Color(0.65, 0.5, 1.0), 26)
	attention_plate = PlateScene.instantiate() as PressurePlateSwitch
	attention_plate.name = "AttentionPlate"
	attention_plate.position = Vector3(0.0, 0.0, 5.0)
	attention_plate.display_name = "Sentry Attention Plate"
	attention_plate.accept_any_physics_body = true
	attention_plate.minimum_mass_kg = 1.0
	actors_root.add_child(attention_plate)
	attention_guard = _spawn_guard("AttentionSentry", Vector3(0.0, 0.92, 5.0), true)
	attention_guard_start = attention_guard.global_position
	_create_marker("AttentionDecoyHint", Vector3(4.2, 0.06, 5.0), Vector3(2.2, 0.12, 2.2), dream_material)
	_create_label("PLACE THE FALSE GRACE AWAY FROM THE PLATE", Vector3(0.0, 3.0, 5.0), Color(0.82, 0.76, 1.0), 16)
	attention_gate = _spawn_gate("AttentionGate", "Attention Gate", Vector3(0.0, 0.0, 11.0))


func _build_misdirection_room() -> void:
	_create_label("II • MISDIRECTION", Vector3(0.0, 4.0, 15.0), Color(0.65, 0.5, 1.0), 26)
	misdirection_guard = _spawn_guard("MisdirectionSentry", Vector3(0.0, 0.92, 20.0), false)
	misdirection_zone = _create_trigger(
		"MisdirectionZone",
		misdirection_zone_position,
		Vector3(3.4, 2.6, 3.4)
	)
	_create_marker("MisdirectionMark", Vector3(5.1, 0.06, 23.8), Vector3(2.8, 0.12, 2.8), dream_material)
	_create_static_box("MisdirectionDivider", Vector3(2.55, 1.0, 24.0), Vector3(0.45, 2.0, 7.0), wall_material)
	_create_label("LURE THE SENTRY INTO THE SIDE ALCOVE", Vector3(0.0, 3.0, 21.5), Color(0.82, 0.76, 1.0), 16)
	misdirection_gate = _spawn_gate("MisdirectionGate", "Misdirection Gate", Vector3(0.0, 0.0, 29.0))


func _build_false_target_room() -> void:
	_create_label("III • FALSE TARGET", Vector3(0.0, 4.0, 33.0), Color(0.65, 0.5, 1.0), 26)
	attack_guard = _spawn_guard("AttackSentry", Vector3(0.0, 0.92, 36.0), false)
	_create_marker("AttackDecoyMark", Vector3(0.0, 0.06, 40.0), Vector3(2.6, 0.12, 2.6), danger_material)
	_create_label("LET THE SENTRY ATTACK WHAT ISN'T THERE", Vector3(0.0, 3.0, 38.0), Color(0.9, 0.66, 1.0), 16)
	attack_gate = _spawn_gate("FalseTargetGate", "False Target Gate", Vector3(0.0, 0.0, 45.0))


func _build_mastery_room() -> void:
	mastery_area = _create_trigger("MasteryArea", Vector3(0.0, 1.0, 50.0), Vector3(6.0, 2.5, 4.0))
	mastery_area.body_entered.connect(_on_mastery_entered)
	_create_marker("MasterySeal", Vector3(0.0, 0.06, 50.0), Vector3(5.0, 0.14, 3.0), gold_material)
	_create_label("PERCEIVE • DECEIVE • REDIRECT", Vector3(0.0, 3.8, 51.0), Color(1.0, 0.85, 0.3), 24)


func _evaluate_attention() -> bool:
	if attention_guard == null:
		return false
	var debug: Dictionary = attention_guard.get_debug_data()
	if str(debug.get("target_kind", "none")) != "illusion":
		return false
	if attention_guard.global_position.distance_to(attention_guard_start) < attention_displacement_required:
		return false
	_open_gate_reliably(attention_gate, "illusion_redirected_attention")
	_set_stage(TrialStage.MISDIRECTION)
	attention_completed.emit()
	_show_message("Attention redirected. The sentry abandoned real weight to pursue a perceived actor.")
	return true


func _evaluate_misdirection() -> bool:
	if misdirection_guard == null:
		return false
	var debug: Dictionary = misdirection_guard.get_debug_data()
	if str(debug.get("target_kind", "none")) != "illusion":
		return false
	if misdirection_guard.global_position.distance_to(misdirection_zone_position) > misdirection_zone_radius:
		return false
	_open_gate_reliably(misdirection_gate, "illusion_lured_side_route")
	_set_stage(TrialStage.FALSE_TARGET)
	misdirection_completed.emit()
	_show_message("Misdirection confirmed. The same world contains Grace, but the sentry chooses the more salient false target.")
	return true


func _evaluate_false_target() -> bool:
	if attack_guard == null:
		return false
	if attack_guard.illusion_attack_count <= attack_baseline:
		return false
	var illusion: Node = get_tree().get_first_node_in_group("illusion_decoys")
	if illusion == null or not is_instance_valid(illusion):
		return false
	var illusion_debug: Dictionary = (
		illusion.call("get_debug_data") as Dictionary
		if illusion.has_method("get_debug_data")
		else {}
	)
	if int(illusion_debug.get("attacks_received", 0)) <= 0:
		return false
	_open_gate_reliably(attack_gate, "illusion_absorbed_false_attack")
	_set_stage(TrialStage.MASTERY)
	false_target_completed.emit()
	_show_message("False Target confirmed. The sentry attacked a target with zero authenticity and zero combat authority.")
	return true


func _on_mastery_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Illusion mastered: PERCEIVE • DECEIVE • REDIRECT.")


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	if attention_guard != null:
		attention_guard.set_training_enabled(stage == TrialStage.ATTENTION)
	if misdirection_guard != null:
		misdirection_guard.set_training_enabled(stage == TrialStage.MISDIRECTION)
	if attack_guard != null:
		attack_guard.set_training_enabled(stage == TrialStage.FALSE_TARGET)
	if stage == TrialStage.FALSE_TARGET and attack_guard != null:
		attack_baseline = attack_guard.illusion_attack_count
	match stage:
		TrialStage.ATTENTION:
			_set_objective("Illusion: lure the first sentry away from its pressure plate.")
		TrialStage.MISDIRECTION:
			_set_objective("Illusion: lure the second sentry into the marked side alcove.")
		TrialStage.FALSE_TARGET:
			_set_objective("Illusion: place a phantom on the violet mark and let the sentry attack it.")
		TrialStage.MASTERY:
			_set_objective("Illusion: enter the gold mastery seal.")
		TrialStage.COMPLETE:
			_set_objective("Hall of False Faces complete: PERCEIVE • DECEIVE • REDIRECT.")


func _spawn_guard(
	node_name: String,
	position_value: Vector3,
	enabled: bool
) -> IllusionPerceptionGuard:
	var guard := GuardScript.new() as IllusionPerceptionGuard
	guard.name = node_name
	guard.position = position_value
	guard.training_enabled = enabled
	actors_root.add_child(guard)
	guard.set_canonical_target(player)
	return guard


func _spawn_gate(
	node_name: String,
	display_name_value: String,
	position_value: Vector3
) -> MechanismSlidingGate:
	var gate := GateScene.instantiate() as MechanismSlidingGate
	gate.name = node_name
	gate.position = position_value
	gate.display_name = display_name_value
	gate.open_offset = Vector3(0.0, 4.5, 0.0)
	gate.transition_seconds = 0.42
	actors_root.add_child(gate)
	var label: Label3D = gate.get_node_or_null("StateLabel") as Label3D
	if label != null:
		label.visible = false
	_create_static_box(node_name + "LeftDivider", Vector3(-4.8, 2.2, position_value.z), Vector3(5.1, 5.3, 0.8), wall_material)
	_create_static_box(node_name + "RightDivider", Vector3(4.8, 2.2, position_value.z), Vector3(5.1, 5.3, 0.8), wall_material)
	return gate


func _open_gate_reliably(gate: MechanismSlidingGate, reason: String) -> void:
	if gate == null:
		return
	reliable_gate_open_count += 1
	last_gate_reason = reason
	gate.set_gate_open(true, false, {"reason": reason, "reliable_retry": true})
	call_deferred("_verify_gate_open", gate, reason)


func _verify_gate_open(gate: MechanismSlidingGate, reason: String) -> void:
	if gate == null or not is_instance_valid(gate):
		return
	if not gate.is_mechanism_active():
		gate.set_gate_open(true, true, {"reason": reason + "_forced", "reliable_retry": true})


func reset_trial() -> void:
	trial_complete = false
	reliable_gate_open_count = 0
	last_gate_reason = "none"
	evaluation_remaining = 0.0
	attack_baseline = 0
	GameState.set_flag(completion_flag, false)
	for illusion: Node in get_tree().get_nodes_in_group("illusion_decoys"):
		if illusion != null and is_instance_valid(illusion):
			if illusion.has_method("expire_illusion"):
				illusion.call("expire_illusion", "trial_reset")
			else:
				illusion.queue_free()
	for guard: IllusionPerceptionGuard in [attention_guard, misdirection_guard, attack_guard]:
		if guard != null:
			guard.reset_target()
	if attention_plate != null:
		attention_plate.reset_target()
	for gate: MechanismSlidingGate in [attention_gate, misdirection_gate, attack_gate]:
		if gate != null:
			gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	_restore_resources()
	_set_stage(TrialStage.ATTENTION)
	call_deferred("_equip_spell", "illusion")
	trial_reset.emit()


func _equip_spell(spell_id: String) -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null:
		return
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout := loadout_value as AbilityLoadout
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			caster.call("select_ability", index, false)
			return


func _restore_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _create_trigger(
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
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
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


func _create_marker(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	environment_root.add_child(visual)


func _create_label(text_value: String, position_value: Vector3, color: Color, font_size_value: int) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = font_size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	environment_root.add_child(label)


func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material


func _make_emissive(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color, 0.2, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _set_objective(text_value: String) -> void:
	if GameState.has_method("set_objective"):
		GameState.call("set_objective", text_value)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text_value)
	elif ui != null and ui.has_method("set_objective_text"):
		ui.call("set_objective_text", text_value)


func _show_message(text_value: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)
	else:
		print(text_value)


func get_debug_data() -> Dictionary:
	return {
		"illusion_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"complete": trial_complete,
		"reliable_gate_opens": reliable_gate_open_count,
		"last_gate_reason": last_gate_reason,
		"active_illusions": get_tree().get_node_count_in_group("illusion_decoys"),
		"attention_guard": attention_guard.get_debug_data() if attention_guard != null else {},
		"misdirection_guard": misdirection_guard.get_debug_data() if misdirection_guard != null else {},
		"attack_guard": attack_guard.get_debug_data() if attack_guard != null else {},
		"completion_flag": GameState.get_flag(completion_flag),
	}
