extends RefCounted
class_name TacticalActionCandidate

var action_id: String = "action"
var display_name: String = "Action"
var action_kind: String = "utility"
var role_tags: Array[String] = []
var incoming_tags: Array[String] = []
var applies_states: Array[String] = []
var capabilities: Array[String] = []
var movement_mode: String = "none"
var affordable: bool = true
var base_score: float = 0.0
var current_distance: float = 0.0
var minimum_distance: float = 0.0
var maximum_distance: float = 999.0
var source_kind: String = "runtime"
var source_ref: Variant = null


static func from_enemy_option(option: EnemyActionOption) -> TacticalActionCandidate:
	var candidate := TacticalActionCandidate.new()
	candidate.source_kind = "enemy_option"
	candidate.source_ref = option
	if option == null:
		candidate.affordable = false
		candidate.action_id = "missing_option"
		candidate.display_name = "Missing Option"
		return candidate
	var action: EnemyCombatActionDefinition = option.get_action()
	candidate.action_id = action.get_action_id() if action != null else "missing_action"
	candidate.display_name = option.get_display_name()
	candidate.action_kind = option.get_action_kind()
	candidate.role_tags = _normalized(option.get_role_tags())
	candidate.incoming_tags = candidate.role_tags.duplicate()
	candidate.capabilities = _infer_action_capabilities(candidate.action_kind, candidate.role_tags)
	candidate.movement_mode = action.get_movement_mode() if action != null else "none"
	candidate.minimum_distance = option.get_minimum_start_distance()
	candidate.maximum_distance = option.get_maximum_start_distance()
	if action is EnemyAttackDefinition:
		var payload: DamagePayload = (action as EnemyAttackDefinition).get_payload()
		_apply_damage_payload(candidate, payload)
	return candidate


static func from_spell_record(record: Dictionary) -> TacticalActionCandidate:
	var candidate := TacticalActionCandidate.new()
	candidate.source_kind = "spell_record"
	candidate.source_ref = record.duplicate(true)
	candidate.action_id = str(record.get("spell_id", "spell"))
	candidate.display_name = str(record.get("display_name", candidate.action_id.capitalize()))
	candidate.action_kind = "spell"
	candidate.role_tags = _normalized(record.get("roles", []))
	candidate.incoming_tags = _normalized(record.get("identity_tags", []))
	candidate.applies_states = _normalized(record.get("applies_states", []))
	candidate.capabilities = _normalized(record.get("capabilities", []))
	var targeting: Dictionary = _dictionary(record.get("targeting_preview", {}))
	candidate.maximum_distance = float(targeting.get("range", 999.0))
	candidate.movement_mode = "none"
	return candidate


static func make_test_candidate(
	id: String,
	kind: String,
	tags: Array[String],
	states: Array[String] = [],
	candidate_capabilities: Array[String] = [],
	movement: String = "none"
) -> TacticalActionCandidate:
	var candidate := TacticalActionCandidate.new()
	candidate.action_id = id
	candidate.display_name = id.capitalize()
	candidate.action_kind = kind
	candidate.role_tags = _normalized(tags)
	candidate.incoming_tags = candidate.role_tags.duplicate()
	candidate.applies_states = _normalized(states)
	candidate.capabilities = _normalized(candidate_capabilities)
	candidate.movement_mode = movement
	return candidate


func to_debug_data() -> Dictionary:
	return {
		"action_id": action_id,
		"display_name": display_name,
		"action_kind": action_kind,
		"role_tags": role_tags.duplicate(),
		"incoming_tags": incoming_tags.duplicate(),
		"applies_states": applies_states.duplicate(),
		"capabilities": capabilities.duplicate(),
		"movement_mode": movement_mode,
		"affordable": affordable,
		"base_score": base_score,
		"distance": current_distance,
		"minimum_distance": minimum_distance,
		"maximum_distance": maximum_distance,
		"source_kind": source_kind,
	}


func has_tag(tag: String) -> bool:
	return incoming_tags.has(tag.strip_edges().to_lower()) or role_tags.has(
		tag.strip_edges().to_lower()
	)


func has_capability(capability: String) -> bool:
	return capabilities.has(capability.strip_edges().to_lower())


static func _apply_damage_payload(
	candidate: TacticalActionCandidate,
	payload: DamagePayload
) -> void:
	if payload == null:
		return
	_append_unique(candidate.incoming_tags, payload.element)
	_append_unique(candidate.incoming_tags, payload.hit_type)
	_append_many(candidate.incoming_tags, payload.tags)
	if payload.status_effect != "":
		_append_unique(candidate.applies_states, payload.status_effect)
	if payload.amount > 0 or payload.stance_damage > 0:
		_append_unique(candidate.capabilities, "damage")
	if (
		payload.status_effect != ""
		or payload.knockback_strength > 0.0
		or payload.knockback_up_strength > 0.0
	):
		_append_unique(candidate.capabilities, "control")
	if payload.status_effect != "":
		_append_unique(candidate.capabilities, "setup")


static func _infer_action_capabilities(
	kind: String,
	tags: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	match kind:
		"attack":
			_append_unique(result, "damage")
		"defense":
			_append_unique(result, "defense")
		"movement":
			_append_unique(result, "movement")
		"support":
			_append_unique(result, "utility")
		_:
			_append_unique(result, "utility")
	for tag: String in tags:
		if tag in ["heal", "guard", "shield", "defense"]:
			_append_unique(result, "defense")
		if tag in ["retreat", "dodge", "reposition", "movement"]:
			_append_unique(result, "movement")
		if tag in ["control", "stun", "slow", "force", "pull"]:
			_append_unique(result, "control")
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _normalized(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _append_many(target: Array[String], values: Array[String]) -> void:
	for value: String in values:
		_append_unique(target, value)


static func _append_unique(target: Array[String], value: String) -> void:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == "" or target.has(normalized):
		return
	target.append(normalized)
