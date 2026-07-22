extends Node3D
class_name PhysicalMechanismLab

@export var refresh_interval: float = 0.08

@onready var solver: DCCircuitSolver = get_node_or_null("DCCircuitSolver") as DCCircuitSolver
@onready var battery: CircuitVoltageSource = get_node_or_null("Circuit/Battery") as CircuitVoltageSource
@onready var pressure_plate: PressurePlateSwitch = get_node_or_null("Circuit/PressurePlate") as PressurePlateSwitch
@onready var door: CounterweightedSlidingDoor = get_node_or_null("Circuit/MotorizedDoor") as CounterweightedSlidingDoor
@onready var motor: ElectricMotorComponent = get_node_or_null("Circuit/MotorizedDoor/Motor") as ElectricMotorComponent
@onready var fuse_component: CircuitComponent = get_node_or_null("MovableFuse/CircuitComponent") as CircuitComponent
@onready var player: Node3D = get_node_or_null("Player") as Node3D
@onready var readout: Label3D = get_node_or_null("MechanismReadout") as Label3D

var refresh_timer: float = 0.0
var initial_player_transform: Transform3D
var completion_announced: bool = false


func _ready() -> void:
	add_to_group("debuggable")
	if player != null:
		player.add_to_group("player")
		initial_player_transform = player.transform
	GameState.set_objective("Stand on the pressure plate and trace power through the physical circuit to the door motor.")
	if solver != null:
		solver.request_solve()
	update_presentation()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = max(refresh_interval, 0.03)
	update_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_lab()


func update_presentation() -> void:
	for component: CircuitComponent in get_scoped_components():
		var current_glow: Node3D = component.get_node_or_null("CurrentGlow") as Node3D
		if current_glow != null:
			current_glow.visible = component.energized

	if readout != null:
		var circuit_text: String = "CLOSED" if solver != null and solver.circuit_closed else "OPEN"
		var plate_text: String = "PRESSED" if pressure_plate != null and pressure_plate.is_pressed else "RELEASED"
		var motor_text: String = "POWERED" if motor != null and motor.energized else "OFF"
		var fuse_text: String = "CONNECTED" if fuse_component != null and fuse_component.energized else "DISCONNECTED"
		var door_percent: int = int(round(door.open_fraction * 100.0)) if door != null else 0
		var current_text: String = str(snapped(solver.current_amps, 0.01)) if solver != null else "0"
		readout.text = (
			"PHYSICAL MECHANISM\n"
			+ "CIRCUIT: " + circuit_text + "   CURRENT: " + current_text + " A\n"
			+ "PLATE: " + plate_text + "   FUSE: " + fuse_text + "\n"
			+ "MOTOR: " + motor_text + "   DOOR: " + str(door_percent) + "%"
		)

	if not completion_announced and door != null and door.open_fraction >= 0.95:
		completion_announced = true
		GameState.set_objective("Step off the plate to let the counterweight close the door, or knock the copper fuse out of contact.")
		show_message("The complete physical circuit powers the motor and lifts the door.")


func get_scoped_components() -> Array[CircuitComponent]:
	var components: Array[CircuitComponent] = []
	for candidate: Node in get_tree().get_nodes_in_group("circuit_components"):
		if candidate is CircuitComponent and is_ancestor_of(candidate):
			components.append(candidate as CircuitComponent)
	return components


func reset_lab() -> void:
	if player != null:
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO

	for resettable: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if resettable != null and is_ancestor_of(resettable) and resettable.has_method("reset_target"):
			resettable.call("reset_target")

	completion_announced = false
	refresh_timer = 0.0
	if solver != null:
		solver.request_solve()
	call_deferred("update_presentation")
	GameState.set_objective("Stand on the pressure plate and trace power through the physical circuit to the door motor.")
	show_message("Physical mechanism laboratory reset.")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"physical_mechanism_lab": true,
		"solver": solver.get_debug_data() if solver != null else {},
		"plate": pressure_plate.get_debug_data() if pressure_plate != null else {},
		"motor": motor.get_debug_data() if motor != null else {},
		"door": door.get_debug_data() if door != null else {},
		"fuse": fuse_component.get_debug_data() if fuse_component != null else {},
	}
