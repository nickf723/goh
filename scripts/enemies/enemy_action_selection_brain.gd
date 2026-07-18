extends "res://scripts/enemies/enemy_combat_action_brain.gd"
class_name EnemyActionSelectionBrain

@export_group("Action Selection")
@export var action_options: Array[EnemyActionOption] = []
@export var reposition_when_no_action_matches: bool = true
@export var retreat_speed_multiplier: float = 0.9

var selected_option: EnemyActionOption
var committed_option: EnemyActionOption
var last_selection_score: float = 0.0
var last_selection_summary: String = "none"
var post_miss_retreat_timer: float = 0.0


func process_chase(delta: float) -> void:
	if player == null:
		selected_option = null
		change_state(EnemyState.IDLE)
		return

	if should_hesitate_for_zone():
		selected_option = null
		clear_horizontal_velocity()
		reset_attack_commit()
		face_player(delta)
		last_action_summary = "hesitating near " + get_zone_summary()
		return

	var distance: float = get_distance_to_player()
	if distance > get_definition().get_lose_interest_radius():
		selected_option = null
		change_state(EnemyState.IDLE)
		return

	if post_miss_retreat_timer > 0.0:
		post_miss_retreat_timer = max(post_miss_retreat_timer - delta, 0.0)
		selected_option = null
		reset_attack_commit()
		move_away_from_player(delta)
		last_action_summary = "retreating after miss"
		return

	if attack_cooldown_timer > 0.0:
		selected_option = null
		reset_attack_commit()

		if distance <= get_maximum_action_start_distance():
			last_action_summary = "repositioning during cooldown"
			wait_for_attack_opening(delta)
		else:
			last_action_summary = "closing during cooldown"
			move_toward_player(delta)
		return

	selected_option = select_action(distance)
	if selected_option != null:
		commit_selected_action(delta, selected_option)
		return

	reset_attack_commit()
	reposition_for_action(delta, distance)


func select_action(distance: float) -> EnemyActionOption:
	var best_option: EnemyActionOption
	var best_score: float = -INF

	for option: EnemyActionOption in action_options:
		if option == null or not option.is_valid_at_distance(distance):
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
	if option == null or option.attack == null:
		reset_attack_commit()
		return

	clear_horizontal_velocity()
	face_player(delta)

	attack_commit_timer += delta
	last_action_summary = "choosing " + option.get_display_name()

	var commit_time: float = max(get_definition().get_attack_commit_time(), 0.0)
	commit_time *= get_personality_number("attack_commit_time_multiplier", 1.0)

	if attack_commit_timer >= commit_time:
		start_attack()


func start_attack() -> void:
	if selected_option == null or selected_option.attack == null:
		return

	committed_option = selected_option
	committed_option.apply_presentation(telegraph)
	super.start_attack()

	if action_runner == null or not action_runner.is_running():
		committed_option = null


func get_current_attack() -> EnemyAttackDefinition:
	if action_runner != null and action_runner.is_running() and committed_option != null:
		return committed_option.attack

	if selected_option != null and selected_option.attack != null:
		return selected_option.attack

	return default_attack


func is_player_in_locked_attack_shape(attack: EnemyAttackDefinition) -> bool:
	if player == null or actor == null or action_runner == null:
		return false

	var contact_range: float = attack.get_range()
	if committed_option != null:
		contact_range = committed_option.get_contact_range()

	var to_player: Vector3 = player.global_position - actor.global_position
	to_player.y = 0.0
	if to_player.length() > contact_range:
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
	if (
		committed_option != null
		and committed_option.stop_movement_on_hit
		and action_runner != null
		and action_runner.hit_registered
	):
		clear_horizontal_velocity()
		return

	super.apply_action_movement()


func register_attack_miss() -> void:
	super.register_attack_miss()
	post_miss_retreat_timer = get_personality_number("post_miss_retreat_time", 0.0)


func finish_action_state() -> void:
	super.finish_action_state()
	selected_option = null
	committed_option = null


func reposition_for_action(delta: float, distance: float) -> void:
	if not reposition_when_no_action_matches or action_options.is_empty():
		last_action_summary = "closing without matching action"
		move_toward_player(delta)
		return

	if distance > get_maximum_action_start_distance():
		last_action_summary = "closing for action window"
		move_toward_player(delta)
		return

	last_action_summary = "repositioning between action windows"
	circle_player(delta)


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
	debug_data["committed_option"] = committed_option.get_display_name() if committed_option != null else "none"
	debug_data["retreat"] = snapped(post_miss_retreat_timer, 0.01)
	return debug_data
