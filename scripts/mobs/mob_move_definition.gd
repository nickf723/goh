extends Resource
class_name MobMoveDefinition

@export var move_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var action_kind: String = "utility"
@export var target_mode: String = "self"
@export var tags: Array[String] = []
@export var required_body_tags: Array[String] = []
@export var minimum_range: float = 0.0
@export var maximum_range: float = 0.0
@export var cooldown: float = 0.0
@export var base_utility: float = 1.0
@export var effect: Dictionary = {}
@export var timing: Dictionary = {}
@export var scaling: Dictionary = {}
@export var augment_slots: Array[String] = []


static func from_dictionary(data: Dictionary) -> MobMoveDefinition:
	var definition := MobMoveDefinition.new()
	definition.move_id = str(data.get("id", data.get("move_id", ""))).strip_edges()
	definition.display_name = str(data.get(
		"display_name",
		definition.move_id.replace("_", " ").capitalize()
	))
	definition.description = str(data.get("description", ""))
	definition.action_kind = str(data.get("action_kind", "utility"))
	definition.target_mode = str(data.get("target_mode", "self"))
	definition.tags = _string_array(data.get("tags", []))
	definition.required_body_tags = _string_array(data.get("required_body_tags", []))
	definition.minimum_range = maxf(float(data.get("minimum_range", 0.0)), 0.0)
	definition.maximum_range = maxf(
		float(data.get("maximum_range", definition.minimum_range)),
		definition.minimum_range
	)
	definition.cooldown = maxf(float(data.get("cooldown", 0.0)), 0.0)
	definition.base_utility = maxf(float(data.get("base_utility", 1.0)), 0.0)
	definition.effect = _dictionary(data.get("effect", {}))
	definition.timing = _dictionary(data.get("timing", {}))
	definition.scaling = _dictionary(data.get("scaling", {}))
	definition.augment_slots = _string_array(data.get("augment_slots", []))
	return definition


func duplicate_definition() -> MobMoveDefinition:
	return MobMoveDefinition.from_dictionary(to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"id": move_id,
		"display_name": display_name,
		"description": description,
		"action_kind": action_kind,
		"target_mode": target_mode,
		"tags": tags.duplicate(),
		"required_body_tags": required_body_tags.duplicate(),
		"minimum_range": minimum_range,
		"maximum_range": maximum_range,
		"cooldown": cooldown,
		"base_utility": base_utility,
		"effect": effect.duplicate(true),
		"timing": timing.duplicate(true),
		"scaling": scaling.duplicate(true),
		"augment_slots": augment_slots.duplicate(),
	}


func has_tag(tag: String) -> bool:
	return tags.has(tag.to_lower().strip_edges())


func supports_body(body_tags: Array[String]) -> bool:
	for required_tag: String in required_body_tags:
		if not body_tags.has(required_tag):
			return false
	return true


func validate() -> Array[String]:
	var failures: Array[String] = []
	if move_id == "":
		failures.append("move id is empty")
	if display_name == "":
		failures.append(move_id + " has no display name")
	if maximum_range < minimum_range:
		failures.append(move_id + " has an inverted range")
	if base_utility < 0.0:
		failures.append(move_id + " has negative utility")
	if action_kind == "attack" and effect.is_empty():
		failures.append(move_id + " attack has no effect payload")
	for phase_id: String in ["startup", "active", "recovery"]:
		if timing.has(phase_id) and float(timing[phase_id]) < 0.0:
			failures.append(move_id + " has negative " + phase_id + " timing")
	var effect_trigger: String = str(
		timing.get("effect_trigger", "active_start")
	).to_lower().strip_edges()
	if effect_trigger != "active_start":
		failures.append(move_id + " has unsupported effect trigger " + effect_trigger)
	if not effect.is_empty() and float(timing.get("active", 0.0)) <= 0.0:
		failures.append(move_id + " has an effect but no active phase")
	return failures


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).to_lower().strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
