extends Node
class_name MechanicalActuator

signal activated
signal deactivated
signal motion_completed(is_activated: bool)

@export var reservoir_path: NodePath
@export var moving_node_path: NodePath
@export var activation_pressure: float = 80.0
@export var deactivation_pressure: float = 20.0
@export var travel_offset: Vector3 = Vector3(0.0, 2.6, 0.0)
@export var move_duration: float = 1.25
@export var latch_when_activated: bool = true
@export var active: bool = true

var reservoir: PressureReservoir
var moving_node: Node3D
var initial_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var is_activated: bool = false
var motion_tween: Tween


func _ready() -> void:
	add_to_group("debuggable")
	reservoir = get_node_or_null(reservoir_path) as PressureReservoir
	moving_node = get_node_or_null(moving_node_path) as Node3D

	if moving_node != null:
		initial_position = moving_node.position
		target_position = initial_position + travel_offset

	if reservoir != null:
		reservoir.pressure_changed.connect(_on_pressure_changed)
		evaluate_pressure(reservoir.current_pressure)


func _on_pressure_changed(
	current_pressure: float,
	_maximum_pressure: float,
	_delta_pressure: float,
	_source: String
) -> void:
	evaluate_pressure(current_pressure)


func evaluate_pressure(current_pressure: float) -> void:
	if not active:
		return

	if not is_activated and current_pressure >= activation_pressure:
		activate()
		return

	if (
		is_activated
		and not latch_when_activated
		and current_pressure <= deactivation_pressure
	):
		deactivate()


func activate() -> void:
	if is_activated:
		return
	is_activated = true
	activated.emit()
	move_to(target_position, true)


func deactivate() -> void:
	if not is_activated:
		return
	is_activated = false
	deactivated.emit()
	move_to(initial_position, false)


func move_to(destination: Vector3, activated_state: bool) -> void:
	if moving_node == null:
		motion_completed.emit(activated_state)
		return

	if motion_tween != null and motion_tween.is_valid():
		motion_tween.kill()

	if move_duration <= 0.0:
		moving_node.position = destination
		motion_completed.emit(activated_state)
		return

	motion_tween = create_tween()
	motion_tween.set_trans(Tween.TRANS_SINE)
	motion_tween.set_ease(Tween.EASE_IN_OUT)
	motion_tween.tween_property(moving_node, "position", destination, move_duration)
	motion_tween.tween_callback(Callable(self, "finish_motion").bind(activated_state))


func finish_motion(activated_state: bool) -> void:
	motion_completed.emit(activated_state)


func reset_actuator() -> void:
	if motion_tween != null and motion_tween.is_valid():
		motion_tween.kill()
	is_activated = false
	if moving_node != null:
		moving_node.position = initial_position


func get_debug_data() -> Dictionary:
	return {
		"actuator": "mechanical",
		"active": active,
		"activated": is_activated,
		"activation_pressure": activation_pressure,
		"deactivation_pressure": deactivation_pressure,
		"latched": latch_when_activated,
		"moving_node": moving_node.name if moving_node != null else "missing",
		"position": moving_node.position if moving_node != null else Vector3.ZERO,
		"target_position": target_position,
	}
