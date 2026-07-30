extends RefCounted
class_name SpellCapabilityAudit


const Manifest = preload(
	"res://scripts/abilities/spell_capability_manifest.gd"
)
const ReactionCatalog = preload(
	"res://scripts/systems/reaction_rule_catalog.gd"
)
const StatePolicy = preload(
	"res://scripts/systems/reaction_state_policy.gd"
)


static func audit_bundle(bundle: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var records: Array[Dictionary] = _dictionary_array(bundle.get("spells", []))
	var seen_ids: Dictionary = {}
	var produced_states: Array[String] = []

	for catalog_error: String in ReactionCatalog.validate_catalog():
		errors.append("Reaction catalog: " + catalog_error)

	for record: Dictionary in records:
		var spell_id: String = str(record.get("spell_id", "")).strip_edges()
		var display_name: String = str(record.get("display_name", "")).strip_edges()
		var path: String = str(record.get("resource_path", ""))
		var element: String = str(record.get("element", "")).to_lower()
		if spell_id == "":
			errors.append("Ability has no effective spell ID: " + path)
		elif seen_ids.has(spell_id):
			errors.append(
				"Duplicate spell ID `" + spell_id + "`: "
				+ str(seen_ids[spell_id]) + " and " + path
			)
		else:
			seen_ids[spell_id] = path
		if display_name == "":
			errors.append("Spell `" + spell_id + "` has no display name.")
		if str(record.get("authored_spell_id", "")) == "":
			warnings.append(
				"Spell `" + spell_id
				+ "` relies on a display-name fallback instead of an authored spell_id."
			)
		if element == "":
			errors.append("Spell `" + spell_id + "` has no element.")
		elif element != "neutral" and not Manifest.ELEMENT_ORDER.has(element):
			warnings.append(
				"Spell `" + spell_id + "` uses non-core element `" + element + "`."
			)

		var payload: Dictionary = record.get("payload", {}) as Dictionary
		var payload_element: String = str(payload.get("element", "")).to_lower()
		if (
			payload_element not in ["", "neutral", element]
			and element != "neutral"
		):
			warnings.append(
				"Spell `" + spell_id + "` is " + element
				+ " but its payload is " + payload_element + "."
			)
		if _string_array(record.get("roles", [])).is_empty():
			warnings.append("Spell `" + spell_id + "` declares no gameplay roles.")
		if _string_array(record.get("identity_tags", [])).is_empty():
			warnings.append("Spell `" + spell_id + "` exposes no interaction tags.")

		var targeting: Dictionary = record.get("targeting_preview", {}) as Dictionary
		for targeting_error: String in _string_array(targeting.get("errors", [])):
			errors.append(
				"Spell `" + spell_id + "` targeting profile: " + targeting_error
			)
		for state: String in _string_array(record.get("applies_states", [])):
			_append_unique(produced_states, StatePolicy.normalize_state(state))

	var reaction_rows: Array[Dictionary] = _dictionary_array(
		bundle.get("reactions", [])
	)
	var unreachable_reactions: Array[String] = []
	var reactions_without_setup: Array[String] = []
	var required_states: Array[String] = []
	for row: Dictionary in reaction_rows:
		var rule_id: String = str(row.get("rule_id", "reaction"))
		if not bool(row.get("reachable", false)):
			unreachable_reactions.append(rule_id)
			warnings.append(
				"Reaction `" + rule_id + "` has no authored spell trigger."
			)
		if not bool(row.get("has_authored_setup", false)):
			reactions_without_setup.append(rule_id)
		for state: String in _string_array(row.get("required_states", [])):
			_append_unique(required_states, StatePolicy.normalize_state(state))

	for rule: Resource in ReactionCatalog.get_rules():
		if rule == null:
			continue
		var output_status: String = str(rule.get("output_status"))
		if output_status != "":
			_append_unique(
				produced_states,
				StatePolicy.normalize_state(output_status)
			)
		var area_status: String = str(rule.get("area_output_status"))
		if area_status != "":
			_append_unique(
				produced_states,
				StatePolicy.normalize_state(area_status)
			)

	var orphan_states: Array[String] = []
	for state: String in required_states:
		if produced_states.has(state):
			continue
		orphan_states.append(state)
		warnings.append(
			"Reaction state `" + state
			+ "` has no spell or reaction producer; it may require an environmental source."
		)

	var coverage: Array[Dictionary] = _dictionary_array(bundle.get("coverage", []))
	var coverage_gaps: Dictionary = {}
	for row: Dictionary in coverage:
		var missing: Array[String] = _string_array(
			row.get("missing_core_capabilities", [])
		)
		if not missing.is_empty():
			coverage_gaps[str(row.get("element", "neutral"))] = missing

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"spell_count": records.size(),
		"reaction_count": reaction_rows.size(),
		"unreachable_reactions": unreachable_reactions,
		"reactions_without_authored_setup": reactions_without_setup,
		"orphan_states": orphan_states,
		"coverage_gaps": coverage_gaps,
		"produced_states": produced_states,
		"required_states": required_states,
	}


static func build_current_audit(
	root_path: String = Manifest.DEFAULT_ABILITY_ROOT
) -> Dictionary:
	var bundle: Dictionary = Manifest.build_bundle(root_path)
	var audit: Dictionary = audit_bundle(bundle)
	return {
		"bundle": bundle,
		"audit": audit,
	}


static func format_summary(audit: Dictionary) -> String:
	return (
		("PASS" if bool(audit.get("valid", false)) else "FAIL")
		+ " | spells=" + str(audit.get("spell_count", 0))
		+ " | reactions=" + str(audit.get("reaction_count", 0))
		+ " | errors=" + str(_string_array(audit.get("errors", [])).size())
		+ " | warnings=" + str(_string_array(audit.get("warnings", [])).size())
		+ " | orphan_states=" + str(_string_array(audit.get("orphan_states", [])).size())
	)


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append(raw as Dictionary)
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _append_unique(target: Array[String], value: String) -> void:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == "" or target.has(normalized):
		return
	target.append(normalized)
