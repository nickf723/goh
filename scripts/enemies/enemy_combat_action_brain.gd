extends "res://scripts/enemies/enemy_zone_aware_brain.gd"
class_name EnemyCombatActionBrain

const EnemyActionRunnerScript = preload("res://scripts/enemies/enemy_action_runner.gd")

@export_group("Action Pipeline")
@export var action_runner_path: NodePath = NodePath("../EnemyActionRunner")
@export var force_interrupt_threshold: float = 4.0

var action_runner
var recover_visual_started: bool = false


func _ready() -> void:
	super._ready()
	resolve_action_runner()


func resolve_action_runner() -> void:
	action_runner = get_node_or_null(action_runner_path)
	if action_runner != null:
		return

	action_runner = EnemyActionRunnerScript.new()
	action_runner.name = "EnemyActionRunner"

	if actor != null:
		actor.add_child.call_deferred(action_runner)
	else:
		add_child.call_deferred(action_runner)


func start_attack() -> void:
	start_combat_action(get_current_combat_action())


func start_combat_action(action: EnemyCombatActionDefinition) -> void:
	if action == null:
		return

	if action_runner == null:
		resolve_action_runner()

	if action_runner == null or action_runner.is_running():
		return

	var target_direction: Vector3 = get_direction_to_player()
	var movement_direction: Vector3 = resolve_action_movement_direction(
		action,
		target_direction
	)
	if not action_runner.begin_action(action, target_direction, movement_direction):
		return

	reset_attack_commit()
	recover_visual_started = false
	last_action_summary = "windup: " + action.get_display_name()

	if telegraph != null and telegraph.has_method("start_windup"):
		telegraph.start_windup()

	on_action_started(action)
	change_state(EnemyState.ATTACK_WINDUP)


func process_attack_windup(delta: float) -> void:
	if not has_running_action():
		finish_action_state()
		return

	if should_interrupt_for_force():
		interrupt_current_action("force")
		return

	apply_action_movement()
	face_action_direction(delta)
	action_runner.tick(delta)

	var action: EnemyCombatActionDefinition = action_runner.get_current_action()

	if action_runner.consume_impact_request():
		last_action_summary = "active: " + action_runner.get_action_display_name()

		if telegraph != null and telegraph.has_method("start_active"):
			telegraph.start_active()

		on_action_active_started(action)

	if action_runner.get_phase_name() == "ACTIVE":
		process_active_action(action)

	if action_runner.get_phase_name() == "RECOVERY":
		if action is EnemyAttackDefinition and not action_runner.hit_registered:
			register_attack_miss(action as EnemyAttackDefinition)

		on_action_recovery_started(action)
		start_recovery_visual()
		change_state(EnemyState.ATTACK_RECOVER)


func process_attack_recover(delta: float) -> void:
	if not has_running_action():
		finish_action_state()
		return

	var committed_action: EnemyCombatActionDefinition = action_runner.get_current_action()

	apply_action_movement()
	face_action_direction(delta)
	action_runner.tick(delta)

	if action_runner.consume_finished_request():
		var default_cooldown: float = 0.0
		if committed_action != null:
			default_cooldown = committed_action.get_cooldown()

		on_action_completed(committed_action)
		attack_cooldown_timer = get_shared_cooldown_after_action(
			committed_action,
			default_cooldown
		)
		finish_action_state()


func process_staggered(delta: float) -> void:
	if has_running_action() and status_blocks_actions():
		if not interrupt_current_action("status"):
			cancel_current_action("status")

	super.process_staggered(delta)


func process_dead(delta: float) -> void:
	if action_runner != null and action_runner.is_running():
		cancel_current_action("defeated")

	super.process_dead(delta)


func process_active_action(action: EnemyCombatActionDefinition) -> void:
	if action is EnemyAttackDefinition:
		perform_attack(action as EnemyAttackDefinition)
	elif action is EnemyDefenseDefinition:
		perform_defense(action as EnemyDefenseDefinition)


func perform_attack(attack_override: EnemyAttackDefinition = null) -> void:
	if action_runner == null or action_runner.hit_registered:
		return

	var attack: EnemyAttackDefinition = attack_override
	if attack == null:
		attack = action_runner.get_current_action() as EnemyAttackDefinition
	if attack == null:
		return

	if player == null or not is_player_in_locked_attack_shape(attack):
		return

	var payload: DamagePayload = attack.get_payload()
	action_runner.mark_hit_registered()
	last_action_summary = "hit: " + payload.source_name
	apply_attack_to_player(payload)


func perform_defense(defense: EnemyDefenseDefinition) -> void:
	if defense == null:
		return

	last_action_summary = "defending: " + defense.get_display_name()


func register_attack_miss(attack_override: EnemyAttackDefinition = null) -> void:
	if action_runner == null:
		return

	var attack: EnemyAttackDefinition = attack_override
	if attack == null:
		attack = action_runner.get_current_action() as EnemyAttackDefinition
	if attack == null:
		return

	last_action_summary = attack.get_display_name() + " missed"

	if attack.should_show_miss_message():
		show_message(get_enemy_display_name() + " misses.")


func is_player_in_locked_attack_shape(attack: EnemyAttackDefinition) -> bool:
	if player == null or actor == null or action_runner == null:
		return false

	var to_player: Vector3 = player.global_position - actor.global_position
	to_player.y = 0.0
	if to_player.length() > attack.get_range():
		return false

	if to_player.length() <= 0.01:
		return true

	var attack_direction: Vector3 = action_runner.get_locked_target_direction()
	attack_direction.y = 0.0
	if attack_direction.length() <= 0.01:
		return true

	var minimum_dot: float = cos(deg_to_rad(attack.get_cone_angle_degrees() * 0.5))
	return attack_direction.normalized().dot(to_player.normalized()) >= minimum_dot


func apply_action_movement() -> void:
	if actor == null or action_runner == null:
		return

	var multiplier: float = action_runner.get_move_speed_multiplier()
	var direction: Vector3 = action_runner.get_locked_movement_direction()
	if multiplier <= 0.0 or direction.length() <= 0.01:
		clear_horizontal_velocity()
		return

	var speed: float = get_definition().get_move_speed()
	speed *= get_status_move_multiplier()
	speed *= multiplier

	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed


func face_action_direction(delta: float) -> void:
	if action_runner == null:
		return

	var action: EnemyCombatActionDefinition = action_runner.get_current_action()
	if action == null:
		return

	if action.should_face_target_during_action():
		face_direction(action_runner.get_locked_target_direction(), delta)
	else:
		face_direction(action_runner.get_locked_movement_direction(), delta)


func resolve_action_movement_direction(
	action: EnemyCombatActionDefinition,
	target_direction: Vector3
) -> Vector3:
	if action == null:
		return Vector3.ZERO

	var direction: Vector3 = target_direction
	direction.y = 0.0
	if direction.length() <= 0.01:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()

	match action.get_movement_mode():
		"away_from_target":
			return -direction
		"strafe_left":
			return Vector3(-direction.z, 0.0, direction.x).normalized()
		"strafe_right":
			return Vector3(direction.z, 0.0, -direction.x).normalized()
		"none":
			return Vector3.ZERO
		_:
			return direction


func should_interrupt_for_force() -> bool:
	if action_runner == null or not action_runner.is_interruptible():
		return false

	if force_receiver == null:
		return false

	var external_velocity: Variant = force_receiver.get("external_velocity")
	if not external_velocity is Vector3:
		return false

	return (external_velocity as Vector3).length() >= force_interrupt_threshold


func interrupt_current_action(reason: String) -> bool:
	if action_runner == null:
		return false

	if not action_runner.interrupt_action(reason):
		return false

	last_action_summary = "interrupted: " + reason
	recover_visual_started = false

	if telegraph != null and telegraph.has_method("reset"):
		telegraph.reset()

	change_state(EnemyState.STAGGERED)
	return true


func cancel_current_action(reason: String) -> void:
	if action_runner == null or not action_runner.is_running():
		return

	action_runner.cancel_action(reason)
	last_action_summary = "cancelled: " + reason
	recover_visual_started = false

	if telegraph != null and telegraph.has_method("reset"):
		telegraph.reset()


func start_recovery_visual() -> void:
	if recover_visual_started:
		return

	recover_visual_started = true
	last_action_summary = "recovery: " + get_current_action_name()

	if telegraph != null and telegraph.has_method("start_recover"):
		telegraph.start_recover()


func finish_action_state() -> void:
	recover_visual_started = false

	if telegraph != null and telegraph.has_method("reset"):
		telegraph.reset()

	if player != null and get_distance_to_player() <= get_definition().get_lose_interest_radius():
		change_state(EnemyState.CHASE)
	else:
		change_state(EnemyState.IDLE)


func on_action_started(_action: EnemyCombatActionDefinition) -> void:
	pass


func on_action_active_started(_action: EnemyCombatActionDefinition) -> void:
	pass


func on_action_recovery_started(_action: EnemyCombatActionDefinition) -> void:
	pass


func on_action_completed(_action: EnemyCombatActionDefinition) -> void:
	pass


func get_shared_cooldown_after_action(
	_action: EnemyCombatActionDefinition,
	default_cooldown: float
) -> float:
	return max(default_cooldown, 0.0)


func has_running_action() -> bool:
	return action_runner != null and action_runner.is_running()


func get_direction_to_player() -> Vector3:
	if player == null or actor == null:
		return -actor.global_transform.basis.z if actor != null else Vector3.FORWARD

	var direction: Vector3 = player.global_position - actor.global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		return -actor.global_transform.basis.z

	return direction.normalized()


func get_current_combat_action() -> EnemyCombatActionDefinition:
	return get_current_attack()


func get_current_action_name() -> String:
	if action_runner != null and action_runner.is_running():
		return action_runner.get_action_display_name()

	var action: EnemyCombatActionDefinition = get_current_combat_action()
	return action.get_display_name() if action != null else "action"


func get_current_attack_name() -> String:
	return get_current_action_name()


func get_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_debug_data()

	if action_runner != null and action_runner.is_running():
		var action: EnemyCombatActionDefinition = action_runner.get_current_action()
		debug_data["phase"] = action_runner.get_phase_name()
		debug_data["phase_time"] = snapped(action_runner.get_phase_time_remaining(), 0.01)
		debug_data["interruptible"] = action_runner.is_interruptible()
		debug_data["hit"] = action_runner.hit_registered
		debug_data["action"] = action_runner.get_action_display_name()
		debug_data["action_kind"] = action.get_action_kind() if action != null else "none"
		debug_data["movement_mode"] = action.get_movement_mode() if action != null else "none"
	elif attack_cooldown_timer > 0.0:
		debug_data["phase"] = "COOLDOWN"
		debug_data["phase_time"] = snapped(attack_cooldown_timer, 0.01)
		debug_data["interruptible"] = false
		debug_data["hit"] = false
		debug_data["action"] = get_current_action_name()
		debug_data["action_kind"] = "none"
		debug_data["movement_mode"] = "none"
	else:
		debug_data["phase"] = "DECIDING"
		debug_data["phase_time"] = 0.0
		debug_data["interruptible"] = false
		debug_data["hit"] = false
		debug_data["action"] = get_current_action_name()
		debug_data["action_kind"] = "none"
		debug_data["movement_mode"] = "none"

	return debug_data
