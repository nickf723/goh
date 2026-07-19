extends RefCounted
class_name BuoyancyLabStation

const WoodProfile: PhysicalMaterialProfile = preload("res://data/materials/wood_physical_profile.tres")
const IronProfile: PhysicalMaterialProfile = preload("res://data/materials/iron_physical_profile.tres")
const IceProfile: PhysicalMaterialProfile = preload("res://data/materials/ice_physical_profile.tres")
const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")


static func build(host: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "BuoyancyStations"
	host.add_child(root)

	var density_pool := add_pool(
		root,
		"DensityPool",
		Vector3(-7.2, -1.0, 1.2),
		Vector3(5.4, 3.0, 6.2),
		Vector3.ZERO,
		Color(0.08, 0.58, 0.88, 0.68),
		Color(0.015, 0.1, 0.3, 0.84)
	)
	var raft_pool := add_pool(
		root,
		"RaftPool",
		Vector3(0.0, -1.0, 1.2),
		Vector3(6.4, 3.0, 6.2),
		Vector3.ZERO,
		Color(0.08, 0.62, 0.86, 0.68),
		Color(0.012, 0.13, 0.3, 0.84)
	)
	var current_pool := add_pool(
		root,
		"CurrentPool",
		Vector3(7.2, -1.0, 1.2),
		Vector3(5.4, 3.0, 6.2),
		Vector3(0.0, 0.0, -2.4),
		Color(0.06, 0.7, 0.9, 0.7),
		Color(0.01, 0.16, 0.34, 0.86)
	)
	current_pool.horizontal_drag_coefficient = 3.8
	current_pool.wave_amplitude = 0.11
	current_pool.wave_speed = 1.35

	var boat_pool := add_pool(
		root,
		"BoatPool",
		Vector3(0.0, -1.0, 8.2),
		Vector3(19.8, 3.0, 5.0),
		Vector3.ZERO,
		Color(0.07, 0.56, 0.82, 0.7),
		Color(0.01, 0.09, 0.25, 0.86)
	)
	boat_pool.wave_amplitude = 0.1

	add_pool_borders(root, density_pool)
	add_pool_borders(root, raft_pool)
	add_pool_borders(root, current_pool)
	add_pool_borders(root, boat_pool)

	var stone_profile := make_stone_profile()
	var density_bodies: Array[BuoyantFieldBody] = []
	density_bodies.append(add_buoyant_box(
		root, "WoodBlock", "WOOD", Vector3(-8.7, 2.2, 1.2), Vector3.ONE,
		WoodProfile, Color(0.62, 0.34, 0.12, 1.0)
	))
	density_bodies.append(add_buoyant_box(
		root, "IceBlock", "ICE", Vector3(-7.7, 2.2, 1.2), Vector3.ONE,
		IceProfile, Color(0.58, 0.9, 1.0, 0.82)
	))
	density_bodies.append(add_buoyant_box(
		root, "StoneBlock", "STONE", Vector3(-6.7, 2.2, 1.2), Vector3.ONE,
		stone_profile, Color(0.34, 0.38, 0.44, 1.0)
	))
	density_bodies.append(add_buoyant_box(
		root, "IronBlock", "IRON", Vector3(-5.7, 2.2, 1.2), Vector3.ONE,
		IronProfile, Color(0.3, 0.34, 0.4, 1.0)
	))

	var raft := add_buoyant_box(
		root,
		"CargoRaft",
		"CARGO RAFT",
		Vector3(0.0, 1.25, 1.2),
		Vector3(4.3, 0.55, 2.7),
		WoodProfile,
		Color(0.52, 0.27, 0.08, 1.0),
		12.0,
		0.03
	)
	raft.angular_inertia = 5.0
	var raft_receiver := raft.get_node("BuoyancyReceiver") as BuoyancyReceiver
	raft_receiver.stability_scale = 1.8
	var load_sensor := BuoyancyLoadSensor.new()
	load_sensor.name = "BuoyancyLoadSensor"
	load_sensor.position = Vector3(0.0, 0.45, 0.0)
	load_sensor.half_extents = Vector3(2.0, 0.9, 1.2)
	raft.add_child(load_sensor)
	raft_receiver.load_sensor = load_sensor

	var cargo_a := add_buoyant_box(
		root, "CargoA", "IRON CARGO A", Vector3(-0.75, 2.05, 1.2), Vector3(0.8, 0.8, 0.8),
		IronProfile, Color(0.32, 0.36, 0.43, 1.0), 4.0
	)
	var cargo_b := add_buoyant_box(
		root, "CargoB", "IRON CARGO B", Vector3(0.75, 2.05, 1.2), Vector3(0.8, 0.8, 0.8),
		IronProfile, Color(0.38, 0.4, 0.46, 1.0), 4.0
	)

	var current_float := add_buoyant_box(
		root, "CurrentFloat", "CURRENT FLOAT", Vector3(7.2, 2.0, 3.1), Vector3(1.2, 0.8, 1.2),
		WoodProfile, Color(1.0, 0.62, 0.12, 1.0), 2.0
	)
	var current_sink := add_buoyant_box(
		root, "CurrentSink", "CURRENT STONE", Vector3(7.2, 2.0, 0.0), Vector3(1.0, 1.0, 1.0),
		stone_profile, Color(0.3, 0.34, 0.4, 1.0), 3.0
	)

	var boat_data: Dictionary = add_motorboat(root, Vector3(0.0, 1.25, 8.2))

	var density_readout := ThermalLabGeometry.add_label(
		host, "DensityReadout", "DENSITY TEST", Vector3(-7.2, 4.0, -1.6), 20,
		Color(0.74, 0.92, 1.0, 1.0)
	)
	var raft_readout := ThermalLabGeometry.add_label(
		host, "RaftReadout", "CARGO RAFT", Vector3(0.0, 4.0, -1.6), 20,
		Color(1.0, 0.78, 0.45, 1.0)
	)
	var current_readout := ThermalLabGeometry.add_label(
		host, "CurrentReadout", "FLOW CHANNEL", Vector3(7.2, 4.0, -1.6), 20,
		Color(0.55, 0.94, 1.0, 1.0)
	)
	var boat_readout := ThermalLabGeometry.add_label(
		host, "BoatReadout", "MOTORBOAT", Vector3(0.0, 4.0, 6.0), 20,
		Color(0.65, 0.85, 1.0, 1.0)
	)

	return {
		"root": root,
		"density_pool": density_pool,
		"raft_pool": raft_pool,
		"current_pool": current_pool,
		"boat_pool": boat_pool,
		"density_bodies": density_bodies,
		"raft": raft,
		"raft_receiver": raft_receiver,
		"load_sensor": load_sensor,
		"cargo": [cargo_a, cargo_b],
		"current_float": current_float,
		"current_sink": current_sink,
		"boat": boat_data.get("boat"),
		"boat_receiver": boat_data.get("receiver"),
		"boat_shaft": boat_data.get("shaft"),
		"boat_motor": boat_data.get("motor"),
		"boat_source": boat_data.get("source"),
		"boat_solver": boat_data.get("solver"),
		"propeller": boat_data.get("propeller"),
		"density_readout": density_readout,
		"raft_readout": raft_readout,
		"current_readout": current_readout,
		"boat_readout": boat_readout,
	}


static func add_pool(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	flow: Vector3,
	shallow: Color,
	deep: Color
) -> FluidForceVolume:
	var pool := FluidForceVolume.new()
	pool.name = node_name
	pool.position = position_value
	pool.volume_size = size
	pool.fluid_density_kg_m3 = 1000.0
	pool.flow_velocity_m_s = flow
	pool.shallow_color = shallow
	pool.deep_color = deep
	pool.foam_color = Color(0.7, 0.96, 1.0, 0.9)
	parent.add_child(pool)
	return pool


static func add_pool_borders(parent: Node3D, pool: FluidForceVolume) -> void:
	var size: Vector3 = pool.volume_size
	var center: Vector3 = pool.position
	var bottom_y: float = center.y - size.y * 0.5 - 0.2
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "Bottom", Vector3(center.x, bottom_y, center.z),
		Vector3(size.x + 0.5, 0.4, size.z + 0.5), Color(0.035, 0.06, 0.09, 1.0)
	)
	var wall_color := Color(0.08, 0.12, 0.17, 1.0)
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "LeftWall",
		Vector3(center.x - size.x * 0.5 - 0.18, center.y, center.z),
		Vector3(0.36, size.y + 0.7, size.z + 0.7), wall_color
	)
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "RightWall",
		Vector3(center.x + size.x * 0.5 + 0.18, center.y, center.z),
		Vector3(0.36, size.y + 0.7, size.z + 0.7), wall_color
	)
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "FrontWall",
		Vector3(center.x, center.y, center.z - size.z * 0.5 - 0.18),
		Vector3(size.x + 0.7, size.y + 0.7, 0.36), wall_color
	)
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "BackWall",
		Vector3(center.x, center.y, center.z + size.z * 0.5 + 0.18),
		Vector3(size.x + 0.7, size.y + 0.7, 0.36), wall_color
	)


static func add_buoyant_box(
	parent: Node3D,
	node_name: String,
	label: String,
	position_value: Vector3,
	size: Vector3,
	profile: PhysicalMaterialProfile,
	color: Color,
	mass_override: float = 0.0,
	volume_override: float = 0.0
) -> BuoyantFieldBody:
	var body := BuoyantFieldBody.new()
	body.name = node_name
	body.body_label = label
	body.position = position_value
	body.material_profile = profile
	body.mass_override_kg = mass_override
	body.gravity_strength = 14.0
	body.angular_inertia = max(size.length(), 1.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	ThermalLabGeometry.add_box_visual(body, "BodyVisual", size, color, true, 0.55)
	var force_receiver := ForceReceiver.new()
	force_receiver.name = "ForceReceiver"
	force_receiver.drag = 5.0
	force_receiver.max_force_speed = 8.0
	force_receiver.continuous_linear_damping = 0.9
	force_receiver.continuous_angular_damping = 3.4
	force_receiver.max_continuous_speed = 5.5
	body.add_child(force_receiver)
	var receiver := BuoyancyReceiver.new()
	receiver.name = "BuoyancyReceiver"
	receiver.body_height_m = size.y
	receiver.volume_override_m3 = volume_override
	receiver.maximum_horizontal_force = 95.0
	body.add_child(receiver)
	parent.add_child(body)
	return body


static func add_motorboat(parent: Node3D, position_value: Vector3) -> Dictionary:
	var boat := add_buoyant_box(
		parent, "Motorboat", "ELECTRIC MOTORBOAT", position_value,
		Vector3(4.0, 0.65, 2.8), WoodProfile, Color(0.18, 0.42, 0.62, 1.0),
		18.0, 0.05
	)
	boat.angular_inertia = 7.0
	var receiver := boat.get_node("BuoyancyReceiver") as BuoyancyReceiver
	receiver.stability_scale = 2.2

	var shaft := RotationalShaftState.new()
	shaft.name = "PropellerShaft"
	shaft.maximum_abs_rpm = 1800.0
	shaft.acceleration_rpm_per_second = 1000.0
	shaft.deceleration_rpm_per_second = 600.0
	boat.add_child(shaft)

	var source := CircuitVoltageSource.new()
	source.name = "BoatBattery"
	source.component_id = "boat_battery"
	source.display_name = "Boat Battery"
	source.nominal_voltage_volts = 12.0
	source.source_internal_resistance_ohms = 0.25
	source.position = Vector3(0.0, 0.55, -0.9)
	ThermalLabGeometry.add_terminal(source, "TerminalA", "negative", Vector3(-1.3, 0.0, 0.0), 0.3)
	ThermalLabGeometry.add_terminal(source, "TerminalB", "positive", Vector3(1.3, 0.0, 0.0), 0.3)
	ThermalLabGeometry.add_box_visual(source, "BatteryVisual", Vector3(1.25, 0.55, 0.75), Color(0.58, 0.2, 0.72, 1.0), true, 1.2)
	add_interaction_area(source, Vector3(1.6, 1.2, 1.0))
	boat.add_child(source)

	var motor := ElectricMotorComponent.new()
	motor.name = "BoatMotor"
	motor.component_id = "boat_motor"
	motor.display_name = "Boat Motor"
	motor.material_profile = CopperProfile
	motor.resistance_ohms = 3.0
	motor.rpm_per_amp = 520.0
	motor.maximum_output_rpm = 1600.0
	motor.position = Vector3(1.3, 0.55, 0.0)
	motor.configure_shaft(shaft)
	ThermalLabGeometry.add_terminal(motor, "TerminalA", "a", Vector3(0.0, 0.0, -0.9), 0.3)
	ThermalLabGeometry.add_terminal(motor, "TerminalB", "b", Vector3(0.0, 0.0, 0.9), 0.3)
	ThermalLabGeometry.add_box_visual(motor, "MotorVisual", Vector3(0.85, 0.65, 0.85), Color(0.12, 0.5, 0.92, 1.0), true, 1.5)
	boat.add_child(motor)

	var return_wire := CircuitComponent.new()
	return_wire.name = "BoatReturn"
	return_wire.component_id = "boat_return"
	return_wire.material_profile = CopperProfile
	return_wire.resistance_ohms = 0.18
	return_wire.position = Vector3(0.0, 0.55, 0.9)
	ThermalLabGeometry.add_terminal(return_wire, "TerminalA", "a", Vector3(1.3, 0.0, 0.0), 0.3)
	ThermalLabGeometry.add_terminal(return_wire, "TerminalB", "b", Vector3(-1.3, 0.0, 0.0), 0.3)
	ThermalLabGeometry.add_box_visual(return_wire, "WireVisual", Vector3(2.6, 0.12, 0.12), Color(0.84, 0.3, 0.06, 1.0), true, 0.8)
	boat.add_child(return_wire)

	var left_wire := CircuitComponent.new()
	left_wire.name = "BoatLeftWire"
	left_wire.component_id = "boat_left_wire"
	left_wire.material_profile = CopperProfile
	left_wire.resistance_ohms = 0.18
	left_wire.position = Vector3(-1.3, 0.55, 0.0)
	ThermalLabGeometry.add_terminal(left_wire, "TerminalA", "a", Vector3(0.0, 0.0, 0.9), 0.3)
	ThermalLabGeometry.add_terminal(left_wire, "TerminalB", "b", Vector3(0.0, 0.0, -0.9), 0.3)
	ThermalLabGeometry.add_box_visual(left_wire, "WireVisual", Vector3(0.12, 0.12, 1.8), Color(0.84, 0.3, 0.06, 1.0), true, 0.8)
	boat.add_child(left_wire)

	var solver := DCCircuitSolver.new()
	solver.name = "BoatCircuitSolver"
	solver.solve_interval = 0.05
	boat.add_child(solver)

	var propeller := FluidPropellerDrive.new()
	propeller.name = "FluidPropeller"
	propeller.propeller_local_position = Vector3(0.0, -0.35, 1.65)
	propeller.thrust_direction_local = Vector3.FORWARD
	propeller.thrust_newtons_per_1000_rpm = 30.0
	propeller.maximum_thrust_newtons = 44.0
	var propeller_visual := MeshInstance3D.new()
	propeller_visual.name = "PropellerVisual"
	var propeller_mesh := CylinderMesh.new()
	propeller_mesh.top_radius = 0.42
	propeller_mesh.bottom_radius = 0.42
	propeller_mesh.height = 0.16
	propeller_visual.mesh = propeller_mesh
	propeller_visual.rotation_degrees.x = 90.0
	propeller_visual.position = propeller.propeller_local_position
	propeller_visual.material_override = ThermalLabGeometry.make_material(Color(0.72, 0.82, 0.9, 1.0), true, 1.2)
	propeller.add_child(propeller_visual)
	propeller.visual = propeller_visual
	propeller.configure(shaft, boat, receiver)
	boat.add_child(propeller)

	solver.request_solve()
	return {
		"boat": boat,
		"receiver": receiver,
		"shaft": shaft,
		"source": source,
		"motor": motor,
		"solver": solver,
		"propeller": propeller,
	}


static func add_interaction_area(parent: Node3D, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.monitoring = false
	area.monitorable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	parent.add_child(area)


static func make_stone_profile() -> PhysicalMaterialProfile:
	var profile := PhysicalMaterialProfile.new()
	profile.material_id = "stone"
	profile.display_name = "Stone"
	profile.density_kg_m3 = 2600.0
	profile.default_mass_kg = 3.0
	profile.material_tags = ["stone", "mineral", "dense"]
	return profile
