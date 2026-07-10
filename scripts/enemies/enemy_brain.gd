extends Node
class_name EnemyBrain

const EnemyOverheadHud = preload("res://scripts/combat/enemy_overhead_hud.gd")

enum EnemyState {
	IDLE,
	CHASE,
	ATTACK_WINDUP,
	ATTACK_RECOVER,
	STAGGERED,
	DEAD,
}

@export var enemy_definition: EnemyDefinition
@export var default_attack: EnemyAttackDefinition
@export var player_group: String = "player"
@export var show_debug_prints: bool = false

var state: EnemyState = EnemyState.IDLE
var state_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var last_action_summary: String = "none"
var strafe_direction: float = 1.0
var strafe_switch_timer: float = 0.0
var actor: CharacterBody3D
var player: Node3D

@onready var status_receiver: Node = get_node_or_null("../StatusReceiver")
@onready var force_receiver: Node = get_node_or_null("../ForceReceiver")
@onready var hit_receiver: Node = get_node_or_null("../HitReceiver")
@onready var tag_component: Node = get_node_or_null("../TagComponent")
@onready var telegraph: Node = get_node_or_null("../EnemyTelegraph")


func _ready() -> void:
	add_to_group("debuggable")

	actor = get_parent() as CharacterBody3D

	if actor != null:
		actor.add_to_group("enemy")

	apply_definition_to_components()
	refresh_player()


func _physics_process(delta: float) -> void:
	if actor == null:
		return

	refresh_player()
	update_timers(delta)

	if is_defeated():
		state = EnemyState.DEAD

	if state != EnemyState.DEAD and status_blocks_actions():
		state = EnemyState.STAGGERED

	match state:
		EnemyState.IDLE:
			process_idle(delta)

		EnemyState.CHASE:
			process_chase(delta)

		EnemyState.ATTACK_WINDUP:
			process_attack_windup(delta)

		EnemyState.ATTACK_RECOVER:
			process_attack_recover(delta)

		EnemyState.STAGGERED:
			process_staggered(delta)

		EnemyState.DEAD:
			process_dead(delta)

	apply_gravity(delta)
	apply_external_force(delta)

	actor.move_and_slide()


func update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if strafe_switch_timer > 0.0:
		strafe_switch_timer -= delta

	if strafe_switch_timer <= 0.0:
		strafe_switch_timer = max(get_definition().get_strafe_switch_interval(), 0.1)
		strafe_direction *= -1.0


func refresh_player() -> void:
	if player != null and is_instance_valid(player):
		return

	var found_player: Node = get_tree().get_first_node_in_group(player_group)

	if found_player is Node3D:
		player = found_player as Node3D


func process_idle(_delta: float) -> void:
	clear_horizontal_velocity()

	if player == null:
		return

	if get_distance_to_player() <= get_definition().get_detection_radius():
		change_state(EnemyState.CHASE)


func process_chase(delta: float) -> void:
	if player == null:
		change_state(EnemyState.IDLE)
		return

	var distance: float = get_distance_to_player()

	if distance > get_definition().get_lose_interest_radius():
		change_state(EnemyState.IDLE)
		return

	if default_attack != null:
		if distance <= default_attack.range and attack_cooldown_timer <= 0.0:
			start_attack()
			return

		if distance <= get_definition().get_preferred_distance() + get_definition().get_spacing_buffer():
			wait_for_attack_opening(delta)
			return

	move_toward_player(delta)


func process_attack_windup(delta: float) -> void:
	clear_horizontal_velocity()
	face_player(delta)

	state_timer -= delta

	if state_timer <= 0.0:
		perform_attack()

		if telegraph != null and telegraph.has_method("start_recover"):
			telegraph.start_recover()

		change_state(EnemyState.ATTACK_RECOVER, get_attack_recovery())


func process_attack_recover(delta: float) -> void:
	clear_horizontal_velocity()

	state_timer -= delta

	if state_timer <= 0.0:
		if player != null and get_distance_to_player() <= get_definition().get_lose_interest_radius():
			change_state(EnemyState.CHASE)
		else:
			change_state(EnemyState.IDLE)


func process_staggered(_delta: float) -> void:
	clear_horizontal_velocity()

	if not status_blocks_actions():
		if player != null and get_distance_to_player() <= get_definition().get_lose_interest_radius():
			change_state(EnemyState.CHASE)
		else:
			change_state(EnemyState.IDLE)


func process_dead(_delta: float) -> void:
	clear_horizontal_velocity()

	if telegraph != null and telegraph.has_method("reset"):
		telegraph.reset()


func start_attack() -> void:
	if default_attack == null:
		return

	last_action_summary = "windup: " + default_attack.display_name

	if telegraph != null and telegraph.has_method("start_windup"):
		telegraph.start_windup()

	change_state(EnemyState.ATTACK_WINDUP, default_attack.windup_time)


func perform_attack() -> void:
	if default_attack == null:
		return

	attack_cooldown_timer = default_attack.cooldown

	if player == null:
		return

	if not is_player_in_attack_range():
		last_action_summary = default_attack.display_name + " missed"

		if default_attack.show_miss_message:
			show_message(get_enemy_display_name() + " misses.")

		return

	var payload: DamagePayload = default_attack.get_payload()
	last_action_summary = "hit: " + payload.source_name

	apply_attack_to_player(payload)


func apply_attack_to_player(payload: DamagePayload) -> void:
	if payload == null:
		return

	GameState.take_damage(payload.amount)

	show_message(
		get_enemy_display_name()
		+ " hits Grace with "
		+ payload.source_name
		+ " for "
		+ str(payload.amount)
		+ "."
	)


func move_toward_player(delta: float) -> void:
	if player == null:
		clear_horizontal_velocity()
		return

	var direction: Vector3 = player.global_position - actor.global_position
	direction.y = 0.0

	if direction.length() <= 0.01:
		clear_horizontal_velocity()
		return

	direction = direction.normalized()

	var move_multiplier: float = get_status_move_multiplier()
	var speed: float = get_definition().get_move_speed() * move_multiplier

	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed

	face_direction(direction, delta)


func face_player(delta: float) -> void:
	if player == null:
		return

	var direction: Vector3 = player.global_position - actor.global_position
	direction.y = 0.0

	if direction.length() <= 0.01:
		return

	face_direction(direction.normalized(), delta)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length() <= 0.01:
		return

	var target_angle: float = atan2(-direction.x, -direction.z)
	var turn_amount: float = clamp(get_definition().get_turn_speed() * delta, 0.0, 1.0)

	actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, turn_amount)


func is_player_in_attack_range() -> bool:
	if player == null or default_attack == null:
		return false

	if get_distance_to_player() > default_attack.range:
		return false

	return is_player_in_attack_cone()


func is_player_in_attack_cone() -> bool:
	if player == null or default_attack == null:
		return false

	var to_player: Vector3 = player.global_position - actor.global_position
	to_player.y = 0.0

	if to_player.length() <= 0.01:
		return true

	var direction_to_player: Vector3 = to_player.normalized()
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0

	if forward.length() <= 0.01:
		return true

	forward = forward.normalized()

	var minimum_dot: float = cos(deg_to_rad(default_attack.cone_angle_degrees * 0.5))

	return forward.dot(direction_to_player) >= minimum_dot


func get_distance_to_player() -> float:
	if player == null or actor == null:
		return INF

	return actor.global_position.distance_to(player.global_position)


func clear_horizontal_velocity() -> void:
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0


func apply_gravity(delta: float) -> void:
	if not actor.is_on_floor():
		actor.velocity.y -= get_definition().get_gravity() * delta
	else:
		if actor.velocity.y < 0.0:
			actor.velocity.y = -0.1


func apply_external_force(delta: float) -> void:
	if force_receiver == null:
		return

	if not force_receiver.has_method("consume_external_velocity"):
		return

	var force_velocity: Vector3 = force_receiver.consume_external_velocity(delta)

	actor.velocity.x += force_velocity.x
	actor.velocity.z += force_velocity.z


func status_blocks_actions() -> bool:
	if status_receiver == null:
		return false

	if status_receiver.has_method("blocks_actions"):
		return status_receiver.blocks_actions()

	return false


func get_status_move_multiplier() -> float:
	if status_receiver == null:
		return 1.0

	if status_receiver.has_method("get_movement_multiplier"):
		return status_receiver.get_movement_multiplier()

	return 1.0


func is_defeated() -> bool:
	if hit_receiver == null:
		return false

	var current_health = hit_receiver.get("current_health")

	if current_health != null and int(current_health) <= 0:
		return true

	return false


func get_definition() -> EnemyDefinition:
	if enemy_definition != null:
		return enemy_definition

	var fallback: EnemyDefinition = EnemyDefinition.new()
	fallback.display_name = actor.name if actor != null else "Enemy"
	return fallback


func get_enemy_display_name() -> String:
	return get_definition().get_display_name()


func get_attack_recovery() -> float:
	if default_attack == null:
		return 0.4

	return default_attack.recovery_time


func change_state(new_state: EnemyState, timer: float = 0.0) -> void:
	if state == new_state and state_timer == timer:
		return

	state = new_state
	state_timer = timer


func apply_definition_to_components() -> void:
	var definition: EnemyDefinition = get_definition()

	apply_definition_to_hit_receiver(definition)
	apply_definition_to_force_receiver(definition)
	apply_definition_tags(definition)
	refresh_overhead_hud()

	last_action_summary = "class: " + definition.get_class_summary()


func apply_definition_to_hit_receiver(definition: EnemyDefinition) -> void:
	if hit_receiver == null:
		return

	hit_receiver.set("target_name", definition.get_display_name())
	hit_receiver.set("hit_mode", definition.get_hit_mode())
	hit_receiver.set("max_health", definition.get_max_health())
	hit_receiver.set("current_health", definition.get_max_health())
	hit_receiver.set("max_stance", definition.get_max_stance())
	hit_receiver.set("current_stance", definition.get_max_stance())
	hit_receiver.set("resets_stance_after_break", definition.get_resets_stance_after_break())
	hit_receiver.set("disappears_when_defeated", definition.get_disappears_when_defeated())
	hit_receiver.set("restores_mana_when_defeated", definition.get_restores_mana_when_defeated())
	hit_receiver.set("weak_elements", definition.get_weak_elements())
	hit_receiver.set("resistant_elements", definition.get_resistant_elements())
	hit_receiver.set("immune_elements", definition.get_immune_elements())
	hit_receiver.set("weakness_multiplier", definition.get_weakness_multiplier())
	hit_receiver.set("resistance_multiplier", definition.get_resistance_multiplier())


func apply_definition_to_force_receiver(definition: EnemyDefinition) -> void:
	if force_receiver == null:
		return

	force_receiver.set("drag", definition.get_force_drag())
	force_receiver.set("max_force_speed", definition.get_max_force_speed())


func apply_definition_tags(definition: EnemyDefinition) -> void:
	if tag_component == null:
		return

	if not tag_component.has_method("add_tag"):
		return

	for tag: String in definition.get_tags():
		tag_component.add_tag(tag)


func refresh_overhead_hud() -> void:
	if actor == null:
		return

	var hud: Node = EnemyOverheadHud.ensure_for_target(actor)

	if hud != null and hud.has_method("refresh_now"):
		hud.refresh_now()


func show_message(text: String) -> void:
	if show_debug_prints:
		print(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func get_debug_data() -> Dictionary:
	return {
		"state": EnemyState.keys()[state],
		"enemy": get_enemy_display_name(),
		"class": get_definition().get_class_summary(),
		"dist": snapped(get_distance_to_player(), 0.1),
		"cd": snapped(attack_cooldown_timer, 0.1),
		"last": last_action_summary,
	}


func wait_for_attack_opening(delta: float) -> void:
	if get_definition().get_circle_when_waiting_to_attack():
		circle_player(delta)
	else:
		clear_horizontal_velocity()
		face_player(delta)


func circle_player(delta: float) -> void:
	if player == null:
		clear_horizontal_velocity()
		return

	var to_player: Vector3 = player.global_position - actor.global_position
	to_player.y = 0.0

	if to_player.length() <= 0.01:
		clear_horizontal_velocity()
		return

	var toward_player: Vector3 = to_player.normalized()
	var tangent: Vector3 = Vector3(-toward_player.z, 0.0, toward_player.x) * strafe_direction

	var desired_distance: float = get_definition().get_preferred_distance()
	var distance: float = get_distance_to_player()
	var spacing_push: Vector3 = Vector3.ZERO

	if distance < desired_distance:
		spacing_push = -toward_player * 0.65
	elif distance > desired_distance + get_definition().get_spacing_buffer():
		spacing_push = toward_player * 0.35

	var move_direction: Vector3 = (tangent + spacing_push).normalized()
	var move_multiplier: float = get_status_move_multiplier()
	var speed: float = get_definition().get_move_speed() * get_definition().get_strafe_speed_multiplier() * move_multiplier

	actor.velocity.x = move_direction.x * speed
	actor.velocity.z = move_direction.z * speed

	face_player(delta)
