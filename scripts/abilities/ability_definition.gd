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

# Optional reusable taxonomy profile. Keep this typed as Resource so Godot can parse
# this script even before the editor has indexed AbilityTraitProfile.
@export var trait_profile: Resource
@export var use_trait_profile: bool = true

# Spell identity metadata. These fields are intentionally data-only for now.
# They make spells easier to sort, inspect, display, and eventually combine.
@export var spell_id: String = ""
@export var short_label: String = ""
@export var icon_text: String = ""

# What the spell is for. Examples: damage, control, movement, detection,
# hazard, status, force, traversal, combo_starter, combo_reactor.
# These are spell-specific additions layered on top of trait_profile roles.
@export var roles: Array[String] = []

# Optional spell-specific overrides. If blank, the trait_profile supplies them.
@export var targeting_style: String = ""
@export var delivery_type: String = ""

# Spell-specific tags used for future combo search, UI grouping, and debug views.
# These merge with trait_profile tags instead of replacing them.
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


func has_active_trait_profile() -> bool:
	return use_trait_profile and trait_profile != null


func get_trait_profile_id() -> String:
	if not has_active_trait_profile():
		return "none"

	var profile_id_value: String = get_profile_string("profile_id", "")

	if profile_id_value != "":
		return profile_id_value

	if trait_profile.resource_path != "":
		return trait_profile.resource_path.get_file().get_basename()

	return "profile"


func get_trait_profile_summary() -> String:
	if not has_active_trait_profile():
		return "none"

	if trait_profile.has_method("get_summary"):
		return str(trait_profile.call("get_summary"))

	return get_trait_profile_id()


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


func get_roles() -> Array[String]:
	var merged_roles: Array[String] = []
	append_profile_strings(merged_roles, "roles")
	append_unique_strings(merged_roles, roles)
	return merged_roles


func get_targeting_style() -> String:
	if targeting_style != "":
		return targeting_style

	return get_profile_string("targeting_style", "aimed")


func get_delivery_type() -> String:
	if delivery_type != "":
		return delivery_type

	return get_profile_string("delivery_type", "projectile")


func get_combo_tags() -> Array[String]:
	var merged_tags: Array[String] = []
	append_profile_strings(merged_tags, "combo_tags")
	append_unique_strings(merged_tags, combo_tags)
	return merged_tags


func get_status_tags() -> Array[String]:
	var merged_tags: Array[String] = []
	append_profile_strings(merged_tags, "status_tags")
	append_unique_strings(merged_tags, status_tags)
	return merged_tags


func get_ui_tags() -> Array[String]:
	var merged_tags: Array[String] = []
	append_profile_strings(merged_tags, "ui_tags")
	append_unique_strings(merged_tags, ui_tags)
	return merged_tags


func get_debug_tags() -> Array[String]:
	var merged_tags: Array[String] = []
	append_profile_strings(merged_tags, "debug_tags")
	append_unique_strings(merged_tags, debug_tags)
	return merged_tags


func get_design_notes() -> String:
	var notes: Array[String] = []
	var profile_notes: String = get_profile_string("design_notes", "")

	if profile_notes != "":
		notes.append(profile_notes)

	if design_notes != "":
		notes.append(design_notes)

	return " | ".join(notes)


func get_identity_summary() -> String:
	var summary_parts: Array[String] = []
	var effective_roles: Array[String] = get_roles()
	var effective_targeting: String = get_targeting_style()
	var effective_delivery: String = get_delivery_type()

	summary_parts.append(get_spell_id())
	summary_parts.append(element)
	summary_parts.append(effective_delivery)

	if effective_targeting != "":
		summary_parts.append(effective_targeting)

	if get_trait_profile_id() != "none":
		summary_parts.append("profile=" + get_trait_profile_id())

	if effective_roles.size() > 0:
		summary_parts.append("roles=" + ",".join(effective_roles))

	return " | ".join(summary_parts)


func has_role(role: String) -> bool:
	return get_roles().has(role)


func has_combo_tag(combo_tag: String) -> bool:
	return get_combo_tags().has(combo_tag)


func has_status_tag(status_tag: String) -> bool:
	return get_status_tags().has(status_tag)


func has_any_role(required_roles: Array[String]) -> bool:
	for role: String in required_roles:
		if has_role(role):
			return true

	return false


func get_all_spell_tags() -> Array[String]:
	var all_tags: Array[String] = []
	append_unique_strings(all_tags, get_roles())
	append_unique_strings(all_tags, get_combo_tags())
	append_unique_strings(all_tags, get_status_tags())
	append_unique_strings(all_tags, get_ui_tags())
	append_unique_strings(all_tags, get_debug_tags())

	if element != "" and not all_tags.has(element):
		all_tags.append(element)

	var effective_delivery: String = get_delivery_type()
	if effective_delivery != "" and not all_tags.has(effective_delivery):
		all_tags.append(effective_delivery)

	var effective_targeting: String = get_targeting_style()
	if effective_targeting != "" and not all_tags.has(effective_targeting):
		all_tags.append(effective_targeting)

	var profile_id_value: String = get_trait_profile_id()
	if profile_id_value != "none" and not all_tags.has(profile_id_value):
		all_tags.append(profile_id_value)

	return all_tags


func get_debug_data() -> Dictionary:
	return {
		"id": get_spell_id(),
		"name": display_name,
		"element": element,
		"profile": get_trait_profile_id(),
		"roles": get_roles(),
		"targeting": get_targeting_style(),
		"delivery": get_delivery_type(),
		"combo": get_combo_tags(),
		"status": get_status_tags(),
		"ui": get_ui_tags(),
		"debug": get_debug_tags(),
		"all_tags": get_all_spell_tags(),
		"notes": get_design_notes(),
	}


func get_profile_string(field_name: String, fallback: String = "") -> String:
	if not has_active_trait_profile():
		return fallback

	var value: Variant = trait_profile.get(field_name)

	if value == null:
		return fallback

	var text_value: String = str(value)

	if text_value == "":
		return fallback

	return text_value


func append_profile_strings(target: Array[String], field_name: String) -> void:
	if not has_active_trait_profile():
		return

	var value: Variant = trait_profile.get(field_name)

	if value == null:
		return

	if value is Array:
		for entry in value:
			var text_entry: String = str(entry)

			if text_entry == "":
				continue

			if target.has(text_entry):
				continue

			target.append(text_entry)


func append_unique_strings(target: Array[String], source: Array[String]) -> void:
	for value: String in source:
		if value == "":
			continue

		if target.has(value):
			continue

		target.append(value)
