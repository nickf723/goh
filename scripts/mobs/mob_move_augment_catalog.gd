extends RefCounted
class_name MobMoveAugmentCatalog

const DEFINITIONS: Dictionary = {
	"ferocious": {
		"id": "ferocious",
		"display_name": "Ferocious",
		"description": "Increase direct damage without changing the move's identity.",
		"requires_all_tags": ["attack"],
		"modifiers": [
			{"path": "effect.damage", "operation": "multiply", "value": 1.25},
		],
	},
	"guard_breaker": {
		"id": "guard_breaker",
		"display_name": "Guard Breaker",
		"description": "Increase stance damage and make the action better at breaking defenses.",
		"requires_all_tags": ["attack"],
		"modifiers": [
			{"path": "effect.stance_damage", "operation": "add", "value": 2.0},
		],
	},
	"quickened": {
		"id": "quickened",
		"display_name": "Quickened",
		"description": "Reduce the action's recovery and reuse cooldown.",
		"modifiers": [
			{"path": "cooldown", "operation": "multiply", "value": 0.8},
		],
	},
	"venomous": {
		"id": "venomous",
		"display_name": "Venomous",
		"description": "Add a Poison buildup rider to a contact or projectile attack.",
		"requires_all_tags": ["attack"],
		"requires_any_tags": ["contact", "projectile", "jaw"],
		"modifiers": [
			{
				"path": "effect.statuses",
				"operation": "append_unique",
				"value": {"id": "poisoned", "duration": 5.0, "buildup": 20},
			},
		],
	},
	"wide_arc": {
		"id": "wide_arc",
		"display_name": "Wide Arc",
		"description": "Increase the action's area or contact sweep radius.",
		"requires_all_tags": ["attack"],
		"requires_any_tags": ["area", "melee", "tail"],
		"modifiers": [
			{"path": "effect.radius", "operation": "add", "value": 1.25},
		],
	},
	"long_reach": {
		"id": "long_reach",
		"display_name": "Long Reach",
		"description": "Extend the usable range of the action.",
		"requires_any_tags": ["attack", "movement", "projectile"],
		"modifiers": [
			{"path": "maximum_range", "operation": "add", "value": 1.5},
		],
	},
	"wetting": {
		"id": "wetting",
		"display_name": "Wetting",
		"description": "Add a Wet primer to a compatible projectile or spit action.",
		"requires_all_tags": ["attack"],
		"requires_any_tags": ["projectile", "water"],
		"modifiers": [
			{
				"path": "effect.statuses",
				"operation": "append_unique",
				"value": {"id": "wet", "duration": 6.0},
			},
		],
	},
	"steadfast": {
		"id": "steadfast",
		"display_name": "Steadfast",
		"description": "Improve defensive movement or recovery duration.",
		"requires_any_tags": ["defense", "retreat", "recovery"],
		"modifiers": [
			{"path": "effect.duration", "operation": "add", "value": 0.4},
		],
	},
}


static func has_augment(augment_id: String) -> bool:
	return DEFINITIONS.has(augment_id)


static func get_definition(augment_id: String) -> Dictionary:
	var value: Variant = DEFINITIONS.get(augment_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func get_augment_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw: Variant in DEFINITIONS.keys():
		ids.append(str(raw))
	ids.sort()
	return ids


static func is_compatible(move: Variant, augment_id: String) -> bool:
	var move_data: Dictionary = (
		move.to_dictionary()
		if move is MobMoveDefinition
		else (move as Dictionary).duplicate(true) if move is Dictionary else {}
	)
	var augment: Dictionary = get_definition(augment_id)
	if move_data.is_empty() or augment.is_empty():
		return false
	var tags: Array[String] = _string_array(move_data.get("tags", []))
	for required: String in _string_array(augment.get("requires_all_tags", [])):
		if not tags.has(required):
			return false
	var any_tags: Array[String] = _string_array(augment.get("requires_any_tags", []))
	if not any_tags.is_empty():
		var matched: bool = false
		for accepted: String in any_tags:
			if tags.has(accepted):
				matched = true
				break
		if not matched:
			return false
	for forbidden: String in _string_array(augment.get("forbidden_tags", [])):
		if tags.has(forbidden):
			return false
	return true


static func apply_augment(move: Dictionary, augment_id: String) -> Dictionary:
	var result: Dictionary = move.duplicate(true)
	if not is_compatible(result, augment_id):
		return result
	var augment: Dictionary = get_definition(augment_id)
	var modifiers: Variant = augment.get("modifiers", [])
	if modifiers is Array:
		for raw_modifier: Variant in modifiers as Array:
			if raw_modifier is Dictionary:
				_apply_modifier(result, raw_modifier as Dictionary)
	var applied: Array[String] = _string_array(result.get("applied_augments", []))
	if not applied.has(augment_id):
		applied.append(augment_id)
	result["applied_augments"] = applied
	return result


static func apply_augments(move: Dictionary, augment_ids: Array[String]) -> Dictionary:
	var result: Dictionary = move.duplicate(true)
	for augment_id: String in augment_ids:
		result = apply_augment(result, augment_id)
	return result


static func get_compatible_augments(move: Variant) -> Array[String]:
	var result: Array[String] = []
	for augment_id: String in get_augment_ids():
		if is_compatible(move, augment_id):
			result.append(augment_id)
	return result


static func _apply_modifier(target: Dictionary, modifier: Dictionary) -> void:
	var path: String = str(modifier.get("path", "")).strip_edges()
	if path == "":
		return
	var operation: String = str(modifier.get("operation", "set")).to_lower()
	var value: Variant = modifier.get("value")
	var current: Variant = _read_path(target, path)
	match operation:
		"add":
			_write_path(target, path, float(current if current != null else 0.0) + float(value))
		"multiply":
			_write_path(target, path, float(current if current != null else 0.0) * float(value))
		"append_unique":
			var values: Array = (current as Array).duplicate(true) if current is Array else []
			if not values.has(value):
				values.append(value)
			_write_path(target, path, values)
		"merge":
			var merged: Dictionary = (current as Dictionary).duplicate(true) if current is Dictionary else {}
			if value is Dictionary:
				merged.merge(value as Dictionary, true)
			_write_path(target, path, merged)
		_:
			_write_path(target, path, value)


static func _read_path(target: Dictionary, path: String) -> Variant:
	var current: Variant = target
	for key: String in path.split(".", false):
		if not current is Dictionary:
			return null
		current = (current as Dictionary).get(key)
	return current


static func _write_path(target: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".", false)
	if parts.is_empty():
		return
	var current: Dictionary = target
	for index: int in range(parts.size() - 1):
		var key: String = parts[index]
		var child: Variant = current.get(key)
		if not child is Dictionary:
			current[key] = {}
		child = current[key]
		current = child as Dictionary
	current[parts[parts.size() - 1]] = value


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).to_lower().strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result
