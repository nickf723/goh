extends "res://scripts/levels/mechanism_network_lab_complete.gd"
class_name MechanismNetworkLabValue

const ValueElevatorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_value_elevator.tscn"
)

var value_comparators: Array[MechanismValueComparator] = []
var value_labels: Dictionary = {}


func _ready() -> void:
	super._ready()
	_build_value_extension_environment()
	_build_weight_threshold_station(184.0)
	_build_balance_scale_station(207.0)
	_build_proportional_elevator_station(230.0)
	GameState.set_objective(
		"Explore the mechanism grammar through Boolean logic, memory, measurable weight, comparisons, balance, and proportional motion. F8 resets everything."
	)
	_show_message(
		"Value Signal wing online. Pressure plates now report total kilograms as well as pressed or released state."
	)
	call_deferred("_refresh_all_presentations")


func _build_value_extension_environment() -> void:
	_create_static_box(
		"ValueWingFloor",
		Vector3(0.0, -0.5, 210.0),
		Vector3(24.0, 1.0, 82.0),
		Color(0.1, 0.15, 0.19)
	)
	_create_static_box(
		"ValueWingLeftWall",
		Vector3(-12.5, 2.0, 210.0),
		Vector3(1.0, 5.0, 82.0),
		Color(0.06, 0.1, 0.13)
	)
	_create_static_box(
		"ValueWingRightWall",
		Vector3(12.5, 2.0, 210.0),
		Vector3(1.0, 5.0, 82.0),
		Color(0.06, 0.1, 0.13)
	)
	for divider_z: float in [195.0, 218.0, 241.0]:
		_create_static_box(
			"ValueDividerLeft" + str(int(divider_z)),
			Vector3(-8.0, 1.5, divider_z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.14, 0.21, 0.25)
		)
		_create_static_box(
			"ValueDividerRight" + str(int(divider_z)),
			Vector3(8.0, 1.5, divider_z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.14, 0.21, 0.25)
		)
	_create_station_label(
		"VALUE SIGNAL WING\nMechanisms can carry quantities as well as ON and OFF",
		Vector3(0.0, 5.1, 176.0),
		Color(0.38, 0.9, 1.0)
	)


func _build_weight_threshold_station(z: float) -> void:
	_create_station_platform(z, "09 • WEIGHT THRESHOLD: LOAD ≥ 10 KG")
	var plate: PressurePlateSwitch = _spawn_pressure_plate(
		"ThresholdWeightPlate",
		"threshold_weight_plate",
		Vector3(-4.0, 0.0, z)
	)
	plate.scale = Vector3(1.45, 1.0, 1.45)
	plate.maximum_reported_mass_kg = 14.0
	_spawn_value_crate(
		"ThresholdCrate2kg",
		Vector3(2.8, 0.65, z - 2.0),
		2.0,
		Vector3(1.0, 1.0, 1.0),
		Color(0.25, 0.58, 0.72)
	)
	_spawn_value_crate(
		"ThresholdCrate4kg",
		Vector3(4.2, 0.65, z),
		4.0,
		Vector3(1.05, 1.05, 1.05),
		Color(0.25, 0.72, 0.5)
	)
	_spawn_value_crate(
		"ThresholdCrate7kg",
		Vector3(2.8, 0.75, z + 2.0),
		7.0,
		Vector3(1.2, 1.2, 1.2),
		Color(0.76, 0.48, 0.18)
	)
	var comparator: MechanismValueComparator = _create_value_comparator(
		"TenKilogramComparator",
		"ten_kilogram_comparator",
		"LOAD ≥ 10 KG",
		MechanismValueComparator.Comparison.GREATER_OR_EQUAL,
		[plate]
	)
	comparator.primary_source_id = plate.get_mechanism_id()
	comparator.threshold = 10.0
	comparator.minimum_value = 0.0
	comparator.maximum_value = 14.0
	comparator.value_unit = "kg"
	_create_value_label(comparator, Vector3(0.0, 3.25, z + 2.2))
	var indicator: MechanismIndicator = _spawn_indicator(
		"ThresholdWeightIndicator",
		"10 KG REACHED",
		Vector3(4.2, 0.0, z + 4.0)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"ThresholdWeightGate",
		"WEIGHT THRESHOLD GATE",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("ThresholdWeightIndicatorOutput", comparator, indicator)
	_wire_output("ThresholdWeightGateOutput", comparator, gate)
	station_states["weight_threshold"] = {
		"value_comparator": comparator,
		"inputs": [plate],
		"outputs": [indicator, gate],
	}


func _build_balance_scale_station(z: float) -> void:
	_create_station_platform(z, "10 • BALANCE SCALE: LEFT = RIGHT")
	var left_plate: PressurePlateSwitch = _spawn_pressure_plate(
		"BalanceLeftPlate",
		"balance_left_plate",
		Vector3(-4.4, 0.0, z)
	)
	var right_plate: PressurePlateSwitch = _spawn_pressure_plate(
		"BalanceRightPlate",
		"balance_right_plate",
		Vector3(4.4, 0.0, z)
	)
	for plate: PressurePlateSwitch in [left_plate, right_plate]:
		plate.scale = Vector3(1.35, 1.0, 1.35)
		plate.maximum_reported_mass_kg = 12.0
	_spawn_value_crate(
		"BalanceCrate2kgA",
		Vector3(-1.8, 0.6, z - 2.0),
		2.0,
		Vector3(0.95, 0.95, 0.95),
		Color(0.28, 0.62, 0.78)
	)
	_spawn_value_crate(
		"BalanceCrate2kgB",
		Vector3(1.8, 0.6, z - 2.0),
		2.0,
		Vector3(0.95, 0.95, 0.95),
		Color(0.28, 0.62, 0.78)
	)
	_spawn_value_crate(
		"BalanceCrate3kg",
		Vector3(-1.8, 0.65, z + 1.2),
		3.0,
		Vector3(1.0, 1.0, 1.0),
		Color(0.34, 0.72, 0.46)
	)
	_spawn_value_crate(
		"BalanceCrate5kg",
		Vector3(1.8, 0.72, z + 1.2),
		5.0,
		Vector3(1.12, 1.12, 1.12),
		Color(0.78, 0.52, 0.2)
	)
	var comparator: MechanismValueComparator = _create_value_comparator(
		"BalanceComparator",
		"balance_comparator",
		"LEFT = RIGHT",
		MechanismValueComparator.Comparison.SOURCES_WITHIN_TOLERANCE,
		[left_plate, right_plate]
	)
	comparator.primary_source_id = left_plate.get_mechanism_id()
	comparator.secondary_source_id = right_plate.get_mechanism_id()
	comparator.tolerance = 0.1
	comparator.minimum_value = -12.0
	comparator.maximum_value = 12.0
	comparator.value_unit = "kg"
	_create_value_label(comparator, Vector3(0.0, 3.25, z + 2.2))
	var indicator: MechanismIndicator = _spawn_indicator(
		"BalanceIndicator",
		"SCALES BALANCED",
		Vector3(0.0, 0.0, z + 4.3)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"BalanceGate",
		"BALANCE GATE",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("BalanceIndicatorOutput", comparator, indicator)
	_wire_output("BalanceGateOutput", comparator, gate)
	station_states["balance_scale"] = {
		"value_comparator": comparator,
		"inputs": [left_plate, right_plate],
		"outputs": [indicator, gate],
	}


func _build_proportional_elevator_station(z: float) -> void:
	_create_station_platform(z, "11 • PROPORTIONAL OUTPUT: 0–10 KG → 0–6 M")
	var plate: PressurePlateSwitch = _spawn_pressure_plate(
		"ElevatorWeightPlate",
		"elevator_weight_plate",
		Vector3(-4.5, 0.0, z)
	)
	plate.scale = Vector3(1.4, 1.0, 1.4)
	plate.maximum_reported_mass_kg = 10.0
	_spawn_value_crate(
		"ElevatorCrate2kg",
		Vector3(-1.0, 0.6, z - 2.0),
		2.0,
		Vector3(0.95, 0.95, 0.95),
		Color(0.26, 0.62, 0.78)
	)
	_spawn_value_crate(
		"ElevatorCrate3kg",
		Vector3(-1.0, 0.65, z),
		3.0,
		Vector3(1.0, 1.0, 1.0),
		Color(0.32, 0.72, 0.48)
	)
	_spawn_value_crate(
		"ElevatorCrate5kg",
		Vector3(-1.0, 0.72, z + 2.0),
		5.0,
		Vector3(1.12, 1.12, 1.12),
		Color(0.78, 0.52, 0.2)
	)
	_create_static_box(
		"ValueElevatorLeftRail",
		Vector3(1.45, 3.0, z + 2.0),
		Vector3(0.25, 6.5, 0.25),
		Color(0.12, 0.35, 0.48)
	)
	_create_static_box(
		"ValueElevatorRightRail",
		Vector3(7.0, 3.0, z + 2.0),
		Vector3(0.25, 6.5, 0.25),
		Color(0.12, 0.35, 0.48)
	)
	var elevator: MechanismValueElevator = _spawn_value_elevator(
		"ProportionalElevator",
		"WEIGHT ELEVATOR",
		Vector3(4.2, 0.25, z + 2.0)
	)
	elevator.input_minimum = 0.0
	elevator.input_maximum = 10.0
	elevator.movement_offset = Vector3(0.0, 6.0, 0.0)
	_wire_value_output("ProportionalElevatorOutput", plate, elevator)
	station_states["proportional_elevator"] = {
		"inputs": [plate],
		"outputs": [elevator],
	}


func _create_value_comparator(
	node_name: String,
	mechanism_id: String,
	display_name: String,
	comparison: MechanismValueComparator.Comparison,
	sources: Array
) -> MechanismValueComparator:
	var comparator := MechanismValueComparator.new()
	comparator.name = node_name
	comparator.mechanism_id = mechanism_id
	comparator.display_name = display_name
	comparator.comparison = comparison
	network_root.add_child(comparator)
	for source_value: Variant in sources:
		if source_value is Node:
			comparator.bind_source(source_value as Node)
	value_comparators.append(comparator)
	return comparator


func _create_value_label(
	comparator: MechanismValueComparator,
	position_value: Vector3
) -> Label3D:
	var label := _create_station_label(
		comparator.display_name,
		position_value,
		Color(0.28, 0.86, 1.0)
	)
	label.font_size = 20
	value_labels[comparator.get_instance_id()] = label
	return label


func _wire_value_output(
	node_name: String,
	source: Node,
	target: Node
) -> MechanismOutputAdapter:
	var adapter := MechanismOutputAdapter.new()
	adapter.name = node_name
	adapter.mechanism_id = node_name.to_lower()
	adapter.display_name = node_name
	adapter.forward_value = true
	adapter.value_target_method = &"set_mechanism_value"
	adapter.also_apply_boolean_state = false
	network_root.add_child(adapter)
	adapter.bind_source(source)
	adapter.bind_target(target)
	output_adapters.append(adapter)
	return adapter


func _spawn_value_elevator(
	node_name: String,
	display_name: String,
	position_value: Vector3
) -> MechanismValueElevator:
	var elevator: MechanismValueElevator = (
		ValueElevatorScene.instantiate() as MechanismValueElevator
	)
	elevator.name = node_name
	elevator.display_name = display_name
	elevator.position = position_value
	mechanisms_root.add_child(elevator)
	output_nodes.append(elevator)
	return elevator


func _spawn_value_crate(
	node_name: String,
	position_value: Vector3,
	mass_kg: float,
	size_value: Vector3,
	color: Color
) -> RigidBody3D:
	var crate := RigidBody3D.new()
	crate.name = node_name
	crate.mass = maxf(mass_kg, 0.1)
	crate.position = position_value
	crate.add_to_group("mechanism_weights")
	crate.add_to_group("lab_resettable")
	crate.set_meta("mechanism_mass_kg", crate.mass)
	crate.set_meta("mechanism_initial_transform", crate.transform)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	crate.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, 0.18, 0.72)
	crate.add_child(mesh_instance)
	var label := Label3D.new()
	label.name = "MassLabel"
	label.position = Vector3(0.0, size_value.y * 0.75, 0.0)
	label.text = str(snappedf(crate.mass, 0.1)) + " KG"
	label.font_size = 22
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	crate.add_child(label)
	mechanisms_root.add_child(crate)
	return crate


func reset_lab() -> void:
	super.reset_lab()
	for comparator: MechanismValueComparator in value_comparators:
		if comparator != null and is_instance_valid(comparator):
			comparator.reset_target()
	for adapter: MechanismOutputAdapter in output_adapters:
		if adapter != null and is_instance_valid(adapter) and adapter.forward_value:
			adapter.apply_target_state()
	call_deferred("_refresh_all_presentations")


func _refresh_all_presentations() -> void:
	super._refresh_all_presentations()
	for comparator: MechanismValueComparator in value_comparators:
		_refresh_value_comparator_presentation(comparator)


func _refresh_value_comparator_presentation(
	comparator: MechanismValueComparator
) -> void:
	if comparator == null or not is_instance_valid(comparator):
		return
	var label: Label3D = value_labels.get(comparator.get_instance_id()) as Label3D
	if label == null or not is_instance_valid(label):
		return
	label.text = (
		comparator.display_name
		+ "\n"
		+ get_value_comparator_detail(comparator)
		+ " → "
		+ ("ON" if comparator.active else "OFF")
	)
	label.modulate = (
		Color(0.32, 1.0, 0.62)
		if comparator.active
		else Color(0.28, 0.78, 1.0)
	)


func get_value_comparator_detail(
	comparator: MechanismValueComparator
) -> String:
	if comparator.comparison == (
		MechanismValueComparator.Comparison.SOURCES_WITHIN_TOLERANCE
	):
		return (
			"L "
			+ str(snappedf(comparator.last_primary_value, 0.1))
			+ " kg • R "
			+ str(snappedf(comparator.last_secondary_value, 0.1))
			+ " kg • Δ "
			+ str(snappedf(comparator.last_difference, 0.1))
			+ " kg"
		)
	return (
		str(snappedf(comparator.last_primary_value, 0.1))
		+ " kg / "
		+ str(snappedf(comparator.threshold, 0.1))
		+ " kg"
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var comparator_data: Dictionary = {}
	for comparator: MechanismValueComparator in value_comparators:
		if comparator != null and is_instance_valid(comparator):
			comparator_data[comparator.get_mechanism_id()] = comparator.get_debug_data()
	data["value_signal_lab"] = true
	data["value_comparators"] = comparator_data
	data["value_comparator_count"] = value_comparators.size()
	return data
