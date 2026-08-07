extends "res://scripts/actions/lightning_spark_burst.gd"
class_name LightningSparkBurstUpgraded

const SpellModifiers = preload(
	"res://scripts/abilities/spell_modifier_registry.gd"
)

var chain_effect_applied: bool = false
var chain_message_count: int = 0
var primary_target_count: int = 0
var chain_primary_target_name: String = ""


func execute(player: Node3D, requested_direction: Vector3) -> void:
	if player != null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	cast_direction = requested_direction
	cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = -source_actor.global_transform.basis.z
		cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = Vector3.FORWARD
	cast_direction = cast_direction.normalized()

	cast_origin = source_actor.global_position + Vector3.UP * origin_height
	global_transform = Transform3D(_get_cast_basis(), cast_origin)
	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)

	last_hit_names.clear()
	last_hit_count = 0
	last_query_result_count = 0
	chain_effect_applied = false
	chain_message_count = 0
	primary_target_count = 0
	chain_primary_target_name = ""
	last_visual_range = _resolve_centerline_visual_range()

	var hits: Array[Dictionary] = _collect_cone_targets()
	hits.sort_custom(_sort_hit_by_distance)
	primary_target_count = hits.size()
	var used_target_ids: Dictionary = {}
	for hit: Dictionary in hits:
		var target_value: Variant = hit.get("target")
		if target_value is Node:
			used_target_ids[(target_value as Node).get_instance_id()] = true

	for hit: Dictionary in hits:
		var target_value: Variant = hit.get("target")
		if not target_value is Node:
			continue
		var target: Node = target_value as Node
		_apply_spark_payload(target)
		last_hit_count += 1
		last_hit_names.append(str(target.name))
		target_struck.emit(
			target,
			float(hit.get("distance", 0.0)),
			float(hit.get("angle_degrees", 0.0))
		)

	# Lightning Spark now owns a whole primary cone. Preserve the existing Chain
	# Lightning upgrade without multiplying it once per primary target: one chain
	# begins at the nearest primary hit, while every target already struck by the
	# fan is excluded from secondary jumps.
	if not hits.is_empty():
		var primary_value: Variant = hits[0].get("target")
		if primary_value is Node:
			var primary_target: Node = primary_value as Node
			chain_primary_target_name = str(primary_target.name)
			var messages: Array[String] = SpellModifiers.apply_on_hit_effects(
				self,
				primary_target,
				get_payload(),
				_get_target_center(primary_target),
				cast_direction,
				used_target_ids
			)
			chain_message_count = messages.size()
			chain_effect_applied = not SpellModifiers.get_on_hit_modifiers_for_payload(
				get_payload()
			).is_empty()

	_build_procedural_spark_pattern(last_visual_range)
	last_haptic_started = _play_haptic_pattern(last_hit_count)
	age = 0.0
	active = true
	if spark_segments != null:
		spark_segments.visible = true
		spark_segments.transparency = 0.0
	if spark_light != null:
		spark_light.light_energy = 3.6
	set_process(true)
	spark_fired.emit(last_hit_count)

	if show_debug_messages:
		print(
			"LIGHTNING_SPARK cone hit ",
			last_hit_count,
			" targets: ",
			last_hit_names,
			" chain=",
			chain_effect_applied
		)


func send_payload_to_target(
	target: Node,
	damage_payload: DamagePayload
) -> Dictionary:
	if target == null or damage_payload == null:
		return {
			"message": "Lightning has no valid receiver.",
			"objective": "",
			"handled": false,
		}

	var target_name: String = str(target.name)
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return _normalize_payload_result(
			payload_receiver.call("receive_payload", damage_payload),
			target_name,
			damage_payload.source_name
		)
	if target.has_method("receive_damage_payload"):
		return _normalize_payload_result(
			target.call("receive_damage_payload", damage_payload),
			target_name,
			damage_payload.source_name
		)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			return _normalize_payload_result(
				hit_receiver.call("receive_payload", damage_payload),
				target_name,
				damage_payload.source_name
			)
		if hit_receiver.has_method("receive_hit"):
			return _normalize_payload_result(
				hit_receiver.call("receive_hit", damage_payload.amount),
				target_name,
				damage_payload.source_name
			)

	if target.has_method("receive_magic_hit"):
		return _normalize_payload_result(
			target.call("receive_magic_hit", damage_payload.amount),
			target_name,
			damage_payload.source_name
		)

	return {
		"message": damage_payload.source_name + " reaches " + target_name
		+ ", but nothing receives it.",
		"objective": "",
		"handled": false,
	}


func _normalize_payload_result(
	value: Variant,
	target_name: String,
	source_name: String
) -> Dictionary:
	if value is Dictionary:
		var result: Dictionary = (value as Dictionary).duplicate(true)
		result["handled"] = bool(result.get("handled", true))
		if not result.has("message"):
			result["message"] = ""
		if not result.has("objective"):
			result["objective"] = ""
		return result
	if value is String:
		return {
			"message": str(value),
			"objective": "",
			"handled": true,
		}
	return {
		"message": "",
		"objective": "",
		"handled": true,
		"target": target_name,
		"source": source_name,
		"receiver_return_type": type_string(typeof(value)),
	}


func _sort_hit_by_distance(left: Dictionary, right: Dictionary) -> bool:
	return float(left.get("distance", INF)) < float(right.get("distance", INF))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["chain_upgrade_compatible"] = true
	data["chain_effect_applied"] = chain_effect_applied
	data["chain_message_count"] = chain_message_count
	data["chain_primary_target"] = chain_primary_target_name
	data["primary_target_count"] = primary_target_count
	data["chain_per_primary"] = false
	return data
