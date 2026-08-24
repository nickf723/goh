extends Resource
class_name MobEcologyProfile

const VALID_SCALE_BANDS: Array[String] = [
	"micro",
	"tiny",
	"small",
	"medium",
	"large",
	"huge",
	"colossal",
	"variable",
]
const VALID_BREATHING_MEDIA: Array[String] = [
	"air",
	"water",
	"none",
]
const VALID_SOCIAL_STRUCTURES: Array[String] = [
	"solitary",
	"pair",
	"family",
	"pack",
	"herd",
	"flock",
	"school",
	"swarm",
	"colony",
	"variable",
]
const VALID_AGGREGATION_MODES: Array[String] = [
	"individual",
	"group",
	"swarm",
	"colony",
	"multipart",
	"variable",
]

@export var scale_band: String = "medium"
@export var breathing_media: Array[String] = ["air"]
@export var diet_tags: Array[String] = []
@export var activity_cycle_tags: Array[String] = ["variable"]
@export var social_structure: String = "solitary"
@export var aggregation_mode: String = "individual"
@export var required_habitat_tags: Array[String] = []
@export var any_habitat_tags: Array[String] = []
@export var preferred_habitat_tags: Array[String] = []
@export var forbidden_habitat_tags: Array[String] = []
@export var minimum_temperature: float = -50.0
@export var maximum_temperature: float = 50.0
@export var home_range: float = 10.0


static func from_dictionary(data: Dictionary) -> MobEcologyProfile:
	var profile := MobEcologyProfile.new()
	profile.scale_band = str(
		data.get("scale_band", "medium")
	).to_lower().strip_edges()
	profile.breathing_media = _string_array(
		data.get("breathing_media", ["air"])
	)
	profile.diet_tags = _string_array(data.get("diet_tags", []))
	profile.activity_cycle_tags = _string_array(
		data.get("activity_cycle_tags", ["variable"])
	)
	profile.social_structure = str(
		data.get("social_structure", "solitary")
	).to_lower().strip_edges()
	profile.aggregation_mode = str(
		data.get("aggregation_mode", "individual")
	).to_lower().strip_edges()
	profile.required_habitat_tags = _string_array(
		data.get("required_habitat_tags", [])
	)
	profile.any_habitat_tags = _string_array(
		data.get("any_habitat_tags", [])
	)
	profile.preferred_habitat_tags = _string_array(
		data.get("preferred_habitat_tags", [])
	)
	profile.forbidden_habitat_tags = _string_array(
		data.get("forbidden_habitat_tags", [])
	)
	profile.minimum_temperature = float(
		data.get("minimum_temperature", -50.0)
	)
	profile.maximum_temperature = float(
		data.get("maximum_temperature", 50.0)
	)
	profile.home_range = maxf(float(data.get("home_range", 10.0)), 0.0)
	return profile


func duplicate_profile() -> MobEcologyProfile:
	return MobEcologyProfile.from_dictionary(to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"scale_band": scale_band,
		"breathing_media": breathing_media.duplicate(),
		"diet_tags": diet_tags.duplicate(),
		"activity_cycle_tags": activity_cycle_tags.duplicate(),
		"social_structure": social_structure,
		"aggregation_mode": aggregation_mode,
		"required_habitat_tags": required_habitat_tags.duplicate(),
		"any_habitat_tags": any_habitat_tags.duplicate(),
		"preferred_habitat_tags": preferred_habitat_tags.duplicate(),
		"forbidden_habitat_tags": forbidden_habitat_tags.duplicate(),
		"minimum_temperature": minimum_temperature,
		"maximum_temperature": maximum_temperature,
		"home_range": home_range,
	}


func validate() -> Array[String]:
	var failures: Array[String] = []
	if not VALID_SCALE_BANDS.has(scale_band):
		failures.append("invalid scale band " + scale_band)
	if breathing_media.is_empty():
		failures.append("ecology profile has no breathing medium")
	for medium_id: String in breathing_media:
		if not VALID_BREATHING_MEDIA.has(medium_id):
			failures.append("invalid breathing medium " + medium_id)
	if breathing_media.has("none") and breathing_media.size() > 1:
		failures.append("breathing medium none cannot be combined with another medium")
	if not VALID_SOCIAL_STRUCTURES.has(social_structure):
		failures.append("invalid social structure " + social_structure)
	if not VALID_AGGREGATION_MODES.has(aggregation_mode):
		failures.append("invalid aggregation mode " + aggregation_mode)
	if minimum_temperature > maximum_temperature:
		failures.append("minimum temperature exceeds maximum temperature")
	for tag: String in required_habitat_tags:
		if forbidden_habitat_tags.has(tag):
			failures.append(
				"habitat tag " + tag + " is both required and forbidden"
			)
	return failures


func evaluate_habitat(context: Dictionary) -> Dictionary:
	var habitat_tags: Array[String] = _string_array(
		context.get("habitat_tags", context.get("tags", []))
	)
	var available_media: Array[String] = _string_array(
		context.get("available_media", [])
	)
	if available_media.is_empty():
		for medium_id: String in ["air", "water"]:
			if habitat_tags.has(medium_id):
				available_media.append(medium_id)
		if available_media.is_empty() and habitat_tags.has("land"):
			available_media.append("air")

	var failures: Array[String] = []
	var breathing_match: String = ""
	if breathing_media.has("none"):
		breathing_match = "none"
	else:
		for medium_id: String in breathing_media:
			if available_media.has(medium_id):
				breathing_match = medium_id
				break
		if breathing_match == "":
			failures.append(
				"missing breathing medium " + "/".join(breathing_media)
			)

	for tag: String in required_habitat_tags:
		if not habitat_tags.has(tag):
			failures.append("missing required habitat tag " + tag)
	if not any_habitat_tags.is_empty():
		var has_any_habitat: bool = false
		for tag: String in any_habitat_tags:
			if habitat_tags.has(tag):
				has_any_habitat = true
				break
		if not has_any_habitat:
			failures.append(
				"needs one habitat tag from " + ", ".join(any_habitat_tags)
			)
	for tag: String in forbidden_habitat_tags:
		if habitat_tags.has(tag):
			failures.append("forbidden habitat tag " + tag)

	var temperature_known: bool = context.has("temperature")
	var temperature: float = float(context.get("temperature", 0.0))
	if temperature_known:
		if temperature < minimum_temperature:
			failures.append("temperature below species minimum")
		elif temperature > maximum_temperature:
			failures.append("temperature above species maximum")

	var matched_preferred: Array[String] = []
	for tag: String in preferred_habitat_tags:
		if habitat_tags.has(tag):
			matched_preferred.append(tag)
	var preference_score: float = 1.0
	if not preferred_habitat_tags.is_empty():
		preference_score = (
			float(matched_preferred.size())
			/ float(preferred_habitat_tags.size())
	)
	if not failures.is_empty():
		preference_score = 0.0

	return {
		"viable": failures.is_empty(),
		"preference_score": clampf(preference_score, 0.0, 1.0),
		"failures": failures,
		"habitat_tags": habitat_tags,
		"available_media": available_media,
		"breathing_match": breathing_match,
		"temperature_known": temperature_known,
		"temperature": temperature,
		"matched_preferred_tags": matched_preferred,
	}


func get_context_tags() -> Array[String]:
	var result: Array[String] = [
		"scale:" + scale_band,
		"social_structure:" + social_structure,
		"aggregation:" + aggregation_mode,
	]
	for medium_id: String in breathing_media:
		result.append("breathes:" + medium_id)
	for diet_tag: String in diet_tags:
		result.append("diet:" + diet_tag)
	for activity_tag: String in activity_cycle_tags:
		result.append("activity:" + activity_tag)
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var normalized: String = str(raw).to_lower().strip_edges()
			if normalized != "" and not result.has(normalized):
				result.append(normalized)
	return result
