extends Node
class_name CombustionBreakAdapter

@export var combustion_state_path: NodePath = NodePath("../CombustionState")
@export var hit_receiver_path: NodePath = NodePath("../HitReceiver")
@export var break_when_spent: bool = true
@export var break_source_name: String = "Burnout"

var combustion_state: Node = null
var hit_receiver: Node = null
var last_transition: String = "none"


func _ready() -> void:
	resolve_components()
	connect_combustion_signal()
	add_to_group("debuggable")


func resolve_components() -> void:
	combustion_state = get_node_or_null(combustion_state_path)
	hit_receiver = get_node_or_null(hit_receiver_path)


func connect_combustion_signal() -> void:
	if combustion_state == null:
		push_warning(name + " could not find CombustionState at " + str(combustion_state_path))
		return

	if not combustion_state.has_signal("combustion_state_changed"):
		push_warning(name + " found a combustion component without combustion_state_changed")
		return

	var callback: Callable = Callable(self, "_on_combustion_state_changed")

	if not combustion_state.is_connected("combustion_state_changed", callback):
		combustion_state.connect("combustion_state_changed", callback)


func _on_combustion_state_changed(previous_state: String, next_state: String) -> void:
	last_transition = previous_state + " -> " + next_state

	if break_when_spent and next_state == "spent":
		break_target_from_combustion()


func break_target_from_combustion() -> void:
	if hit_receiver == null or not is_instance_valid(hit_receiver):
		resolve_components()

	if hit_receiver == null:
		return

	var current_health: int = int(hit_receiver.get("current_health"))

	if current_health <= 0:
		return

	var payload: DamagePayload = DamagePayload.new()
	payload.amount = max(current_health, 1)
	payload.stance_damage = 0
	payload.element = "fire"
	payload.source_name = break_source_name
	payload.hit_type = "environmental"
	payload.tags = [
		"fire",
		"combustion",
		"environmental",
		"structural_failure",
	]

	if hit_receiver.has_method("receive_payload"):
		hit_receiver.call("receive_payload", payload)
	elif hit_receiver.has_method("receive_hit"):
		hit_receiver.call("receive_hit", payload.amount)


func get_debug_data() -> Dictionary:
	return {
		"combustion_break_adapter": true,
		"transition": last_transition,
		"break_when_spent": break_when_spent,
		"connected": combustion_state != null and hit_receiver != null,
	}
