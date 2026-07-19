extends RefCounted
class_name MotorMachineStation

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")


static func build(host: Node3D) -> Dictionary:
	var data: Dictionary = GeneratorMachineStation.build(host)
	var root: Node3D = data.get("root") as Node3D
	var solver: DCCircuitSolver = data.get("solver") as DCCircuitSolver
	var old_coil: ElectromagneticCoilComponent = data.get("coil") as ElectromagneticCoilComponent
	var old_puck: FieldResponsiveBody = data.get("iron_puck") as FieldResponsiveBody
	var circuit_root: Node3D = old_coil.get_parent() as Node3D if old_coil != null else null
	var motor_position: Vector3 = old_coil.position if old_coil != null else Vector3(0.0, 0.8, 3.0)

	if old_coil != null:
		var coil_parent: Node = old_coil.get_parent()
		if coil_parent != null:
			coil_parent.remove_child(old_coil)
		old_coil.free()
	if old_puck != null:
		var puck_parent: Node = old_puck.get_parent()
		if puck_parent != null:
			puck_parent.remove_child(old_puck)
		old_puck.free()

	var motor_shaft := RotationalShaftState.new()
	motor_shaft.name = "MotorShaft"
	motor_shaft.position = Vector3(5.85, 1.2, 3.2)
	motor_shaft.maximum_abs_rpm = 1800.0
	motor_shaft.acceleration_rpm_per_second = 1100.0
	motor_shaft.deceleration_rpm_per_second = 520.0
	motor_shaft.rotation_axis = Vector3.FORWARD
	motor_shaft.rotor_visual_path = NodePath("Rotor")
	add_motor_rotor(motor_shaft)
	root.add_child(motor_shaft)

	var motor := ElectricMotorComponent.new()
	motor.name = "ElectricMotor"
	motor.component_id = "electric_motor"
	motor.display_name = "Electric Motor"
	motor.material_profile = CopperProfile
	motor.resistance_ohms = 2.6
	motor.max_current_amps = 8.0
	motor.minimum_activation_amps = 0.05
	motor.rpm_per_amp = 470.0
	motor.maximum_output_rpm = 1600.0
	motor.position = motor_position
	motor.configure_shaft(motor_shaft)
	ThermalLabGeometry.add_terminal(motor, "TerminalA", "a", Vector3(2.0, 0.0, 0.0), 0.36)
	ThermalLabGeometry.add_terminal(motor, "TerminalB", "b", Vector3(-2.0, 0.0, 0.0), 0.36)
	ThermalLabGeometry.add_box_visual(
		motor,
		"MotorBody",
		Vector3(2.0, 1.15, 1.15),
		Color(0.18, 0.34, 0.52, 1.0),
		true,
		1.5
	)
	add_motor_interaction(motor)
	if circuit_root != null:
		circuit_root.add_child(motor)

	add_motor_axle(root, circuit_root.position + motor_position if circuit_root != null else motor_position, motor_shaft.position)
	var conveyor_data: Dictionary = add_conveyor(root, motor_shaft)
	var conveyor: RotationalConveyorDrive = conveyor_data.get("drive") as RotationalConveyorDrive
	var carriage: Node3D = conveyor_data.get("carriage") as Node3D

	var motor_label := ThermalLabGeometry.add_label(
		host,
		"MotorLabel",
		"MOTOR WINDING\nFORWARD  •  INTERACT TO REVERSE",
		(circuit_root.position if circuit_root != null else Vector3.ZERO) + motor.position + Vector3(0.0, 1.65, 0.0),
		18,
		Color(0.62, 0.86, 1.0, 1.0)
	)
	var conveyor_label := ThermalLabGeometry.add_label(
		host,
		"ConveyorLabel",
		"CONVEYOR CLUTCH\nCOUPLED  •  INTERACT TO DISCONNECT",
		conveyor.position + Vector3(0.0, 2.15, 0.0),
		18,
		Color(0.72, 1.0, 0.72, 1.0)
	)

	if solver != null:
		solver.request_solve()
	data["coil"] = null
	data["magnetic_field"] = null
	data["iron_puck"] = null
	data["motor"] = motor
	data["motor_shaft"] = motor_shaft
	data["conveyor"] = conveyor
	data["carriage"] = carriage
	data["motor_label"] = motor_label
	data["conveyor_label"] = conveyor_label
	return data


static func add_motor_rotor(shaft: RotationalShaftState) -> void:
	var rotor := MeshInstance3D.new()
	rotor.name = "Rotor"
	var rotor_mesh := CylinderMesh.new()
	rotor_mesh.top_radius = 0.72
	rotor_mesh.bottom_radius = 0.72
	rotor_mesh.height = 0.46
	rotor_mesh.radial_segments = 20
	rotor.mesh = rotor_mesh
	rotor.rotation_degrees.x = 90.0
	rotor.material_override = ThermalLabGeometry.make_material(Color(0.2, 0.62, 1.0, 1.0), true, 2.0)
	shaft.add_child(rotor)
	for angle: float in [0.0, 60.0, 120.0]:
		var spoke := ThermalLabGeometry.add_box_visual(
			rotor,
			"MotorSpoke",
			Vector3(1.75, 0.13, 0.18),
			Color(0.65, 0.88, 1.0, 1.0),
			true,
			1.4
		)
		spoke.rotation_degrees.y = angle


static func add_motor_interaction(motor: ElectricMotorComponent) -> void:
	var area := Area3D.new()
	area.name = "WindingInteractionArea"
	area.monitoring = false
	area.monitorable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.8, 1.8)
	collision.shape = shape
	area.add_child(collision)
	motor.add_child(area)
	var handle := ThermalLabGeometry.add_box_visual(
		motor,
		"WindingHandle",
		Vector3(0.24, 1.15, 0.24),
		Color(1.0, 0.48, 0.08, 1.0),
		true,
		2.2
	)
	handle.position = Vector3(0.0, 1.0, 0.0)


static func add_motor_axle(root: Node3D, motor_position: Vector3, shaft_position: Vector3) -> void:
	var distance: float = absf(shaft_position.x - motor_position.x)
	var axle := ThermalLabGeometry.add_box_visual(
		root,
		"MotorAxle",
		Vector3(distance, 0.18, 0.18),
		Color(0.46, 0.58, 0.72, 1.0),
		true,
		0.9
	)
	axle.position = Vector3((motor_position.x + shaft_position.x) * 0.5, shaft_position.y, shaft_position.z)


static func add_conveyor(root: Node3D, shaft: RotationalShaftState) -> Dictionary:
	var drive := RotationalConveyorDrive.new()
	drive.name = "ConveyorDrive"
	drive.position = Vector3(5.85, 0.0, 0.2)
	drive.track_length = 5.0
	drive.revolutions_per_track_length = 5.0
	drive.starting_track_offset = 2.5

	for z_offset: float in [-0.58, 0.58]:
		var rail := ThermalLabGeometry.add_box_visual(
			drive,
			"ConveyorRail",
			Vector3(5.4, 0.18, 0.18),
			Color(0.24, 0.28, 0.34, 1.0),
			true,
			0.7
		)
		rail.position = Vector3(0.0, 0.3, z_offset)
	var belt := ThermalLabGeometry.add_box_visual(
		drive,
		"ConveyorBelt",
		Vector3(5.0, 0.12, 1.05),
		Color(0.08, 0.12, 0.17, 1.0),
		true,
		0.45
	)
	belt.position = Vector3(0.0, 0.35, 0.0)

	var carriage := Node3D.new()
	carriage.name = "CargoCarriage"
	carriage.position = Vector3(0.0, 0.78, 0.0)
	ThermalLabGeometry.add_box_visual(
		carriage,
		"Cargo",
		Vector3(0.9, 0.9, 0.9),
		Color(0.88, 0.48, 0.12, 1.0),
		true,
		1.3
	)
	drive.add_child(carriage)

	var collision := CollisionShape3D.new()
	collision.position = Vector3(0.0, 1.0, 1.25)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.8, 1.2)
	collision.shape = shape
	drive.add_child(collision)
	var clutch := ThermalLabGeometry.add_box_visual(
		drive,
		"ConveyorClutch",
		Vector3(1.35, 0.65, 0.65),
		Color(0.16, 0.66, 0.34, 1.0),
		true,
		1.8
	)
	clutch.position = Vector3(0.0, 1.0, 1.25)

	drive.configure(shaft, carriage)
	root.add_child(drive)
	return {
		"drive": drive,
		"carriage": carriage,
	}
