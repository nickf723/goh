extends RefCounted

# Prototype spell modifier registry.
#
# This is intentionally data-driven but still small enough to inspect quickly.
# It gives prototype upgrades one place to declare:
# spell_id + unlock_id -> payload changes + projectile runtime changes.

const MODIFIER_DEFS: Dictionary = {
	"charged_firebolt": {
		"id": "charged_firebolt",
		"display_name": "Charged Firebolt",
		"unlock_id": "charged_firebolt",
		"spell_id": "firebolt",
		"behavior": "charge",
		"notes": "Charge timing still lives in AbilityCaster because it needs hold/release input state.",
		"payload_match_tags": ["charged", "firebolt"],
		"projectile": {
			"impact_style": "charged_firebolt",
		},
	},
	"piercing_ice_lance": {
		"id": "piercing_ice_lance",
		"display_name": "Piercing Ice Lance",
		"unlock_id": "piercing_ice_lance",
		"spell_id": "ice_lance",
		"behavior": "payload_projectile_modifier",
		"cast_message": "Piercing Ice Lance.",
		"cast_lock_duration": 0.18,
		"extra_mana_cost": 0,
		"payload": {
			"source_name": "Piercing Ice Lance",
			"min_amount": 2,
			"stance_bonus": 1,
			"min_stance_damage": 5,
			"status_duration_multiplier": 1.15,
			"tags_to_add": ["piercing", "upgrade", "ice_lance", "piercing_ice_lance"],
		},
		"payload_match_tags": ["piercing", "ice_lance"],
		"projectile": {
			"destroy_on_hit": true,
			"hit_limit": 4,
			"min_speed": 24.0,
			"min_lifetime": 3.05,
			"trail_interval": 0.028,
			"impact_radius": 1.18,
		},
	},
}


static func get_modifier_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []

	for modifier_id: String in MODIFIER_DEFS.keys():
		definitions.append(get_modifier_definition(modifier_id))

	return definitions


static func get_modifier_definition(modifier_id: String) -> Dictionary:
	if MODIFIER_DEFS.has(modifier_id):
		var definition: Dictionary = MODIFIER_DEFS[modifier_id] as Dictionary
		return definition.duplicate(true)

	return {}


static func get_active_modifier_definitions_for_ability(ability: Resource) -> Array[Dictionary]:
	var active_definitions: Array[Dictionary] = []
	var spell_id: String = get_ability_spell_id(ability)

	if spell_id == "":
		return active_definitions

	for definition: Dictionary in get_modifier_definitions():
		if str(definition.get("spell_id", "")) != spell_id:
			continue

		if not is_modifier_unlocked(definition):
			continue

		active_definitions.append(definition)

	return active_definitions


static func get_active_payload_modifier_definitions_for_ability(ability: Resource) -> Array[Dictionary]:
	var payload_definitions: Array[Dictionary] = []

	for definition: Dictionary in get_active_modifier_definitions_for_ability(ability):
		if not definition.has("payload"):
			continue

		payload_definitions.append(definition)

	return payload_definitions


static func has_active_payload_modifier_for_ability(ability: Resource) -> bool:
	return get_active_payload_modifier_definitions_for_ability(ability).size() > 0


static func build_modified_payload_for_ability(ability: Resource) -> Resource:
	var payload_definitions: Array[Dictionary] = get_active_payload_modifier_definitions_for_ability(ability)

	if payload_definitions.size() <= 0:
		return null

	var base_payload: Resource = get_ability_payload(ability)

	if not (base_payload is DamagePayload):
		return base_payload

	var duplicate_payload: Resource = base_payload.duplicate(true)

	if not (duplicate_payload is DamagePayload):
		return base_payload

	var modified_payload: DamagePayload = duplicate_payload as DamagePayload

	for definition: Dictionary in payload_definitions:
		apply_payload_modifier(modified_payload, definition)

	return modified_payload


static func get_cast_extra_mana_cost_for_ability(ability: Resource) -> int:
	var extra_cost: int = 0

	for definition: Dictionary in get_active_payload_modifier_definitions_for_ability(ability):
		extra_cost += int(definition.get("extra_mana_cost", 0))

	return extra_cost


static func get_cast_lock_duration_for_ability(ability: Resource, fallback_duration: float) -> float:
	var resolved_duration: float = fallback_duration

	for definition: Dictionary in get_active_payload_modifier_definitions_for_ability(ability):
		if definition.has("cast_lock_duration"):
			resolved_duration = max(resolved_duration, float(definition.get("cast_lock_duration", resolved_duration)))

	return resolved_duration


static func get_cast_message_for_ability(ability: Resource) -> String:
	var messages: Array[String] = []

	for definition: Dictionary in get_active_payload_modifier_definitions_for_ability(ability):
		var cast_message: String = str(definition.get("cast_message", ""))
		if cast_message != "":
			messages.append(cast_message)

	if messages.size() <= 0:
		return ""

	return " ".join(messages)


static func get_projectile_modifiers_for_payload(active_payload: DamagePayload) -> Array[Dictionary]:
	var projectile_modifiers: Array[Dictionary] = []

	if active_payload == null:
		return projectile_modifiers

	for definition: Dictionary in get_modifier_definitions():
		if not definition.has("projectile"):
			continue

		if not payload_matches_modifier(active_payload, definition):
			continue

		var projectile_modifier: Dictionary = (definition["projectile"] as Dictionary).duplicate(true)
		projectile_modifier["id"] = str(definition.get("id", ""))
		projectile_modifier["display_name"] = str(definition.get("display_name", projectile_modifier["id"]))
		projectile_modifiers.append(projectile_modifier)

	return projectile_modifiers


static func payload_matches_modifier(active_payload: DamagePayload, definition: Dictionary) -> bool:
	if active_payload == null:
		return false

	var required_tags_variant: Variant = definition.get("payload_match_tags", [])

	if not (required_tags_variant is Array):
		return false

	for required_tag_variant: Variant in required_tags_variant:
		var required_tag: String = str(required_tag_variant)
		if required_tag == "":
			continue

		if not payload_has_tag(active_payload, required_tag):
			return false

	return true


static func apply_payload_modifier(payload: DamagePayload, definition: Dictionary) -> void:
	if payload == null:
		return

	var payload_rules_variant: Variant = definition.get("payload", {})

	if not (payload_rules_variant is Dictionary):
		return

	var payload_rules: Dictionary = payload_rules_variant as Dictionary

	if payload_rules.has("source_name"):
		payload.source_name = str(payload_rules.get("source_name", payload.source_name))

	if payload_rules.has("amount_bonus"):
		payload.amount += int(payload_rules.get("amount_bonus", 0))

	if payload_rules.has("min_amount"):
		payload.amount = max(payload.amount, int(payload_rules.get("min_amount", payload.amount)))

	if payload_rules.has("stance_bonus"):
		payload.stance_damage += int(payload_rules.get("stance_bonus", 0))

	if payload_rules.has("min_stance_damage"):
		payload.stance_damage = max(payload.stance_damage, int(payload_rules.get("min_stance_damage", payload.stance_damage)))

	if payload_rules.has("status_duration_multiplier"):
		payload.status_duration *= float(payload_rules.get("status_duration_multiplier", 1.0))

	if payload_rules.has("tags_to_add"):
		append_payload_tags(payload, payload_rules.get("tags_to_add", []))


static func append_payload_tags(payload: DamagePayload, tags_to_add_variant: Variant) -> void:
	if payload == null:
		return

	if not (tags_to_add_variant is Array):
		return

	var next_tags: Array[String] = []

	for existing_tag_variant: Variant in payload.tags:
		var existing_tag: String = str(existing_tag_variant)
		if existing_tag == "":
			continue
		if next_tags.has(existing_tag):
			continue
		next_tags.append(existing_tag)

	for tag_variant: Variant in tags_to_add_variant:
		var tag: String = str(tag_variant)
		if tag == "":
			continue
		if next_tags.has(tag):
			continue
		next_tags.append(tag)

	payload.tags = next_tags


static func get_ability_spell_id(ability: Resource) -> String:
	if ability == null:
		return ""

	if ability.has_method("get_spell_id"):
		return str(ability.call("get_spell_id"))

	var spell_id_value: Variant = ability.get("spell_id")
	if spell_id_value != null and str(spell_id_value) != "":
		return str(spell_id_value)

	var display_name_value: Variant = ability.get("display_name")
	if display_name_value != null:
		return str(display_name_value).to_lower().replace(" ", "_")

	return ""


static func get_ability_payload(ability: Resource) -> Resource:
	if ability == null:
		return null

	if ability.has_method("get_action_payload"):
		var method_payload: Variant = ability.call("get_action_payload")
		if method_payload is Resource:
			return method_payload as Resource

	var action_payload: Variant = ability.get("action_payload")
	if action_payload is Resource:
		return action_payload as Resource

	var legacy_payload: Variant = ability.get("payload")
	if legacy_payload is Resource:
		return legacy_payload as Resource

	return null


static func is_modifier_unlocked(definition: Dictionary) -> bool:
	var unlock_id: String = str(definition.get("unlock_id", ""))

	if unlock_id == "":
		return false

	if not GameState.has_method("has_unlock"):
		return false

	return GameState.has_unlock(unlock_id)


static func payload_has_tag(active_payload: DamagePayload, tag_name: String) -> bool:
	if active_payload == null:
		return false

	var normalized_tag_name: String = tag_name.to_lower()

	for tag_variant: Variant in active_payload.tags:
		if str(tag_variant).to_lower() == normalized_tag_name:
			return true

	return false
