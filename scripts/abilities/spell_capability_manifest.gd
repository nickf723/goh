extends RefCounted
class_name SpellCapabilityManifest


const TargetingCatalog = preload(
	"res://scripts/abilities/spell_targeting_catalog.gd"
)
const ReactionCatalog = preload(
	"res://scripts/systems/reaction_rule_catalog.gd"
)
const StatePolicy = preload(
	"res://scripts/systems/reaction_state_policy.gd"
)

const DEFAULT_ABILITY_ROOT: String = "res://data/abilities"
const ELEMENT_ORDER: Array[String] = [
	"water",
	"earth",
	"fire",
	"air",
	"ice",
	"metal",
	"lightning",
	"poison",
	"life",
	"death",
	"body",
	"soul",
	"dreams",
	"sound",
	"space",
	"time",
]
const CAPABILITY_BUCKETS: Array[String] = [
	"damage",
	"control",
	"movement",
	"setup",
	"payoff",
	"terrain",
	"detection",
	"summon",
	"defense",
	"utility",
]


static func build_bundle(root_path: String = DEFAULT_ABILITY_ROOT) -> Dictionary:
	var records: Array[Dictionary] = build_manifest(scan_abilities(root_path))
	return {
		"version": 1,
		"ability_root": root_path,
		"spell_count": records.size(),
		"spells": records,
		"coverage": build_coverage_matrix(records),
		"reactions": build_reaction_reachability(records),
	}


static func scan_abilities(root_path: String = DEFAULT_ABILITY_ROOT) -> Array[AbilityDefinition]:
	var resource_paths: Array[String] = []
	_collect_resource_paths(root_path, resource_paths)
	resource_paths.sort()
	var abilities: Array[AbilityDefinition] = []
	for resource_path: String in resource_paths:
		var resource: Resource = ResourceLoader.load(resource_path)
		if resource is AbilityDefinition:
			abilities.append(resource as AbilityDefinition)
	return abilities


static func build_manifest(
	abilities: Array[AbilityDefinition]
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for ability: AbilityDefinition in abilities:
		if ability == null:
			continue
		records.append(build_record(ability))
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var element_a: int = _element_sort_index(str(a.get("element", "neutral")))
		var element_b: int = _element_sort_index(str(b.get("element", "neutral")))
		if element_a != element_b:
			return element_a < element_b
		return str(a.get("spell_id", "")) < str(b.get("spell_id", ""))
	)
	return records


static func build_record(ability: AbilityDefinition) -> Dictionary:
	var payload: Resource = ability.get_action_payload()
	var payload_data: Dictionary = _summarize_payload(payload)
	var declared_states: Array[String] = []
	_append_known_states(declared_states, ability.get_status_tags())
	_append_known_states(
		declared_states,
		_string_array(payload_data.get("statuses", []))
	)

	var identity_tags: Array[String] = []
	_append_unique(identity_tags, ability.element)
	_append_unique(identity_tags, ability.get_targeting_style())
	_append_unique(identity_tags, ability.get_delivery_type())
	_append_many(identity_tags, ability.get_roles())
	_append_many(identity_tags, ability.get_combo_tags())
	_append_many(identity_tags, ability.get_status_tags())
	_append_many(identity_tags, ability.get_ui_tags())
	_append_many(identity_tags, ability.get_debug_tags())
	_append_many(identity_tags, _string_array(payload_data.get("tags", [])))
	_append_unique(identity_tags, str(payload_data.get("element", "")))
	_append_unique(identity_tags, str(payload_data.get("hit_type", "")))
	_append_many(identity_tags, declared_states)

	var triggered_reactions: Array[String] = _find_triggered_reactions(identity_tags)
	var setup_reactions: Array[String] = _find_setup_reactions(declared_states)
	var targeting: Dictionary = TargetingCatalog.get_preview_summary(ability)
	var capabilities: Array[String] = _infer_capabilities(
		ability,
		payload_data,
		identity_tags,
		declared_states,
		triggered_reactions,
		setup_reactions
	)

	return {
		"spell_id": ability.get_spell_id(),
		"authored_spell_id": ability.spell_id,
		"display_name": ability.display_name,
		"description": ability.description,
		"resource_path": ability.resource_path,
		"element": ability.element.strip_edges().to_lower(),
		"category": _category_name(ability.category),
		"mana_cost": ability.mana_cost,
		"stamina_cost": ability.stamina_cost,
		"focus_cost": ability.focus_cost,
		"roles": ability.get_roles(),
		"targeting_style": ability.get_targeting_style(),
		"delivery_type": ability.get_delivery_type(),
		"identity_tags": identity_tags,
		"applies_states": declared_states,
		"payload": payload_data,
		"targeting_preview": targeting,
		"triggers_reactions": triggered_reactions,
		"sets_up_reactions": setup_reactions,
		"capabilities": capabilities,
		"trait_profile": ability.get_trait_profile_id(),
		"scaling": ability.get_scaling_stats(),
	}


static func build_coverage_matrix(
	records: Array[Dictionary]
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for element: String in ELEMENT_ORDER:
		var bucket_counts: Dictionary = {}
		var bucket_spells: Dictionary = {}
		for bucket: String in CAPABILITY_BUCKETS:
			bucket_counts[bucket] = 0
			bucket_spells[bucket] = []
		var spell_ids: Array[String] = []
		for record: Dictionary in records:
			if str(record.get("element", "")) != element:
				continue
			var spell_id: String = str(record.get("spell_id", ""))
			spell_ids.append(spell_id)
			for capability: String in _string_array(
				record.get("capabilities", [])
			):
				if not bucket_counts.has(capability):
					continue
				bucket_counts[capability] = int(bucket_counts[capability]) + 1
				var spells: Array = bucket_spells[capability] as Array
				spells.append(spell_id)
		var missing: Array[String] = []
		for bucket: String in [
			"damage", "control", "movement", "setup", "payoff", "terrain", "detection"
		]:
			if int(bucket_counts.get(bucket, 0)) <= 0:
				missing.append(bucket)
		rows.append({
			"element": element,
			"spell_count": spell_ids.size(),
			"spell_ids": spell_ids,
			"counts": bucket_counts,
			"spells_by_capability": bucket_spells,
			"missing_core_capabilities": missing,
		})
	return rows


static func build_reaction_reachability(
	records: Array[Dictionary]
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for rule: Resource in ReactionCatalog.get_rules():
		if rule == null:
			continue
		var rule_id: String = str(rule.get("rule_id"))
		var trigger_spells: Array[String] = []
		var setup_spells: Array[String] = []
		for record: Dictionary in records:
			if _string_array(record.get("triggers_reactions", [])).has(rule_id):
				trigger_spells.append(str(record.get("spell_id", "")))
			if _string_array(record.get("sets_up_reactions", [])).has(rule_id):
				setup_spells.append(str(record.get("spell_id", "")))
		rows.append({
			"rule_id": rule_id,
			"reaction_id": str(rule.get("reaction_id")),
			"reaction_name": str(rule.get("reaction_name")),
			"priority": int(rule.get("priority")),
			"incoming_all": _property_strings(rule, "incoming_tags"),
			"incoming_any": _property_strings(rule, "incoming_any_tags"),
			"required_states": _get_rule_state_requirements(rule),
			"trigger_spells": trigger_spells,
			"setup_spells": setup_spells,
			"reachable": not trigger_spells.is_empty(),
			"has_authored_setup": not setup_spells.is_empty(),
		})
	return rows


static func to_json(bundle: Dictionary, indent: String = "  ") -> String:
	return JSON.stringify(bundle, indent, false)


static func to_markdown(bundle: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Spell Capability Manifest")
	lines.append("")
	lines.append("Generated from authored `AbilityDefinition` resources and the live reaction catalog.")
	lines.append("")
	lines.append("## Element coverage")
	lines.append("")
	lines.append("| Element | Spells | Damage | Control | Move | Setup | Payoff | Terrain | Detect |")
	lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
	for row_value: Variant in bundle.get("coverage", []) as Array:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		var counts: Dictionary = row.get("counts", {}) as Dictionary
		lines.append(
			"| " + str(row.get("element", "")).capitalize()
			+ " | " + str(row.get("spell_count", 0))
			+ " | " + str(counts.get("damage", 0))
			+ " | " + str(counts.get("control", 0))
			+ " | " + str(counts.get("movement", 0))
			+ " | " + str(counts.get("setup", 0))
			+ " | " + str(counts.get("payoff", 0))
			+ " | " + str(counts.get("terrain", 0))
			+ " | " + str(counts.get("detection", 0))
			+ " |"
		)
	lines.append("")
	lines.append("## Reaction reachability")
	lines.append("")
	lines.append("| Reaction | Trigger spells | Setup spells |")
	lines.append("|---|---|---|")
	for row_value: Variant in bundle.get("reactions", []) as Array:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		lines.append(
			"| " + str(row.get("reaction_name", row.get("rule_id", "Reaction")))
			+ " | " + _markdown_list(row.get("trigger_spells", []))
			+ " | " + _markdown_list(row.get("setup_spells", []))
			+ " |"
		)
	lines.append("")
	lines.append("## Spells")
	lines.append("")
	for record_value: Variant in bundle.get("spells", []) as Array:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value as Dictionary
		lines.append("### " + str(record.get("display_name", "Spell")))
		lines.append("")
		lines.append("- ID: `" + str(record.get("spell_id", "")) + "`")
		lines.append("- Element: " + str(record.get("element", "neutral")).capitalize())
		lines.append("- Capabilities: " + _markdown_list(record.get("capabilities", [])))
		lines.append("- Applies states: " + _markdown_list(record.get("applies_states", [])))
		lines.append("- Triggers reactions: " + _markdown_list(record.get("triggers_reactions", [])))
		lines.append("")
	return "\n".join(lines)


static func _summarize_payload(payload: Resource) -> Dictionary:
	if payload == null:
		return {
			"type": "none",
			"tags": [],
			"statuses": [],
			"amount": 0,
			"stance_damage": 0,
			"element": "",
			"hit_type": "",
			"force": 0.0,
		}
	var statuses: Array[String] = []
	for property_name: String in [
		"status_effect", "echo_status_effect", "default_status_effect"
	]:
		var state: String = _read_string(payload, property_name, "")
		if state != "":
			_append_unique(statuses, StatePolicy.normalize_state(state))
	var script_path: String = "resource"
	var script_value: Variant = payload.get_script()
	if script_value is Script:
		script_path = (script_value as Script).resource_path.get_file().get_basename()
	return {
		"type": script_path,
		"tags": _read_string_array(payload, "tags"),
		"statuses": statuses,
		"amount": _read_int(payload, "amount", 0),
		"stance_damage": _read_int(payload, "stance_damage", 0),
		"element": _read_string(payload, "element", ""),
		"hit_type": _read_string(payload, "hit_type", ""),
		"force": maxf(
			_read_float(payload, "knockback_strength", 0.0),
			_read_float(payload, "knockback_up_strength", 0.0)
		),
		"detection_type": _read_string(payload, "detection_type", ""),
		"radius": _read_float(payload, "radius", 0.0),
		"reveal_duration": _read_float(payload, "reveal_duration", 0.0),
	}


static func _find_triggered_reactions(identity_tags: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for rule: Resource in ReactionCatalog.get_rules():
		if rule == null:
			continue
		var incoming_all: Array[String] = _property_strings(rule, "incoming_tags")
		var incoming_any: Array[String] = _property_strings(rule, "incoming_any_tags")
		if not _contains_all(identity_tags, incoming_all):
			continue
		if not incoming_any.is_empty() and not _contains_any(identity_tags, incoming_any):
			continue
		_append_unique(result, str(rule.get("rule_id")))
	return result


static func _find_setup_reactions(states: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if states.is_empty():
		return result
	for rule: Resource in ReactionCatalog.get_rules():
		if rule == null:
			continue
		var requirements: Array[String] = _get_rule_state_requirements(rule)
		if _contains_any(states, requirements):
			_append_unique(result, str(rule.get("rule_id")))
	return result


static func _get_rule_state_requirements(rule: Resource) -> Array[String]:
	var states: Array[String] = []
	for property_name: String in [
		"target_tags", "target_any_tags", "target_statuses", "target_any_statuses"
	]:
		for value: String in _property_strings(rule, property_name):
			var normalized: String = StatePolicy.normalize_state(value)
			if StatePolicy.STATUS_ELEMENTS.has(normalized):
				_append_unique(states, normalized)
	return states


static func _infer_capabilities(
	ability: AbilityDefinition,
	payload: Dictionary,
	identity_tags: Array[String],
	states: Array[String],
	triggered_reactions: Array[String],
	setup_reactions: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	var tags: Array[String] = identity_tags.duplicate()
	var delivery: String = ability.get_delivery_type().to_lower()
	var targeting: String = ability.get_targeting_style().to_lower()
	if int(payload.get("amount", 0)) > 0 or _has_any_word(
		tags,
		["damage", "offense", "attack", "burn", "projectile", "thorn"]
	):
		_append_unique(result, "damage")
	if (
		not states.is_empty()
		or float(payload.get("force", 0.0)) > 0.0
		or _has_any_word(tags, ["control", "stun", "slow", "pull", "force", "snare"])
	):
		_append_unique(result, "control")
	if _has_any_word(
		tags,
		["movement", "mobility", "traversal", "blink", "flight", "dash", "navigation"]
	):
		_append_unique(result, "movement")
	if (
		not states.is_empty()
		or not setup_reactions.is_empty()
		or _has_any_word(tags, ["setup", "combo_starter", "primer"])
	):
		_append_unique(result, "setup")
	if (
		not triggered_reactions.is_empty()
		or _has_any_word(tags, ["payoff", "combo_reactor", "hazard_reactor", "finisher"])
	):
		_append_unique(result, "payoff")
	if (
		delivery in ["field", "hazard", "trap", "weather"]
		or targeting in ["ground", "ground_aoe", "area", "field", "trap"]
		or _has_any_word(tags, ["terrain", "field", "hazard", "trap", "weather", "surface"])
	):
		_append_unique(result, "terrain")
	if (
		str(payload.get("detection_type", "")) != ""
		or _has_any_word(tags, ["detection", "reveal", "echo", "information", "perception"])
	):
		_append_unique(result, "detection")
	if ability.category == AbilityDefinition.AbilityCategory.SUMMON or _has_any_word(
		tags,
		["summon", "familiar", "companion", "spawn"]
	):
		_append_unique(result, "summon")
	if _has_any_word(tags, ["defense", "shield", "guard", "heal", "protection"]):
		_append_unique(result, "defense")
	if ability.category == AbilityDefinition.AbilityCategory.UTILITY or _has_any_word(
		tags,
		["utility", "exploration", "navigation", "support"]
	):
		_append_unique(result, "utility")
	return result


static func _collect_resource_paths(
	root_path: String,
	resource_paths: Array[String]
) -> void:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var path: String = root_path.path_join(entry)
			if directory.current_is_dir():
				_collect_resource_paths(path, resource_paths)
			elif entry.get_extension().to_lower() in ["tres", "res"]:
				resource_paths.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _object_has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false
	for property: Dictionary in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


static func _read_string(object: Object, property_name: String, fallback: String) -> String:
	if not _object_has_property(object, property_name):
		return fallback
	var value: Variant = object.get(property_name)
	return fallback if value == null else str(value)


static func _read_int(object: Object, property_name: String, fallback: int) -> int:
	if not _object_has_property(object, property_name):
		return fallback
	var value: Variant = object.get(property_name)
	return fallback if value == null else int(value)


static func _read_float(object: Object, property_name: String, fallback: float) -> float:
	if not _object_has_property(object, property_name):
		return fallback
	var value: Variant = object.get(property_name)
	return fallback if value == null else float(value)


static func _read_string_array(object: Object, property_name: String) -> Array[String]:
	if not _object_has_property(object, property_name):
		return []
	return _string_array(object.get(property_name))


static func _property_strings(object: Object, property_name: String) -> Array[String]:
	if not _object_has_property(object, property_name):
		return []
	return _string_array(object.get(property_name))


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _append_known_states(target: Array[String], values: Array[String]) -> void:
	for value: String in values:
		var normalized: String = StatePolicy.normalize_state(value)
		if StatePolicy.STATUS_ELEMENTS.has(normalized):
			_append_unique(target, normalized)


static func _append_many(target: Array[String], values: Array[String]) -> void:
	for value: String in values:
		_append_unique(target, value)


static func _append_unique(target: Array[String], value: String) -> void:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == "" or target.has(normalized):
		return
	target.append(normalized)


static func _contains_all(values: Array[String], required: Array[String]) -> bool:
	for value: String in required:
		if not values.has(value.strip_edges().to_lower()):
			return false
	return true


static func _contains_any(values: Array[String], required: Array[String]) -> bool:
	for value: String in required:
		if values.has(value.strip_edges().to_lower()):
			return true
	return false


static func _has_any_word(values: Array[String], words: Array[String]) -> bool:
	for value: String in values:
		for word: String in words:
			if value == word or value.contains(word):
				return true
	return false


static func _category_name(category: int) -> String:
	match category:
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
			return "unknown"


static func _element_sort_index(element: String) -> int:
	var index: int = ELEMENT_ORDER.find(element)
	return index if index >= 0 else ELEMENT_ORDER.size()


static func _markdown_list(value: Variant) -> String:
	var values: Array[String] = _string_array(value)
	return "—" if values.is_empty() else ", ".join(values)
