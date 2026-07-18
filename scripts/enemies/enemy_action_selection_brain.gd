extends "res://scripts/enemies/enemy_combat_action_brain.gd"
class_name EnemyActionSelectionBrain

@export_group("Action Selection")
@export var action_options: Array[EnemyActionOption] = []
@export var reposition_when_no_action_matches: bool = true
@export var retreat_speed_multiplier: float = 0.9
@export var shared_decision_cooldown: float = 0.02

var selected_option: EnemyActionOption
var committed_option: EnemyActionOption
var last_selection_score: float = 0.0
var last_selection_summary: String = "none"
var post_miss_retreat_timer: float = 0.0
var option_cooldowns: Dictionary = {}


func update_timers(delta: float) -> void:
	super.update_timers(delta)
	update_option_cooldowns(delta)


func process_chase(delta: float) -> void:
	if player == null:
		clear_selection("no target")
		change_state(EnemyState.IDLE)
		return

	if should_hesitate_for_zone():
		clear_selection("zone hesitation")
		clear_horizontal_velocity()
		reset_attack_commit()
		face_player(delta)
		last_action_summary = "hesitating near " + get_zone_summary()
		return

	var distance: float = get_distance_to_player()
	if distance > get_definition().get_lose_interest_radius():
		clear_selection("lost target")
		change_state(EnemyState.IDLE)
		return

	if post_miss_retreat_timer > 0.0:
		selected_option = select_action(distance, true)
		if selected_option != null:
			post_miss_retreat_timer = 0.0
			last_action_summary = "cornered into " + selected_option.get_display_name()
			commit_selected_action(delta, selected_option)
			return

		post_miss_retreat_timer = max(post_miss_retreat_timer - delta, 0.0)
		clear_selection("post-miss retreat")
		reset_attack_commit()
		move_away_from_player(delta)
		last_action_summary = "retreating after miss"
		return

	if attack_cooldown_timer > 0.0:
		clear_selection("shared cooldown")
		reset_attack_commit()

		if distance <= get_maximum_action_start_distance():
			last_action_summary = "repositioning during shared cooldown"
			wait_for_attack_opening(delta)
		else:
			last_action_summary = "closing during shared cooldown"
			move_toward_player(delta)
		return

	selected_option = select_action(distance)
	if selected_option != null:
		commit_selected_action(delta, selected_option)
		return

	reset_attack_commit()
	reposition_for_action(delta, distance)


func select_action(
	distance: float,
	retreat_interrupt_only: bool = false
) -> EnemyActionOption:
	var best_option: EnemyActionOption
	var best_score: float = -INF

	for option: EnemyActionOption in action_options:
		if option == null or not option.is_valid_at_distance(distance):
			continue

		if retreat_interrupt_only and not option.can_interrupt_post_miss_retreat:
			continue

		if not is_option_available(option):
			continue

		var score: float = score_action_option(option, distance)
		if score <= best_score:
			continue

		best_option = option
		best_score = score

	last_selection_score = 0.0 if best_option == null else best_score
	last_selection_summary = "none" if best_option == null else best_option.get_display_name()
	return best_option


func score_action_option(option: EnemyActionOption, distance: float) -> float:
	var score: float = option.get_selection_weight()
	score *= PersonalityTraits.get_action_role_multiplier(
		personality_id,
		option.selection_role,
		1.0
	)

	var minimum: float = option.get_minimum_start_distance()
	var maximum: float = option.get_maximum_start_distance()
	var center: float = (minimum + maximum) * 0.5
	var half_span: float = max((maximum - minimum) * 0.5, 0.01)
	var distance_fit: float = 1.0 - clamp(abs(distance - center) / half_span, 0.0, 1.0)
	score *= lerp(0.9, 1.1, distance_fit)
	return score


func commit_selected_action(delta: float, option: EnemyActionOption) -> void:
	if option == null or option.get_action() == null:
		reset_attack_commit()
		return

	clear_horizontal_velocity()
	face_player(delta)

	attack_commit_timer += delta
	last_action_summary = "choosing " + option.get_display_name()

	var commit_time: float = max(get_definition().get_attack_commit_time(), 0.0)
	commit_time *= get_personality_number("attack_commit_time_multiplier", 1.0)

	if attack_commit_timer >= commit_time:
		start_selected_action()


func start_attack() -> void:
	start_selected_action()


func start_selected_action() -> void:
	if selected_option == null:
		return

	var combat_action: EnemyCombatActionDefinition = selected_option.get_action()
	if combat_action == null:
		return

	committed_option = selected_option
	committed_option.apply_presentation(telegraph)
	super.start_combat_action(combat_action)

	if action_runner == null or not action_runner.is_running():
		committed_option = null


func get_current_combat_action() -> EnemyCombatActionDefinition:
	if action_runner != null and action_runner.is_running() and committed_option != null:
		return committed_option.get_action()

	if selected_option != null:
		var selected_action: EnemyCombatActionDefinition = selected_option.get_action()
		if selected_action != null:
			return selected_action

	return default_attack


func get_current_attack() -> EnemyAttackDefinition:
	var combat_action: EnemyCombatActionDefinition = get_current_combat_action()
	if combat_action is EnemyAttackDefinition:
		return combat_action as EnemyAttackDefinition

	return default_attack


func is_player_in_locked_attack_shape(attack: EnemyAttackDefinition) -> bool:
	if player == null or actor == null or action_runner == null:
		return false

	var contact_range: float = attack.get_range()
	if committed_option != null and committed_option.is_attack_option():
		contact_range = committed_option.get_contact_range()

	var to_player: Vector3 = player.global_position - actor.global_position
	to_player.y = 0.0
	if to_player.length() > contact_range:
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
	if (
		committed_option != null
		and committed_option.is_attack_option()
		and committed_option.stop_movement_on_hit
		and action_runner != null
		and action_runner.hit_registered
	):
		clear_horizontal_velocity()
		return

	super.apply_action_movement()


func register_attack_miss(attack_override: EnemyAttackDefinition = null) -> void:
	super.register_attack_miss(attack_override)
	post_miss_retreat_timer = get_personality_number("post_miss_retreat_time", 0.0)


func on_action_completed(_action: EnemyCombatActionDefinition) -> void:
	if committed_option != null:
		start_option_cooldown(committed_option)


func get_shared_cooldown_after_action(
	_action: EnemyCombatActionDefinition,
	_default_cooldown: float
) -> float:
	return max(shared_decision_cooldown, 0.0)


func interrupt_current_action(reason: String) -> bool:
	var interrupted: bool = super.interrupt_current_action(reason)
	if interrupted:
		selected_option = null
		committed_option = null
		last_selection_summary = "interrupted"
		last_selection_score = 0.0

	return interrupted


func cancel_current_action(reason: String) -> void:
	super.cancel_current_action(reason)
	selected_option = null
	committed_option = null
	last_selection_summary = reason
	last_selection_score = 0.0


func finish_action_state() -> void:
	super.finish_action_state()
	selected_option = null
	committed_option = null


func clear_selection(reason: String = "none") -> void:
	selected_option = null
	last_selection_summary = reason
	last_selection_score = 0.0


func reposition_for_action(delta: float, distance: float) -> void:
	if not reposition_when_no_action_matches or action_options.is_empty():
		last_action_summary = "closing without matching action"
		move_toward_player(delta)
		return

	if distance > get_maximum_action_start_distance():
		last_action_summary = "closing for action window"
		move_toward_player(delta)
		return

	last_selection_summary = get_reposition_summary(distance)
	last_action_summary = "repositioning between action windows"
	circle_player(delta)


func get_reposition_summary(distance: float) -> String:
	var cooling_options: Array[String] = []

	for option: EnemyActionOption in action_options:
		if option == null or not option.is_valid_at_distance(distance):
			continue

		var remaining: float = get_option_cooldown(option)
		if remaining > 0.0:
			cooling_options.append(
				option.get_display_name() + " " + str(snapped(remaining, 0.1)) + "s"
			)

	if not cooling_options.is_empty():
		return "waiting: " + ", ".join(cooling_options)

	return "reposition"


func move_away_from_player(delta: float) -> void:
	if player == null or actor == null:
		clear_horizontal_velocity()
		return

	var direction: Vector3 = actor.global_position - player.global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		direction = actor.global_transform.basis.x

	direction = get_zone_adjusted_direction(direction)

	var speed: float = get_definition().get_move_speed()
	speed *= retreat_speed_multiplier
	speed *= get_personality_number("post_miss_retreat_speed_multiplier", 1.0)
	speed *= get_status_move_multiplier()

	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed
	face_player(delta)


func start_option_cooldown(option: EnemyActionOption) -> void:
	if option == null:
		return

	var cooldown: float = option.get_reuse_cooldown()
	if cooldown <= 0.0:
		option_cooldowns.erase(get_option_key(option))
		return

	option_cooldowns[get_option_key(option)] = cooldown


func update_option_cooldowns(delta: float) -> void:
	var expired_keys: Array = []

	for key in option_cooldowns.keys():
		var remaining: float = max(float(option_cooldowns[key]) - delta, 0.0)
		option_cooldowns[key] = remaining

		if remaining <= 0.0:
			expired_keys.append(key)

	for key in expired_keys:
		option_cooldowns.erase(key)


func is_option_available(option: EnemyActionOption) -> bool:
	return get_option_cooldown(option) <= 0.0


func get_option_cooldown(option: EnemyActionOption) -> float:
	if option == null:
		return 0.0

	return float(option_cooldowns.get(get_option_key(option), 0.0))


func get_option_key(option: EnemyActionOption) -> int:
	return option.get_instance_id() if option != null else 0


func get_option_cooldown_summary() -> String:
	var summaries: Array[String] = []

	for option: EnemyActionOption in action_options:
		if option == null:
			continue

		var remaining: float = get_option_cooldown(option)
		if remaining <= 0.0:
			continue

		summaries.append(
			option.get_display_name() + "=" + str(snapped(remaining, 0.1))
		)

	return "none" if summaries.is_empty() else ", ".join(summaries)


func get_maximum_action_start_distance() -> float:
	var maximum: float = 0.0
	for option: EnemyActionOption in action_options:
		if option != null:
			maximum = max(maximum, option.get_maximum_start_distance())

	return maximum


func get_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_debug_data()
	debug_data["selected"] = last_selection_summary
	debug_data["selection_score"] = snapped(last_selection_score, 0.01)
	debug_data["selected_kind"] = selected_option.get_action_kind() if selected_option != null else "none"
	debug_data["committed_option"] = committed_option.get_display_name() if committed_option != null else "none"
	debug_data["retreat"] = snapped(post_miss_retreat_timer, 0.01)
	debug_data["option_cooldowns"] = get_option_cooldown_summary()
	return debug_data
