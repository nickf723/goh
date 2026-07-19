extends Node3D
class_name BuoyancyLab

@export var readout_refresh_interval: float = 0.08

@onready var player: Node3D = get_node_or_null("Player") as Node3D

var initial_player_transform: Transform3D
var refresh_timer: float = 0.0
var completion_announced: bool = false

var density_pool: FluidForceVolume
var raft_pool: FluidForceVolume
var current_pool: FluidForceVolume
var boat_pool: FluidForceVolume
var density_bodies: Array[BuoyantFieldBody] = []
var raft: BuoyantFieldBody
var raft_receiver: BuoyancyReceiver
var load_sensor: BuoyancyLoadSensor
var cargo: Array[BuoyantFieldBody] = []
var current_float: BuoyantFieldBody
var current_sink: BuoyantFieldBody
var boat: BuoyantFieldBody
var boat_receiver: BuoyancyReceiver
var boat_shaft: RotationalShaftState
var boat_motor: ElectricMotorComponent
var boat_source: CircuitVoltageSource
var boat_solver: DCCircuitSolver
var propeller: FluidPropellerDrive
var density_readout: Label3D
var raft_readout: Label3D
var current_readout: Label3D
var boat_readout: Label3D
var initial_boat_position: Vector3


func _ready() -> void:
	build_environment()
	resolve_stations(BuoyancyLabStation.build(self))
	configure_player()
	GameState.set_objective("Observe density, cargo displacement, current flow, and the electric motorboat.")
	update_presentation()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = max(readout_refresh_interval, 0.03)
	update_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_lab()


func build_environment() -> void:
	ThermalLabGeometry.add_static_box(
		self, "FrontWalkway", Vector3(0.0, -0.5, -4.6),
		Vector3(27.0, 1.0, 5.0), Color(0.035, 0.045, 0.065, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "LeftWalkway", Vector3(-12.0, -0.5, 5.0),
		Vector3(3.0, 1.0, 19.0), Color(0.035, 0.045, 0.065, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "RightWalkway", Vector3(12.0, -0.5, 5.0),
		Vector3(3.0, 1.0, 19.0), Color(0.035, 0.045, 0.065, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "BackWalkway", Vector3(0.0, -0.5, 12.0),
		Vector3(27.0, 1.0, 2.5), Color(0.035, 0.045, 0.065, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "BackWall", Vector3(0.0, 2.0, 13.1),
		Vector3(27.0, 5.0, 0.6), Color(0.065, 0.08, 0.115, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "LeftWall", Vector3(-13.4, 2.0, 4.0),
		Vector3(0.6, 5.0, 18.8), Color(0.065, 0.08, 0.115, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "RightWall", Vector3(13.4, 2.0, 4.0),
		Vector3(0.6, 5.0, 18.8), Color(0.065, 0.08, 0.115, 1.0)
	)

	var directional := DirectionalLight3D.new()
	directional.name = "DirectionalLight3D"
	directional.rotation_degrees = Vector3(-58.0, -30.0, 0.0)
	directional.light_energy = 1.35
	directional.shadow_enabled = true
	add_child(directional)

	var fill_light := OmniLight3D.new()
	fill_light.name = "WaterFillLight"
	fill_light.position = Vector3(0.0, 5.0, 4.0)
	fill_light.light_color = Color(0.35, 0.68, 1.0, 1.0)
	fill_light.light_energy = 4.0
	fill_light.omni_range = 24.0
	add_child(fill_light)

	ThermalLabGeometry.add_label(
		self, "Title", "BUOYANCY & FLUID FORCES",
		Vector3(0.0, 5.25, -6.4), 42, Color(0.48, 0.88, 1.0, 1.0)
	)
	ThermalLabGeometry.add_label(
		self, "Instructions",
		"DENSITY SETS FLOAT DEPTH  •  CARGO ADDS LOAD  •  CURRENT ADDS FLOW  •  INTERACT WITH BOAT BATTERY TO REVERSE  •  F8 RESET",
		Vector3(0.0, 4.5, -6.15), 19, Color(0.8, 0.9, 1.0, 1.0)
	)


func resolve_stations(data: Dictionary) -> void:
	density_pool = data.get("density_pool") as FluidForceVolume
	raft_pool = data.get("raft_pool") as FluidForceVolume
	current_pool = data.get("current_pool") as FluidForceVolume
	boat_pool = data.get("boat_pool") as FluidForceVolume
	for node: Variant in data.get("density_bodies", []):
		var body := node as BuoyantFieldBody
		if body != null:
			density_bodies.append(body)
	raft = data.get("raft") as BuoyantFieldBody
	raft_receiver = data.get("raft_receiver") as BuoyancyReceiver
	load_sensor = data.get("load_sensor") as BuoyancyLoadSensor
	for node: Variant in data.get("cargo", []):
		var body := node as BuoyantFieldBody
		if body != null:
			cargo.append(body)
	current_float = data.get("current_float") as BuoyantFieldBody
	current_sink = data.get("current_sink") as BuoyantFieldBody
	boat = data.get("boat") as BuoyantFieldBody
	boat_receiver = data.get("boat_receiver") as BuoyancyReceiver
	boat_shaft = data.get("boat_shaft") as RotationalShaftState
	boat_motor = data.get("boat_motor") as ElectricMotorComponent
	boat_source = data.get("boat_source") as CircuitVoltageSource
	boat_solver = data.get("boat_solver") as DCCircuitSolver
	propeller = data.get("propeller") as FluidPropellerDrive
	density_readout = data.get("density_readout") as Label3D
	raft_readout = data.get("raft_readout") as Label3D
	current_readout = data.get("current_readout") as Label3D
	boat_readout = data.get("boat_readout") as Label3D
	if boat != null:
		initial_boat_position = boat.global_position


func configure_player() -> void:
	if player == null:
		push_warning("Buoyancy laboratory could not find the player.")
		return
	player.add_to_group("player")
	initial_player_transform = player.transform
	GameState.set_stat("mana", 999)


func update_presentation() -> void:
	update_density_readout()
	update_raft_readout()
	update_current_readout()
	update_boat_readout()
	if (
		not completion_announced
		and boat != null
		and boat.global_position.distance_to(initial_boat_position) > 1.5
	):
		completion_announced = true
		GameState.set_objective("Reverse the boat battery, then compare the current float and sinking stone.")
		show_message("Electric rotation is now producing submerged propeller thrust.")


func update_density_readout() -> void:
	if density_readout == null:
		return
	var lines: Array[String] = ["DENSITY TEST"]
	for body: BuoyantFieldBody in density_bodies:
		var receiver := body.get_node_or_null("BuoyancyReceiver") as BuoyancyReceiver
		var material_density: float = body.material_profile.density_kg_m3 if body.material_profile != null else 0.0
		lines.append(
			body.body_label + "  " + str(snapped(material_density, 1.0)) + " kg/m³"
			+ "  SUBMERGED " + str(snapped(receiver.submerged_fraction * 100.0, 1.0)) + "%"
			+ "  " + receiver.fluid_state.to_upper()
		)
	density_readout.text = "\n".join(lines)


func update_raft_readout() -> void:
	if raft_readout == null or raft_receiver == null:
		return
	var cargo_names: String = ", ".join(load_sensor.last_body_names) if load_sensor != null else "none"
	raft_readout.text = (
		"CARGO RAFT"
		+ "\nLOAD: " + str(snapped(raft_receiver.external_load_kg, 0.1)) + " kg"
		+ "  TOTAL: " + str(snapped(raft_receiver.total_mass_kg, 0.1)) + " kg"
		+ "\nSUBMERGED: " + str(snapped(raft_receiver.submerged_fraction * 100.0, 1.0)) + "%"
		+ "  STATE: " + raft_receiver.fluid_state.to_upper()
		+ "\nDECK SENSOR: " + cargo_names
	)


func update_current_readout() -> void:
	if current_readout == null or current_pool == null:
		return
	var float_receiver := current_float.get_node_or_null("BuoyancyReceiver") as BuoyancyReceiver if current_float != null else null
	var sink_receiver := current_sink.get_node_or_null("BuoyancyReceiver") as BuoyancyReceiver if current_sink != null else null
	current_readout.text = (
		"FLOW CHANNEL"
		+ "\nCURRENT: " + str(current_pool.flow_velocity_m_s) + " m/s"
		+ "\nFLOAT SPEED: " + str(snapped(current_float.velocity.length(), 0.01) if current_float != null else 0.0)
		+ "  " + (float_receiver.fluid_state.to_upper() if float_receiver != null else "NONE")
		+ "\nSTONE SPEED: " + str(snapped(current_sink.velocity.length(), 0.01) if current_sink != null else 0.0)
		+ "  " + (sink_receiver.fluid_state.to_upper() if sink_receiver != null else "NONE")
	)


func update_boat_readout() -> void:
	if boat_readout == null or boat == null or boat_receiver == null:
		return
	var circuit_text: String = "CLOSED" if boat_solver != null and boat_solver.circuit_closed else "OPEN"
	var direction_text: String = "FORWARD" if boat_source != null and boat_source.polarity_sign > 0 else "REVERSE"
	boat_readout.text = (
		"ELECTRIC MOTORBOAT"
		+ "\nBATTERY: " + direction_text + "  CIRCUIT: " + circuit_text
		+ "  CURRENT: " + str(snapped(boat_solver.current_amps, 0.01) if boat_solver != null else 0.0) + " A"
		+ "\nMOTOR: " + str(snapped(boat_shaft.current_rpm, 1.0) if boat_shaft != null else 0.0) + " RPM"
		+ "  PROPELLER: " + ("SUBMERGED" if propeller != null and propeller.submerged else "DRY")
		+ "\nTHRUST: " + str(snapped(propeller.last_thrust_newtons, 0.1) if propeller != null else 0.0) + " N"
		+ "  BOAT SPEED: " + str(snapped(boat.velocity.length(), 0.01))
		+ "\nSUBMERGED: " + str(snapped(boat_receiver.submerged_fraction * 100.0, 1.0)) + "%"
	)


func reset_lab() -> void:
	for body: BuoyantFieldBody in density_bodies:
		body.reset_target()
	if raft != null:
		raft.reset_target()
	for body: BuoyantFieldBody in cargo:
		body.reset_target()
	if current_float != null:
		current_float.reset_target()
	if current_sink != null:
		current_sink.reset_target()
	if boat != null:
		boat.reset_target()
	if boat_source != null:
		boat_source.reset_target()
	if boat_motor != null:
		boat_motor.reset_target()
	if boat_shaft != null:
		boat_shaft.reset_target()
	if propeller != null:
		propeller.reset_target()
	if boat_solver != null:
		boat_solver.request_solve()
	if player != null:
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	GameState.set_stat("mana", 999)
	completion_announced = false
	refresh_timer = 0.0
	call_deferred("update_presentation")
	show_message("Buoyancy laboratory reset.")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"buoyancy_lab": true,
		"density_pool": density_pool.get_debug_data() if density_pool != null else {},
		"raft": raft.get_debug_data() if raft != null else {},
		"current_pool": current_pool.get_debug_data() if current_pool != null else {},
		"boat": boat.get_debug_data() if boat != null else {},
		"propeller": propeller.get_debug_data() if propeller != null else {},
	}
