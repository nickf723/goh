extends Node
class_name AvatarControlDriver

signal driver_bound(actor: Node3D, owner: Node3D)
signal intent_sampled(intent_data: Dictionary)
signal action_result_received(action_kind: String, action_id: String, success: bool)

@export var driver_id: String = "avatar_driver"
@export var display_name: String = "Avatar Control Driver"
@export var enabled: bool = true

var controlled_actor: Node3D
var owner_actor: Node3D
var current_intent: AvatarActionIntent = AvatarActionIntent.new()
var samples_emitted: int = 0
var last_action_kind: String = "none"
var last_action_id: String = "none"
var last_action_success: bool = false


func bind_actor(actor: Node3D, owner: Node3D = null) -> void:
	controlled_actor = actor
	owner_actor = owner
	driver_bound.emit(controlled_actor, owner_actor)


func set_driver_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		current_intent.clear()


func sample_intent(delta: float) -> AvatarActionIntent:
	current_intent.clear()
	if enabled and controlled_actor != null and is_instance_valid(controlled_actor):
		_build_intent(maxf(delta, 0.0), current_intent)
	samples_emitted += 1
	intent_sampled.emit(current_intent.get_debug_data())
	return current_intent


func notify_action_result(
	action_kind: String,
	action_id: String,
	success: bool
) -> void:
	last_action_kind = action_kind if action_kind != "" else "none"
	last_action_id = action_id if action_id != "" else "none"
	last_action_success = success
	action_result_received.emit(last_action_kind, last_action_id, success)


func _build_intent(_delta: float, _intent: AvatarActionIntent) -> void:
	pass


func get_debug_data() -> Dictionary:
	return {
		"driver_id": driver_id,
		"display_name": display_name,
		"enabled": enabled,
		"actor": (
			controlled_actor.name
			if controlled_actor != null and is_instance_valid(controlled_actor)
			else "none"
		),
		"owner": (
			owner_actor.name
			if owner_actor != null and is_instance_valid(owner_actor)
			else "none"
		),
		"samples": samples_emitted,
		"last_action_kind": last_action_kind,
		"last_action_id": last_action_id,
		"last_action_success": last_action_success,
		"intent": current_intent.get_debug_data(),
	}
