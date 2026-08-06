extends Node3D
class_name PrototypeStormObservatorySpellTrial

signal still_rod_completed
signal moving_relay_completed
signal precision_stage_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const TargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)

enum TrialStage {
	STILL_ROD,
	MOVING_RELAY,
	PRECISION_RING,
	MASTERY,
	COMPLETE,
}

@export_group("Moving Relay")
@export_range(0.5, 6.0, 0.1) var relay_amplitude: float = 2.8
@export_range(0.1, 4.0, 0.05) var relay_speed: float = 1.2

@export_group("Trial")
@export var completion_flag: String = (
	"storm_observatory_spell_trial_complete"
)
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Lightning Bolt casts."
)

var environment_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D

var still_target: CombatTrainingTarget
var moving_target: CombatTrainingTarget
var precision_target: CombatTrainingTarget
var left_bystander: CombatTrainingTarget
var right_bystander: CombatTrainingTarget

var still_gate: MechanismSlidingGate
var moving_gate: MechanismSlidingGate
var precision_gate: MechanismSlidingGate
var mastery_area: Area3D

var stage: TrialStage = TrialStage.STILL_ROD
var trial_complete: bool = false
var initial_player_transform: Transform3D
var moving_relay_center: Vector3 = Vector3.ZERO
var relay_elapsed: float = 0.0
var still_completion_count: int = 0
var moving_completion_count: int = 0
var precision_completion_count: int = 0

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var indigo_material: StandardMaterial3D
var storm_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var safe_ring_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("storm_observatory_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_still_rod_stage()
	_build_moving_relay_stage()
	_build_precision_stage()
	_build_mastery_landing()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	_set_stage(TrialStage.STILL_ROD)
	_show_message(
		"Storm Observatory: place the outer storm mark, then land the bright center bolt. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_lightning_bolt")


func _physics_process(delta: float) -> void:
	if (
		stage != TrialStage.MOVING_RELAY
		or moving_target == null
		or not is_instance_valid(moving_target)
		or _get_target_health(moving_target) <= 0
	):
		return
	relay_elapsed += maxf(delta, 0.0)
	var next_position: Vector3 = moving_relay_center
	next_position.x += sin(relay_elapsed * relay_speed * TAU) * relay_amplitude
	moving_target.global_position = next_position
	moving_target.velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "StormObservatoryEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "StormObservatoryActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(
		Color(0.075, 0.09, 0.13),
		0.28,
		0.76
	)
	wall_material = _make_material(
		Color(0.035, 0.05, 0.085),
		0.56,
		0.46
	)
	indigo_material = _make_emissive_material(
		Color(0.08, 0.18, 0.62, 0.78),
		Color(0.12, 0.36, 1.0),
		2.6
	)
	storm_material = _make_emissive_material(
		Color(0.48, 0.72, 1.0, 0.86),
		Color(0.62, 0.86, 1.0),
		4.2
	)
	gold_material = _make_emissive_material(
		Color(0.66, 0.48, 0.1, 0.84),
		Color(1.0, 0.78, 0.16),
		3.7
	)
	safe_ring_material = _make_emissive_material(
		Color(0.14, 0.28, 0.82, 0.22),
		Color(0.18, 0.44, 1.0),
		1.5
	)


func _build_environment() -> void:
	_create_static_box(
		"ObservatoryFloor",
		Vector3(0.0, -0.5, 28.0),
		Vector3(18.0, 1.0, 70.0),
		floor_material
	)
	_create_static_box(
		"ObservatoryLeftWall",
		Vector3(-9.5, 2.5, 28.0),
		Vector3(1.0, 6.0, 70.0),
		wall_material
	)
	_create_static_box(
		"ObservatoryRightWall",
		Vector3(9.5, 2.5, 28.0),
		Vector3(1.0, 6.0, 70.0),
		wall_material
	)
	_create_static_box(
		"ObservatoryBackWall",
		Vector3(0.0, 2.5, -7.0),
		Vector3(18.0, 6.0, 1.0),
		wall_material
	)
	_create_static_box(
		"ObservatoryFrontWall",
		Vector3(0.0, 2.5, 63.0),
		Vector3(18.0, 6.0, 1.0),
		wall_material
	)

	for divider_z: float in [15.0, 31.0, 47.0]:
		_create_static_box(
			"StormDividerLeft" + str(roundi(divider_z)),
			Vector3(-6.1, 2.2, divider_z),
			Vector3(6.8, 5.4, 0.8),
			wall_material
		)
		_create_static_box(
			"StormDividerRight" + str(roundi(divider_z)),
			Vector3(6.1, 2.2, divider_z),
			Vector3(6.8, 5.4, 0.8),
			wall_material
		)

	_create_label(
		"THE STORM OBSERVATORY",
		Vector3(0.0, 4.9, -3.8),
		Color(0.64, 0.78, 1.0),
		34
	)
	_create_label(
		"The ring chooses the storm. The center chooses the wound.",
		Vector3(0.0, 3.9, 0.0),
		Color(0.7, 0.8, 0.96),
		21
	)
	_create_label(
		"I • STILL ROD",
		Vector3(0.0, 4.1, 3.0),
		Color(0.48, 0.72, 1.0),
		28
	)
	_create_label(
		"II • MOVING RELAY",
		Vector3(0.0, 4.1, 19.0),
		Color(0.48, 0.72, 1.0),
		28
	)
	_create_label(
		"III • CENTER JUDGMENT",
		Vector3(0.0, 4.1, 35.0),
		Color(0.68, 0.84, 1.0),
		28
	)

	for channel_z: float in [8.0, 24.0, 40.0]:
		var channel := MeshInstance3D.new()
		channel.name = "StormChannel" + str(roundi(channel_z))
		channel.position = Vector3(0.0, 0.035, channel_z)
		var channel_mesh := BoxMesh.new()
		channel_mesh.size = Vector3(14.0, 0.05, 8.0)
		channel.mesh = channel_mesh
		channel.material_override = indigo_material
		environment_root.add_child(channel)

	for rod_x: float in [-7.3, 7.3]:
		for rod_z: float in [6.0, 22.0, 38.0, 54.0]:
			_create_lightning_rod(
				"LightningRod" + str(roundi(rod_x * 10.0)) + str(roundi(rod_z)),
				Vector3(rod_x, 0.0, rod_z)
			)


func _build_still_rod_stage() -> void:
	still_target = _spawn_target(
		"StillStormRod",
		"STILL STORM ROD",
		Vector3(0.0, 0.0, 8.0),
		5
	)
	var hit_receiver: Node = still_target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.health_depleted.connect(_on_still_target_depleted)
	still_gate = _spawn_gate(
		"StillRodGate",
		"Still Rod Gate",
		Vector3(0.0, 0.0, 15.0)
	)


func _build_moving_relay_stage() -> void:
	moving_relay_center = Vector3(0.0, 0.0, 24.0)
	moving_target = _spawn_target(
		"MovingStormRelay",
		"MOVING STORM RELAY",
		moving_relay_center,
		5
	)
	var hit_receiver: Node = moving_target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.health_depleted.connect(_on_moving_target_depleted)
	moving_gate = _spawn_gate(
		"MovingRelayGate",
		"Moving Relay Gate",
		Vector3(0.0, 0.0, 31.0)
	)


func _build_precision_stage() -> void:
	precision_target = _spawn_target(
		"PrecisionStormCore",
		"DIRECT STRIKE CORE",
		Vector3(0.0, 0.0, 40.0),
		5
	)
	left_bystander = _spawn_target(
		"LeftPeripheralSensor",
		"PERIPHERAL SENSOR",
		Vector3(-1.25, 0.0, 40.0),
		12
	)
	right_bystander = _spawn_target(
		"RightPeripheralSensor",
		"PERIPHERAL SENSOR",
		Vector3(1.25, 0.0, 40.0),
		12
	)
	var hit_receiver: Node = precision_target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.health_depleted.connect(_on_precision_target_depleted)

	var preview_disc := MeshInstance3D.new()
	preview_disc.name = "ReservedPeripheralRing"
	preview_disc.position = Vector3(0.0, 0.055, 40.0)
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.8
	disc_mesh.bottom_radius = 1.8
	disc_mesh.height = 0.035
	disc_mesh.radial_segments = 32
	preview_disc.mesh = disc_mesh
	preview_disc.material_override = safe_ring_material
	environment_root.add_child(preview_disc)
	_create_label(
		"OUTER RING: RESERVED • BRIGHT CENTER: DAMAGE",
		Vector3(0.0, 3.05, 43.0),
		Color(0.68, 0.86, 1.0),
		19
	)
	precision_gate = _spawn_gate(
		"PrecisionGate",
		"Center Judgment Gate",
		Vector3(0.0, 0.0, 47.0)
	)


func _build_mastery_landing() -> void:
	mastery_area = Area3D.new()
	mastery_area.name = "LightningBoltMasteryArea"
	mastery_area.position = Vector3(0.0, 1.0, 55.5)
	mastery_area.collision_layer = 0
	mastery_area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 2.4, 4.0)
	collision.shape = shape
	mastery_area.add_child(collision)
	actors_root.add_child(mastery_area)
	mastery_area.body_entered.connect(_on_mastery_area_body_entered)

	var pad := MeshInstance3D.new()
	pad.name = "StormMasteryPad"
	pad.position = Vector3(0.0, 0.06, 55.5)
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.4
	pad_mesh.bottom_radius = 2.4
	pad_mesh.height = 0.12
	pad.mesh = pad_mesh
	pad.material_override = gold_material
	environment_root.add_child(pad)
	_create_label(
		"MARK • LEAD • STRIKE",
		Vector3(0.0, 3.8, 57.8),
		Color(1.0, 0.82, 0.28),
		26
	)


func _on_still_target_depleted() -> void:
	if stage != TrialStage.STILL_ROD:
		return
	still_completion_count += 1
	still_gate.set_gate_open(true, false, {"reason": "still_rod_struck"})
	_set_stage(TrialStage.MOVING_RELAY)
	still_rod_completed.emit()
	_show_message(
		"The still rod answers. The next relay moves during the warning flash, so lead its path."
	)


func _on_moving_target_depleted() -> void:
	if stage != TrialStage.MOVING_RELAY:
		return
	moving_completion_count += 1
	moving_gate.set_gate_open(true, false, {"reason": "moving_relay_struck"})
	_set_stage(TrialStage.PRECISION_RING)
	moving_relay_completed.emit()
	_show_message(
		"Relay intercepted. In the final ring, only the bright center bolt deals damage."
	)


func _on_precision_target_depleted() -> void:
	if stage != TrialStage.PRECISION_RING:
		return
	precision_completion_count += 1
	precision_gate.set_gate_open(true, false, {"reason": "precision_core_struck"})
	_set_stage(TrialStage.MASTERY)
	precision_stage_completed.emit()
	_show_message(
		"Center judgment confirmed. The peripheral ring remains dormant until a future spell upgrade."
	)


func _on_mastery_area_body_entered(body: Node3D) -> void:
	if stage != TrialStage.MASTERY or trial_complete:
		return
	if not body.is_in_group("player"):
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	_show_message(
		"Lightning Bolt mastery recorded: mark the ground, lead moving targets, and land the direct sky strike."
	)
	trial_completed.emit()


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.STILL_ROD:
			GameState.set_objective(
				"Place Lightning Bolt beneath the still storm rod and confirm the strike."
			)
		TrialStage.MOVING_RELAY:
			GameState.set_objective(
				"Lead the moving relay. It must be inside the bright center when the delayed bolt lands."
			)
		TrialStage.PRECISION_RING:
			GameState.set_objective(
				"Strike the center core while leaving both peripheral sensors unharmed."
			)
		TrialStage.MASTERY:
			GameState.set_objective(
				"Reach the Storm Observatory mastery seal."
			)
		TrialStage.COMPLETE:
			GameState.set_objective(
				"Storm Observatory Spell Trial complete."
			)


func _equip_lightning_bolt() -> void:
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
		if ability != null and ability.get_spell_id() == "lightning_bolt":
			caster.call("select_ability", index, false)
			return


func _spawn_target(
	node_name: String,
	display_name: String,
	position_value: Vector3,
	health: int
) -> CombatTrainingTarget:
	var target: CombatTrainingTarget = (
		TargetScene.instantiate() as CombatTrainingTarget
	)
	target.name = node_name
	target.target_label = display_name
	target.position = position_value
	actors_root.add_child(target)
	target.set_physics_process(false)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.set("target_name", display_name)
		hit_receiver.set("hit_mode", 2)
		hit_receiver.set("max_health", maxi(health, 1))
		hit_receiver.set("current_health", maxi(health, 1))
		hit_receiver.set("max_stance", 1)
		hit_receiver.set("current_stance", 1)
		hit_receiver.set("disappears_when_defeated", false)
		hit_receiver.set("restores_mana_when_defeated", 0)
	var label: Label3D = target.get_node_or_null("NameLabel") as Label3D
	if label != null:
		label.text = display_name
		label.font_size = 25
	return target


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
	gate.scale = Vector3(1.45, 1.0, 1.0)
	gate.open_offset = Vector3(0.0, 4.5, 0.0)
	gate.transition_seconds = 0.5
	actors_root.add_child(gate)
	var state_label: Label3D = gate.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		state_label.visible = false
	return gate


func _create_lightning_rod(node_name: String, position_value: Vector3) -> void:
	var rod := MeshInstance3D.new()
	rod.name = node_name
	rod.position = position_value + Vector3.UP * 2.2
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 0.22
	mesh.height = 4.4
	mesh.radial_segments = 8
	rod.mesh = mesh
	rod.material_override = storm_material
	environment_root.add_child(rod)


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
	label.visibility_range_end = 48.0
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
	var material := _make_material(albedo, 0.46, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func reset_trial() -> void:
	trial_complete = false
	GameState.set_flag(completion_flag, false)
	for strike: Node in get_tree().get_nodes_in_group("lightning_bolt_strikes"):
		if strike != null and is_instance_valid(strike):
			strike.queue_free()
	for target: CombatTrainingTarget in [
		still_target,
		moving_target,
		precision_target,
		left_bystander,
		right_bystander,
	]:
		if target != null and is_instance_valid(target):
			target.reset_target()
			target.set_physics_process(false)
	moving_target.global_position = moving_relay_center
	moving_target.velocity = Vector3.ZERO
	for gate: MechanismSlidingGate in [still_gate, moving_gate, precision_gate]:
		if gate != null:
			gate.reset_target()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	relay_elapsed = 0.0
	still_completion_count = 0
	moving_completion_count = 0
	precision_completion_count = 0
	_set_stage(TrialStage.STILL_ROD)
	call_deferred("_equip_lightning_bolt")
	trial_reset.emit()
	_show_message("Storm Observatory trial reset.")


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


func get_debug_data() -> Dictionary:
	return {
		"storm_observatory_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"still_health": _get_target_health(still_target),
		"moving_health": _get_target_health(moving_target),
		"precision_health": _get_target_health(precision_target),
		"left_bystander_health": _get_target_health(left_bystander),
		"right_bystander_health": _get_target_health(right_bystander),
		"still_gate_open": still_gate.active if still_gate != null else false,
		"moving_gate_open": moving_gate.active if moving_gate != null else false,
		"precision_gate_open": precision_gate.active if precision_gate != null else false,
		"relay_position": moving_target.global_position if moving_target != null else Vector3.ZERO,
		"still_completions": still_completion_count,
		"moving_completions": moving_completion_count,
		"precision_completions": precision_completion_count,
	}
