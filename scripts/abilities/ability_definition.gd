extends Resource
class_name AbilityDefinition

enum AbilityCategory {
	PROJECTILE,
	INSTANT,
	SUMMON,
	TRANSFORMATION,
	UTILITY,
}

@export var display_name: String = "New Ability"
@export var description: String = ""
@export var element: String = "neutral"
@export var category: AbilityCategory = AbilityCategory.PROJECTILE

@export var mana_cost: int = 1
@export var stamina_cost: int = 0
@export var focus_cost: int = 0

@export var ability_scene: PackedScene

# Legacy field. We are keeping it for now so old resources do not explode.
@export var payload: DamagePayload

# New universal payload field.
# Use this for DamagePayload, DetectionPayload, future HealPayload, TriggerPayload, etc.
@export var action_payload: Resource

# Spell identity metadata. These fields are intentionally data-only for now.
# They make spells easier to sort, inspect, display, and eventually combine.
@export var spell_id: String = ""
@export var short_label: String = ""
@export var icon_text: String = ""

# What the spell is for. Examples: damage, control, movement, detection,
# hazard, status, force, traversal, combo_starter, combo_reactor.
@export var roles: Array[String] = []

# How the spell is aimed and delivered. Keep these as strings so we can
# grow the grammar without breaking saved resources.
@export var targeting_style: String = "aimed"
@export var delivery_type: String = "projectile"

# Tags used for future combo search, UI grouping, and debug views.
@export var combo_tags: Array[String] = []
@export var status_tags: Array[String] = []
@export var ui_tags: Array[String] = []
@export var debug_tags: Array[String] = []

@export_multiline var design_notes: String = ""


func get_action_payload() -> Resource:
	if action_payload != null:
		return action_payload

	if payload != null:
		return payload

	return null


func get_spell_id() -> String:
	if spell_id != "":
		return spell_id

	return display_name.to_lower().replace(" ", "_")


func get_ui_label() -> String:
	if icon_text != "":
		return icon_text

	if short_label != "":
		return short_label

	return display_name


func get_identity_summary() -> String:
	var summary_parts: Array[String] = []
	summary_parts.append(get_spell_id())
	summary_parts.append(element)
	summary_parts.append(delivery_type)

	if targeting_style != "":
		summary_parts.append(targeting_style)

	if roles.size() > 0:
		summary_parts.append("roles=" + ",".join(roles))

	return " | ".join(summary_parts)


func has_role(role: String) -> bool:
	return roles.has(role)


func has_combo_tag(combo_tag: String) -> bool:
	return combo_tags.has(combo_tag)


func has_status_tag(status_tag: String) -> bool:
	return status_tags.has(status_tag)


func has_any_role(required_roles: Array[String]) -> bool:
	for role: String in required_roles:
		if has_role(role):
			return true

	return false


func get_all_spell_tags() -> Array[String]:
	var all_tags: Array[String] = []
	append_unique_strings(all_tags, roles)
	append_unique_strings(all_tags, combo_tags)
	append_unique_strings(all_tags, status_tags)
	append_unique_strings(all_tags, ui_tags)
	append_unique_strings(all_tags, debug_tags)

	if element != "" and not all_tags.has(element):
		all_tags.append(element)

	if delivery_type != "" and not all_tags.has(delivery_type):
		all_tags.append(delivery_type)

	return all_tags


func get_debug_data() -> Dictionary:
	return {
		"id": get_spell_id(),
		"name": display_name,
		"element": element,
		"roles": roles,
		"targeting": targeting_style,
		"delivery": delivery_type,
		"combo": combo_tags,
		"status": status_tags,
		"ui": ui_tags,
		"notes": design_notes,
	}


func append_unique_strings(target: Array[String], source: Array[String]) -> void:
	for value: String in source:
		if value == "":
			continue

		if target.has(value):
			continue

		target.append(value)
