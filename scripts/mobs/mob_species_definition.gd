extends Resource
class_name MobSpeciesDefinition

const BodyPlanCatalog = preload(
	"res://scripts/mobs/mob_body_plan_catalog.gd"
)
const EcologyProfileScript = preload(
	"res://scripts/mobs/mob_ecology_profile.gd"
)

@export var species_id: String = ""
@export var display_name: String = ""
@export var parent_species_id: String = ""
@export var body_plan_id: String = ""
@export var category: String = "creature"
@export var taxonomy_tags: Array[String] = []
@export var body_tags: Array[String] = []
@export var anatomy_counts: Dictionary = {}
@export var locomotion_tags: Array[String] = []
@export var ecology_tags: Array[String] = []
@export var ecology_profile: MobEcologyProfile
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
	definition.parent_species_id = str(
		data.get("parent_species_id", "")
	).to_lower().strip_edges()
	definition.body_plan_id = str(
		data.get("body_plan_id", "")
	).to_lower().strip_edges()
	definition.category = str(data.get("category", "creature")).to_lower().strip_edges()
	definition.taxonomy_tags = _string_array(data.get("taxonomy_tags", []))
	definition.body_tags = BodyPlanCatalog.resolve_body_tags(
		definition.body_plan_id,
		_string_array(data.get("body_tags", []))
	)
	definition.anatomy_counts = BodyPlanCatalog.resolve_anatomy_counts(
		definition.body_plan_id,
		_int_dictionary(data.get("anatomy_counts", {}))
	)
	if data.has("locomotion_tags"):
		definition.locomotion_tags = _string_array(data.get("locomotion_tags", []))
	else:
		definition.locomotion_tags = BodyPlanCatalog.get_default_locomotion_tags(
			definition.body_plan_id
		)
	definition.ecology_tags = _string_array(data.get("ecology_tags", []))
	var raw_ecology_profile: Variant = data.get("ecology_profile", {})
	definition.ecology_profile = EcologyProfileScript.from_dictionary(
		raw_ecology_profile as Dictionary
		if raw_ecology_profile is Dictionary
		else {}
	)
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
		"parent_species_id": parent_species_id,
		"body_plan_id": body_plan_id,
		"category": category,
		"taxonomy_tags": taxonomy_tags.duplicate(),
		"body_tags": body_tags.duplicate(),
		"anatomy_counts": anatomy_counts.duplicate(true),
		"locomotion_tags": locomotion_tags.duplicate(),
		"ecology_tags": ecology_tags.duplicate(),
		"ecology_profile": (
			ecology_profile.to_dictionary()
			if ecology_profile != null
			else {}
		),
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


func get_anatomy_count(part_id: String) -> int:
	var normalized: String = part_id.to_lower().strip_edges()
	if anatomy_counts.has(normalized):
		return maxi(0, int(anatomy_counts[normalized]))
	return 1 if has_body_tag(normalized) else 0


func has_anatomy(part_id: String, minimum_count: int = 1) -> bool:
	return get_anatomy_count(part_id) >= maxi(1, minimum_count)


func get_mobility_kind() -> String:
	if body_plan_id == "":
		return "mobile"
	return BodyPlanCatalog.get_mobility_kind(body_plan_id)


func is_sessile() -> bool:
	return get_mobility_kind() == "sessile"


func get_locomotion_profile() -> Dictionary:
	return MobLocomotionCatalog.resolve_profile(body_tags, locomotion_tags)


func supports_locomotion(capability_id: String) -> bool:
	return MobLocomotionCatalog.supports(
		body_tags,
		locomotion_tags,
		capability_id
	)


func evaluate_habitat(context: Dictionary) -> Dictionary:
	if ecology_profile == null:
		return {
			"viable": false,
			"preference_score": 0.0,
			"failures": ["species has no ecology profile"],
		}
	return ecology_profile.evaluate_habitat(context)


func can_inhabit(context: Dictionary) -> bool:
	return bool(evaluate_habitat(context).get("viable", false))


func get_ecology_context_tags() -> Array[String]:
	return (
		ecology_profile.get_context_tags()
		if ecology_profile != null
		else []
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
	if body_plan_id != "" and not BodyPlanCatalog.has_body_plan(body_plan_id):
		failures.append(species_id + " references missing body plan " + body_plan_id)
	if parent_species_id == species_id and species_id != "":
		failures.append(species_id + " cannot inherit from itself")
	if body_tags.is_empty():
		failures.append(species_id + " has no body tags")
	for raw_part: Variant in anatomy_counts.keys():
		var part_id: String = str(raw_part).to_lower().strip_edges()
		if part_id == "" or int(anatomy_counts[raw_part]) <= 0:
			failures.append(species_id + " has invalid anatomy count for " + part_id)
		elif not has_body_tag(part_id):
			failures.append(species_id + " counts missing body tag " + part_id)
	if locomotion_tags.is_empty():
		if not is_sessile():
			failures.append(species_id + " has no locomotion capabilities")
	else:
		var locomotion_profile: Dictionary = get_locomotion_profile()
		for locomotion_failure: String in (
			locomotion_profile.get("failures", []) as Array[String]
		):
			failures.append(species_id + ": " + locomotion_failure)
	if ecology_profile == null:
		failures.append(species_id + " has no ecology profile")
	else:
		for ecology_failure: String in ecology_profile.validate():
			failures.append(species_id + ": " + ecology_failure)
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
			elif move_catalog.has_method("get_definition"):
				var move_value: Variant = move_catalog.call(
					"get_definition",
					policy.move_id
				)
				if move_value is MobMoveDefinition:
					var move: MobMoveDefinition = move_value as MobMoveDefinition
					if not move.supports_body(body_tags):
						failures.append(
							species_id + " lacks anatomy for " + policy.move_id
						)
					if not move.supports_locomotion(body_tags, locomotion_tags):
						failures.append(
							species_id + " lacks locomotion for " + policy.move_id
						)
	return failures


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).to_lower().strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _int_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for raw_key: Variant in (value as Dictionary).keys():
			result[str(raw_key).to_lower().strip_edges()] = int(
				(value as Dictionary)[raw_key]
			)
	return result


static func _number_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for raw_key: Variant in (value as Dictionary).keys():
			result[str(raw_key).to_lower().strip_edges()] = float((value as Dictionary)[raw_key])
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
