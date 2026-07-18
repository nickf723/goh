extends "res://scripts/enemies/enemy_brain.gd"
class_name EnemyZoneAwareBrain

const ZoneAwareness = preload("res://scripts/enemies/enemy_zone_awareness.gd")
const PersonalityTraits = preload("res://scripts/enemies/enemy_personality_traits.gd")

@export_group("Personality")
@export var personality_id: String = "balanced"

@export_group("Zone Awareness")
@export var enable_zone_awareness: bool = true
@export var zone_awareness_radius: float = 5.0
@export var zone_avoid_strength: float = 1.25
@export var zone_hesitation_time: float = 0.16
@export var zone_debug_prints: bool = false

var zone_awareness_data: Dictionary = {}
var zone_hesitation_timer: float = 0.0
var last_zone_summary: String = "clear"
var personality_profile: Dictionary = {}


func _ready() -> void:
	super._ready()
	personality_profile = PersonalityTraits.get_profile(personality_id)
	zone_awareness_data = ZoneAwareness.empty_result()


func _physics_process(delta: float) -> void:
	update_zone_awareness(delta)
	super._physics_process(delta)


func update_zone_awareness(delta: float) -> void:
	if zone_hesitation_timer > 0.0:
		zone_hesitation_timer -= delta

	if not enable_zone_awareness or actor == null:
		zone_awareness_data = ZoneAwareness.empty_result()
		return

	var awareness_radius: float = zone_awareness_radius * get_personality_number("zone_awareness_radius_multiplier", 1.0)
	zone_awareness_data = ZoneAwareness.evaluate(actor, awareness_radius)

	if bool(zone_awareness_data.get("hesitate", false)):
		var hesitation: float = zone_hesitation_time * get_personality_number("zone_hesitation_time_multiplier", 1.0)
		zone_hesitation_timer = max(zone_hesitation_timer, hesitation)

	var summary: String = get_zone_summary()
	if zone_debug_prints and summary != last_zone_summary:
		print(get_enemy_display_name(), " zone awareness: ", summary)
	last_zone_summary = summary


func process_chase(delta: float) -> void:
	if should_hesitate_for_zone():
		clear_horizontal_velocity()
		reset_attack_commit()
		face_player(delta)
		last_action_summary = "hesitating near " + get_zone_summary()
		return

	super.process_chase(delta)


func commit_to_attack(delta: float, distance: float, attack: EnemyAttackDefinition) -> void:
	if distance > attack.get_range():
		reset_attack_commit()
		last_action_summary = "closing: " + attack.get_display_name()
		move_toward_player(delta)
		return

	clear_horizontal_velocity()
	face_player(delta)

	attack_commit_timer += delta
	last_action_summary = "pressuring: " + attack.get_display_name()

	var commit_time: float = max(get_definition().get_attack_commit_time(), 0.0)
	commit_time *= get_personality_number("attack_commit_time_multiplier", 1.0)

	if attack_commit_timer >= commit_time:
		start_attack()


func move_toward_player(delta: float) -> void:
	if player == null:
		clear_horizontal_velocity()
		return

	var direction: Vector3 = player.global_position - actor.global_position
	direction.y = 0.0

	if direction.length() <= 0.01:
		clear_horizontal_velocity()
		return

	direction = get_zone_adjusted_direction(direction)

	var move_multiplier: float = get_status_move_multiplier()
	var speed: float = get_definition().get_move_speed() * move_multiplier

	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed

	if is_zone_active():
		last_action_summary = "steering around " + get_zone_summary()

	face_direction(direction, delta)


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
	move_direction = get_zone_adjusted_direction(move_direction)

	var move_multiplier: float = get_status_move_multiplier()
	var speed: float = get_definition().get_move_speed() * get_definition().get_strafe_speed_multiplier() * move_multiplier

	actor.velocity.x = move_direction.x * speed
	actor.velocity.z = move_direction.z * speed

	if is_zone_active():
		last_action_summary = "circling around " + get_zone_summary()

	face_player(delta)


func get_zone_adjusted_direction(desired_direction: Vector3) -> Vector3:
	desired_direction.y = 0.0
	if desired_direction.length() <= 0.01:
		return Vector3.ZERO

	var desired: Vector3 = desired_direction.normalized()
	var avoid_direction: Vector3 = get_zone_avoid_direction()
	if avoid_direction.length() <= 0.01:
		return desired

	var behavior: String = str(zone_awareness_data.get("behavior", "none"))
	var strength: float = zone_avoid_strength
	strength *= get_personality_number("zone_avoid_strength_multiplier", 1.0)
	strength *= PersonalityTraits.get_behavior_avoid_multiplier(personality_id, behavior, 1.0)

	match behavior:
		"slow":
			strength *= 0.65
		"trap":
			strength *= 0.9
		"danger":
			strength *= 1.15

	var mixed: Vector3 = desired + avoid_direction.normalized() * strength
	mixed.y = 0.0

	if mixed.length() <= 0.01:
		return avoid_direction.normalized()

	return mixed.normalized()


func should_hesitate_for_zone() -> bool:
	return zone_hesitation_timer > 0.0 and is_zone_active()


func is_zone_active() -> bool:
	return bool(zone_awareness_data.get("active", false))


func get_zone_avoid_direction() -> Vector3:
	if not is_zone_active():
		return Vector3.ZERO

	var avoid_value: Variant = zone_awareness_data.get("avoid_direction", Vector3.ZERO)
	if avoid_value is Vector3:
		return avoid_value as Vector3

	return Vector3.ZERO


func get_zone_summary() -> String:
	if not is_zone_active():
		return "clear"

	var summary: String = str(zone_awareness_data.get("summary", "hazard"))
	var behavior: String = str(zone_awareness_data.get("behavior", "hazard"))
	var distance: float = float(zone_awareness_data.get("distance", 0.0))
	return summary + " / " + behavior + " / " + str(snapped(distance, 0.1)) + "m"


func get_personality_number(key: String, fallback: float = 1.0) -> float:
	return PersonalityTraits.get_number(personality_id, key, fallback)


func get_personality_summary() -> String:
	return PersonalityTraits.get_debug_summary(personality_id)


func get_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_debug_data()
	debug_data["personality"] = get_personality_summary()
	debug_data["zone"] = get_zone_summary()
	debug_data["zone_wait"] = snapped(zone_hesitation_timer, 0.1)
	return debug_data
