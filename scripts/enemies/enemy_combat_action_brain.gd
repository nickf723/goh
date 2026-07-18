extends "res://scripts/enemies/enemy_zone_aware_brain.gd"
class_name EnemyCombatActionBrain

const EnemyActionRunnerScript = preload("res://scripts/enemies/enemy_action_runner.gd")

@export_group("Action Pipeline")
@export var action_runner_path: NodePath = NodePath("../EnemyActionRunner")
@export var force_interrupt_threshold: float = 4.0

var action_runner: EnemyActionRunner
var recover_visual_started: bool = false


func _ready() -> void:
	super._ready()
	resolve_action_runner()


func resolve_action_runner() -> void:
	action_runner = get_node_or_null(action_runner_path) as EnemyActionRunner
	if action_runner != null:
		return

	action_runner = EnemyActionRunnerScript.new() as EnemyActionRunner
	action_runner.name = "EnemyActionRunner"

	if actor != null:
		actor.add_child(action_runner)
	else:
		add_child(action_runner)


func start_attack() -> void:
	var attack: EnemyAttackDefinition = get_current_attack()
	if attack == null:
		return

	if action_runner == null:
		resolve_action_runner()

	if action_runner == null or action_runner.is_running():
		return

	var locked_direction: Vector3 = get_direction_to_player()
	if not action_runner.begin_action(attack, locked_direction):
		return

	reset_attack_commit()
	recover_visual_started = false
	last_action_summary = "windup: " + attack.get_display_name()

	if telegraph != null and telegraph.has_method("start_windup"):
		telegraph.start_windup()

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

	if action_runner.consume_impact_request():
		last_action_summary = "active: " + action_runner.get_action_display_name()

		if telegraph != null and telegraph.has_method("start_active"):
			telegraph.start_active()

	if action_runner.get_phase_name() == "ACTIVE" and not action_runner.hit_registered:
		perform_attack()

	if action_runner.get_phase_name() == "RECOVERY":
		if not action_runner.hit_registered:
			register_attack_miss()

		start_recovery_visual()
		change_state(EnemyState.ATTACK_RECOVER)


func process_attack_recover(delta: float) -> void:
	if not has_running_action():
		finish_action_state()
		return

	apply_action_movement()
	face_action_direction(delta)
	action_runner.tick(delta)

	if action_runner.consume_finished_request():
		attack_cooldown_timer = get_attack_cooldown()
		finish_action_state()


func process_staggered(delta: float) -> void:
	if has_running_action() and status_blocks_actions():
		interrupt_current_action("status")

	super.process_staggered(delta)


func process_dead(delta: float) -> void:
	if action_runner != null and action_runner.is_running():
		action_runner.cancel_action("defeated")

	super.process_dead(delta)


func perform_attack() -> void:
	var attack: EnemyAttackDefinition = get_current_attack()
	if attack == null or action_runner == null or action_runner.hit_registered:
		return

	if player == null or not is_player_in_locked_attack_shape(attack):
		return

	var payload: DamagePayload = attack.get_payload()
	action_runner.mark_hit_registered()
	last_action_summary = "hit: " + payload.source_name
	apply_attack_to_player(payload)


func register_attack_miss() -> void:
	var attack: EnemyAttackDefinition = get_current_attack()
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

	var attack_direction: Vector3 = action_runner.get_locked_direction()
	attack_direction.y = 0.0
	if attack_direction.length() <= 0.01:
		return true

	var minimum_dot: float = cos(deg_to_rad(attack.get_cone_angle_degrees() * 0.5))
	return attack_direction.normalized().dot(to_player.normalized()) >= minimum_dot


func apply_action_movement() -> void:
	if actor == null or action_runner == null:
		return

	var multiplier: float = action_runner.get_move_speed_multiplier()
	if multiplier <= 0.0:
		clear_horizontal_velocity()
		return

	var direction: Vector3 = action_runner.get_locked_direction()
	var speed: float = get_definition().get_move_speed()
	speed *= get_status_move_multiplier()
	speed *= multiplier

	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed


func face_action_direction(delta: float) -> void:
	if action_runner == null:
		return

	face_direction(action_runner.get_locked_direction(), delta)


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


func start_recovery_visual() -> void:
	if recover_visual_started:
		return

	recover_visual_started = true
	last_action_summary = "recovery: " + get_current_attack_name()

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


func get_current_attack_name() -> String:
	var attack: EnemyAttackDefinition = get_current_attack()
	return attack.get_display_name() if attack != null else "attack"


func get_attack_cooldown() -> float:
	var attack: EnemyAttackDefinition = get_current_attack()
	return attack.get_cooldown() if attack != null else 0.0


func get_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_debug_data()

	if action_runner != null and action_runner.is_running():
		debug_data["phase"] = action_runner.get_phase_name()
		debug_data["phase_time"] = snapped(action_runner.get_phase_time_remaining(), 0.01)
		debug_data["interruptible"] = action_runner.is_interruptible()
		debug_data["hit"] = action_runner.hit_registered
		debug_data["action"] = action_runner.get_action_display_name()
	elif attack_cooldown_timer > 0.0:
		debug_data["phase"] = "COOLDOWN"
		debug_data["phase_time"] = snapped(attack_cooldown_timer, 0.01)
		debug_data["interruptible"] = false
		debug_data["hit"] = false
		debug_data["action"] = get_current_attack_name()
	else:
		debug_data["phase"] = "DECIDING"
		debug_data["phase_time"] = 0.0
		debug_data["interruptible"] = false
		debug_data["hit"] = false
		debug_data["action"] = get_current_attack_name()

	return debug_data
