extends Node3D
class_name TrialChamber002ConductiveCircuit

signal stage_completed(stage_id: String)
signal optional_cache_unlocked
signal optional_reward_claimed(item_id: String, quantity: int)
signal trial_completed
signal trial_reset

enum TrialStage {
	METAL_LINK,
	WATER_PATH,
	SYNTHESIS,
	COMPLETE,
}

const TrialLoadout: AbilityLoadout = preload(
	"res://data/loadouts/trial_conductive_circuit_loadout.tres"
)
const CopperProfile: PhysicalMaterialProfile = preload(
	"res://data/materials/copper_physical_profile.tres"
)
const WaterProfile: PhysicalMaterialProfile = preload(
	"res://data/materials/water_physical_profile.tres"
)
const StatusReceiverScript: Script = preload(
	"res://scripts/combat/status_receiver.gd"
)
const PayloadReceiverScript: Script = preload(
	"res://scripts/combat/payload_receiver.gd"
)
const RewardChoiceChestScene: PackedScene = preload(
	"res://scenes/items/reward_choice_chest.tscn"
)

const COMPLETION_FLAG: String = "trial_chamber_002_conductive_circuit_complete"
const OPTIONAL_FLAG: String = "trial_chamber_002_optional_cache_powered"
const START_POSITION: Vector3 = Vector3(0.0, 1.0, 29.0)

var player: CharacterBody3D
var architecture_root: Node3D
var stage: TrialStage = TrialStage.METAL_LINK
var trial_complete: bool = false
var resetting: bool = false
var optional_cache_powered: bool = false
var optional_reward_taken: bool = false

var puzzle_one: Dictionary = {}
var puzzle_two: Dictionary = {}
var puzzle_three: Dictionary = {}
var optional_circuit: Dictionary = {}
var gate_one: StaticBody3D
var gate_two: StaticBody3D
var final_gate: StaticBody3D
var goal_area: Area3D
var goal_beacon: MeshInstance3D
var optional_chest: Node

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var bench_material: StandardMaterial3D
var copper_material: StandardMaterial3D
var water_material: StandardMaterial3D
var dry_channel_material: StandardMaterial3D
var lightning_material: StandardMaterial3D
var receiver_material: StandardMaterial3D
var gold_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("trial_chambers")
	add_to_group("spell_trials")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	GameState.set_flag(COMPLETION_FLAG, false)
	GameState.set_flag(OPTIONAL_FLAG, false)
	_build_materials()
	_build_chamber()
	_configure_trial_loadout()
	_restore_resources()
	_set_stage(TrialStage.METAL_LINK, false)
	_show_message(
		"Trial 002 • Conductive Circuit\n"
		+ "Complete each physical circuit, then pulse its violet input with Lightning."
	)
	set_process(true)


func _process(_delta: float) -> void:
	if resetting:
		return
	_update_wet_conductor(puzzle_two)
	_update_wet_conductor(puzzle_three)
	_update_wet_conductor(optional_circuit)
	_evaluate_main_circuits()
	_evaluate_optional_circuit()
	if player != null and player.global_position.y < -4.0:
		_show_message("The trial floor returns Grace to the entrance.")
		_reset_player_only()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_materials() -> void:
	floor_material = _make_material(Color(0.045, 0.055, 0.075, 1.0), 0.08, 0.9)
	wall_material = _make_material(Color(0.065, 0.08, 0.115, 1.0), 0.1, 0.86)
	bench_material = _make_material(Color(0.11, 0.13, 0.17, 1.0), 0.22, 0.7)
	copper_material = _make_material(Color(0.76, 0.29, 0.07, 1.0), 0.9, 0.24)
	water_material = _make_emissive(
		Color(0.06, 0.45, 0.7, 0.76),
		Color(0.06, 0.55, 0.9),
		1.15,
		true
	)
	dry_channel_material = _make_material(Color(0.095, 0.12, 0.16, 1.0), 0.12, 0.74)
	lightning_material = _make_emissive(
		Color(0.42, 0.26, 0.92, 1.0),
		Color(0.56, 0.36, 1.0),
		3.0
	)
	receiver_material = _make_emissive(
		Color(0.18, 0.31, 0.48, 1.0),
		Color(0.2, 0.64, 1.0),
		1.0
	)
	gold_material = _make_emissive(
		Color(0.82, 0.58, 0.1, 1.0),
		Color(1.0, 0.72, 0.16),
		3.1
	)


func _build_chamber() -> void:
	architecture_root = Node3D.new()
	architecture_root.name = "TrialArchitecture"
	add_child(architecture_root)

	_create_static_box("Floor", Vector3(0.0, -0.5, -2.0), Vector3(19.0, 1.0, 66.0), floor_material)
	_create_static_box("LeftWall", Vector3(-10.0, 6.0, -2.0), Vector3(1.0, 13.0, 66.0), wall_material)
	_create_static_box("RightWall", Vector3(10.0, 6.0, -2.0), Vector3(1.0, 13.0, 66.0), wall_material)
	_create_static_box("Ceiling", Vector3(0.0, 12.5, -2.0), Vector3(20.0, 1.0, 66.0), wall_material)
	_create_static_box("FrontWall", Vector3(0.0, 6.0, 31.0), Vector3(20.0, 13.0, 1.0), wall_material)
	_create_static_box("BackWall", Vector3(0.0, 6.0, -35.0), Vector3(20.0, 13.0, 1.0), wall_material)

	_build_puzzle_one()
	_build_puzzle_two()
	_build_optional_cache()
	_build_puzzle_three()
	_build_goal()
	_build_visual_language()


func _build_puzzle_one() -> void:
	var root := _make_room_root("PuzzleOneMetalLink", Vector3(0.0, 0.0, 20.0))
	_create_visual_box_under(root, "Bench", Vector3(0.0, 0.12, 0.0), Vector3(15.5, 0.24, 7.2), bench_material)
	puzzle_one = _build_circuit(
		root,
		"p1",
		Vector3.ZERO,
		6.0,
		2.15,
		1.7,
		"metal",
		"solid",
		0.0
	)
	gate_one = _create_barrier("GateOne", Vector3(0.0, 3.2, 12.0), Vector3(18.0, 6.5, 0.8))


func _build_puzzle_two() -> void:
	var root := _make_room_root("PuzzleTwoWaterPath", Vector3(0.0, 0.0, 5.0))
	_create_visual_box_under(root, "Bench", Vector3(0.0, 0.12, 0.0), Vector3(15.5, 0.24, 7.2), bench_material)
	puzzle_two = _build_circuit(
		root,
		"p2",
		Vector3.ZERO,
		6.0,
		2.15,
		1.7,
		"water",
		"solid",
		0.0
	)
	gate_two = _create_barrier("GateTwo", Vector3(0.0, 3.2, -3.0), Vector3(18.0, 6.5, 0.8))


func _build_optional_cache() -> void:
	var alcove := _make_room_root("OptionalCacheAlcove", Vector3(5.15, 0.0, -7.0))
	_create_visual_box_under(alcove, "CacheBench", Vector3(0.0, 0.12, 0.0), Vector3(8.2, 0.24, 6.2), bench_material)
	optional_circuit = _build_circuit(
		alcove,
		"optional",
		Vector3.ZERO,
		3.2,
		1.35,
		0.9,
		"metal",
		"solid",
		0.0
	)
	optional_chest = RewardChoiceChestScene.instantiate()
	optional_chest.name = "OptionalRewardChest"
	optional_chest.set("starts_locked", true)
	optional_chest.set("resettable_in_lab", false)
	if optional_chest is Node3D:
		(optional_chest as Node3D).position = Vector3(-5.8, 0.0, -8.3)
	if optional_chest.has_signal("reward_chosen"):
		optional_chest.connect("reward_chosen", _on_optional_reward_chosen)
	architecture_root.add_child(optional_chest)
	_create_visual_box("CachePlinth", Vector3(-5.8, 0.15, -8.3), Vector3(3.2, 0.3, 3.0), bench_material)


func _build_puzzle_three() -> void:
	var root := _make_room_root("PuzzleThreeSynthesis", Vector3(0.0, 0.0, -19.5))
	_create_visual_box_under(root, "Bench", Vector3(0.0, 0.12, 0.0), Vector3(15.5, 0.24, 7.2), bench_material)
	puzzle_three = _build_circuit(
		root,
		"p3",
		Vector3.ZERO,
		6.0,
		2.15,
		1.7,
		"metal",
		"water",
		0.0
	)
	final_gate = _create_barrier("FinalGate", Vector3(0.0, 3.2, -27.0), Vector3(18.0, 6.5, 0.8))


func _build_goal() -> void:
	goal_area = Area3D.new()
	goal_area.name = "CompletionSeal"
	goal_area.position = Vector3(0.0, 1.6, -31.0)
	goal_area.collision_layer = 0
	goal_area.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.0, 3.2, 5.0)
	collision.shape = shape
	goal_area.add_child(collision)
	goal_area.body_entered.connect(_on_goal_body_entered)
	architecture_root.add_child(goal_area)

	goal_beacon = MeshInstance3D.new()
	goal_beacon.name = "CompletionBeacon"
	goal_beacon.position = Vector3(0.0, 3.0, -33.4)
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 1.25
	beacon_mesh.bottom_radius = 1.25
	beacon_mesh.height = 0.18
	goal_beacon.mesh = beacon_mesh
	goal_beacon.rotation_degrees.x = 90.0
	goal_beacon.material_override = gold_material
	architecture_root.add_child(goal_beacon)


func _build_visual_language() -> void:
	_create_label("TRIAL 002", Vector3(0.0, 4.2, 29.8), Color(0.82, 0.88, 1.0), 24)
	_create_label("CONDUCTIVE CIRCUIT", Vector3(0.0, 3.35, 29.8), Color(1.0, 0.7, 0.2), 34)
	_create_label("I", Vector3(-8.8, 3.2, 20.0), Color(0.9, 0.46, 0.12), 30)
	_create_label("II", Vector3(-8.8, 3.2, 5.0), Color(0.2, 0.7, 1.0), 30)
	_create_label("CACHE", Vector3(7.7, 3.1, -7.0), Color(1.0, 0.72, 0.2), 19)
	_create_label("III", Vector3(-8.8, 3.2, -19.5), Color(0.65, 0.54, 1.0), 30)


func _make_room_root(node_name: String, position_value: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = position_value
	architecture_root.add_child(root)
	return root


func _build_circuit(
	parent: Node3D,
	circuit_id: String,
	origin: Vector3,
	half_width: float,
	terminal_z: float,
	gap_half: float,
	top_mode: String,
	bottom_mode: String,
	bridge_start_z: float
) -> Dictionary:
	var circuit_root := Node3D.new()
	circuit_root.name = circuit_id.capitalize() + "Circuit"
	circuit_root.position = origin
	parent.add_child(circuit_root)

	var source: CircuitExcitationPort = _create_excitation_port(
		circuit_root,
		circuit_id + "_source",
		Vector3(-half_width, 0.55, 0.0),
		terminal_z
	)
	var load: CircuitComponent = _create_load(
		circuit_root,
		circuit_id + "_receiver",
		Vector3(half_width, 0.55, 0.0),
		terminal_z
	)

	var data: Dictionary = {
		"id": circuit_id,
		"root": circuit_root,
		"source": source,
		"load": load,
		"solver": null,
		"metal_bridge": null,
		"metal_target_z": terminal_z,
		"metal_start_transform": Transform3D.IDENTITY,
		"wet_target": null,
		"wet_component": null,
		"water_visual": null,
		"water_latched": false,
		"solved": false,
	}

	_build_path_side(
		circuit_root,
		circuit_id,
		"top",
		top_mode,
		half_width,
		terminal_z,
		gap_half,
		bridge_start_z,
		data
	)
	_build_path_side(
		circuit_root,
		circuit_id,
		"bottom",
		bottom_mode,
		half_width,
		-terminal_z,
		gap_half,
		bridge_start_z,
		data
	)

	var solver := DCCircuitSolver.new()
	solver.name = "DCCircuitSolver"
	solver.solve_interval = 0.04
	circuit_root.add_child(solver)
	data["solver"] = solver
	return data


func _build_path_side(
	root: Node3D,
	circuit_id: String,
	side_name: String,
	mode: String,
	half_width: float,
	z_value: float,
	gap_half: float,
	bridge_start_z: float,
	data: Dictionary
) -> void:
	if mode == "solid":
		_create_conductor(
			root,
			circuit_id + "_" + side_name + "_solid",
			Vector3(0.0, 0.55, z_value),
			half_width * 2.0,
			CopperProfile,
			copper_material,
			0.16
		)
		return

	var segment_length: float = half_width - gap_half
	var center_offset: float = (half_width + gap_half) * 0.5
	_create_conductor(
		root,
		circuit_id + "_" + side_name + "_left",
		Vector3(-center_offset, 0.55, z_value),
		segment_length,
		CopperProfile,
		copper_material,
		0.12
	)
	_create_conductor(
		root,
		circuit_id + "_" + side_name + "_right",
		Vector3(center_offset, 0.55, z_value),
		segment_length,
		CopperProfile,
		copper_material,
		0.12
	)

	if mode == "metal":
		var bridge: RigidBody3D = _create_movable_copper_bridge(
			root,
			circuit_id + "_" + side_name + "_bridge",
			Vector3(0.0, 0.58, bridge_start_z),
			gap_half * 2.0
		)
		data["metal_bridge"] = bridge
		data["metal_target_z"] = z_value
		data["metal_start_transform"] = bridge.transform
		return

	if mode == "water":
		var wet_data: Dictionary = _create_wet_conductor(
			root,
			circuit_id + "_" + side_name + "_water",
			Vector3(0.0, 0.56, z_value),
			gap_half * 2.0
		)
		data["wet_target"] = wet_data["target"]
		data["wet_component"] = wet_data["component"]
		data["water_visual"] = wet_data["water_visual"]


func _create_excitation_port(
	parent: Node3D,
	component_id: String,
	position_value: Vector3,
	terminal_z: float
) -> CircuitExcitationPort:
	var port := CircuitExcitationPort.new()
	port.name = component_id.capitalize() + "Input"
	port.position = position_value
	port.component_id = component_id
	port.display_name = "Lightning Input"
	port.default_voltage_volts = 36.0
	port.default_duration_seconds = 0.9
	port.default_source_resistance_ohms = 0.45
	port.default_current_limit_amps = 12.0
	port.retain_polarity_between_pulses = true
	_create_terminal(port, "TerminalA", "positive", Vector3(0.0, 0.0, terminal_z), 0.42)
	_create_terminal(port, "TerminalB", "negative", Vector3(0.0, 0.0, -terminal_z), 0.42)

	# CircuitExcitationPort is a Node3D-based circuit component, not an Area3D.
	# Give it a child hit area so Lightning can discover the collider and then
	# resolve upward to the port's receive_damage_payload() implementation.
	var hit_area := Area3D.new()
	hit_area.name = "LightningTargetArea"
	hit_area.collision_layer = 1
	hit_area.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	collision.shape = shape
	collision.position = Vector3(0.0, 1.0, 0.0)
	hit_area.add_child(collision)
	port.add_child(hit_area)

	var rod := MeshInstance3D.new()
	rod.name = "LightningRod"
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.18
	rod_mesh.bottom_radius = 0.18
	rod_mesh.height = 2.2
	rod_mesh.radial_segments = 12
	rod.mesh = rod_mesh
	rod.position = Vector3(0.0, 1.05, 0.0)
	rod.material_override = lightning_material
	port.add_child(rod)
	parent.add_child(port)
	return port


func _create_load(
	parent: Node3D,
	component_id: String,
	position_value: Vector3,
	terminal_z: float
) -> CircuitComponent:
	var load := CircuitComponent.new()
	load.name = component_id.capitalize() + "Receiver"
	load.component_id = component_id
	load.display_name = "Receiver"
	load.component_kind = "load"
	load.material_profile = CopperProfile
	load.resistance_ohms = 2.0
	load.position = position_value
	_create_terminal(load, "TerminalA", "a", Vector3(0.0, 0.0, terminal_z), 0.42)
	_create_terminal(load, "TerminalB", "b", Vector3(0.0, 0.0, -terminal_z), 0.42)
	var mesh_instance := _make_box_mesh(Vector3(0.9, 0.9, terminal_z * 2.0), receiver_material)
	mesh_instance.name = "ReceiverBody"
	load.add_child(mesh_instance)
	parent.add_child(load)
	return load


func _create_conductor(
	parent: Node3D,
	component_id: String,
	position_value: Vector3,
	length: float,
	profile: PhysicalMaterialProfile,
	material: Material,
	resistance: float
) -> CircuitComponent:
	var component := CircuitComponent.new()
	component.name = component_id.capitalize()
	component.component_id = component_id
	component.display_name = "Conductor"
	component.material_profile = profile
	component.resistance_ohms = resistance
	component.position = position_value
	_create_terminal(component, "TerminalA", "a", Vector3(-length * 0.5, 0.0, 0.0), 0.42)
	_create_terminal(component, "TerminalB", "b", Vector3(length * 0.5, 0.0, 0.0), 0.42)
	var visual := _make_box_mesh(Vector3(length, 0.16, 0.16), material)
	visual.name = "ConductorVisual"
	component.add_child(visual)
	parent.add_child(component)
	return component


func _create_movable_copper_bridge(
	parent: Node3D,
	component_id: String,
	position_value: Vector3,
	length: float
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = component_id.capitalize() + "Body"
	body.position = position_value
	body.mass = 4.0
	body.linear_damp = 4.5
	body.angular_damp = 10.0
	body.axis_lock_linear_x = true
	body.axis_lock_linear_y = true
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.axis_lock_angular_z = true
	body.collision_layer = 1
	body.collision_mask = 1

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 0.5, 0.72)
	collision.shape = shape
	body.add_child(collision)
	var visual := _make_box_mesh(Vector3(length, 0.5, 0.72), copper_material)
	visual.name = "CopperLinkVisual"
	body.add_child(visual)

	var component := CircuitComponent.new()
	component.name = "CircuitComponent"
	component.component_id = component_id
	component.display_name = "Movable Copper Link"
	component.material_profile = CopperProfile
	component.resistance_ohms = 0.1
	_create_terminal(component, "TerminalA", "a", Vector3(-length * 0.5, 0.0, 0.0), 0.72)
	_create_terminal(component, "TerminalB", "b", Vector3(length * 0.5, 0.0, 0.0), 0.72)
	body.add_child(component)

	var anchor := MetalTetherAnchor3D.new()
	anchor.name = "MetalTetherAnchor"
	anchor.position = Vector3(0.0, 0.62, 0.0)
	anchor.anchor_id = component_id + "_anchor"
	anchor.display_name = "Copper Link"
	anchor.break_strength = 6000.0
	anchor.maximum_transferred_force = 4200.0
	body.add_child(anchor)
	_build_anchor_visual(anchor)
	parent.add_child(body)
	return body


func _create_wet_conductor(
	parent: Node3D,
	component_id: String,
	position_value: Vector3,
	length: float
) -> Dictionary:
	var target := Area3D.new()
	target.name = component_id.capitalize() + "Channel"
	target.position = position_value
	target.collision_layer = 1
	target.collision_mask = 1

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 0.55, 1.0)
	collision.shape = shape
	target.add_child(collision)
	var dry_visual := _make_box_mesh(Vector3(length, 0.12, 0.9), dry_channel_material)
	dry_visual.name = "DryChannelVisual"
	target.add_child(dry_visual)
	var water_visual := _make_box_mesh(Vector3(length, 0.18, 0.92), water_material)
	water_visual.name = "WaterFillVisual"
	water_visual.position.y = 0.08
	water_visual.visible = false
	target.add_child(water_visual)

	var status_receiver := Node.new()
	status_receiver.name = "StatusReceiver"
	status_receiver.set_script(StatusReceiverScript)
	target.add_child(status_receiver)
	var payload_receiver := Node.new()
	payload_receiver.name = "PayloadReceiver"
	payload_receiver.set_script(PayloadReceiverScript)
	target.add_child(payload_receiver)

	var component := CircuitComponent.new()
	component.name = "CircuitComponent"
	component.component_id = component_id
	component.display_name = "Water Conduit"
	component.material_profile = WaterProfile
	component.resistance_ohms = max(WaterProfile.electrical_resistivity, 0.5)
	component.path_enabled = false
	_create_terminal(component, "TerminalA", "a", Vector3(-length * 0.5, 0.0, 0.0), 0.58)
	_create_terminal(component, "TerminalB", "b", Vector3(length * 0.5, 0.0, 0.0), 0.58)
	target.add_child(component)
	parent.add_child(target)
	return {
		"target": target,
		"component": component,
		"water_visual": water_visual,
	}


func _create_terminal(
	parent: Node3D,
	node_name: String,
	terminal_id: String,
	position_value: Vector3,
	connection_radius: float
) -> CircuitTerminal:
	var terminal := CircuitTerminal.new()
	terminal.name = node_name
	terminal.terminal_id = terminal_id
	terminal.position = position_value
	terminal.connection_radius = connection_radius
	parent.add_child(terminal)
	return terminal


func _build_anchor_visual(anchor: Node3D) -> void:
	var core := MeshInstance3D.new()
	core.name = "AnchorCore"
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	core.mesh = sphere
	core.material_override = gold_material
	anchor.add_child(core)
	var ring := MeshInstance3D.new()
	ring.name = "AnchorRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.4
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = gold_material
	anchor.add_child(ring)


func _update_wet_conductor(data: Dictionary) -> void:
	if data.is_empty() or bool(data.get("water_latched", false)):
		return
	var target: Node = data.get("wet_target") as Node
	var component: CircuitComponent = data.get("wet_component") as CircuitComponent
	if target == null or component == null:
		return
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	if status_receiver == null or not status_receiver.has_method("has_status"):
		return
	if not bool(status_receiver.call("has_status", "wet")):
		return
	data["water_latched"] = true
	component.path_enabled = true
	var water_visual: Node3D = data.get("water_visual") as Node3D
	if water_visual != null:
		water_visual.visible = true
	var solver: DCCircuitSolver = data.get("solver") as DCCircuitSolver
	if solver != null:
		solver.request_solve()
	_show_message("Water fills the dry channel and becomes part of the conductive path.")


func _evaluate_main_circuits() -> void:
	if stage == TrialStage.METAL_LINK and _circuit_load_is_powered(puzzle_one):
		puzzle_one["solved"] = true
		_set_barrier_open(gate_one, true)
		stage_completed.emit("metal_link")
		_set_stage(TrialStage.WATER_PATH)
		_show_message("Current reaches the first receiver. The next chamber opens.")
		return
	if stage == TrialStage.WATER_PATH and _circuit_load_is_powered(puzzle_two):
		puzzle_two["solved"] = true
		_set_barrier_open(gate_two, true)
		stage_completed.emit("water_path")
		_set_stage(TrialStage.SYNTHESIS)
		_show_message("The filled channel carries the pulse. The synthesis chamber opens.")
		return
	if stage == TrialStage.SYNTHESIS and _circuit_load_is_powered(puzzle_three):
		puzzle_three["solved"] = true
		_set_barrier_open(final_gate, true)
		stage_completed.emit("synthesis")
		_set_stage(TrialStage.COMPLETE)
		_show_message("Metal and water complete one loop. The final seal releases.")


func _evaluate_optional_circuit() -> void:
	if optional_cache_powered or not _circuit_load_is_powered(optional_circuit):
		return
	optional_cache_powered = true
	GameState.set_flag(OPTIONAL_FLAG, true)
	if optional_chest != null and optional_chest.has_method("unlock_chest"):
		optional_chest.call("unlock_chest")
	optional_cache_unlocked.emit()
	_show_message("A side receiver flickers awake. The cache unlocks.")
	_restore_stage_objective()


func _circuit_load_is_powered(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var load: CircuitComponent = data.get("load") as CircuitComponent
	return load != null and load.energized


func _set_stage(next_stage: TrialStage, announce: bool = true) -> void:
	stage = next_stage
	_restore_stage_objective()
	if announce and stage != TrialStage.COMPLETE:
		GameFeedback.play("objective_update", {"source": "trial_002"})


func _restore_stage_objective() -> void:
	match stage:
		TrialStage.METAL_LINK:
			_set_objective("Puzzle I: complete the copper loop, then pulse the violet input with Lightning.")
		TrialStage.WATER_PATH:
			_set_objective("Puzzle II: fill the dry channel, then energize the circuit.")
		TrialStage.SYNTHESIS:
			_set_objective("Puzzle III: complete both missing links, then energize the final receiver.")
		TrialStage.COMPLETE:
			_set_objective("The final passage is open. Reach the gold seal.")


func _on_goal_body_entered(body: Node3D) -> void:
	if trial_complete or body == null or not body.is_in_group("player"):
		return
	if stage != TrialStage.COMPLETE:
		_show_message("The final receiver is still dark.")
		return
	trial_complete = true
	GameState.set_flag(COMPLETION_FLAG, true)
	_set_objective("Trial 002 complete. Conductive topology mastered.")
	_show_message("Conductive Circuit complete. The trial accepted the powered network.")
	if goal_beacon != null:
		goal_beacon.scale = Vector3.ONE * 1.4
	trial_completed.emit()


func _on_optional_reward_chosen(item_id: String, quantity: int) -> void:
	optional_reward_taken = true
	optional_reward_claimed.emit(item_id, quantity)
	_restore_stage_objective()


func reset_trial() -> void:
	if resetting:
		return
	resetting = true
	trial_complete = false
	GameState.set_flag(COMPLETION_FLAG, false)
	GameState.set_flag(OPTIONAL_FLAG, optional_reward_taken)
	_reset_circuit(puzzle_one)
	_reset_circuit(puzzle_two)
	_reset_circuit(puzzle_three)
	_reset_circuit(optional_circuit)
	_set_barrier_open(gate_one, false)
	_set_barrier_open(gate_two, false)
	_set_barrier_open(final_gate, false)
	optional_cache_powered = optional_reward_taken
	if optional_chest != null and not optional_reward_taken and optional_chest.has_method("reset_chest"):
		optional_chest.call("reset_chest")
	if goal_beacon != null:
		goal_beacon.scale = Vector3.ONE
	_reset_player_only()
	_configure_trial_loadout()
	_restore_resources()
	_set_stage(TrialStage.METAL_LINK, false)
	trial_reset.emit()
	resetting = false


func _reset_circuit(data: Dictionary) -> void:
	if data.is_empty():
		return
	data["solved"] = false
	data["water_latched"] = false
	var source: Node = data.get("source") as Node
	if source != null and source.has_method("reset_target"):
		source.call("reset_target")
	var wet_target: Node = data.get("wet_target") as Node
	if wet_target != null:
		var status_receiver: Node = wet_target.get_node_or_null("StatusReceiver")
		if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
			status_receiver.call("clear_all_statuses")
	var wet_component: CircuitComponent = data.get("wet_component") as CircuitComponent
	if wet_component != null:
		wet_component.path_enabled = false
	var water_visual: Node3D = data.get("water_visual") as Node3D
	if water_visual != null:
		water_visual.visible = false
	var bridge: RigidBody3D = data.get("metal_bridge") as RigidBody3D
	if bridge != null:
		bridge.transform = data.get("metal_start_transform", bridge.transform) as Transform3D
		bridge.linear_velocity = Vector3.ZERO
		bridge.angular_velocity = Vector3.ZERO
		bridge.sleeping = false
		var anchor: Node = bridge.get_node_or_null("MetalTetherAnchor")
		if anchor != null and anchor.has_method("reset_anchor"):
			anchor.call("reset_anchor")
	var solver: DCCircuitSolver = data.get("solver") as DCCircuitSolver
	if solver != null:
		solver.request_solve()


func _reset_player_only() -> void:
	if player == null:
		return
	var tether: Node = player.get_node_or_null("MetalTetherController")
	if tether != null and tether.has_method("release_tether"):
		tether.call("release_tether", "trial reset", false)
	player.global_position = START_POSITION
	player.rotation_degrees = Vector3.ZERO
	player.velocity = Vector3.ZERO


func _configure_trial_loadout() -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster != null:
		caster.set("loadout", TrialLoadout.duplicate(true))
		caster.set("current_ability_index", 0)
		if caster.has_method("align_focus_menu_to_current_ability"):
			caster.call("align_focus_menu_to_current_ability")
		if caster.has_method("emit_current_ability"):
			caster.call("emit_current_ability")
	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	if aerial != null:
		if "double_jump_unlocked" in aerial:
			aerial.set("double_jump_unlocked", false)
		if "hover_unlocked" in aerial:
			aerial.set("hover_unlocked", false)
		if "flight_unlocked" in aerial:
			aerial.set("flight_unlocked", false)


func _restore_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _create_barrier(node_name: String, position_value: Vector3, size_value: Vector3) -> StaticBody3D:
	var body := _create_static_box(node_name, position_value, size_value, wall_material)
	body.set_meta("barrier_open", false)
	return body


func _set_barrier_open(barrier: StaticBody3D, open: bool) -> void:
	if barrier == null:
		return
	barrier.set_meta("barrier_open", open)
	var collision: CollisionShape3D = barrier.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", open)
	var visual: Node3D = barrier.get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.visible = not open


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
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual := _make_box_mesh(size_value, material)
	visual.name = "Visual"
	body.add_child(visual)
	architecture_root.add_child(body)
	return body


func _create_visual_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var visual := _make_box_mesh(size_value, material)
	visual.name = node_name
	visual.position = position_value
	architecture_root.add_child(visual)
	return visual


func _create_visual_box_under(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var visual := _make_box_mesh(size_value, material)
	visual.name = node_name
	visual.position = position_value
	parent.add_child(visual)
	return visual


func _make_box_mesh(size_value: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	return visual


func _create_label(text_value: String, position_value: Vector3, color: Color, size_value: int) -> void:
	var label := Label3D.new()
	label.name = text_value.replace(" ", "")
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	architecture_root.add_child(label)


func _make_material(
	color: Color,
	metallic: float,
	roughness: float,
	transparent: bool = false
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if transparent or color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _make_emissive(
	color: Color,
	emission: Color,
	energy: float,
	transparent: bool = false
) -> StandardMaterial3D:
	var material := _make_material(color, 0.16, 0.36, transparent)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _set_objective(text_value: String) -> void:
	GameState.set_objective(text_value)
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
		"trial_chamber_002": true,
		"trial_id": "conductive_circuit",
		"stage": TrialStage.keys()[int(stage)],
		"complete": trial_complete,
		"optional_cache_powered": optional_cache_powered,
		"optional_reward_taken": optional_reward_taken,
		"puzzle_one": _circuit_debug(puzzle_one),
		"puzzle_two": _circuit_debug(puzzle_two),
		"puzzle_three": _circuit_debug(puzzle_three),
		"optional": _circuit_debug(optional_circuit),
	}


func _circuit_debug(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var solver: DCCircuitSolver = data.get("solver") as DCCircuitSolver
	var bridge: RigidBody3D = data.get("metal_bridge") as RigidBody3D
	return {
		"solved": bool(data.get("solved", false)),
		"water_latched": bool(data.get("water_latched", false)),
		"metal_bridge_position": bridge.position if bridge != null else Vector3.ZERO,
		"metal_target_z": float(data.get("metal_target_z", 0.0)),
		"solver": solver.get_debug_data() if solver != null else {},
	}
