extends Resource
class_name MobSpeciesDefinition

@export var species_id: String = ""
@export var display_name: String = ""
@export var category: String = "creature"
@export var taxonomy_tags: Array[String] = []
@export var body_tags: Array[String] = []
@export var locomotion_tags: Array[String] = []
@export var ecology_tags: Array[String] = []
@export var base_stats: Dictionary = {}
@export var default_personality: Dictionary = {}
@export var move_policies: Array[MobMovePolicy] = []
@export var familiar_eligible: bool = false
@export var familiar_profile: Dictionary = {}


static func from_dictionary(data: Dictionary) -> MobSpeciesDefinition:
	var definition := MobSpeciesDefinition.new()
	definition.species_id = str(data.get("id", data.get("species_id", ""))).strip_edges()
	definition.display_name = str(data.get(
		"display_name",
		definition.species_id.replace("_", " ").capitalize()
	))
	definition.category = str(data.get("category", "creature")).to_lower().strip_edges()
	definition.taxonomy_tags = _string_array(data.get("taxonomy_tags", []))
	definition.body_tags = _string_array(data.get("body_tags", []))
	definition.locomotion_tags = _string_array(data.get("locomotion_tags", []))
	definition.ecology_tags = _string_array(data.get("ecology_tags", []))
	definition.base_stats = _number_dictionary(data.get("base_stats", {}))
	definition.default_personality = _number_dictionary(data.get("default_personality", {}))
	definition.familiar_eligible = bool(data.get("familiar_eligible", false))
	definition.familiar_profile = _dictionary(data.get("familiar_profile", {}))
	definition.move_policies.clear()
	var raw_policies: Variant = data.get("move_policies", [])
	if raw_policies is Array:
		for raw: Variant in raw_policies as Array:
			if raw is Dictionary:
				definition.move_policies.append(MobMovePolicy.from_dictionary(raw as Dictionary))
	return definition


func duplicate_definition() -> MobSpeciesDefinition:
	return MobSpeciesDefinition.from_dictionary(to_dictionary())


func to_dictionary() -> Dictionary:
	var policies: Array[Dictionary] = []
	for policy: MobMovePolicy in move_policies:
		if policy != null:
			policies.append(policy.to_dictionary())
	return {
		"id": species_id,
		"display_name": display_name,
		"category": category,
		"taxonomy_tags": taxonomy_tags.duplicate(),
		"body_tags": body_tags.duplicate(),
		"locomotion_tags": locomotion_tags.duplicate(),
		"ecology_tags": ecology_tags.duplicate(),
		"base_stats": base_stats.duplicate(true),
		"default_personality": default_personality.duplicate(true),
		"move_policies": policies,
		"familiar_eligible": familiar_eligible,
		"familiar_profile": familiar_profile.duplicate(true),
	}


func get_move_policy(move_id: String) -> MobMovePolicy:
	for policy: MobMovePolicy in move_policies:
		if policy != null and policy.move_id == move_id:
			return policy
	return null


func get_move_ids() -> Array[String]:
	var ids: Array[String] = []
	for policy: MobMovePolicy in move_policies:
		if policy != null and policy.move_id != "" and not ids.has(policy.move_id):
			ids.append(policy.move_id)
	return ids


func has_body_tag(tag: String) -> bool:
	return body_tags.has(tag.to_lower().strip_edges())


func get_locomotion_profile() -> Dictionary:
	return MobLocomotionCatalog.resolve_profile(body_tags, locomotion_tags)


func supports_locomotion(capability_id: String) -> bool:
	return MobLocomotionCatalog.supports(
		body_tags,
		locomotion_tags,
		capability_id
	)


func get_personality(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = default_personality.duplicate(true)
	for raw_key: Variant in overrides.keys():
		result[str(raw_key).to_lower().strip_edges()] = clampf(float(overrides[raw_key]), 0.0, 1.0)
	return result


func validate(move_catalog: Variant = null) -> Array[String]:
	var failures: Array[String] = []
	if species_id == "":
		failures.append("species id is empty")
	if display_name == "":
		failures.append(species_id + " has no display name")
	if body_tags.is_empty():
		failures.append(species_id + " has no body tags")
	if locomotion_tags.is_empty():
		failures.append(species_id + " has no locomotion capabilities")
	else:
		var locomotion_profile: Dictionary = get_locomotion_profile()
		for locomotion_failure: String in (
			locomotion_profile.get("failures", []) as Array[String]
		):
			failures.append(species_id + ": " + locomotion_failure)
	if move_policies.is_empty():
		failures.append(species_id + " has no move policies")
	var seen: Dictionary = {}
	for policy: MobMovePolicy in move_policies:
		if policy == null:
			failures.append(species_id + " has a null move policy")
			continue
		for failure: String in policy.validate():
			failures.append(species_id + ": " + failure)
		if seen.has(policy.move_id):
			failures.append(species_id + " repeats policy for " + policy.move_id)
		seen[policy.move_id] = true
		if move_catalog != null and move_catalog.has_method("has_move"):
			if not bool(move_catalog.call("has_move", policy.move_id)):
				failures.append(species_id + " references missing move " + policy.move_id)
	return failures


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).to_lower().strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _number_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for raw_key: Variant in (value as Dictionary).keys():
			result[str(raw_key).to_lower().strip_edges()] = float((value as Dictionary)[raw_key])
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
