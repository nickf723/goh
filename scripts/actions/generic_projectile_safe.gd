extends "res://scripts/actions/generic_projectile.gd"
class_name GenericProjectileSafe

# Gameplay receivers do not all share one return contract. Combat receivers
# often return a result Dictionary, while environmental receivers such as
# Recorded Objects deliberately perform their reaction and return void. The
# base projectile used to return those values directly from a Dictionary-typed
# function, turning a successful barrel detonation into a runtime type error.
var last_payload_result: Dictionary = {}


func send_payload_to_target(
	target: Node,
	damage_payload: DamagePayload
) -> Dictionary:
	if target == null:
		return _store_payload_result({
			"message": "The projectile has no valid target.",
			"objective": "",
			"handled": false,
		})

	var target_name: String = target.name
	var source_name: String = (
		damage_payload.source_name
		if damage_payload != null
		else "Projectile"
	)
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return _normalize_payload_result(
			payload_receiver.call("receive_payload", damage_payload),
			target_name,
			source_name
		)

	if target.has_method("receive_damage_payload"):
		return _normalize_payload_result(
			target.call("receive_damage_payload", damage_payload),
			target_name,
			source_name
		)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			return _normalize_payload_result(
				hit_receiver.call("receive_payload", damage_payload),
				target_name,
				source_name
			)
		if hit_receiver.has_method("receive_hit"):
			return _normalize_payload_result(
				hit_receiver.call(
					"receive_hit",
					damage_payload.amount if damage_payload != null else 0
				),
				target_name,
				source_name
			)

	if target.has_method("receive_magic_hit"):
		return _normalize_payload_result(
			target.call(
				"receive_magic_hit",
				damage_payload.amount if damage_payload != null else 0
			),
			target_name,
			source_name
		)

	return _store_payload_result({
		"message": source_name + " hits " + target_name + ", but nothing happens.",
		"objective": "",
		"handled": false,
	})


func _normalize_payload_result(
	value: Variant,
	target_name: String,
	source_name: String
) -> Dictionary:
	if value is Dictionary:
		var dictionary_result: Dictionary = (value as Dictionary).duplicate(true)
		if not dictionary_result.has("message"):
			dictionary_result["message"] = ""
		if not dictionary_result.has("objective"):
			dictionary_result["objective"] = ""
		dictionary_result["handled"] = bool(
			dictionary_result.get("handled", true)
		)
		return _store_payload_result(dictionary_result)

	if value is String:
		return _store_payload_result({
			"message": str(value),
			"objective": "",
			"handled": true,
		})

	# Nil, booleans, and numeric receiver results all mean that the receiver
	# accepted the call but did not provide presentation metadata. Keep the hit
	# silent and let its own reaction visuals speak.
	return _store_payload_result({
		"message": "",
		"objective": "",
		"handled": true,
		"target": target_name,
		"source": source_name,
		"receiver_return_type": type_string(typeof(value)),
	})


func _store_payload_result(result: Dictionary) -> Dictionary:
	last_payload_result = result.duplicate(true)
	return last_payload_result
