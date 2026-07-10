extends Node

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")

signal health_changed(current_health: int, max_health: int)
signal stance_changed(current_stance: int, max_stance: int)
signal health_depleted
signal stance_broken

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

@export var restores_mana_when_defeated: int = 0

@export var weak_elements: Array[String] = []
@export var resistant_elements: Array[String] = []
@export var immune_elements: Array[String] = []

@export var weakness_multiplier: float = 2.0
@export var resistance_multiplier: float = 0.5

@export var last_payload_summary: String = "none"

func _ready() -> void:
	current_health = clamp(current_health, 0, max_health)
	current_stance = clamp(current_stance, 0, max_stance)
	add_to_group("debuggable")

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
	return result

func _receive_invulnerable_hit() -> Dictionary:
	return {
		"message": "Arcane Spark flickers against " + target_name + ". It does not seem harmed.",
		"objective": "Some targets cannot be damaged yet."
	}

func _damage_stance(power: int) -> Dictionary:
	current_stance = clamp(current_stance - power, 0, max_stance)
	stance_changed.emit(current_stance, max_stance)

	if current_stance <= 0:
		stance_broken.emit()

		var message: String = target_name + "'s stance breaks."

		if resets_stance_after_break:
			current_stance = max_stance
			stance_changed.emit(current_stance, max_stance)
			message += " It steadies itself again."

		return {
			"message": message,
			"objective": "Target stance is working."
		}

	return {
		"message": target_name + " is hit. Stance: " + str(current_stance) + " / " + str(max_stance),
		"objective": "Keep testing target stance."
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
			"objective": "Breaking objects can now reward the player."
		}

	return {
		"message": target_name + " is hit. Health: " + str(current_health) + " / " + str(max_health),
		"objective": "Keep testing target health."
	}

func reset_health() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func reset_stance() -> void:
	current_stance = max_stance
	stance_changed.emit(current_stance, max_stance)

func receive_payload(payload: DamagePayload) -> Dictionary:
	last_payload_summary = (
		payload.source_name
		+ " | " + payload.element
		+ " | hp:" + str(payload.amount)
		+ " | st:" + str(payload.stance_damage)
		+ " | " + str(payload.tags)
	)

	var result: Dictionary = {}

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
			"objective": "Element immunity is working."
		}

	current_stance = clamp(current_stance - modified_stance_damage, 0, max_stance)
	stance_changed.emit(current_stance, max_stance)

	if current_stance <= 0:
		stance_broken.emit()

		var break_message: String = payload.source_name + " breaks " + target_name + "'s stance."

		if resets_stance_after_break:
			current_stance = max_stance
			stance_changed.emit(current_stance, max_stance)
			break_message += " It steadies itself again."

		return {
			"message": break_message,
			"objective": "Payload stance damage is working."
		}

	return {
		"message": payload.source_name + " hits " + target_name + ". Stance: " + str(current_stance) + " / " + str(max_stance),
		"objective": "Payload hits are working."
	}

func _damage_health_from_payload(payload: DamagePayload) -> Dictionary:
	var modified_amount: int = modify_damage_by_element(payload.amount, payload.element)

	if modified_amount <= 0:
		return {
			"message": target_name + " is immune to " + payload.element + ".",
			"objective": "Element immunity is working."
		}

	current_health = clamp(current_health - modified_amount, 0, max_health)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		health_depleted.emit()

		var defeat_message: String = payload.source_name + " defeats " + target_name + "."

		if restores_mana_when_defeated > 0:
			GameState.restore_mana(restores_mana_when_defeated)
			defeat_message += " Grace recovers " + str(restores_mana_when_defeated) + " mana."

		if disappears_when_defeated and get_parent() != null:
			get_parent().queue_free()

		return {
			"message": defeat_message,
			"objective": "Payload health damage is working."
		}

	return {
		"message": payload.source_name + " hits " + target_name + " for " + str(modified_amount) + " " + payload.element + " damage. Health: " + str(current_health) + " / " + str(max_health),
		"objective": "Element damage is working."
	}

func show_payload_feedback(payload: DamagePayload, result: Dictionary) -> void:
	var target: Node = get_parent()

	if target == null:
		target = self

	CombatFeedback.show_payload_feedback(target, payload, result)

func show_basic_feedback(power: int, result: Dictionary) -> void:
	var target: Node = get_parent()

	if target == null:
		target = self

	var payload: DamagePayload = DamagePayload.new()
	payload.amount = power
	payload.stance_damage = power
	payload.element = "neutral"
	payload.source_name = "Hit"
	payload.tags = ["physical"]

	CombatFeedback.show_payload_feedback(target, payload, result)

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
		"elem": elements,
		"last": last_payload_summary,
	}
