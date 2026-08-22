extends RefCounted
class_name MobLocomotionCatalog

const LocomotionDefinition = preload(
	"res://scripts/mobs/mob_locomotion_definition.gd"
)

const CAPABILITIES: Dictionary = {
	"ground": {
		"id": "ground",
		"display_name": "Ground",
		"kind": "mode",
		"dimension": "planar",
		"medium_tags": ["land"],
		"required_any_body_tags": ["legs", "serpentine_body", "slithering_body"],
		"transition_capabilities": ["swimmer", "flight", "climber", "burrower"],
		"uses_gravity": true,
		"vertical_control": 0.0,
	},
	"swimmer": {
		"id": "swimmer",
		"display_name": "Swimming",
		"kind": "mode",
		"dimension": "volumetric",
		"medium_tags": ["water", "water_surface", "underwater"],
		"required_any_body_tags": ["swimmer", "fins", "flippers", "tentacles"],
		"transition_capabilities": ["ground"],
		"speed_multiplier": 0.9,
		"acceleration_multiplier": 0.75,
		"turn_multiplier": 0.8,
		"uses_gravity": false,
		"vertical_control": 1.0,
	},
	"flight": {
		"id": "flight",
		"display_name": "Flight",
		"kind": "mode",
		"dimension": "volumetric",
		"medium_tags": ["air"],
		"required_any_body_tags": ["wings", "winged", "levitation"],
		"transition_capabilities": ["ground", "climber"],
		"speed_multiplier": 1.15,
		"acceleration_multiplier": 0.8,
		"turn_multiplier": 0.82,
		"uses_gravity": false,
		"vertical_control": 1.0,
	},
	"climber": {
		"id": "climber",
		"display_name": "Climbing",
		"kind": "mode",
		"dimension": "surface",
		"medium_tags": ["vertical_surface", "ceiling"],
		"required_any_body_tags": [
			"claws",
			"hands",
			"adhesive_pads",
			"tentacles",
			"climbing_limbs",
		],
		"transition_capabilities": ["ground", "flight"],
		"speed_multiplier": 0.62,
		"acceleration_multiplier": 0.7,
		"turn_multiplier": 0.65,
		"uses_gravity": false,
		"vertical_control": 0.8,
	},
	"burrower": {
		"id": "burrower",
		"display_name": "Burrowing",
		"kind": "mode",
		"dimension": "volumetric",
		"medium_tags": ["soil", "sand", "snow"],
		"required_any_body_tags": [
			"digging_limbs",
			"claws",
			"burrowing_body",
			"boring_head",
		],
		"transition_capabilities": ["ground"],
		"speed_multiplier": 0.55,
		"acceleration_multiplier": 0.58,
		"turn_multiplier": 0.5,
		"uses_gravity": false,
		"vertical_control": 0.75,
	},
	"runner": {
		"id": "runner",
		"display_name": "Runner",
		"kind": "modifier",
		"dimension": "planar",
		"medium_tags": ["land"],
		"required_any_body_tags": ["legs"],
		"requires_capabilities": ["ground"],
		"speed_multiplier": 1.35,
		"acceleration_multiplier": 1.2,
		"turn_multiplier": 0.95,
	},
	"jumper": {
		"id": "jumper",
		"display_name": "Jumper",
		"kind": "transition",
		"dimension": "volumetric",
		"medium_tags": ["air"],
		"required_any_body_tags": ["legs", "jumping_limbs"],
		"requires_capabilities": ["ground"],
		"speed_multiplier": 1.0,
		"acceleration_multiplier": 1.1,
		"turn_multiplier": 0.75,
		"vertical_control": 0.35,
	},
	"serpentine": {
		"id": "serpentine",
		"display_name": "Serpentine Gait",
		"kind": "modifier",
		"dimension": "planar",
		"medium_tags": ["land"],
		"required_any_body_tags": ["tail", "serpentine_body", "slithering_body"],
		"requires_capabilities": ["ground"],
		"speed_multiplier": 0.95,
		"acceleration_multiplier": 0.88,
		"turn_multiplier": 1.2,
	},
	"hover": {
		"id": "hover",
		"display_name": "Hover",
		"kind": "modifier",
		"dimension": "volumetric",
		"medium_tags": ["air"],
		"required_any_body_tags": ["wings", "winged", "levitation"],
		"requires_capabilities": ["flight"],
		"speed_multiplier": 0.72,
		"acceleration_multiplier": 1.15,
		"turn_multiplier": 1.3,
		"uses_gravity": false,
		"vertical_control": 1.0,
	},
}

const ALIASES: Dictionary = {
	"land": "ground",
	"walking": "ground",
	"run": "runner",
	"jump": "jumper",
	"swim": "swimmer",
	"swimming": "swimmer",
	"aquatic": "swimmer",
	"surface_swim": "swimmer",
	"submerged_swim": "swimmer",
	"fly": "flight",
	"flying": "flight",
	"winged_flight": "flight",
	"climb": "climber",
	"climbing": "climber",
	"burrow": "burrower",
	"burrowing": "burrower",
	"slither": "serpentine",
}


static func has_capability(capability_id: String) -> bool:
	return CAPABILITIES.has(normalize_id(capability_id))


static func normalize_id(capability_id: String) -> String:
	var normalized: String = capability_id.to_lower().strip_edges()
	return str(ALIASES.get(normalized, normalized))


static func normalize_ids(raw_ids: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_ids is Array:
		for raw: Variant in raw_ids as Array:
			var normalized: String = normalize_id(str(raw))
			if normalized != "" and not result.has(normalized):
				result.append(normalized)
	return result


static func get_definition(capability_id: String) -> MobLocomotionDefinition:
	var value: Variant = CAPABILITIES.get(normalize_id(capability_id))
	if not value is Dictionary:
		return null
	return LocomotionDefinition.from_dictionary(value as Dictionary)


static func get_capability_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id: Variant in CAPABILITIES.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


static func resolve_profile(
	body_tags: Array[String],
	locomotion_tags: Array[String]
) -> Dictionary:
	var normalized_body: Array[String] = _normalize_body_tags(body_tags)
	var declared: Array[String] = normalize_ids(locomotion_tags)
	var supported: Array[String] = []
	var unresolved: Array[String] = declared.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for capability_id: String in unresolved.duplicate():
			var definition: MobLocomotionDefinition = get_definition(capability_id)
			if definition == null:
				continue
			if (
				definition.supports_body(normalized_body)
				and definition.has_dependencies(supported)
			):
				supported.append(capability_id)
				unresolved.erase(capability_id)
				changed = true

	var modes: Array[String] = []
	var modifiers: Array[String] = []
	var transitions: Array[String] = []
	var rows: Array[Dictionary] = []
	var medium_tags: Array[String] = []
	for capability_id: String in supported:
		var definition: MobLocomotionDefinition = get_definition(capability_id)
		if definition == null:
			continue
		rows.append(definition.to_dictionary())
		match definition.capability_kind:
			"mode":
				modes.append(capability_id)
			"modifier":
				modifiers.append(capability_id)
			"transition":
				transitions.append(capability_id)
		for medium_tag: String in definition.medium_tags:
			if not medium_tags.has(medium_tag):
				medium_tags.append(medium_tag)

	var failures: Array[String] = []
	for capability_id: String in unresolved:
		var definition: MobLocomotionDefinition = get_definition(capability_id)
		if definition == null:
			failures.append("unknown locomotion capability " + capability_id)
			continue
		if not definition.supports_body(normalized_body):
			failures.append(
				capability_id + " is not supported by body tags " + str(normalized_body)
			)
		elif not definition.has_dependencies(supported):
			failures.append(
				capability_id + " requires " + str(definition.requires_capabilities)
			)
	if modes.is_empty():
		failures.append("locomotion profile has no supported movement mode")

	return {
		"body_tags": normalized_body,
		"declared_capabilities": declared,
		"supported_capabilities": supported,
		"modes": modes,
		"modifiers": modifiers,
		"transitions": transitions,
		"medium_tags": medium_tags,
		"definitions": rows,
		"failures": failures,
	}


static func supports(
	body_tags: Array[String],
	locomotion_tags: Array[String],
	capability_id: String
) -> bool:
	var profile: Dictionary = resolve_profile(body_tags, locomotion_tags)
	var supported: Array[String] = normalize_ids(
		profile.get("supported_capabilities", [])
	)
	return supported.has(normalize_id(capability_id))


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	for capability_id: String in get_capability_ids():
		var definition: MobLocomotionDefinition = get_definition(capability_id)
		if definition == null:
			failures.append("missing locomotion definition " + capability_id)
			continue
		for failure: String in definition.validate():
			failures.append(failure)
		for dependency_id: String in definition.requires_capabilities:
			if not CAPABILITIES.has(dependency_id):
				failures.append(
					capability_id + " references missing dependency " + dependency_id
				)
		for transition_id: String in definition.transition_capabilities:
			if not CAPABILITIES.has(transition_id):
				failures.append(
					capability_id + " references missing transition " + transition_id
				)
	return failures


static func _normalize_body_tags(body_tags: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for raw_tag: String in body_tags:
		var normalized: String = raw_tag.to_lower().strip_edges()
		if normalized != "" and not result.has(normalized):
			result.append(normalized)
	return result
