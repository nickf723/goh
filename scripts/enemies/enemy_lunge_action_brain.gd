extends "res://scripts/enemies/enemy_combat_action_brain.gd"
class_name EnemyLungeActionBrain

@export_group("Lunge Action")
@export var lunge_start_range: float = 3.0
@export var contact_range_override: float = -1.0
@export var stop_movement_on_hit: bool = true


func get_attack_pressure_range(attack: EnemyAttackDefinition) -> float:
	if attack == null:
		return 0.0

	return get_lunge_start_range(attack) + max(
		get_definition().get_attack_pressure_range_padding(),
		0.0
	)


func commit_to_attack(delta: float, distance: float, attack: EnemyAttackDefinition) -> void:
	if distance > get_lunge_start_range(attack):
		reset_attack_commit()
		last_action_summary = "closing for lunge: " + attack.get_display_name()
		move_toward_player(delta)
		return

	clear_horizontal_velocity()
	face_player(delta)

	attack_commit_timer += delta
	last_action_summary = "lining up lunge: " + attack.get_display_name()

	var commit_time: float = max(get_definition().get_attack_commit_time(), 0.0)
	commit_time *= get_personality_number("attack_commit_time_multiplier", 1.0)

	if attack_commit_timer >= commit_time:
		start_attack()


func is_player_in_locked_attack_shape(attack: EnemyAttackDefinition) -> bool:
	if player == null or actor == null or action_runner == null:
		return false

	var to_player: Vector3 = player.global_position - actor.global_position
	to_player.y = 0.0
	if to_player.length() > get_lunge_contact_range(attack):
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
	if stop_movement_on_hit and action_runner != null and action_runner.hit_registered:
		clear_horizontal_velocity()
		return

	super.apply_action_movement()


func get_lunge_start_range(attack: EnemyAttackDefinition) -> float:
	if lunge_start_range > 0.0:
		return lunge_start_range

	return attack.get_range() if attack != null else 0.0


func get_lunge_contact_range(attack: EnemyAttackDefinition) -> float:
	if contact_range_override > 0.0:
		return contact_range_override

	return attack.get_range() if attack != null else 0.0


func get_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_debug_data()
	var attack: EnemyAttackDefinition = get_current_attack()
	debug_data["lunge_start"] = snapped(get_lunge_start_range(attack), 0.1)
	debug_data["lunge_contact"] = snapped(get_lunge_contact_range(attack), 0.1)
	return debug_data
