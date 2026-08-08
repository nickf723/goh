extends Node3D
class_name PrototypeDuplicateSpellTrial

signal divergence_completed
signal double_strike_completed
signal mirrored_magic_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload("res://scenes/mechanisms/mechanism_sliding_gate.tscn")
const PlateScene: PackedScene = preload("res://scenes/mechanisms/pressure_plate_switch.tscn")
const TargetScript = preload("res://scripts/levels/soul_duplicate_trial_target.gd")

enum TrialStage { DIVERGENCE, DOUBLE_STRIKE, MIRRORED_MAGIC, MASTERY, COMPLETE }

@export var completion_flag: String = "hall_of_two_souls_duplicate_trial_complete"
@export_range(0.02, 0.5, 0.01) var evaluation_interval: float = 0.08
@export var lane_offset_x: float = 1.7

var player: CharacterBody3D = null
var initial_player_transform: Transform3D
var environment_root: Node3D = null
var actors_root: Node3D = null
var stage: TrialStage = TrialStage.DIVERGENCE
var evaluation_remaining: float = 0.0
var trial_complete: bool = false
var reliable_gate_open_count: int = 0

var grace_plate: PressurePlateSwitch = null
var soul_plate: PressurePlateSwitch = null
var divergence_gate: MechanismSlidingGate = null
var strike_gate: MechanismSlidingGate = null
var magic_gate: MechanismSlidingGate = null
var grace_strike_target: SoulDuplicateTrialTarget = null
var soul_strike_target: SoulDuplicateTrialTarget = null
var grace_magic_target: SoulDuplicateTrialTarget = null
var soul_magic_target: SoulDuplicateTrialTarget = null
var mastery_area: Area3D = null

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var soul_material: StandardMaterial3D
var grace_material: StandardMaterial3D
var gold_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("hall_of_two_souls_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_divergence_stage()
	_build_double_strike_stage()
	_build_magic_stage()
	_build_mastery_stage()
	_restore_resources()
	_set_stage(TrialStage.DIVERGENCE)
	call_deferred("_equip_duplicate")
	set_process(true)
	_show_message("Hall of Two Souls: cast Duplicate. Two bodies receive one intent, but the world resolves each body independently.")


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
		TrialStage.DIVERGENCE:
			return _evaluate_divergence()
		TrialStage.DOUBLE_STRIKE:
			return _evaluate_double_strike()
		TrialStage.MIRRORED_MAGIC:
			return _evaluate_magic()
	return false


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "HallOfTwoSoulsEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "HallOfTwoSoulsActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _mat(Color(0.035, 0.065, 0.085), 0.15, 0.8)
	wall_material = _mat(Color(0.025, 0.035, 0.055), 0.35, 0.62)
	grace_material = _emissive(Color(0.16, 0.58, 0.86, 0.9), Color(0.2, 0.7, 1.0), 2.2)
	soul_material = _emissive(Color(0.16, 0.82, 0.9, 0.88), Color(0.25, 1.0, 1.0), 2.8)
	gold_material = _emissive(Color(0.72, 0.5, 0.08, 0.95), Color(1.0, 0.78, 0.15), 3.5)


func _build_environment() -> void:
	_box("Floor", Vector3(0, -0.5, 23), Vector3(16, 1, 62), floor_material)
	_box("LeftWall", Vector3(-8.5, 2.5, 23), Vector3(1, 6, 62), wall_material)
	_box("RightWall", Vector3(8.5, 2.5, 23), Vector3(1, 6, 62), wall_material)
	_box("BackWall", Vector3(0, 2.5, -8), Vector3(16, 6, 1), wall_material)
	_box("FrontWall", Vector3(0, 2.5, 54), Vector3(16, 6, 1), wall_material)
	_label("THE HALL OF TWO SOULS", Vector3(0, 5, -5.5), Color(0.5, 0.94, 1.0), 34)
	_label("One intent. Two bodies. Two outcomes.", Vector3(0, 4, -3.2), Color(0.7, 0.88, 0.96), 20)


func _build_divergence_stage() -> void:
	_label("I • DIVERGENCE", Vector3(0, 4.0, 1.0), Color(0.52, 0.92, 1.0), 26)
	# Two narrow lanes preserve the initial side-by-side spawn. Holding Forward
	# carries Grace and Soul Grace onto separate switches without teleporting them.
	_box("LaneDivider", Vector3(lane_offset_x * 0.5, 1.0, 5.5), Vector3(0.38, 2.0, 9.0), wall_material)
	grace_plate = _plate("GracePlate", Vector3(0.0, 0.0, 7.8), "Grace Switch")
	soul_plate = _plate("SoulPlate", Vector3(lane_offset_x, 0.0, 7.8), "Soul Switch")
	_marker("GraceLane", Vector3(0, 0.06, 5.2), Vector3(1.35, 0.12, 6.5), grace_material)
	_marker("SoulLane", Vector3(lane_offset_x, 0.06, 5.2), Vector3(1.35, 0.12, 6.5), soul_material)
	divergence_gate = _gate("DivergenceGate", Vector3(lane_offset_x * 0.5, 0, 11.0), "Divergence Gate")
	_label("HOLD BOTH SWITCHES AT ONCE", Vector3(lane_offset_x * 0.5, 3.0, 8.0), Color(0.75, 0.95, 1.0), 17)


func _build_double_strike_stage() -> void:
	_label("II • DOUBLE STRIKE", Vector3(0, 4.0, 15.0), Color(0.52, 0.92, 1.0), 26)
	grace_strike_target = _target("GraceStrikeTarget", Vector3(0.0, 1.0, 20.0), grace_material)
	soul_strike_target = _target("SoulStrikeTarget", Vector3(lane_offset_x, 1.0, 20.0), soul_material)
	_marker("StrikeGraceMark", Vector3(0, 0.06, 17.6), Vector3(1.2, 0.12, 1.1), grace_material)
	_marker("StrikeSoulMark", Vector3(lane_offset_x, 0.06, 17.6), Vector3(1.2, 0.12, 1.1), soul_material)
	strike_gate = _gate("StrikeGate", Vector3(lane_offset_x * 0.5, 0, 23.3), "Double Strike Gate")
	_label("ONE ATTACK INPUT • TWO TARGETS", Vector3(lane_offset_x * 0.5, 3.0, 20.0), Color(0.75, 0.95, 1.0), 17)


func _build_magic_stage() -> void:
	_label("III • MIRRORED MAGIC", Vector3(0, 4.0, 28.0), Color(0.52, 0.92, 1.0), 26)
	grace_magic_target = _target("GraceMagicTarget", Vector3(0.0, 1.0, 36.0), grace_material)
	soul_magic_target = _target("SoulMagicTarget", Vector3(lane_offset_x, 1.0, 36.0), soul_material)
	_marker("MagicGraceMark", Vector3(0, 0.06, 30.5), Vector3(1.2, 0.12, 1.1), grace_material)
	_marker("MagicSoulMark", Vector3(lane_offset_x, 0.06, 30.5), Vector3(1.2, 0.12, 1.1), soul_material)
	magic_gate = _gate("MagicGate", Vector3(lane_offset_x * 0.5, 0, 40.0), "Mirrored Magic Gate")
	_label("CAST ONE PROJECTILE • CREATE TWO LIVE SHOTS", Vector3(lane_offset_x * 0.5, 3.0, 35.2), Color(0.75, 0.95, 1.0), 17)


func _build_mastery_stage() -> void:
	mastery_area = _trigger("MasteryArea", Vector3(lane_offset_x * 0.5, 1.0, 47.0), Vector3(6.0, 2.5, 4.0))
	mastery_area.body_entered.connect(_on_mastery_entered)
	_marker("MasterySeal", Vector3(lane_offset_x * 0.5, 0.06, 47.0), Vector3(5.0, 0.14, 3.0), gold_material)
	_label("DIVIDE • ACT • CONVERGE", Vector3(lane_offset_x * 0.5, 3.8, 48.5), Color(1.0, 0.84, 0.3), 25)


func _evaluate_divergence() -> bool:
	if grace_plate == null or soul_plate == null:
		return false
	if not grace_plate.is_pressed or not soul_plate.is_pressed:
		return false
	_open_gate(divergence_gate, "two_bodies_two_switches")
	_set_stage(TrialStage.DOUBLE_STRIKE)
	divergence_completed.emit()
	_show_message("Divergence confirmed. The two bodies occupy independent collision lanes while sharing one movement intent.")
	return true


func _evaluate_double_strike() -> bool:
	if grace_strike_target == null or soul_strike_target == null:
		return false
	# One target must have a normal Grace hit and the other a Soul-tagged hit.
	var grace_side_ok: bool = grace_strike_target.grace_hit_count > 0 or soul_strike_target.grace_hit_count > 0
	var soul_side_ok: bool = grace_strike_target.duplicate_hit_count > 0 or soul_strike_target.duplicate_hit_count > 0
	if not grace_side_ok or not soul_side_ok:
		return false
	_open_gate(strike_gate, "parallel_weapon_attack")
	_set_stage(TrialStage.MIRRORED_MAGIC)
	double_strike_completed.emit()
	_show_message("Double Strike confirmed. Select Firebolt and send two independent projectiles down the paired lanes.")
	call_deferred("_equip_spell", "firebolt")
	return true


func _evaluate_magic() -> bool:
	if grace_magic_target == null or soul_magic_target == null:
		return false
	var grace_hit: bool = grace_magic_target.hit_count > 0
	var soul_hit: bool = soul_magic_target.hit_count > 0
	if not grace_hit or not soul_hit:
		return false
	_open_gate(magic_gate, "two_live_spell_outcomes")
	_set_stage(TrialStage.MASTERY)
	mirrored_magic_completed.emit()
	_show_message("Mirrored Magic confirmed. Both shots existed in the same present and resolved their own collisions.")
	return true


func _on_mastery_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Duplicate mastered: DIVIDE • ACT • CONVERGE.")


func _open_gate(gate: MechanismSlidingGate, reason: String) -> void:
	if gate == null:
		return
	reliable_gate_open_count += 1
	gate.set_gate_open(true, false, {"reason": reason, "reliable_retry": true})
	call_deferred("_verify_gate", gate, reason)


func _verify_gate(gate: MechanismSlidingGate, reason: String) -> void:
	if gate != null and is_instance_valid(gate) and not gate.is_mechanism_active():
		gate.set_gate_open(true, true, {"reason": reason + "_forced", "reliable_retry": true})


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.DIVERGENCE:
			_objective("Duplicate: hold both paired switches at the same time.")
		TrialStage.DOUBLE_STRIKE:
			_objective("Duplicate: position both bodies and strike two targets with one attack input.")
		TrialStage.MIRRORED_MAGIC:
			_objective("Duplicate: cast Firebolt once and let both live projectiles hit their lanes.")
		TrialStage.MASTERY:
			_objective("Duplicate: enter the gold mastery seal.")
		TrialStage.COMPLETE:
			_objective("Hall of Two Souls complete: DIVIDE • ACT • CONVERGE.")


func reset_trial() -> void:
	trial_complete = false
	reliable_gate_open_count = 0
	evaluation_remaining = 0.0
	GameState.set_flag(completion_flag, false)
	for target: SoulDuplicateTrialTarget in [grace_strike_target, soul_strike_target, grace_magic_target, soul_magic_target]:
		if target != null:
			target.reset_target()
	for gate: MechanismSlidingGate in [divergence_gate, strike_gate, magic_gate]:
		if gate != null:
			gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if grace_plate != null:
		grace_plate.reset_target()
	if soul_plate != null:
		soul_plate.reset_target()
	for controller: Node in get_tree().get_nodes_in_group("soul_duplicate_controller"):
		controller.queue_free()
	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	if manager != null and manager.has_method("deactivate_effect_by_id"):
		manager.call("deactivate_effect_by_id", "duplicate_concentration", false)
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	_restore_resources()
	_set_stage(TrialStage.DIVERGENCE)
	call_deferred("_equip_duplicate")
	trial_reset.emit()


func _equip_duplicate() -> void:
	_equip_spell("duplicate")


func _equip_spell(spell_id: String) -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null:
		return
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
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


func _plate(node_name: String, position_value: Vector3, display: String) -> PressurePlateSwitch:
	var plate: PressurePlateSwitch = PlateScene.instantiate() as PressurePlateSwitch
	plate.name = node_name
	plate.position = position_value
	plate.display_name = display
	plate.accept_any_physics_body = true
	plate.minimum_mass_kg = 1.0
	actors_root.add_child(plate)
	return plate


func _gate(node_name: String, position_value: Vector3, display: String) -> MechanismSlidingGate:
	var gate: MechanismSlidingGate = GateScene.instantiate() as MechanismSlidingGate
	gate.name = node_name
	gate.position = position_value
	gate.display_name = display
	gate.open_offset = Vector3(0, 4.5, 0)
	actors_root.add_child(gate)
	var label: Label3D = gate.get_node_or_null("StateLabel") as Label3D
	if label != null:
		label.visible = false
	return gate


func _target(node_name: String, position_value: Vector3, material: Material) -> SoulDuplicateTrialTarget:
	var target: SoulDuplicateTrialTarget = TargetScript.new() as SoulDuplicateTrialTarget
	target.name = node_name
	target.position = position_value
	target.collision_layer = 1
	target.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.8
	collision.shape = shape
	target.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.8
	visual.mesh = mesh
	visual.material_override = material
	target.add_child(visual)
	actors_root.add_child(target)
	return target


func _trigger(node_name: String, position_value: Vector3, size_value: Vector3) -> Area3D:
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


func _box(node_name: String, position_value: Vector3, size_value: Vector3, material: Material) -> StaticBody3D:
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


func _marker(node_name: String, position_value: Vector3, size_value: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	environment_root.add_child(visual)


func _label(text_value: String, position_value: Vector3, color: Color, size: int) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	environment_root.add_child(label)


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _emissive(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _mat(color, 0.2, 0.42)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _objective(text_value: String) -> void:
	if GameState.has_method("set_objective"):
		GameState.call("set_objective", text_value)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text_value)


func _show_message(text_value: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)
	else:
		print(text_value)


func get_debug_data() -> Dictionary:
	return {
		"duplicate_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"complete": trial_complete,
		"reliable_gate_opens": reliable_gate_open_count,
		"grace_plate": grace_plate.is_pressed if grace_plate != null else false,
		"soul_plate": soul_plate.is_pressed if soul_plate != null else false,
		"duplicate_count": get_tree().get_node_count_in_group("soul_duplicates"),
		"completion_flag": GameState.get_flag(completion_flag),
	}
