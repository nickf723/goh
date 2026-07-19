extends RefCounted
class_name BuoyancyTestFixture

const WoodProfile: PhysicalMaterialProfile = preload("res://data/materials/wood_physical_profile.tres")
const IronProfile: PhysicalMaterialProfile = preload("res://data/materials/iron_physical_profile.tres")
const IceProfile: PhysicalMaterialProfile = preload("res://data/materials/ice_physical_profile.tres")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "BuoyancyFixture"
	host.add_child(root)

	var water := FluidForceVolume.new()
	water.name = "TestWater"
	water.position = Vector3(0.0, -1.0, 0.0)
	water.volume_size = Vector3(10.0, 3.0, 10.0)
	water.fluid_density_kg_m3 = 1000.0
	water.create_default_visuals = false
	water.presentation_enabled = false
	water.horizontal_drag_coefficient = 3.0
	water.vertical_drag_coefficient = 3.5
	root.add_child(water)

	var wood_data: Dictionary = add_test_body(root, "Wood", WoodProfile, Vector3(0.0, 0.3, 0.0), 2.0, 0.0)
	var ice_data: Dictionary = add_test_body(root, "Ice", IceProfile, Vector3(2.0, 0.083, 0.0), 2.0, 0.0)
	var iron_data: Dictionary = add_test_body(root, "Iron", IronProfile, Vector3(-2.0, 0.0, 0.0), 4.0, 0.0)

	await host.get_tree().process_frame
	await host.get_tree().process_frame

	test_density_equilibrium(wood_data, ice_data, iron_data, failures)
	test_cargo_displacement(root, water, failures)
	test_current_and_exit(water, wood_data, failures)
	test_propeller_submersion(root, water, failures)

	root.queue_free()
	return failures


static func test_density_equilibrium(
	wood_data: Dictionary,
	ice_data: Dictionary,
	iron_data: Dictionary,
	failures: Array[String]
) -> void:
	var wood: BuoyantFieldBody = wood_data.get("body") as BuoyantFieldBody
	var wood_receiver: BuoyancyReceiver = wood_data.get("receiver") as BuoyancyReceiver
	var wood_force: ForceReceiver = wood_data.get("force") as ForceReceiver
	var wood_acceleration: float = wood_receiver.update_fluid_response(wood, wood_force, 0.016)
	if absf(wood_receiver.submerged_fraction - 0.7) > 0.03:
		failures.append("buoyancy: wood equilibrium setup should be about seventy percent submerged")
	if absf(wood_acceleration) > 0.8:
		failures.append("buoyancy: wood at its density-ratio draft should be near vertical equilibrium")

	var ice: BuoyantFieldBody = ice_data.get("body") as BuoyantFieldBody
	var ice_receiver: BuoyancyReceiver = ice_data.get("receiver") as BuoyancyReceiver
	var ice_force: ForceReceiver = ice_data.get("force") as ForceReceiver
	var ice_acceleration: float = ice_receiver.update_fluid_response(ice, ice_force, 0.016)
	if absf(ice_receiver.submerged_fraction - 0.917) > 0.035:
		failures.append("buoyancy: ice should float more deeply than wood")
	if absf(ice_acceleration) > 0.8:
		failures.append("buoyancy: ice at its density-ratio draft should be near equilibrium")

	var iron: BuoyantFieldBody = iron_data.get("body") as BuoyantFieldBody
	var iron_receiver: BuoyancyReceiver = iron_data.get("receiver") as BuoyancyReceiver
	var iron_force: ForceReceiver = iron_data.get("force") as ForceReceiver
	var iron_acceleration: float = iron_receiver.update_fluid_response(iron, iron_force, 0.016)
	if iron_receiver.submerged_fraction < 0.99:
		failures.append("buoyancy: iron test body should be fully submerged")
	if iron_acceleration >= -1.0 or iron_receiver.fluid_state != "sinking":
		failures.append("buoyancy: iron should remain negatively buoyant when fully submerged")


static func test_cargo_displacement(
	root: Node3D,
	water: FluidForceVolume,
	failures: Array[String]
) -> void:
	var raft_data: Dictionary = add_test_body(
		root, "Raft", WoodProfile, Vector3(0.0, 0.55, 2.5), 12.0, 0.03
	)
	var raft: BuoyantFieldBody = raft_data.get("body") as BuoyantFieldBody
	var receiver: BuoyancyReceiver = raft_data.get("receiver") as BuoyancyReceiver
	var force_receiver: ForceReceiver = raft_data.get("force") as ForceReceiver
	var sensor := BuoyancyLoadSensor.new()
	sensor.name = "BuoyancyLoadSensor"
	sensor.half_extents = Vector3(2.0, 1.0, 2.0)
	raft.add_child(sensor)
	receiver.load_sensor = sensor

	var unloaded_acceleration: float = receiver.update_fluid_response(raft, force_receiver, 0.016)
	var unloaded_density: float = receiver.effective_density_kg_m3

	var cargo_data: Dictionary = add_test_body(
		root, "Cargo", IronProfile, raft.global_position + Vector3(0.0, 0.65, 0.0), 6.0, 0.0
	)
	var cargo: BuoyantFieldBody = cargo_data.get("body") as BuoyantFieldBody
	cargo.add_to_group("physical_bodies")
	var loaded_acceleration: float = receiver.update_fluid_response(raft, force_receiver, 0.016)
	if receiver.external_load_kg < 5.9:
		failures.append("buoyancy: deck sensor should add nearby cargo mass to the raft")
	if receiver.effective_density_kg_m3 <= unloaded_density:
		failures.append("buoyancy: cargo should increase the raft's effective density")
	if loaded_acceleration >= unloaded_acceleration:
		failures.append("buoyancy: the same draft should provide less net lift after cargo is added")

	cargo.global_position += Vector3(5.0, 0.0, 0.0)
	receiver.update_fluid_response(raft, force_receiver, 0.016)
	if receiver.external_load_kg > 0.1:
		failures.append("buoyancy: cargo leaving the deck sensor should stop loading the raft")
	if water == null:
		failures.append("buoyancy: cargo fixture lost its fluid volume")


static func test_current_and_exit(
	water: FluidForceVolume,
	wood_data: Dictionary,
	failures: Array[String]
) -> void:
	var body: BuoyantFieldBody = wood_data.get("body") as BuoyantFieldBody
	var receiver: BuoyancyReceiver = wood_data.get("receiver") as BuoyancyReceiver
	var force_receiver: ForceReceiver = wood_data.get("force") as ForceReceiver
	water.flow_velocity_m_s = Vector3(2.0, 0.0, 0.0)
	body.velocity = Vector3.ZERO
	receiver.update_fluid_response(body, force_receiver, 0.016)
	var current_force: Vector3 = force_receiver.get_total_continuous_force()
	if current_force.x <= 0.1:
		failures.append("buoyancy: a current should apply force in its flow direction")

	body.global_position = Vector3(20.0, 2.0, 0.0)
	receiver.update_fluid_response(body, force_receiver, 0.016)
	if receiver.active_volume != null or receiver.submerged_fraction > 0.0:
		failures.append("buoyancy: leaving the water should clear the active fluid state")
	if force_receiver.get_total_continuous_force().length() > 0.001:
		failures.append("buoyancy: leaving the water should clear fluid drag and current forces")
	water.flow_velocity_m_s = Vector3.ZERO


static func test_propeller_submersion(
	root: Node3D,
	water: FluidForceVolume,
	failures: Array[String]
) -> void:
	var boat_data: Dictionary = add_test_body(
		root, "Boat", WoodProfile, Vector3(0.0, 0.35, -2.5), 18.0, 0.05
	)
	var boat: BuoyantFieldBody = boat_data.get("body") as BuoyantFieldBody
	var receiver: BuoyancyReceiver = boat_data.get("receiver") as BuoyancyReceiver
	var force_receiver: ForceReceiver = boat_data.get("force") as ForceReceiver
	receiver.update_fluid_response(boat, force_receiver, 0.016)

	var shaft := RotationalShaftState.new()
	shaft.name = "PropellerShaft"
	root.add_child(shaft)
	shaft.current_rpm = 1000.0
	shaft.target_rpm = 1000.0
	var propeller := FluidPropellerDrive.new()
	propeller.name = "Propeller"
	propeller.propeller_local_position = Vector3(0.0, -0.3, 0.0)
	propeller.thrust_direction_local = Vector3.FORWARD
	propeller.configure(shaft, boat, receiver)
	root.add_child(propeller)

	var forward_thrust: float = propeller.step_propeller(0.1)
	var forward_direction: Vector3 = propeller.last_direction_world
	if forward_thrust <= 0.0 or not propeller.submerged:
		failures.append("buoyancy: shaft RPM should create thrust while the propeller is submerged")

	shaft.current_rpm = -1000.0
	var reverse_thrust: float = propeller.step_propeller(0.1)
	if reverse_thrust <= 0.0 or forward_direction.dot(propeller.last_direction_world) > -0.9:
		failures.append("buoyancy: reversed shaft RPM should reverse submerged thrust")

	propeller.propeller_local_position = Vector3(0.0, 4.0, 0.0)
	shaft.current_rpm = 1000.0
	if propeller.step_propeller(0.1) > 0.0 or propeller.submerged:
		failures.append("buoyancy: a propeller above the surface must not create fluid thrust")
	if not is_finite(receiver.net_vertical_acceleration) or not is_finite(forward_thrust):
		failures.append("buoyancy: fluid calculations must remain finite")
	if water == null:
		failures.append("buoyancy: propeller fixture lost its fluid volume")


static func add_test_body(
	parent: Node3D,
	node_name: String,
	profile: PhysicalMaterialProfile,
	position_value: Vector3,
	mass_override: float,
	volume_override: float
) -> Dictionary:
	var body := BuoyantFieldBody.new()
	body.name = node_name
	body.body_label = node_name
	body.position = position_value
	body.material_profile = profile
	body.mass_override_kg = mass_override
	body.gravity_strength = 14.0
	var force_receiver := ForceReceiver.new()
	force_receiver.name = "ForceReceiver"
	force_receiver.continuous_linear_damping = 0.0
	force_receiver.continuous_angular_damping = 0.0
	body.add_child(force_receiver)
	var receiver := BuoyancyReceiver.new()
	receiver.name = "BuoyancyReceiver"
	receiver.body_height_m = 1.0
	receiver.volume_override_m3 = volume_override
	receiver.create_entry_ripples = false
	receiver.create_wake_ripples = false
	body.add_child(receiver)
	parent.add_child(body)
	return {
		"body": body,
		"force": force_receiver,
		"receiver": receiver,
	}
