extends Node

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")
const EnemyOverheadHud = preload("res://scripts/combat/enemy_overhead_hud.gd")

signal health_changed(current_health: int, max_health: int)
signal stance_changed(current_stance: int, max_stance: int)
signal health_depleted
signal stance_broken
signal critical_window_opened(duration: float)
signal critical_window_closed
signal critical_struck(damage: int)

enum HitMode {
	INVULNERABLE,
	STANCE_ONLY,
	HEALTH_ONLY,
	STANCE_THEN_HEALTH,
}

@export var target_name: String = "Target"
@export var hit_mode: HitMode = HitMode.STANCE_ONLY

@export var max_health: int = 1
@export var current_health: int = 1

@export var max_stance: int = 3
@export var current_stance: int = 3

@export var resets_stance_after_break: bool = false
@export var disappears_when_defeated: bool = false

@export_group("Stance Recovery")
@export var regenerates_stance: bool = true
@export_range(0.0, 10.0, 0.05) var stance_regeneration_delay: float = 2.25
@export_range(0.0, 30.0, 0.1) var stance_regeneration_per_second: float = 4.0

@export_group("Critical Window")
@export_range(0.1, 10.0, 0.05) var critical_window_seconds: float = 3.0
@export_range(0.05, 1.0, 0.05) var stance_recovery_ratio: float = 1.0
@export var critical_requires_weapon_melee: bool = true

@export var restores_mana_when_defeated: int = 0

@export var weak_elements: Array[String] = []
@export var resistant_elements: Array[String] = []
@export var immune_elements: Array[String] = []

@export var weakness_multiplier: float = 2.0
@export var resistance_multiplier: float = 0.5

@export var last_payload_summary: String = "none"

var critical_window_open: bool = false
var critical_window_timer: float = 0.0
var stance_regeneration_delay_timer: float = 0.0
var stance_regeneration_carry: float = 0.0


func _ready() -> void:
	current_health = clamp(current_health, 0, max_health)
	current_stance = clamp(current_stance, 0, max_stance)
	add_to_group("debuggable")
	refresh_overhead_hud()


func _process(delta: float) -> void:
	advance_stance_state(delta)


func advance_stance_state(delta: float) -> void:
	if delta <= 0.0 or current_health <= 0:
		return

	if critical_window_open:
		critical_window_timer = maxf(critical_window_timer - delta, 0.0)
		if critical_window_timer <= 0.0:
			close_critical_window(true)
		return

	stance_regeneration_delay_timer = maxf(
		stance_regeneration_delay_timer - delta,
		0.0
	)

	if (
		not regenerates_stance
		or stance_regeneration_delay_timer > 0.0
		or current_stance <= 0
		or current_stance >= max_stance
	):
		return

	stance_regeneration_carry += maxf(stance_regeneration_per_second, 0.0) * delta
	var recovered_points: int = floori(stance_regeneration_carry)

	if recovered_points <= 0:
		return

	stance_regeneration_carry -= float(recovered_points)
	current_stance = mini(current_stance + recovered_points, max_stance)
	stance_changed.emit(current_stance, max_stance)
	refresh_overhead_hud()


func receive_hit(power: int = 1) -> Dictionary:
	var result: Dictionary = {}

	match hit_mode:
		HitMode.INVULNERABLE:
			result = _receive_invulnerable_hit()

		HitMode.STANCE_ONLY:
			result = _damage_stance(power)

		HitMode.HEALTH_ONLY:
			result = _damage_health(power)

		HitMode.STANCE_THEN_HEALTH:
			if current_stance > 0:
				result = _damage_stance(power)
			else:
				result = _damage_health(power)

		_:
			result = {
				"message": target_name + " is hit, but nothing happens.",
				"objective": ""
			}

	show_basic_feedback(power, result)
	refresh_overhead_hud()
	return result


func _receive_invulnerable_hit() -> Dictionary:
	return {
		"message": "Arcane Spark flickers against " + target_name + ". It does not seem harmed.",
		"objective": "Some targets cannot be damaged yet."
	}


func _damage_stance(power: int) -> Dictionary:
	current_stance = clamp(current_stance - power, 0, max_stance)
	arm_stance_regeneration()
	stance_changed.emit(current_stance, max_stance)

	if current_stance <= 0:
		return resolve_stance_break("Hit")

	return {
		"message": target_name + " is hit. Stance: " + str(current_stance) + " / " + str(max_stance),
		"objective": "Keep testing target stance.",
		"stance_damage_dealt": power,
	}


func _damage_health(power: int) -> Dictionary:
	current_health = clamp(current_health - power, 0, max_health)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		health_depleted.emit()

		var message: String = target_name + " is defeated."

		if restores_mana_when_defeated > 0:
			GameState.restore_mana(restores_mana_when_defeated)
			message += " Grace recovers " + str(restores_mana_when_defeated) + " mana."

		if disappears_when_defeated and get_parent() != null:
			get_parent().queue_free()

		return {
			"message": message,
			"objective": "Breaking objects can now reward the player.",
			"damage_dealt": power,
		}

	return {
		"message": target_name + " is hit. Health: " + str(current_health) + " / " + str(max_health),
		"objective": "Keep testing target health.",
		"damage_dealt": power,
	}


func reset_health() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	refresh_overhead_hud()


func reset_stance() -> void:
	close_critical_window(false)
	current_stance = max_stance
	stance_regeneration_delay_timer = 0.0
	stance_regeneration_carry = 0.0
	stance_changed.emit(current_stance, max_stance)
	refresh_overhead_hud()


func receive_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {
			"message": target_name + " receives an invalid payload.",
			"objective": "",
		}

	last_payload_summary = (
		payload.source_name
		+ " | " + payload.element
		+ " | hp:" + str(payload.amount)
		+ " | st:" + str(payload.stance_damage)
		+ " | crit:" + str(snapped(payload.critical_multiplier, 0.01))
		+ " | " + str(payload.tags)
	)

	var result: Dictionary = {}

	if can_receive_critical(payload):
		result = _damage_health_from_payload(
			payload,
			maxf(payload.critical_multiplier, 1.0),
			true
		)
		if bool(result.get("critical", false)):
			close_critical_window(true)
	else:
		match hit_mode:
			HitMode.INVULNERABLE:
				result = _receive_invulnerable_payload(payload)

			HitMode.STANCE_ONLY:
				result = _damage_stance_from_payload(payload)

			HitMode.HEALTH_ONLY:
				result = _damage_health_from_payload(payload)

			HitMode.STANCE_THEN_HEALTH:
				if current_stance > 0:
					result = _damage_stance_from_payload(payload)
				else:
					result = _damage_health_from_payload(payload)

			_:
				result = {
					"message": payload.source_name + " hits " + target_name + ", but nothing happens.",
					"objective": ""
				}

	show_payload_feedback(payload, result)
	if bool(result.get("critical", false)):
		CombatFeedback.show_reaction_feedback(
			get_feedback_target(),
			"critical_strike",
			{
				"reaction_name": "CRITICAL STRIKE",
				"visual_color": Color(1.0, 0.76, 0.16, 1.0),
				"visual_style": "critical_strike",
				"visual_radius": 1.65,
				"visual_duration": 0.48,
			}
		)
	refresh_overhead_hud()
	return result


func _receive_invulnerable_payload(payload: DamagePayload) -> Dictionary:
	return {
		"message": payload.source_name + " flickers against " + target_name + ". It does not seem harmed.",
		"objective": "Some targets cannot be damaged yet."
	}


func _damage_stance_from_payload(payload: DamagePayload) -> Dictionary:
	var modified_stance_damage: int = modify_damage_by_element(payload.stance_damage, payload.element)

	if modified_stance_damage <= 0:
		return {
			"message": target_name + " ignores " + payload.element + " stance damage.",
			"objective": "Element immunity is working.",
			"stance_damage_dealt": 0,
		}

	current_stance = clamp(current_stance - modified_stance_damage, 0, max_stance)
	arm_stance_regeneration()
	stance_changed.emit(current_stance, max_stance)

	if current_stance <= 0:
		var break_result: Dictionary = resolve_stance_break(payload.source_name)
		break_result["stance_damage_dealt"] = modified_stance_damage
		return break_result

	return {
		"message": payload.source_name + " hits " + target_name + ". Stance: " + str(current_stance) + " / " + str(max_stance),
		"objective": "Payload hits are working.",
		"stance_damage_dealt": modified_stance_damage,
	}


func _damage_health_from_payload(
	payload: DamagePayload,
	damage_multiplier: float = 1.0,
	is_critical: bool = false
) -> Dictionary:
	var base_amount: int = max(
		0,
		roundi(float(payload.amount) * maxf(damage_multiplier, 0.0))
	)
	var modified_amount: int = modify_damage_by_element(base_amount, payload.element)

	if modified_amount <= 0:
		return {
			"message": target_name + " is immune to " + payload.element + ".",
			"objective": "Element immunity is working.",
			"critical": false,
			"damage_dealt": 0,
		}

	current_health = clamp(current_health - modified_amount, 0, max_health)
	health_changed.emit(current_health, max_health)

	if is_critical:
		critical_struck.emit(modified_amount)

	if current_health <= 0:
		health_depleted.emit()

		var defeat_message: String = (
			payload.source_name
			+ (" critically defeats " if is_critical else " defeats ")
			+ target_name
			+ "."
		)

		if restores_mana_when_defeated > 0:
			GameState.restore_mana(restores_mana_when_defeated)
			defeat_message += " Grace recovers " + str(restores_mana_when_defeated) + " mana."

		if disappears_when_defeated and get_parent() != null:
			get_parent().queue_free()

		return {
			"message": defeat_message,
			"objective": "Critical attacks capitalize on broken stance." if is_critical else "Payload health damage is working.",
			"critical": is_critical,
			"damage_dealt": modified_amount,
		}

	var hit_verb: String = " critically strikes " if is_critical else " hits "
	return {
		"message": (
			payload.source_name
			+ hit_verb
			+ target_name
			+ " for "
			+ str(modified_amount)
			+ " "
			+ payload.element
			+ " damage. Health: "
			+ str(current_health)
			+ " / "
			+ str(max_health)
		),
		"objective": "Critical attacks capitalize on broken stance." if is_critical else "Element damage is working.",
		"critical": is_critical,
		"damage_dealt": modified_amount,
	}


func resolve_stance_break(source_name: String) -> Dictionary:
	stance_broken.emit()
	var break_message: String = source_name + " breaks " + target_name + "'s stance."
	var opened_window: bool = false

	if resets_stance_after_break:
		current_stance = max_stance
		stance_changed.emit(current_stance, max_stance)
		break_message += " It steadies itself again."
	elif hit_mode == HitMode.STANCE_THEN_HEALTH:
		open_critical_window()
		opened_window = true
		break_message += " Critical opening!"

	return {
		"message": break_message,
		"objective": "Land a weapon attack before the critical opening closes." if opened_window else "Payload stance damage is working.",
		"stance_broken": true,
		"critical_window": opened_window,
		"critical_window_seconds": critical_window_timer,
	}


func open_critical_window() -> void:
	critical_window_open = true
	critical_window_timer = maxf(critical_window_seconds, 0.1)
	stance_regeneration_delay_timer = 0.0
	stance_regeneration_carry = 0.0
	apply_staggered_status(critical_window_timer)
	critical_window_opened.emit(critical_window_timer)


func close_critical_window(restore_stance: bool = true) -> void:
	var was_open: bool = critical_window_open
	critical_window_open = false
	critical_window_timer = 0.0
	clear_staggered_status()

	if restore_stance and current_health > 0:
		var recovered_stance: int = maxi(
			1,
			roundi(float(max_stance) * clampf(stance_recovery_ratio, 0.05, 1.0))
		)
		current_stance = mini(recovered_stance, max_stance)
		stance_changed.emit(current_stance, max_stance)

	if was_open:
		critical_window_closed.emit()

	refresh_overhead_hud()


func can_receive_critical(payload: DamagePayload) -> bool:
	if not critical_window_open or current_health <= 0:
		return false

	if hit_mode != HitMode.STANCE_THEN_HEALTH:
		return false

	if not critical_requires_weapon_melee:
		return true

	return (
		payload.hit_type == "melee"
		and payload.tags.has("weapon")
		and payload.tags.has("melee")
	)


func arm_stance_regeneration() -> void:
	stance_regeneration_delay_timer = maxf(stance_regeneration_delay, 0.0)
	stance_regeneration_carry = 0.0


func apply_staggered_status(duration: float) -> void:
	var status_receiver: Node = get_parent().get_node_or_null("StatusReceiver") if get_parent() != null else null
	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.call(
			"apply_status",
			"staggered",
			maxf(duration, 0.1),
			1.0,
			"stance_break"
		)


func clear_staggered_status() -> void:
	var status_receiver: Node = get_parent().get_node_or_null("StatusReceiver") if get_parent() != null else null
	if status_receiver == null or not status_receiver.has_method("remove_status"):
		return

	var active_statuses_value: Variant = status_receiver.get("active_statuses")
	if not active_statuses_value is Dictionary:
		return

	var active_statuses: Dictionary = active_statuses_value as Dictionary
	var staggered_value: Variant = active_statuses.get("staggered", {})
	if not staggered_value is Dictionary:
		return

	var staggered_data: Dictionary = staggered_value as Dictionary
	if str(staggered_data.get("source", "")) == "stance_break":
		status_receiver.call("remove_status", "staggered")


func get_feedback_target() -> Node:
	var target: Node = get_parent()

	if target == null:
		return self

	return target


func refresh_overhead_hud() -> void:
	var hud: Node = EnemyOverheadHud.ensure_for_target(get_feedback_target())

	if hud != null and hud.has_method("refresh_now"):
		hud.refresh_now()


func show_payload_feedback(payload: DamagePayload, result: Dictionary) -> void:
	CombatFeedback.show_payload_feedback(get_feedback_target(), payload, result)


func show_basic_feedback(power: int, result: Dictionary) -> void:
	var payload: DamagePayload = DamagePayload.new()
	payload.amount = power
	payload.stance_damage = power
	payload.element = "neutral"
	payload.source_name = "Hit"
	payload.tags = ["physical"]

	CombatFeedback.show_payload_feedback(get_feedback_target(), payload, result)


func get_element_multiplier(element: String) -> float:
	if immune_elements.has(element):
		return 0.0

	if weak_elements.has(element):
		return weakness_multiplier

	if resistant_elements.has(element):
		return resistance_multiplier

	return 1.0


func modify_damage_by_element(base_damage: int, element: String) -> int:
	var multiplier: float = get_element_multiplier(element)

	if multiplier <= 0.0:
		return 0

	var modified_damage: int = roundi(float(base_damage) * multiplier)

	if base_damage > 0:
		modified_damage = max(modified_damage, 1)

	return modified_damage


func get_debug_data() -> Dictionary:
	var elements: String = "-"

	if weak_elements.size() > 0:
		elements = "W:" + str(weak_elements)

	if resistant_elements.size() > 0:
		elements += " R:" + str(resistant_elements)

	if immune_elements.size() > 0:
		elements += " I:" + str(immune_elements)

	return {
		"mode": HitMode.keys()[hit_mode],
		"hp": str(current_health) + "/" + str(max_health),
		"st": str(current_stance) + "/" + str(max_stance),
		"critical": critical_window_open,
		"critical_time": snapped(critical_window_timer, 0.05),
		"stance_regen_delay": snapped(stance_regeneration_delay_timer, 0.05),
		"elem": elements,
		"last": last_payload_summary,
	}
