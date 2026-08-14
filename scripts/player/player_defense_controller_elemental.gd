extends "res://scripts/player/player_defense_controller.gd"
class_name PlayerDefenseControllerElemental

var elemental_authority_controller: PlayerElementalAuthorityController
var last_authority_result: Dictionary = {}


func _ready() -> void:
	super._ready()
	if actor != null:
		elemental_authority_controller = actor.get_node_or_null(
			"ElementalAuthorityController"
		) as PlayerElementalAuthorityController


func resolve_incoming_attack(
	payload: DamagePayload,
	attacker: Node3D = null
) -> Dictionary:
	last_authority_result.clear()
	if _surf_negates_surface_hazard(payload):
		return _resolve_surf_surface_hazard(payload)
	if (
		payload != null
		and actor != null
		and payload.element.strip_edges().to_lower() == "fire"
		and bool(actor.get_meta("divine_special_fire_immunity", false))
	):
		last_outcome = "divine_special_fire_immunity"
		var hearth_result: Dictionary = make_result(
			"divine_special_fire_immunity",
			payload,
			"The Hearth drinks " + payload.source_name + " before it reaches Grace."
		)
		hearth_result["divine_special"] = "ruvia_hearth_first_flame"
		hearth_result["negated_element"] = "fire"
		hearth_result["damage"] = 0
		hearth_result["stance_damage"] = 0
		hearth_result["health_damage"] = 0
		hearth_result["stance_cost"] = 0
		show_message(str(hearth_result.get("message", "")))
		player_hit.emit(hearth_result)
		emit_defense_state()
		return hearth_result
	if payload == null or elemental_authority_controller == null:
		var direct_counter: Dictionary = _resolve_weapon_counter_contract(
			payload,
			attacker
		)
		if not direct_counter.is_empty():
			return direct_counter
		return super.resolve_incoming_attack(payload, attacker)

	last_authority_result = elemental_authority_controller.resolve_incoming_payload(
		payload
	)
	if bool(last_authority_result.get("immune", false)):
		last_outcome = "elemental_authority"
		var avatar_name: String = "Grace"
		if actor != null:
			avatar_name = str(
				actor.get_meta("active_avatar_display_name", avatar_name)
			)
		var result: Dictionary = make_result(
			"elemental_authority",
			payload,
			avatar_name
			+ " walks through "
			+ payload.source_name
			+ " without harm."
		)
		result["authority_id"] = str(
			last_authority_result.get("authority_id", "none")
		)
		result["negated_element"] = payload.element
		result["damage"] = 0
		result["stance_damage"] = 0
		result["health_damage"] = 0
		result["stance_cost"] = 0
		show_message(str(result.get("message", "")))
		player_hit.emit(result)
		emit_defense_state()
		return result

	var resolved_value: Variant = last_authority_result.get("payload", payload)
	if resolved_value is DamagePayload:
		var resolved_payload: DamagePayload = resolved_value as DamagePayload
		var transformed_counter: Dictionary = _resolve_weapon_counter_contract(
			resolved_payload,
			attacker
		)
		if not transformed_counter.is_empty():
			return transformed_counter
		return super.resolve_incoming_attack(
			resolved_payload,
			attacker
		)
	var fallback_counter: Dictionary = _resolve_weapon_counter_contract(
		payload,
		attacker
	)
	if not fallback_counter.is_empty():
		return fallback_counter
	return super.resolve_incoming_attack(payload, attacker)


# Weapon counters sit inside elemental authority and Bubble, but outside the
# ordinary F/Y guard. The weapon controller owns stance-specific timing and hit
# eligibility; defense remains the sole authority that negates the incoming hit
# and emits the shared blocked-attack result.
func _resolve_weapon_counter_contract(
	payload: DamagePayload,
	attacker: Node3D
) -> Dictionary:
	if payload == null or actor == null or GameState.is_player_invulnerable():
		return {}
	if (
		bubble_shield_controller != null
		and is_instance_valid(bubble_shield_controller)
		and bubble_shield_controller.has_method("is_bubble_active")
		and bool(bubble_shield_controller.call("is_bubble_active"))
	):
		# Bubble remains the outermost ordinary defense layer.
		return {}
	var weapon_controller: Node = actor.get_node_or_null("WeaponController")
	if (
		weapon_controller == null
		or not weapon_controller.has_method("resolve_incoming_weapon_counter")
	):
		return {}
	var raw_value: Variant = weapon_controller.call(
		"resolve_incoming_weapon_counter",
		payload,
		attacker,
		get_incoming_direction(attacker)
	)
	if not raw_value is Dictionary:
		return {}
	var weapon_result: Dictionary = raw_value as Dictionary
	if not bool(weapon_result.get("handled", false)):
		return {}

	last_outcome = str(
		weapon_result.get("outcome", "weapon_counter_block")
	)
	var incoming_direction: Vector3 = get_incoming_direction(attacker)
	start_hit_reaction(
		-incoming_direction,
		maxf(float(weapon_result.get("recoil_seconds", 0.08)), 0.01),
		maxf(float(weapon_result.get("recoil_speed", 0.5)), 0.0)
	)
	var feedback_value: Variant = weapon_result.get(
		"feedback_color",
		Color(0.18, 0.7, 1.0, 0.96)
	)
	var feedback_color: Color = (
		feedback_value as Color
		if feedback_value is Color
		else Color(0.18, 0.7, 1.0, 0.96)
	)
	flash_feedback(
		feedback_color,
		maxf(float(weapon_result.get("feedback_duration", 0.2)), 0.01)
	)

	var result: Dictionary = make_result(
		last_outcome,
		payload,
		str(weapon_result.get("message", "Weapon counter!"))
	)
	for key: Variant in weapon_result.keys():
		if str(key) != "handled":
			result[key] = weapon_result[key]
	result["damage"] = int(result.get("damage", 0))
	result["stance_damage"] = int(result.get("stance_damage", 0))
	result["health_damage"] = int(result.get("health_damage", 0))
	result["stamina_cost"] = int(result.get("stamina_cost", 0))
	result["stance_cost"] = int(result.get("stance_cost", 0))
	show_message(str(result.get("message", "")))
	attack_blocked.emit(result)
	emit_defense_state()
	return result


func _surf_negates_surface_hazard(payload: DamagePayload) -> bool:
	if payload == null or actor == null:
		return false
	if not bool(actor.get_meta("surf_surface_hazard_immunity", false)):
		return false
	var normalized_hit_type: String = payload.hit_type.strip_edges().to_lower()
	if normalized_hit_type in [
		"surface_hazard",
		"terrain_hazard",
		"lava_surface",
		"spike_floor",
	]:
		return true
	for tag: String in payload.tags:
		if tag.strip_edges().to_lower() in [
			"surface_hazard",
			"terrain_hazard",
			"ground_hazard",
			"lava_surface",
			"spike_floor",
		]:
			return true
	return false


func _resolve_surf_surface_hazard(payload: DamagePayload) -> Dictionary:
	last_outcome = "surf_surface_hazard"
	last_authority_result = {
		"immune": true,
		"authority_id": "surf_surface_hazard",
		"surface_hazard": true,
		"element": payload.element,
	}
	var result: Dictionary = make_result(
		"surf_surface_hazard",
		payload,
		"Surf carries Grace over " + payload.source_name + "."
	)
	result["surf"] = true
	result["surface_hazard"] = true
	result["negated_element"] = payload.element
	result["damage"] = 0
	result["stance_damage"] = 0
	result["health_damage"] = 0
	result["stance_cost"] = 0
	result["stamina_cost"] = 0
	result["negated_damage"] = payload.amount
	result["negated_stance_damage"] = payload.stance_damage
	var surf_controller: Node = actor.get_node_or_null("SurfController")
	if (
		surf_controller != null
		and surf_controller.has_method("record_hazard_negation")
	):
		surf_controller.call("record_hazard_negation", payload)
	attack_blocked.emit(result)
	emit_defense_state()
	return result


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["authority_ready"] = elemental_authority_controller != null
	data["authority_result"] = last_authority_result.duplicate(true)
	data["authority_id"] = (
		elemental_authority_controller.get_debug_data().get(
			"authority_id",
			"none"
		)
		if elemental_authority_controller != null
		else "none"
	)
	data["hearth_fire_immunity"] = (
		actor != null
		and bool(actor.get_meta("divine_special_fire_immunity", false))
	)
	data["surf_surface_hazard_immunity"] = (
		actor != null
		and bool(actor.get_meta("surf_surface_hazard_immunity", false))
	)
	data["weapon_counter_contract"] = true
	return data
