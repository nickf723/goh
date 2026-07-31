extends RefCounted
class_name SquadRoleCatalog


const ROLE_PATHS: Dictionary = {
	"generalist": "res://data/ai/squad_roles/generalist.tres",
	"primer": "res://data/ai/squad_roles/primer.tres",
	"payoff_specialist": "res://data/ai/squad_roles/payoff_specialist.tres",
	"protector": "res://data/ai/squad_roles/protector.tres",
	"disruptor": "res://data/ai/squad_roles/disruptor.tres",
	"skirmisher": "res://data/ai/squad_roles/skirmisher.tres",
}
const SPECIALIST_ORDER: Array[String] = [
	"primer",
	"payoff_specialist",
	"protector",
	"disruptor",
	"skirmisher",
]
const ALIASES: Dictionary = {
	"default": "generalist",
	"balanced": "generalist",
	"setup": "primer",
	"setter": "primer",
	"payoff": "payoff_specialist",
	"detonator": "payoff_specialist",
	"finisher": "payoff_specialist",
	"support": "protector",
	"guardian": "protector",
	"controller": "disruptor",
	"harasser": "skirmisher",
	"ranged": "skirmisher",
}

static var cached_profiles: Dictionary = {}


static func get_profiles(include_generalist: bool = true) -> Array:
	var profiles: Array = []
	for role_id: String in SPECIALIST_ORDER:
		var profile: Resource = _load_profile(role_id)
		if profile != null:
			profiles.append(profile)
	if include_generalist:
		var generalist: Resource = _load_profile("generalist")
		if generalist != null:
			profiles.append(generalist)
	return profiles


static func get_profile(role_id: String):
	var normalized: String = normalize_role_id(role_id)
	if normalized == "auto":
		normalized = "generalist"
	var profile: Resource = _load_profile(normalized)
	if profile != null:
		return profile
	return _load_profile("generalist")


static func has_role(role_id: String) -> bool:
	var normalized: String = normalize_role_id(role_id)
	return normalized != "auto" and ROLE_PATHS.has(normalized)


static func normalize_role_id(role_id: String) -> String:
	var normalized: String = role_id.strip_edges().to_lower()
	if normalized == "":
		return "generalist"
	if normalized == "auto":
		return "auto"
	return str(ALIASES.get(normalized, normalized))


static func evaluate_candidate(
	role_id: String,
	candidate: Variant,
	evaluation: Dictionary = {}
) -> Dictionary:
	var profile_value: Variant = get_profile(role_id)
	var result: Dictionary = {}
	if profile_value is Resource:
		var profile: Resource = profile_value as Resource
		if profile.has_method("evaluate_candidate"):
			var value: Variant = profile.call(
				"evaluate_candidate",
				candidate,
				evaluation
			)
			if value is Dictionary:
				result = (value as Dictionary).duplicate(true)
		result["role_id"] = normalize_role_id(str(profile.get("role_id")))
		result["role_name"] = str(profile.get("display_name"))
	else:
		result["role_id"] = "generalist"
		result["role_name"] = "Generalist"
	return result


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for role_id: String in ROLE_PATHS.keys():
		var profile: Resource = _load_profile(role_id)
		if profile == null:
			errors.append("Squad role profile failed to load: " + role_id)
			continue
		var normalized: String = normalize_role_id(str(profile.get("role_id")))
		if ids.has(normalized):
			errors.append("Duplicate squad role id: " + normalized)
		else:
			ids[normalized] = true
		if profile.has_method("validate_profile"):
			var profile_errors: Variant = profile.call("validate_profile")
			if profile_errors is Array:
				for error_value: Variant in profile_errors:
					errors.append(normalized + ": " + str(error_value))
	return errors


static func get_debug_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for profile_value: Variant in get_profiles(true):
		if not profile_value is Resource:
			continue
		var profile: Resource = profile_value as Resource
		if not profile.has_method("to_debug_data"):
			continue
		var row: Variant = profile.call("to_debug_data")
		if row is Dictionary:
			rows.append((row as Dictionary).duplicate(true))
	return rows


static func clear_cache() -> void:
	cached_profiles.clear()


static func _load_profile(role_id: String) -> Resource:
	var normalized: String = normalize_role_id(role_id)
	if normalized == "auto":
		normalized = "generalist"
	if cached_profiles.has(normalized):
		var cached_value: Variant = cached_profiles[normalized]
		return cached_value as Resource if cached_value is Resource else null
	var path: String = str(ROLE_PATHS.get(normalized, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var loaded_value: Variant = load(path)
	if loaded_value is Resource:
		cached_profiles[normalized] = loaded_value
		return loaded_value as Resource
	return null
