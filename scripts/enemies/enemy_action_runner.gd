extends Node
class_name EnemyActionRunner


enum ActionPhase {
	NONE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}


var current_action: EnemyCombatActionDefinition
var phase: int = ActionPhase.NONE
var phase_timer: float = 0.0
var locked_target_direction: Vector3 = Vector3.FORWARD
var locked_movement_direction: Vector3 = Vector3.ZERO
var hit_registered: bool = false
var impact_requested: bool = false
var finished_requested: bool = false
var last_interrupt_reason: String = "none"


func _ready() -> void:
	add_to_group("debuggable")


func begin_action(
	action: EnemyCombatActionDefinition,
	target_direction: Vector3,
	movement_direction: Vector3 = Vector3.ZERO
) -> bool:
	if action == null or is_running():
		return false

	current_action = action
	locked_target_direction = normalize_required_direction(target_direction)
	locked_movement_direction = normalize_optional_direction(movement_direction)
	hit_registered = false
	impact_requested = false
	finished_requested = false
	last_interrupt_reason = "none"
	enter_phase(ActionPhase.WINDUP, action.get_windup_time())
	return true


func tick(delta: float) -> void:
	if not is_running():
		return

	phase_timer = max(phase_timer - delta, 0.0)
	if phase_timer > 0.0:
		return

	match phase:
		ActionPhase.WINDUP:
			enter_phase(ActionPhase.ACTIVE, current_action.get_active_time())
			impact_requested = true

		ActionPhase.ACTIVE:
			enter_phase(ActionPhase.RECOVERY, current_action.get_recovery_time())

		ActionPhase.RECOVERY:
			finish_action()


func interrupt_action(reason: String = "interrupted") -> bool:
	if not is_running() or not is_interruptible():
		return false

	last_interrupt_reason = reason
	clear_running_action()
	finished_requested = true
	return true


func cancel_action(reason: String = "cancelled") -> void:
	if not is_running():
		return

	last_interrupt_reason = reason
	clear_running_action()
	finished_requested = true


func finish_action() -> void:
	clear_running_action()
	finished_requested = true


func clear_running_action() -> void:
	current_action = null
	phase = ActionPhase.NONE
	phase_timer = 0.0
	impact_requested = false
	locked_movement_direction = Vector3.ZERO


func enter_phase(next_phase: int, duration: float) -> void:
	phase = next_phase
	phase_timer = max(duration, 0.0)


func consume_impact_request() -> bool:
	if not impact_requested:
		return false

	impact_requested = false
	return true


func consume_finished_request() -> bool:
	if not finished_requested:
		return false

	finished_requested = false
	return true


func mark_hit_registered() -> void:
	hit_registered = true


func is_running() -> bool:
	return current_action != null and phase != ActionPhase.NONE


func is_interruptible() -> bool:
	if current_action == null:
		return false

	match phase:
		ActionPhase.WINDUP:
			return current_action.get_interruptible_during_windup()
		ActionPhase.ACTIVE:
			return current_action.get_interruptible_during_active()
		ActionPhase.RECOVERY:
			return current_action.get_interruptible_during_recovery()

	return false


func get_move_speed_multiplier() -> float:
	if current_action == null:
		return 0.0

	match phase:
		ActionPhase.WINDUP:
			return current_action.get_windup_move_speed_multiplier()
		ActionPhase.ACTIVE:
			return current_action.get_active_move_speed_multiplier()
		ActionPhase.RECOVERY:
			return current_action.get_recovery_move_speed_multiplier()

	return 0.0


func get_phase_name() -> String:
	return ActionPhase.keys()[phase]


func get_phase_time_remaining() -> float:
	return phase_timer


func get_current_action() -> EnemyCombatActionDefinition:
	return current_action


func get_action_display_name() -> String:
	return current_action.get_display_name() if current_action != null else "none"


func get_locked_direction() -> Vector3:
	return locked_target_direction


func get_locked_target_direction() -> Vector3:
	return locked_target_direction


func get_locked_movement_direction() -> Vector3:
	return locked_movement_direction


func normalize_required_direction(direction: Vector3) -> Vector3:
	direction.y = 0.0
	if direction.length() <= 0.01:
		return Vector3.FORWARD

	return direction.normalized()


func normalize_optional_direction(direction: Vector3) -> Vector3:
	direction.y = 0.0
	if direction.length() <= 0.01:
		return Vector3.ZERO

	return direction.normalized()


func get_debug_data() -> Dictionary:
	return {
		"action": get_action_display_name(),
		"kind": current_action.get_action_kind() if current_action != null else "none",
		"phase": get_phase_name(),
		"phase_time": snapped(phase_timer, 0.01),
		"interruptible": is_interruptible(),
		"hit": hit_registered,
		"movement": locked_movement_direction,
		"interrupt": last_interrupt_reason,
	}
