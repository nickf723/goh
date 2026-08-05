extends Node3D
class_name ChurchTrialChamberOfAccord

signal chamber_completed
signal chamber_reset

const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)
const WeightBlockScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_weight_block.tscn"
)
const ElementSensorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_element_sensor.tscn"
)
const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const IndicatorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_indicator.tscn"
)

@export_group("Persistence")
@export var completion_flag: String = (
	"church_trial_chamber_of_accord_complete"
)

@export_group("Player Guidance")
@export var balance_objective: String = (
	"Chamber of Accord: place V on the left scale and II + III on the right."
)
@export var rite_objective: String = (
	"The scales agree. Complete the rite: Water, then Fire."
)
@export var fire_objective: String = (
	"Water answers. Ignite the Fire altar to complete the rite."
)
@export var completion_objective: String = (
	"The Chamber of Accord opens. Continue into the echo passage."
)
@export var completion_message: String = (
	"Weight, Water, and Fire agree. The Church seal opens."
)

@export_group("Tuning")
@export_range(0.05, 2.0, 0.05) var altar_pulse_seconds: float = 0.45
@export_range(0.0, 2.0, 0.01) var balance_tolerance_kg: float = 0.1
@export var left_required_mass_kg: float = 5.0
@export var right_required_mass_kg: float = 5.0

var mechanisms_root: Node3D
var signal_root: Node
var presentation_root: Node3D

var left_plate: PressurePlateSwitch
var right_plate: PressurePlateSwitch
var weight_two: MechanismWeightBlock
var weight_three: MechanismWeightBlock
var weight_five: MechanismWeightBlock
var water_altar: MechanismElementSensor
var fire_altar: MechanismElementSensor
var passage_gate: MechanismSlidingGate
var completion_indicator: MechanismIndicator

var balance_comparator: MechanismValueComparator
var water_when_balanced: MechanismLogicNode
var fire_when_balanced: MechanismLogicNode
var elemental_sequence: MechanismLogicNode
var accord_and: MechanismLogicNode
var completion_latch: MechanismLogicNode
var gate_adapter: MechanismOutputAdapter
var indicator_adapter: MechanismOutputAdapter

var balance_channels: Array[MeshInstance3D] = []
var water_channels: Array[MeshInstance3D] = []
var fire_channels: Array[MeshInstance3D] = []
var completion_channels: Array[MeshInstance3D] = []
var seal_rings: Array[MeshInstance3D] = []

var stone_material: StandardMaterial3D
var warm_stone_material: StandardMaterial3D
var brass_material: StandardMaterial3D
var dormant_channel_material: StandardMaterial3D
var balance_channel_material: StandardMaterial3D
var water_channel_material: StandardMaterial3D
var fire_channel_material: StandardMaterial3D
var completion_channel_material: StandardMaterial3D
var dormant_seal_material: StandardMaterial3D
var active_seal_material: StandardMaterial3D

var reset_in_progress: bool = false
var completion_announced: bool = false
var presentation_refresh_count: int = 0
var balance_loss_reset_count: int = 0
var last_sequence_reason: String = "none"


func _ready() -> void:
	add_to_group("church_trial_puzzles")
	add_to_group("church_trial_chamber_of_accord")
	add_to_group("debuggable")
	_build_roots()
	_build_materials()
	_build_architecture()
	_build_mechanisms()
	_build_signal_graph()
	_connect_runtime_signals()
	_apply_persisted_completion("startup")
	call_deferred("_refresh_presentation")


func _exit_tree() -> void:
	var flag_callback := Callable(self, "_on_game_state_flag_changed")
	if GameState.flag_changed.is_connected(flag_callback):
		GameState.flag_changed.disconnect(flag_callback)


func _build_roots() -> void:
	mechanisms_root = Node3D.new()
	mechanisms_root.name = "Mechanisms"
	add_child(mechanisms_root)

	signal_root = Node.new()
	signal_root.name = "SignalNetwork"
	add_child(signal_root)

	presentation_root = Node3D.new()
	presentation_root.name = "Presentation"
	add_child(presentation_root)


func _build_materials() -> void:
	stone_material = _make_material(Color(0.13, 0.15, 0.19), 0.08, 0.9)
	warm_stone_material = _make_material(Color(0.25, 0.21, 0.18), 0.12, 0.82)
	brass_material = _make_material(Color(0.48, 0.34, 0.13), 0.78, 0.28)
	dormant_channel_material = _make_emissive_material(
		Color(0.12, 0.13, 0.17),
		Color(0.03, 0.04, 0.06),
		0.25
	)
	balance_channel_material = _make_emissive_material(
		Color(0.58, 0.46, 0.18),
		Color(1.0, 0.68, 0.12),
		2.2
	)
	water_channel_material = _make_emissive_material(
		Color(0.08, 0.35, 0.58),
		Color(0.04, 0.65, 1.0),
		2.8
	)
	fire_channel_material = _make_emissive_material(
		Color(0.58, 0.16, 0.05),
		Color(1.0, 0.26, 0.03),
		3.0
	)
	completion_channel_material = _make_emissive_material(
		Color(0.62, 0.43, 0.08),
		Color(1.0, 0.72, 0.12),
		3.4
	)
	dormant_seal_material = _make_emissive_material(
		Color(0.14, 0.15, 0.2),
		Color(0.04, 0.05, 0.08),
		0.35
	)
	active_seal_material = _make_emissive_material(
		Color(0.72, 0.49, 0.1),
		Color(1.0, 0.7, 0.12),
		4.0
	)


func _build_architecture() -> void:
	_create_static_box(
		"AccordDais",
		Vector3(0.0, 0.14, 52.0),
		Vector3(18.0, 0.28, 25.5),
		warm_stone_material
	)
	_create_static_box(
		"LeftScalePedestal",
		Vector3(-4.0, 0.42, 50.0),
		Vector3(4.3, 0.56, 4.0),
		stone_material
	)
	_create_static_box(
		"RightScalePedestal",
		Vector3(4.0, 0.42, 50.0),
		Vector3(4.3, 0.56, 4.0),
		stone_material
	)
	_create_static_box(
		"WaterAltarPedestal",
		Vector3(-4.2, 0.72, 58.4),
		Vector3(3.0, 1.44, 2.1),
		stone_material
	)
	_create_static_box(
		"FireAltarPedestal",
		Vector3(4.2, 0.72, 58.4),
		Vector3(3.0, 1.44, 2.1),
		stone_material
	)
	for x_position: float in [-8.1, 8.1]:
		for z_position: float in [43.0, 60.5]:
			_create_static_box(
				"AccordColumn" + str(roundi(x_position * 10.0)) + str(roundi(z_position)),
				Vector3(x_position, 1.7, z_position),
				Vector3(1.1, 3.4, 1.1),
				stone_material
			)

	_create_diegetic_label(
		"CHAMBER OF ACCORD",
		Vector3(0.0, 4.2, 40.7),
		Color(0.78, 0.67, 0.42),
		30
	)
	_create_diegetic_label(
		"V",
		Vector3(-4.0, 2.55, 51.9),
		Color(0.78, 0.67, 0.42),
		38
	)
	_create_diegetic_label(
		"II  +  III",
		Vector3(4.0, 2.55, 51.9),
		Color(0.78, 0.67, 0.42),
		34
	)
	_create_diegetic_label(
		"WATER  •  THEN  •  FIRE",
		Vector3(0.0, 4.2, 61.8),
		Color(0.65, 0.72, 0.82),
		24
	)

	balance_channels = [
		_create_channel("LeftBalanceChannel", Vector3(-2.0, 0.62, 53.6), Vector3(3.6, 0.08, 0.18)),
		_create_channel("RightBalanceChannel", Vector3(2.0, 0.62, 53.6), Vector3(3.6, 0.08, 0.18)),
	]
	water_channels = [
		_create_channel("WaterRiteChannel", Vector3(-2.1, 0.66, 59.7), Vector3(3.5, 0.08, 0.16)),
	]
	fire_channels = [
		_create_channel("FireRiteChannel", Vector3(2.1, 0.66, 59.7), Vector3(3.5, 0.08, 0.16)),
	]
	completion_channels = [
		_create_channel("SealToGateChannel", Vector3(0.0, 0.68, 63.5), Vector3(0.18, 0.08, 4.7)),
	]

	for ring_index: int in range(3):
		var ring := MeshInstance3D.new()
		ring.name = "AccordSealRing" + str(ring_index)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.58 + float(ring_index) * 0.22
		torus.outer_radius = 0.68 + float(ring_index) * 0.22
		torus.rings = 28
		torus.ring_segments = 10
		ring.mesh = torus
		ring.position = Vector3(0.0, 0.82 + float(ring_index) * 0.02, 61.3)
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		ring.material_override = dormant_seal_material
		presentation_root.add_child(ring)
		seal_rings.append(ring)


func _build_mechanisms() -> void:
	left_plate = _spawn_plate(
		"LeftOfferingScale",
		"accord_left_scale",
		Vector3(-4.0, 0.7, 50.0)
	)
	right_plate = _spawn_plate(
		"RightOfferingScale",
		"accord_right_scale",
		Vector3(4.0, 0.7, 50.0)
	)

	weight_five = _spawn_weight(
		"OfferingV",
		Vector3(-4.0, 0.85, 44.2),
		5.0,
		Vector3(1.35, 1.35, 1.35),
		Color(0.42, 0.34, 0.25),
		"V"
	)
	weight_two = _spawn_weight(
		"OfferingII",
		Vector3(2.7, 0.78, 44.0),
		2.0,
		Vector3(1.1, 1.1, 1.1),
		Color(0.27, 0.36, 0.46),
		"II"
	)
	weight_three = _spawn_weight(
		"OfferingIII",
		Vector3(5.0, 0.82, 44.4),
		3.0,
		Vector3(1.2, 1.2, 1.2),
		Color(0.34, 0.4, 0.31),
		"III"
	)

	water_altar = _spawn_altar(
		"WaterRiteAltar",
		"accord_water_altar",
		"Water Altar",
		Vector3(-4.2, 1.45, 58.1),
		["water"]
	)
	fire_altar = _spawn_altar(
		"FireRiteAltar",
		"accord_fire_altar",
		"Fire Altar",
		Vector3(4.2, 1.45, 58.1),
		["fire"]
	)

	completion_indicator = IndicatorScene.instantiate() as MechanismIndicator
	completion_indicator.name = "AccordSealIndicator"
	completion_indicator.display_name = "Accord Seal"
	completion_indicator.position = Vector3(0.0, 0.4, 61.3)
	completion_indicator.scale = Vector3.ONE * 1.35
	mechanisms_root.add_child(completion_indicator)
	var indicator_label := completion_indicator.get_node_or_null("StateLabel") as Label3D
	if indicator_label != null:
		indicator_label.visible = false

	passage_gate = GateScene.instantiate() as MechanismSlidingGate
	passage_gate.name = "AccordPassageGate"
	passage_gate.display_name = "Chamber of Accord Seal"
	passage_gate.position = Vector3(0.0, 0.0, 66.0)
	passage_gate.scale = Vector3(1.75, 1.0, 1.0)
	passage_gate.open_offset = Vector3(0.0, 4.3, 0.0)
	mechanisms_root.add_child(passage_gate)
	var gate_label := passage_gate.get_node_or_null("StateLabel") as Label3D
	if gate_label != null:
		gate_label.visible = false
	var gate_visual := passage_gate.get_node_or_null("GateVisual") as MeshInstance3D
	if gate_visual != null:
		gate_visual.material_override = dormant_seal_material


func _build_signal_graph() -> void:
	balance_comparator = MechanismValueComparator.new()
	balance_comparator.name = "ScaleBalanceComparator"
	balance_comparator.mechanism_id = "accord_scale_balance"
	balance_comparator.display_name = "Offering Balance"
	balance_comparator.comparison = (
		MechanismValueComparator.Comparison.SOURCES_WITHIN_TOLERANCE
	)
	balance_comparator.primary_source_id = left_plate.get_mechanism_id()
	balance_comparator.secondary_source_id = right_plate.get_mechanism_id()
	balance_comparator.tolerance = balance_tolerance_kg
	balance_comparator.require_all_sources_active = true
	balance_comparator.minimum_value = -10.0
	balance_comparator.maximum_value = 10.0
	balance_comparator.value_unit = "kg"
	signal_root.add_child(balance_comparator)
	balance_comparator.bind_source(left_plate)
	balance_comparator.bind_source(right_plate)

	water_when_balanced = _create_logic_node(
		"WaterWhileBalanced",
		"accord_water_when_balanced",
		MechanismLogicNode.Operation.AND,
		[balance_comparator, water_altar]
	)
	fire_when_balanced = _create_logic_node(
		"FireWhileBalanced",
		"accord_fire_when_balanced",
		MechanismLogicNode.Operation.AND,
		[balance_comparator, fire_altar]
	)

	elemental_sequence = _create_logic_node(
		"ElementalRiteSequence",
		"accord_elemental_sequence",
		MechanismLogicNode.Operation.SEQUENCE,
		[water_when_balanced, fire_when_balanced]
	)
	var rite_sequence_ids: Array[String] = []
	rite_sequence_ids.append(water_when_balanced.get_mechanism_id())
	rite_sequence_ids.append(fire_when_balanced.get_mechanism_id())
	elemental_sequence.sequence_source_ids = rite_sequence_ids
	elemental_sequence.sequence_wrong_input_behavior = (
		MechanismLogicNode.SequenceWrongInputBehavior.RESET
	)

	accord_and = _create_logic_node(
		"AccordCompletionCondition",
		"accord_completion_condition",
		MechanismLogicNode.Operation.AND,
		[balance_comparator, elemental_sequence]
	)

	completion_latch = MechanismLogicNode.new()
	completion_latch.name = "AccordCompletionLatch"
	completion_latch.mechanism_id = "accord_completion_latch"
	completion_latch.display_name = "Chamber Completion"
	completion_latch.operation = MechanismLogicNode.Operation.LATCH
	completion_latch.initial_active = GameState.get_flag(completion_flag)
	completion_latch.persist_active_state = true
	completion_latch.persistence_flag = completion_flag
	signal_root.add_child(completion_latch)
	completion_latch.bind_source(accord_and)

	gate_adapter = _create_output_adapter(
		"AccordPassageGateOutput",
		completion_latch,
		passage_gate
	)
	indicator_adapter = _create_output_adapter(
		"AccordSealIndicatorOutput",
		completion_latch,
		completion_indicator
	)


func _connect_runtime_signals() -> void:
	var balance_callback := Callable(self, "_on_balance_signal_changed")
	if not balance_comparator.mechanism_signal_changed.is_connected(balance_callback):
		balance_comparator.mechanism_signal_changed.connect(balance_callback)

	var sequence_callback := Callable(self, "_on_sequence_signal_changed")
	if not elemental_sequence.mechanism_signal_changed.is_connected(sequence_callback):
		elemental_sequence.mechanism_signal_changed.connect(sequence_callback)

	var completion_callback := Callable(self, "_on_completion_signal_changed")
	if not completion_latch.mechanism_signal_changed.is_connected(completion_callback):
		completion_latch.mechanism_signal_changed.connect(completion_callback)

	var flag_callback := Callable(self, "_on_game_state_flag_changed")
	if not GameState.flag_changed.is_connected(flag_callback):
		GameState.flag_changed.connect(flag_callback)


func _on_balance_signal_changed(
	_mechanism_id: String,
	active: bool,
	_packet: Dictionary
) -> void:
	if (
		not active
		and elemental_sequence != null
		and not elemental_sequence.memory_active
		and elemental_sequence.sequence_index > 0
	):
		balance_loss_reset_count += 1
		elemental_sequence.reset_sequence()
		last_sequence_reason = "balance_lost"

	if not completion_latch.active:
		_set_objective(rite_objective if active else balance_objective)
	_refresh_presentation()


func _on_sequence_signal_changed(
	_mechanism_id: String,
	_active: bool,
	packet: Dictionary
) -> void:
	last_sequence_reason = str(packet.get("reason", "sequence_update"))
	if completion_latch != null and completion_latch.active:
		_refresh_presentation()
		return

	match last_sequence_reason:
		"sequence_advanced":
			_set_objective(fire_objective)
			_show_message("The Water altar answers. The flame must follow.")
		"sequence_wrong_input":
			_set_objective(rite_objective)
			_show_message("The rite rejects the order. Water must precede Fire.")
		"memory_reset":
			if balance_comparator != null and balance_comparator.active:
				_set_objective(rite_objective)
	_refresh_presentation()


func _on_completion_signal_changed(
	_mechanism_id: String,
	active: bool,
	_packet: Dictionary
) -> void:
	_refresh_presentation()
	if not active or reset_in_progress:
		return
	if not completion_announced:
		completion_announced = true
		_set_objective(completion_objective)
		_show_message(completion_message)
		chamber_completed.emit()


func _on_game_state_flag_changed(flag_name: String, value: bool) -> void:
	if flag_name != completion_flag or reset_in_progress:
		return
	if value:
		_apply_persisted_completion("save_flag_loaded")


func _apply_persisted_completion(reason: String) -> void:
	if completion_latch == null or not GameState.get_flag(completion_flag):
		return
	if completion_latch.active and completion_latch.latched_active:
		return

	var persistence_enabled: bool = completion_latch.persist_active_state
	completion_latch.persist_active_state = false
	completion_latch.initial_active = true
	completion_latch.latched_active = true
	completion_latch.set_mechanism_active(true, {
		"reason": reason,
		"restored_from_flag": true,
	}, true)
	completion_latch.persist_active_state = persistence_enabled
	completion_announced = true
	if gate_adapter != null:
		gate_adapter.apply_target_state()
	if indicator_adapter != null:
		indicator_adapter.apply_target_state()
	_refresh_presentation()


func _refresh_presentation() -> void:
	presentation_refresh_count += 1
	var balanced: bool = (
		balance_comparator != null
		and balance_comparator.active
	)
	var water_complete: bool = (
		elemental_sequence != null
		and (
			elemental_sequence.sequence_index >= 1
			or elemental_sequence.memory_active
		)
	)
	var fire_complete: bool = (
		elemental_sequence != null
		and elemental_sequence.memory_active
	)
	var completed: bool = (
		completion_latch != null
		and completion_latch.active
	)

	_set_materials(
		balance_channels,
		balance_channel_material if balanced else dormant_channel_material
	)
	_set_materials(
		water_channels,
		water_channel_material if water_complete else dormant_channel_material
	)
	_set_materials(
		fire_channels,
		fire_channel_material if fire_complete else dormant_channel_material
	)
	_set_materials(
		completion_channels,
		completion_channel_material if completed else dormant_channel_material
	)
	_set_materials(
		seal_rings,
		active_seal_material if completed else dormant_seal_material
	)

	if passage_gate != null:
		var gate_visual := passage_gate.get_node_or_null("GateVisual") as MeshInstance3D
		if gate_visual != null:
			gate_visual.material_override = (
				active_seal_material
				if completed
				else dormant_seal_material
			)


func reset_chamber(clear_persistent_completion: bool = false) -> void:
	if reset_in_progress:
		return
	reset_in_progress = true

	for weight: MechanismWeightBlock in [weight_two, weight_three, weight_five]:
		if weight != null and is_instance_valid(weight):
			weight.reset_target()
	for plate: PressurePlateSwitch in [left_plate, right_plate]:
		if plate != null and is_instance_valid(plate):
			plate.reset_target()
	for altar: MechanismElementSensor in [water_altar, fire_altar]:
		if altar != null and is_instance_valid(altar):
			altar.reset_target()

	for logic: MechanismLogicNode in [
		water_when_balanced,
		fire_when_balanced,
		elemental_sequence,
		accord_and,
	]:
		if logic != null and is_instance_valid(logic):
			logic.reset_target()
	if balance_comparator != null:
		balance_comparator.reset_target()

	if clear_persistent_completion:
		GameState.set_flag(completion_flag, false)
	completion_latch.initial_active = (
		GameState.get_flag(completion_flag)
		if not clear_persistent_completion
		else false
	)
	var persistence_enabled: bool = completion_latch.persist_active_state
	completion_latch.persist_active_state = false
	completion_latch.reset_target()
	completion_latch.persist_active_state = persistence_enabled

	if gate_adapter != null:
		gate_adapter.apply_target_state()
	if indicator_adapter != null:
		indicator_adapter.apply_target_state()
	completion_announced = completion_latch.active
	last_sequence_reason = "reset"
	reset_in_progress = false
	_refresh_presentation()
	chamber_reset.emit()


func _spawn_plate(
	node_name: String,
	mechanism_id: String,
	position_value: Vector3
) -> PressurePlateSwitch:
	var plate: PressurePlateSwitch = (
		PressurePlateScene.instantiate() as PressurePlateSwitch
	)
	plate.name = node_name
	plate.component_id = mechanism_id
	plate.display_name = node_name.replace("_", " ")
	plate.position = position_value
	plate.scale = Vector3(1.45, 1.0, 1.45)
	plate.maximum_reported_mass_kg = 6.0
	plate.default_non_rigid_body_mass_kg = 70.0
	plate.accept_any_physics_body = true
	plate.accept_static_bodies = false
	plate.accept_animatable_bodies = false
	plate.show_weight_in_label = false
	mechanisms_root.add_child(plate)
	var state_label := plate.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		state_label.visible = false
	var base := plate.get_node_or_null("Base") as MeshInstance3D
	if base != null:
		base.material_override = brass_material
	var plate_visual := plate.get_node_or_null("PlateVisual") as MeshInstance3D
	if plate_visual != null:
		plate_visual.material_override = warm_stone_material
	return plate


func _spawn_weight(
	node_name: String,
	position_value: Vector3,
	mass_kg: float,
	size_value: Vector3,
	color: Color,
	rune: String
) -> MechanismWeightBlock:
	var block: MechanismWeightBlock = (
		WeightBlockScene.instantiate() as MechanismWeightBlock
	)
	block.name = node_name
	block.position = position_value
	block.show_mass_label = false
	block.show_soul_mark = true
	block.configure_weight_block(
		mass_kg,
		size_value,
		color,
		"Offering " + rune
	)
	var rune_label := Label3D.new()
	rune_label.name = "OfferingRune"
	rune_label.position = Vector3(0.0, size_value.y * 0.5 + 0.42, 0.0)
	rune_label.text = rune
	rune_label.font_size = 28
	rune_label.pixel_size = 0.006
	rune_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rune_label.outline_size = 7
	rune_label.modulate = Color(0.88, 0.77, 0.5)
	block.add_child(rune_label)
	mechanisms_root.add_child(block)
	return block


func _spawn_altar(
	node_name: String,
	mechanism_id: String,
	display_name_value: String,
	position_value: Vector3,
	accepted: Array[String]
) -> MechanismElementSensor:
	var altar: MechanismElementSensor = (
		ElementSensorScene.instantiate() as MechanismElementSensor
	)
	altar.name = node_name
	altar.mechanism_id = mechanism_id
	altar.display_name = display_name_value
	altar.position = position_value
	altar.accepted_elements = accepted.duplicate()
	altar.reset_elements = []
	altar.latch_when_activated = false
	altar.active_seconds = altar_pulse_seconds
	altar.starts_active = false
	mechanisms_root.add_child(altar)
	var state_label := altar.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		state_label.visible = false
	return altar


func _create_logic_node(
	node_name: String,
	mechanism_id: String,
	operation: MechanismLogicNode.Operation,
	sources: Array
) -> MechanismLogicNode:
	var logic := MechanismLogicNode.new()
	logic.name = node_name
	logic.mechanism_id = mechanism_id
	logic.display_name = node_name.replace("_", " ")
	logic.operation = operation
	signal_root.add_child(logic)
	for source_value: Variant in sources:
		if source_value is Node:
			logic.bind_source(source_value as Node)
	return logic


func _create_output_adapter(
	node_name: String,
	source: Node,
	target: Node
) -> MechanismOutputAdapter:
	var adapter := MechanismOutputAdapter.new()
	adapter.name = node_name
	adapter.mechanism_id = node_name.to_lower()
	adapter.display_name = node_name.replace("_", " ")
	signal_root.add_child(adapter)
	adapter.bind_source(source)
	adapter.bind_target(target)
	return adapter


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
	presentation_root.add_child(body)
	return body


func _create_channel(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3
) -> MeshInstance3D:
	var channel := MeshInstance3D.new()
	channel.name = node_name
	channel.position = position_value
	var mesh := BoxMesh.new()
	mesh.size = size_value
	channel.mesh = mesh
	channel.material_override = dormant_channel_material
	presentation_root.add_child(channel)
	return channel


func _create_diegetic_label(
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
	label.visibility_range_end = 38.0
	label.visibility_range_end_margin = 4.0
	presentation_root.add_child(label)
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
	var material := _make_material(albedo, 0.4, 0.34)
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func _set_materials(nodes: Array, material: Material) -> void:
	for node_value: Variant in nodes:
		if node_value is MeshInstance3D:
			var mesh_instance := node_value as MeshInstance3D
			if mesh_instance != null and is_instance_valid(mesh_instance):
				mesh_instance.material_override = material


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
	return {
		"church_trial_chamber_of_accord": true,
		"completion_flag": completion_flag,
		"completed": completion_latch.active if completion_latch != null else false,
		"balanced": balance_comparator.active if balance_comparator != null else false,
		"left_mass_kg": left_plate.get_mechanism_value() if left_plate != null else 0.0,
		"right_mass_kg": right_plate.get_mechanism_value() if right_plate != null else 0.0,
		"balance_difference_kg": balance_comparator.last_difference if balance_comparator != null else 0.0,
		"sequence_index": elemental_sequence.sequence_index if elemental_sequence != null else 0,
		"sequence_complete": elemental_sequence.memory_active if elemental_sequence != null else false,
		"sequence_reason": last_sequence_reason,
		"sequence_wrong_inputs": elemental_sequence.sequence_wrong_input_count if elemental_sequence != null else 0,
		"balance_loss_resets": balance_loss_reset_count,
		"gate_open": passage_gate.active if passage_gate != null else false,
		"presentation_refreshes": presentation_refresh_count,
		"weight_count": 3,
	}
