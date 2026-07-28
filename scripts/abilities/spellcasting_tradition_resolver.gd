extends RefCounted
class_name SpellcastingTraditionResolver

const SpellcastingTraditionCatalogScript = preload("res://scripts/progression/spellcasting_tradition_catalog.gd")


static func resolve(ability: AbilityDefinition) -> Array[String]:
	var report: Dictionary = get_compatibility_report(ability)
	var resolved: Array[String] = []
	var raw_traditions: Variant = report.get("compatible_traditions", [])
	if raw_traditions is Array:
		for raw_tradition: Variant in raw_traditions as Array:
			resolved.append(str(raw_tradition))
	return resolved


static func is_compatible(ability: AbilityDefinition, tradition_id: String) -> bool:
	return resolve(ability).has(tradition_id)


static func get_compatibility_report(ability: AbilityDefinition) -> Dictionary:
	var report: Dictionary = {
		"ability_id": "",
		"element": "",
		"category": "",
		"tags": [],
		"compatible_traditions": [],
		"reasons": {},
		"explicit_only": [],
		"explicit_includes": [],
		"explicit_blocks": [],
	}
	if ability == null:
		return report

	var tags: Array[String] = _get_normalized_tags(ability)
	var category_id: String = _get_category_id(ability)
	var element_id: String = ability.element.strip_edges().to_lower()
	var explicit_rules: Dictionary = _parse_explicit_rules(tags)
	var explicit_only: Array[String] = _copy_string_array(explicit_rules.get("only", []))
	var explicit_includes: Array[String] = _copy_string_array(explicit_rules.get("include", []))
	var explicit_blocks: Array[String] = _copy_string_array(explicit_rules.get("block", []))
	var reasons: Dictionary = {}

	if explicit_only.is_empty():
		for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
			var definition: Dictionary = SpellcastingTraditionCatalogScript.get_definition(tradition_id)
			if bool(definition.get("automatic_for_all_spells", false)):
				_add_reason(reasons, tradition_id, "available to every learned spell")

			var compatible_elements: Array[String] = _copy_string_array(
				definition.get("compatibility_elements", [])
			)
			if element_id != "" and compatible_elements.has(element_id):
				_add_reason(reasons, tradition_id, "element:" + element_id)

			var compatible_categories: Array[String] = _copy_string_array(
				definition.get("compatibility_categories", [])
			)
			if category_id != "" and compatible_categories.has(category_id):
				_add_reason(reasons, tradition_id, "category:" + category_id)

			var compatible_tags: Array[String] = _copy_string_array(
				definition.get("compatibility_tags", [])
			)
			for compatible_tag: String in compatible_tags:
				if tags.has(compatible_tag):
					_add_reason(reasons, tradition_id, "tag:" + compatible_tag)

		for tradition_id: String in explicit_includes:
			_add_reason(reasons, tradition_id, "explicit spell metadata")
	else:
		for tradition_id: String in explicit_only:
			_add_reason(reasons, tradition_id, "exclusive spell metadata")

	for tradition_id: String in explicit_blocks:
		reasons.erase(tradition_id)

	var compatible_traditions: Array[String] = []
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		if reasons.has(tradition_id):
			compatible_traditions.append(tradition_id)

	report["ability_id"] = ability.get_spell_id()
	report["element"] = element_id
	report["category"] = category_id
	report["tags"] = tags
	report["compatible_traditions"] = compatible_traditions
	report["reasons"] = reasons
	report["explicit_only"] = explicit_only
	report["explicit_includes"] = explicit_includes
	report["explicit_blocks"] = explicit_blocks
	return report


static func _get_normalized_tags(ability: AbilityDefinition) -> Array[String]:
	var tags: Array[String] = []
	for raw_tag: String in ability.get_all_spell_tags():
		var tag: String = raw_tag.strip_edges().to_lower()
		if tag != "" and not tags.has(tag):
			tags.append(tag)
	return tags


static func _parse_explicit_rules(tags: Array[String]) -> Dictionary:
	var only_ids: Array[String] = []
	var include_ids: Array[String] = []
	var block_ids: Array[String] = []

	for tag: String in tags:
		var tradition_id: String = ""
		if tag.begins_with("tradition_only:"):
			tradition_id = tag.trim_prefix("tradition_only:")
			_append_valid_tradition(only_ids, tradition_id)
		elif tag.begins_with("tradition_only_"):
			tradition_id = tag.trim_prefix("tradition_only_")
			_append_valid_tradition(only_ids, tradition_id)
		elif tag.begins_with("tradition_block:"):
			tradition_id = tag.trim_prefix("tradition_block:")
			_append_valid_tradition(block_ids, tradition_id)
		elif tag.begins_with("tradition_block_"):
			tradition_id = tag.trim_prefix("tradition_block_")
			_append_valid_tradition(block_ids, tradition_id)
		elif tag.begins_with("no_tradition:"):
			tradition_id = tag.trim_prefix("no_tradition:")
			_append_valid_tradition(block_ids, tradition_id)
		elif tag.begins_with("no_tradition_"):
			tradition_id = tag.trim_prefix("no_tradition_")
			_append_valid_tradition(block_ids, tradition_id)
		elif tag.begins_with("tradition:"):
			tradition_id = tag.trim_prefix("tradition:")
			_append_valid_tradition(include_ids, tradition_id)
		elif tag.begins_with("tradition_"):
			tradition_id = tag.trim_prefix("tradition_")
			_append_valid_tradition(include_ids, tradition_id)

	return {
		"only": only_ids,
		"include": include_ids,
		"block": block_ids,
	}


static func _append_valid_tradition(target: Array[String], tradition_id: String) -> void:
	var normalized_id: String = tradition_id.strip_edges().to_lower()
	if not SpellcastingTraditionCatalogScript.has_tradition(normalized_id):
		return
	if not target.has(normalized_id):
		target.append(normalized_id)


static func _add_reason(reasons: Dictionary, tradition_id: String, reason: String) -> void:
	if not SpellcastingTraditionCatalogScript.has_tradition(tradition_id):
		return
	var tradition_reasons: Array[String] = []
	var raw_reasons: Variant = reasons.get(tradition_id, [])
	if raw_reasons is Array:
		for raw_reason: Variant in raw_reasons as Array:
			tradition_reasons.append(str(raw_reason))
	if reason != "" and not tradition_reasons.has(reason):
		tradition_reasons.append(reason)
	reasons[tradition_id] = tradition_reasons


static func _copy_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_values is Array:
		return values
	for raw_value: Variant in raw_values as Array:
		var value: String = str(raw_value).strip_edges().to_lower()
		if value != "" and not values.has(value):
			values.append(value)
	return values


static func _get_category_id(ability: AbilityDefinition) -> String:
	match ability.category:
		AbilityDefinition.AbilityCategory.PROJECTILE:
			return "projectile"
		AbilityDefinition.AbilityCategory.INSTANT:
			return "instant"
		AbilityDefinition.AbilityCategory.SUMMON:
			return "summon"
		AbilityDefinition.AbilityCategory.TRANSFORMATION:
			return "transformation"
		AbilityDefinition.AbilityCategory.UTILITY:
			return "utility"
		_:
			return ""