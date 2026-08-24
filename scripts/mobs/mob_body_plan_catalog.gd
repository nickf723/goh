extends RefCounted
class_name MobBodyPlanCatalog

const LocomotionCatalog = preload(
	"res://scripts/mobs/mob_locomotion_catalog.gd"
)

const VALID_MOBILITY_KINDS: Array[String] = [
	"mobile",
	"sessile",
	"variable",
]

const DEFINITIONS: Dictionary = {
	"quadruped": {
		"id": "quadruped",
		"display_name": "Quadruped",
		"mobility_kind": "mobile",
		"body_tags": ["quadruped", "torso", "head", "mouth", "legs"],
		"default_locomotion_tags": ["ground"],
		"anatomy_counts": {"head": 1, "mouth": 1, "legs": 4},
	},
	"avian": {
		"id": "avian",
		"display_name": "Avian",
		"mobility_kind": "mobile",
		"body_tags": ["bird", "torso", "head", "mouth", "beak", "legs", "wings", "tail"],
		"default_locomotion_tags": ["ground", "flight"],
		"anatomy_counts": {"head": 1, "mouth": 1, "beak": 1, "legs": 2, "wings": 2, "tail": 1},
	},
	"fish": {
		"id": "fish",
		"display_name": "Fish",
		"mobility_kind": "mobile",
		"body_tags": ["fish", "head", "mouth", "fins", "gills", "tail", "swimmer"],
		"default_locomotion_tags": ["swimmer"],
		"anatomy_counts": {"head": 1, "mouth": 1, "gills": 2, "tail": 1},
	},
	"serpentine": {
		"id": "serpentine",
		"display_name": "Serpentine",
		"mobility_kind": "mobile",
		"body_tags": ["head", "mouth", "jaw", "serpentine_body", "tail"],
		"default_locomotion_tags": ["ground", "serpentine"],
		"anatomy_counts": {"head": 1, "mouth": 1, "jaw": 1, "tail": 1},
	},
	"amphibian": {
		"id": "amphibian",
		"display_name": "Amphibian",
		"mobility_kind": "mobile",
		"body_tags": ["amphibian", "torso", "head", "mouth", "legs", "jumping_limbs", "swimmer"],
		"default_locomotion_tags": ["ground", "swimmer", "jumper"],
		"anatomy_counts": {"head": 1, "mouth": 1, "legs": 4},
	},
	"insectoid": {
		"id": "insectoid",
		"display_name": "Insectoid",
		"mobility_kind": "mobile",
		"body_tags": ["insect", "head", "mouth", "mandibles", "legs", "exoskeleton"],
		"default_locomotion_tags": ["ground"],
		"anatomy_counts": {"head": 1, "mouth": 1, "mandibles": 2, "legs": 6},
	},
	"arachnid": {
		"id": "arachnid",
		"display_name": "Arachnid",
		"mobility_kind": "mobile",
		"body_tags": ["arachnid", "head", "mouth", "fangs", "legs", "exoskeleton"],
		"default_locomotion_tags": ["ground"],
		"anatomy_counts": {"head": 1, "mouth": 1, "fangs": 2, "legs": 8},
	},
	"crustacean": {
		"id": "crustacean",
		"display_name": "Crustacean",
		"mobility_kind": "mobile",
		"body_tags": ["crustacean", "head", "mouth", "legs", "exoskeleton", "gills", "swimmer"],
		"default_locomotion_tags": ["ground", "swimmer"],
		"anatomy_counts": {"head": 1, "mouth": 1, "legs": 10},
	},
	"cephalopod": {
		"id": "cephalopod",
		"display_name": "Cephalopod",
		"mobility_kind": "mobile",
		"body_tags": ["cephalopod", "head", "mouth", "tentacles", "mantle", "siphon", "swimmer"],
		"default_locomotion_tags": ["swimmer", "climber"],
		"anatomy_counts": {"head": 1, "mouth": 1, "tentacles": 8, "mantle": 1, "siphon": 1},
	},
	"humanoid": {
		"id": "humanoid",
		"display_name": "Humanoid",
		"mobility_kind": "mobile",
		"body_tags": ["humanoid", "biped", "torso", "head", "mouth", "hands", "legs"],
		"default_locomotion_tags": ["ground"],
		"anatomy_counts": {"head": 1, "mouth": 1, "hands": 2, "legs": 2},
	},
	"amorphous": {
		"id": "amorphous",
		"display_name": "Amorphous",
		"mobility_kind": "mobile",
		"body_tags": ["amorphous_body"],
		"default_locomotion_tags": ["ground"],
		"anatomy_counts": {"amorphous_body": 1},
	},
	"sessile": {
		"id": "sessile",
		"display_name": "Sessile",
		"mobility_kind": "sessile",
		"body_tags": ["anchored_body"],
		"default_locomotion_tags": [],
		"anatomy_counts": {"anchored_body": 1},
	},
	"composite": {
		"id": "composite",
		"display_name": "Composite / Mythic Hybrid",
		"mobility_kind": "variable",
		"body_tags": ["composite_body"],
		"default_locomotion_tags": [],
		"anatomy_counts": {"composite_body": 1},
	},
}


static func has_body_plan(body_plan_id: String) -> bool:
	return DEFINITIONS.has(normalize_id(body_plan_id))


static func normalize_id(body_plan_id: String) -> String:
	return body_plan_id.to_lower().strip_edges()


static func get_definition(body_plan_id: String) -> Dictionary:
	var value: Variant = DEFINITIONS.get(normalize_id(body_plan_id))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func get_body_plan_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id: Variant in DEFINITIONS.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


static func get_body_tags(body_plan_id: String) -> Array[String]:
	return _string_array(get_definition(body_plan_id).get("body_tags", []))


static func get_default_locomotion_tags(body_plan_id: String) -> Array[String]:
	return _string_array(
		get_definition(body_plan_id).get("default_locomotion_tags", [])
	)


static func get_mobility_kind(body_plan_id: String) -> String:
	return str(
		get_definition(body_plan_id).get("mobility_kind", "mobile")
	)


static func resolve_body_tags(
	body_plan_id: String,
	additional_tags: Array[String] = []
) -> Array[String]:
	var result: Array[String] = get_body_tags(body_plan_id)
	for raw_tag: String in additional_tags:
		var normalized: String = raw_tag.to_lower().strip_edges()
		if normalized != "" and not result.has(normalized):
			result.append(normalized)
	return result


static func resolve_anatomy_counts(
	body_plan_id: String,
	overrides: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {}
	var definition: Dictionary = get_definition(body_plan_id)
	var defaults: Variant = definition.get("anatomy_counts", {})
	if defaults is Dictionary:
		for raw_key: Variant in (defaults as Dictionary).keys():
			result[str(raw_key).to_lower().strip_edges()] = int(
				(defaults as Dictionary)[raw_key]
			)
	for raw_key: Variant in overrides.keys():
		result[str(raw_key).to_lower().strip_edges()] = int(overrides[raw_key])
	return result


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	for body_plan_id: String in get_body_plan_ids():
		var definition: Dictionary = get_definition(body_plan_id)
		if str(definition.get("id", "")) != body_plan_id:
			failures.append(body_plan_id + " has a mismatched body-plan id")
		if str(definition.get("display_name", "")).strip_edges() == "":
			failures.append(body_plan_id + " has no display name")
		var mobility_kind: String = str(
			definition.get("mobility_kind", "")
		)
		if not VALID_MOBILITY_KINDS.has(mobility_kind):
			failures.append(body_plan_id + " has invalid mobility kind " + mobility_kind)
		var body_tags: Array[String] = _string_array(
			definition.get("body_tags", [])
		)
		if body_tags.is_empty():
			failures.append(body_plan_id + " has no body tags")
		var anatomy: Dictionary = definition.get(
			"anatomy_counts",
			{}
		) as Dictionary
		for raw_part: Variant in anatomy.keys():
			var part_id: String = str(raw_part).to_lower().strip_edges()
			if part_id == "" or int(anatomy[raw_part]) <= 0:
				failures.append(body_plan_id + " has invalid anatomy count for " + part_id)
			elif not body_tags.has(part_id):
				failures.append(body_plan_id + " counts missing body tag " + part_id)
		var locomotion_tags: Array[String] = _string_array(
			definition.get("default_locomotion_tags", [])
		)
		if mobility_kind == "mobile" and locomotion_tags.is_empty():
			failures.append(body_plan_id + " has no default locomotion")
		elif not locomotion_tags.is_empty():
			var profile: Dictionary = LocomotionCatalog.resolve_profile(
				body_tags,
				locomotion_tags
			)
			for raw_failure: Variant in profile.get("failures", []):
				failures.append(
					body_plan_id + ": " + str(raw_failure)
				)
	return failures


static func get_debug_data() -> Dictionary:
	var rows: Array[Dictionary] = []
	for body_plan_id: String in get_body_plan_ids():
		rows.append(get_definition(body_plan_id))
	return {
		"body_plan_count": rows.size(),
		"body_plans": rows,
		"failures": validate_catalog(),
	}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var normalized: String = str(raw).to_lower().strip_edges()
			if normalized != "" and not result.has(normalized):
				result.append(normalized)
	return result
