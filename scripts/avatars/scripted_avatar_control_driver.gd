extends "res://scripts/avatars/avatar_control_driver.gd"
class_name ScriptedAvatarControlDriver

var queued_steps: Array[Dictionary] = []
var current_step_index: int = -1
var current_step_remaining: float = 0.0
var sequence_loops: bool = false
var completed_sequences: int = 0


func _ready() -> void:
	driver_id = "scripted"
	display_name = "Scripted Control"
	add_to_group("avatar_control_driver")
	add_to_group("scripted_avatar_control_driver")
	add_to_group("debuggable")


func enqueue_step(step_data: Dictionary, duration: float = 0.1) -> void:
	var step: Dictionary = step_data.duplicate(true)
	step["duration"] = maxf(duration, 0.01)
	queued_steps.append(step)
	if current_step_index < 0:
		current_step_index = 0
		current_step_remaining = float(step.get("duration", 0.1))


func set_sequence(steps: Array[Dictionary], loop: bool = false) -> void:
	clear_sequence()
	sequence_loops = loop
	for step: Dictionary in steps:
		enqueue_step(step, float(step.get("duration", 0.1)))


func clear_sequence() -> void:
	queued_steps.clear()
	current_step_index = -1
	current_step_remaining = 0.0
	completed_sequences = 0
	current_intent.clear()


func is_sequence_complete() -> bool:
	return not sequence_loops and current_step_index < 0 and queued_steps.size() > 0


func _build_intent(delta: float, intent: AvatarActionIntent) -> void:
	if queued_steps.is_empty() or current_step_index < 0:
		intent.decision_tag = "script_complete"
		return
	if current_step_index >= queued_steps.size():
		_finish_sequence()
		return

	var step: Dictionary = queued_steps[current_step_index]
	_apply_step(step, intent)
	current_step_remaining -= maxf(delta, 0.0)
	if current_step_remaining <= 0.0:
		current_step_index += 1
		if current_step_index >= queued_steps.size():
			_finish_sequence()
		elif current_step_index >= 0:
			current_step_remaining = float(
				queued_steps[current_step_index].get("duration", 0.1)
			)


func _apply_step(step: Dictionary, intent: AvatarActionIntent) -> void:
	var movement_value: Variant = step.get("movement_direction", Vector3.ZERO)
	if movement_value is Vector3:
		intent.set_movement(
			movement_value as Vector3,
			float(step.get("movement_strength", 1.0))
		)
	var facing_value: Variant = step.get("facing_direction", Vector3.ZERO)
	if facing_value is Vector3:
		intent.set_facing(facing_value as Vector3)
	var target_value: Variant = step.get("target", null)
	if target_value is Node3D and is_instance_valid(target_value):
		intent.target = target_value as Node3D
	intent.attack_id = str(step.get("attack_id", ""))
	intent.spell_id = str(step.get("spell_id", ""))
	intent.dodge_requested = bool(step.get("dodge", false))
	var dodge_value: Variant = step.get("dodge_direction", Vector3.ZERO)
	if dodge_value is Vector3:
		intent.dodge_direction = dodge_value as Vector3
	intent.dodge_kind = str(step.get("dodge_kind", "side"))
	intent.guard_requested = bool(step.get("guard", false))
	intent.recall_requested = bool(step.get("recall", false))
	intent.decision_tag = str(step.get("decision_tag", "scripted_step"))
	intent.action_reason = str(step.get("reason", "scripted sequence"))


func _finish_sequence() -> void:
	completed_sequences += 1
	if sequence_loops and not queued_steps.is_empty():
		current_step_index = 0
		current_step_remaining = float(queued_steps[0].get("duration", 0.1))
	else:
		current_step_index = -1
		current_step_remaining = 0.0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["queued_steps"] = queued_steps.size()
	data["step_index"] = current_step_index
	data["step_remaining"] = snappedf(current_step_remaining, 0.01)
	data["loops"] = sequence_loops
	data["completed_sequences"] = completed_sequences
	data["sequence_complete"] = is_sequence_complete()
	return data
