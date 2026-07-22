extends Node3D
class_name SoulCircuitPuzzle

@export var objective_refresh_interval: float = 0.12
@export var slab_moved_distance: float = 1.25

@onready var solver: DCCircuitSolver = get_node_or_null("DCCircuitSolver") as DCCircuitSolver
@onready var pressure_plate: PressurePlateSwitch = get_node_or_null("Circuit/PressurePlate") as PressurePlateSwitch
@onready var door: CounterweightedSlidingDoor = get_node_or_null("Circuit/MotorizedDoor") as CounterweightedSlidingDoor
@onready var motor: ElectricMotorComponent = get_node_or_null("Circuit/MotorizedDoor/Motor") as ElectricMotorComponent
@onready var fuse_component: CircuitComponent = get_node_or_null("CopperFuse/CircuitComponent") as CircuitComponent
@onready var giant_slab: CharacterBody3D = get_node_or_null("GiantSlab") as CharacterBody3D
@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var exit_trigger: Area3D = get_node_or_null("ExitTrigger") as Area3D
@onready var reward_crate: BreakableProp = get_node_or_null("RewardCrate") as BreakableProp

var refresh_timer: float = 0.0
var initial_player_transform: Transform3D
var initial_slab_position: Vector3 = Vector3.ZERO
var last_objective: String = ""
var door_open_announced: bool = false
var solved: bool = false


func _ready() -> void:
	add_to_group("debuggable")
	if player != null:
		player.add_to_group("player")
		initial_player_transform = player.transform
	if giant_slab != null:
		initial_slab_position = giant_slab.global_position
	if exit_trigger != null and not exit_trigger.body_entered.is_connected(_on_exit_body_entered):
		exit_trigger.body_entered.connect(_on_exit_body_entered)
	if solver != null:
		solver.request_solve()
	set_objective_once("Restore the physical mechanism and open the silent gate.")
	show_message("Nothing here obeys an invisible switch. The machine must be made whole.")


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = max(objective_refresh_interval, 0.04)
	update_puzzle_guidance()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_puzzle()


func update_puzzle_guidance() -> void:
	if solved:
		return

	if door != null and door.open_fraction >= 0.9:
		set_objective_once("The gate is open. Pass through.")
		if not door_open_announced:
			door_open_announced = true
			show_message("The restored circuit turns the winch. The gate rises.")
		return

	if pressure_plate != null and pressure_plate.is_pressed:
		set_objective_once("The pressure switch is held. Fit the copper fuse into the return gap.")
		return

	if giant_slab != null and giant_slab.global_position.distance_to(initial_slab_position) >= slab_moved_distance:
		set_objective_once("The alcove is open. Recover the copper fuse and hold the pressure plate down.")
		return

	set_objective_once("Use Soul Grip to move the slab, recover the copper fuse, and hold the pressure plate.")


func set_objective_once(text: String) -> void:
	if text == last_objective:
		return
	last_objective = text
	GameState.set_objective(text)


func _on_exit_body_entered(body: Node3D) -> void:
	if solved or body == null:
		return
	if body != player and not body.is_in_group("player"):
		return
	solved = true
	set_objective_once("Puzzle solved. Claim the supplies beyond the gate.")
	show_message("The silent gatehouse lives again.")
	GameFeedback.play("heavy_impact", {"source": "soul_circuit_puzzle_complete"})


func reset_puzzle() -> void:
	var soul_grip: Node = player.get_node_or_null("SoulGripController") if player != null else null
	if soul_grip != null and soul_grip.has_method("release_grip"):
		soul_grip.call("release_grip")

	for resettable: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if resettable != null and is_ancestor_of(resettable) and resettable.has_method("reset_target"):
			resettable.call("reset_target")

	if reward_crate != null:
		reward_crate.reset_prop()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO

	solved = false
	door_open_announced = false
	last_objective = ""
	refresh_timer = 0.0
	if solver != null:
		solver.request_solve()
	set_objective_once("Use Soul Grip to move the slab, recover the copper fuse, and hold the pressure plate.")
	show_message("The silent gate puzzle resets.")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"soul_circuit_puzzle": true,
		"solved": solved,
		"circuit_closed": solver.circuit_closed if solver != null else false,
		"plate_pressed": pressure_plate.is_pressed if pressure_plate != null else false,
		"motor_powered": motor.energized if motor != null else false,
		"door_open_fraction": snapped(door.open_fraction, 0.01) if door != null else 0.0,
		"fuse_energized": fuse_component.energized if fuse_component != null else false,
		"slab_moved": giant_slab.global_position.distance_to(initial_slab_position) if giant_slab != null else 0.0,
	}
