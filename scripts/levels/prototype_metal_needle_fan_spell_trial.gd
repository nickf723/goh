extends Node3D
class_name PrototypeMetalNeedleFanSpellTrial

signal fan_stage_completed(cast_serial: int)
signal close_stage_completed(cast_serial: int, hit_count: int)
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const HitReceiverScript = preload(
	"res://scripts/combat/hit_receiver.gd"
)

enum TrialStage {
	THE_BROAD_FAN,
	THE_CLOSE_PRESS,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = (
	"needle_loom_metal_needle_trial_complete"
)
@export_range(0.03, 0.5, 0.01) var evaluation_interval: float = 0.08
@export_range(2, 9, 1) var required_close_hits: int = 3
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Metal Needle volleys."
)

var environment_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D
var initial_player_transform: Transform3D

var fan_targets: Array[CharacterBody3D] = []
var initial_fan_target_transforms: Array[Transform3D] = []
var close_target: CharacterBody3D
var initial_close_target_transform: Transform3D
var fan_gate: MechanismSlidingGate
var close_gate: MechanismSlidingGate
var mastery_area: Area3D

var stage: TrialStage = TrialStage.THE_BROAD_FAN
var trial_complete: bool = false
var evaluation_remaining: float = 0.0
var fan_completion_count: int = 0
var close_completion_count: int = 0
var fan_success_serial: int = 0
var close_success_serial: int = 0
var close_serial_baseline: int = 0
var close_success_hits: int = 0

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var metal_material: StandardMaterial3D
var target_material: StandardMaterial3D
var gold_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("needle_loom_spell_trial")
	add_to_group("metal_needle_fan_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_broad_fan_stage()
	_build_close_press_stage()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.THE_BROAD_FAN)
	set_process(true)
	_show_message(
		"The Needle Loom: spread one volley across every fan target, then crowd the needles into one close mark. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_metal_needle")


func _process(delta: float) -> void:
	evaluation_remaining -= maxf(delta, 0.0)
	if evaluation_remaining > 0.0:
		return
	evaluation_remaining = maxf(evaluation_interval, 0.03)
	match stage:
		TrialStage.THE_BROAD_FAN:
			_evaluate_broad_fan()
		TrialStage.THE_CLOSE_PRESS:
			_evaluate_close_press()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "NeedleLoomEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "NeedleLoomActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(Color(0.055, 0.06, 0.07), 0.52, 0.48)
	wall_material = _make_material(Color(0.025, 0.03, 0.04), 0.72, 0.34)
	metal_material = _make_emissive_material(
		Color(0.56, 0.4, 0.06, 0.94),
		Color(1.0, 0.64, 0.04),
		2.8
	)
	target_material = _make_emissive_material(
		Color(0.34, 0.3, 0.16, 0.96),
		Color(0.92, 0.7, 0.16),
		1.55
	)
	gold_material = _make_emissive_material(
		Color(0.7, 0.48, 0.06, 0.95),
		Color(1.0, 0.78, 0.12),
		3.7
	)


func _build_environment() -> void:
	_create_static_box(
		"NeedleLoomFloor",
		Vector3(0.0, -0.5, 11.0),
		Vector3(16.0, 1.0, 40.0),
		floor_material
	)
	_create_static_box(
		"NeedleLoomLeftWall",
		Vector3(-8.5, 3.0, 11.0),
		Vector3(1.0, 7.0, 40.0),
		wall_material
	)
	_create_static_box(
		"NeedleLoomRightWall",
		Vector3(8.5, 3.0, 11.0),
		Vector3(1.0, 7.0, 40.0),
		wall_material
	)
	_create_static_box(
		"NeedleLoomBackWall",
		Vector3(0.0, 3.0, -9.0),
		Vector3(16.0, 7.0, 1.0),
		wall_material
	)
	_create_static_box(
		"NeedleLoomFrontWall",
		Vector3(0.0, 3.0, 31.0),
		Vector3(16.0, 7.0, 1.0),
		wall_material
	)

	_create_label(
		"THE NEEDLE LOOM",
		Vector3(0.0, 5.2, -5.8),
		Color(1.0, 0.78, 0.22),
		34
	)
	_create_label(
		"Distance separates the fan. Proximity braids it together.",
		Vector3(0.0, 4.1, -3.1),
		Color(0.88, 0.78, 0.48),
		19
	)
	_create_label(
		"I • THE BROAD FAN",
		Vector3(0.0, 4.2, -0.4),
		Color(1.0, 0.72, 0.14),
		27
	)
	_create_label(
		"II • THE CLOSE PRESS",
		Vector3(0.0, 4.2, 12.0),
		Color(1.0, 0.72, 0.14),
		27
	)

	_create_visual_box(
		"BroadFanCastingMark",
		Vector3(0.0, 0.06, -4.5),
		Vector3(3.0, 0.1, 1.4),
		metal_material
	)
	_create_visual_box(
		"ClosePressCastingMark",
		Vector3(0.0, 0.06, 12.5),
		Vector3(3.0, 0.1, 1.4),
		metal_material
	)


func _build_broad_fan_stage() -> void:
	var target_distance: float = 8.0
	var center_z: float = -4.5
	var angles: Array[float] = [-27.0, -13.5, 0.0, 13.5, 27.0]
	for target_index: int in range(angles.size()):
		var angle_radians: float = deg_to_rad(angles[target_index])
		var position_value := Vector3(
			tan(angle_radians) * target_distance,
			1.0,
			center_z + target_distance
		)
		var target: CharacterBody3D = _create_needle_target(
			"FanTarget" + str(target_index + 1),
			"Fan Mark " + str(target_index + 1),
			position_value,
			0.72
		)
		fan_targets.append(target)
		initial_fan_target_transforms.append(target.transform)

	_create_label(
		"ONE VOLLEY • FIVE MARKS • AIM THROUGH THE CENTER",
		Vector3(0.0, 3.1, 5.3),
		Color(0.96, 0.84, 0.48),
		17
	)
	fan_gate = _spawn_gate_with_dividers(
		"BroadFanGate",
		"Broad Fan Gate",
		Vector3(0.0, 0.0, 8.5)
	)


func _build_close_press_stage() -> void:
	close_target = _create_needle_target(
		"ClosePressTarget",
		"Close Press",
		Vector3(0.0, 1.0, 15.4),
		1.08
	)
	initial_close_target_transform = close_target.transform
	_create_label(
		"STAND ON THE MARK • LAND 3 NEEDLES FROM ONE VOLLEY",
		Vector3(0.0, 3.15, 16.4),
		Color(0.96, 0.84, 0.48),
		17
	)
	close_gate = _spawn_gate_with_dividers(
		"ClosePressGate",
		"Close Press Gate",
		Vector3(0.0, 0.0, 19.0)
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"MetalNeedleMasteryArea",
		Vector3(0.0, 1.0, 26.0),
		Vector3(7.0, 2.4, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_entered)
	_create_visual_box(
		"MetalNeedleMasterySeal",
		Vector3(0.0, 0.08, 26.0),
		Vector3(5.0, 0.14, 3.2),
		gold_material
	)
	_create_label(
		"SPREAD • SALVO • PUNCTURE",
		Vector3(0.0, 4.2, 27.4),
		Color(1.0, 0.84, 0.28),
		26
	)


func _evaluate_broad_fan() -> void:
	if fan_targets.size() < 5:
		return
	var shared_serial: int = 0
	for target: CharacterBody3D in fan_targets:
		if target == null or not is_instance_valid(target):
			return
		var serial: int = int(
			target.get_meta("metal_needle_fan_last_serial", 0)
		)
		if serial <= 0:
			return
		if shared_serial == 0:
			shared_serial = serial
		elif serial != shared_serial:
			return
	if shared_serial <= 0:
		return

	fan_success_serial = shared_serial
	fan_completion_count += 1
	fan_gate.set_gate_open(
		true,
		false,
		{"reason": "one_fan_hit_five_marks"}
	)
	_set_stage(TrialStage.THE_CLOSE_PRESS)
	fan_stage_completed.emit(shared_serial)
	_show_message(
		"The fan reached every mark. Move close enough to braid several needles into the Close Press."
	)


func _evaluate_close_press() -> void:
	if close_target == null or not is_instance_valid(close_target):
		return
	var serial: int = int(
		close_target.get_meta("metal_needle_fan_last_serial", 0)
	)
	var hit_count: int = int(
		close_target.get_meta("metal_needle_fan_hits_from_serial", 0)
	)
	if serial <= close_serial_baseline or hit_count < required_close_hits:
		return

	close_success_serial = serial
	close_success_hits = hit_count
	close_completion_count += 1
	close_gate.set_gate_open(
		true,
		false,
		{"reason": "close_target_received_multihit"}
	)
	_set_stage(TrialStage.MASTERY)
	close_stage_completed.emit(serial, hit_count)
	_show_message(
		"Close pressure confirmed. The same fan becomes a clustered puncture at short range."
	)


func _on_mastery_area_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Metal Needle mastered: SPREAD • SALVO • PUNCTURE.")


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.THE_BROAD_FAN:
			_set_objective(
				"Metal Needle: stand on the first mark and hit all five fan targets with one volley."
			)
		TrialStage.THE_CLOSE_PRESS:
			close_serial_baseline = (
				int(player.get_meta("metal_needle_fan_serial", 0))
				if player != null
				else 0
			)
			_set_objective(
				"Metal Needle: stand close and land at least three needles on the Close Press in one volley."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Metal Needle: cross the open gate and enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Needle Loom complete: SPREAD • SALVO • PUNCTURE."
			)


func _equip_metal_needle() -> void:
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
		if ability != null and ability.get_spell_id() == "metal_needle":
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	fan_completion_count = 0
	close_completion_count = 0
	fan_success_serial = 0
	close_success_serial = 0
	close_success_hits = 0
	close_serial_baseline = 0
	GameState.set_flag(completion_flag, false)
	_clear_metal_needle_effects()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		player.set_meta("metal_needle_fan_serial", 0)
		player.remove_meta("metal_needle_fan_last_direction")
	for target_index: int in range(fan_targets.size()):
		var target: CharacterBody3D = fan_targets[target_index]
		if target == null or not is_instance_valid(target):
			continue
		if target_index < initial_fan_target_transforms.size():
			target.transform = initial_fan_target_transforms[target_index]
		_reset_needle_target(target)
	if close_target != null:
		close_target.transform = initial_close_target_transform
		_reset_needle_target(close_target)
	if fan_gate != null:
		fan_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if close_gate != null:
		close_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	_restore_player_resources()
	_set_stage(TrialStage.THE_BROAD_FAN)
	call_deferred("_equip_metal_needle")
	trial_reset.emit()


func _reset_needle_target(target: CharacterBody3D) -> void:
	if target == null:
		return
	target.velocity = Vector3.ZERO
	target.remove_meta("metal_needle_fan_last_serial")
	target.remove_meta("metal_needle_fan_hits_from_serial")
	target.remove_meta("metal_needle_fan_last_needle_index")
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("reset_health"):
			hit_receiver.call("reset_health")
		if hit_receiver.has_method("reset_stance"):
			hit_receiver.call("reset_stance")


func _clear_metal_needle_effects() -> void:
	for effect: Node in get_tree().get_nodes_in_group(
		"metal_needle_fan_effects"
	):
		if effect.has_method("finish_volley"):
			effect.call("finish_volley")


func _restore_player_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _create_needle_target(
	node_name: String,
	display_name: String,
	position_value: Vector3,
	radius: float
) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = node_name
	target.position = position_value
	target.collision_layer = 1
	target.collision_mask = 1
	target.add_to_group("metal_needle_trial_targets")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = 2.0
	collision.shape = shape
	target.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.name = "TargetVisual"
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = 2.0
	visual.mesh = mesh
	visual.material_override = target_material
	target.add_child(visual)
	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", display_name)
	hit_receiver.set("hit_mode", 2)
	hit_receiver.set("max_health", 30)
	hit_receiver.set("current_health", 30)
	hit_receiver.set("max_stance", 20)
	hit_receiver.set("current_stance", 20)
	hit_receiver.set("regenerates_stance", false)
	target.add_child(hit_receiver)
	actors_root.add_child(target)
	_create_label_under(
		target,
		display_name.to_upper(),
		Vector3(0.0, 1.75, 0.0),
		Color(1.0, 0.82, 0.28),
		14
	)
	return target


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
		Vector3(-5.8, 2.2, 0.0),
		Vector3(5.7, 5.4, 0.8),
		wall_material
	)
	_create_static_box_under(
		divider_root,
		node_name + "RightDivider",
		Vector3(5.8, 2.2, 0.0),
		Vector3(5.7, 5.4, 0.8),
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
	label.visibility_range_end = 48.0
	label.visibility_range_end_margin = 4.0
	environment_root.add_child(label)
	return label


func _create_label_under(
	parent: Node3D,
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
	label.outline_size = 5
	label.modulate = color
	parent.add_child(label)
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
	var material: StandardMaterial3D = _make_material(albedo, 0.52, 0.36)
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
	var fan_serials: Array[int] = []
	for target: CharacterBody3D in fan_targets:
		fan_serials.append(
			int(target.get_meta("metal_needle_fan_last_serial", 0))
			if target != null
			else 0
		)
	return {
		"metal_needle_fan_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"fan_completions": fan_completion_count,
		"close_completions": close_completion_count,
		"fan_success_serial": fan_success_serial,
		"close_success_serial": close_success_serial,
		"close_success_hits": close_success_hits,
		"close_serial_baseline": close_serial_baseline,
		"fan_target_serials": fan_serials,
		"close_target_serial": (
			int(close_target.get_meta("metal_needle_fan_last_serial", 0))
			if close_target != null
			else 0
		),
		"close_target_hits": (
			int(close_target.get_meta("metal_needle_fan_hits_from_serial", 0))
			if close_target != null
			else 0
		),
		"fan_gate_open": fan_gate != null and fan_gate.is_mechanism_active(),
		"close_gate_open": close_gate != null and close_gate.is_mechanism_active(),
	}
