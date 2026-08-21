extends "res://scripts/actions/generic_projectile_safe.gd"
class_name DeathSyphonProjectile

@export_group("Life Drain")
@export_range(0.0, 2.0, 0.05) var heal_ratio: float = 0.75
@export_range(0, 20, 1) var minimum_heal: int = 1
@export_range(1, 50, 1) var maximum_heal: int = 8

var last_damage_dealt: int = 0
var last_heal_granted: int = 0
var total_health_stolen: int = 0


func _ready() -> void:
	speed = 20.0
	max_lifetime = 3.0
	trail_interval = 0.055
	show_miss_feedback = true
	super._ready()


func send_payload_to_target(
	target: Node,
	damage_payload: DamagePayload
) -> Dictionary:
	var health_before: int = _read_target_health(target)
	var result: Dictionary = super.send_payload_to_target(target, damage_payload)
	var health_after: int = _read_target_health(target)
	last_damage_dealt = _resolve_actual_damage(result, health_before, health_after)
	last_heal_granted = _grant_syphon_heal(last_damage_dealt)
	if last_heal_granted > 0:
		total_health_stolen += last_heal_granted
		result["syphon_heal"] = last_heal_granted
		var message: String = str(result.get("message", ""))
		var suffix: String = "Grace siphons " + str(last_heal_granted) + " health."
		result["message"] = suffix if message == "" else message + " " + suffix
	last_payload_result = result.duplicate(true)
	return result


func _read_target_health(target: Node) -> int:
	if target == null or not is_instance_valid(target):
		return -1
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver == null:
		return -1
	var value: Variant = hit_receiver.get("current_health")
	if value is int:
		return int(value)
	if value is float:
		return roundi(float(value))
	return -1


func _resolve_actual_damage(
	result: Dictionary,
	health_before: int,
	health_after: int
) -> int:
	if health_before >= 0 and health_after >= 0:
		return maxi(health_before - health_after, 0)
	return maxi(int(result.get("damage_dealt", 0)), 0)


func _grant_syphon_heal(actual_damage: int) -> int:
	if actual_damage <= 0 or source_actor == null or not is_instance_valid(source_actor):
		return 0
	var raw_heal: int = roundi(float(actual_damage) * maxf(heal_ratio, 0.0))
	var heal_amount: int = clampi(
		maxi(raw_heal, minimum_heal),
		0,
		maxi(maximum_heal, 1)
	)
	if heal_amount <= 0:
		return 0
	if source_actor.is_in_group("player"):
		GameState.heal(heal_amount)
		return heal_amount
	if source_actor.has_method("receive_heal"):
		source_actor.call("receive_heal", heal_amount, self)
		return heal_amount
	if source_actor.has_method("heal"):
		source_actor.call("heal", heal_amount)
		return heal_amount
	return 0


func get_debug_data() -> Dictionary:
	var data: Dictionary = get_airflow_debug_data()
	data["spell"] = "syphon"
	data["life_drain_contract"] = true
	data["heals_from_resolved_damage"] = true
	data["heal_ratio"] = heal_ratio
	data["last_damage_dealt"] = last_damage_dealt
	data["last_heal_granted"] = last_heal_granted
	data["total_health_stolen"] = total_health_stolen
	return data
