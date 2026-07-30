extends RefCounted
class_name SquadRoleCatalog


const GENERALIST = preload("res://data/ai/squad_roles/generalist.tres")
const PRIMER = preload("res://data/ai/squad_roles/primer.tres")
const PAYOFF_SPECIALIST = preload("res://data/ai/squad_roles/payoff_specialist.tres")
const PROTECTOR = preload("res://data/ai/squad_roles/protector.tres")
const DISRUPTOR = preload("res://data/ai/squad_roles/disruptor.tres")
const SKIRMISHER = preload("res://data/ai/squad_roles/skirmisher.tres")

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


static func get_profiles(include_generalist: bool = true) -> Array:
	var profiles: Array = [PRIMER, PAYOFF_SPECIALIST, PROTECTOR, DISRUPTOR, SKIRMISHER]
	if include_generalist:
		profiles.append(GENERALIST)
	return profiles


static func get_profile(role_id: String) -> Resource:
	var normalized: String = normalize_role_id(role_id)
	for profile_value: Variant in get_profiles(true):
		if profile_value is Resource:
			var profile: Resource = profile_value as Resource
			if normalize_role_id(str(profile.get("role_id"))) == normalized:
				return profile
	return GENERALIST


static func has_role(role_id: String) -> bool:
	var normalized: String = normalize_role_id(role_id)
	for profile_value: Variant in get_profiles(true):
		if profile_value is Resource and normalize_role_id(str((profile_value as Resource).get("role_id"))) == normalized:
			return true
	return false


static func normalize_role_id(role_id: String) -> String:
	var normalized: String = role_id.strip_edges().to_lower()
	if normalized == "":
		return "generalist"
	if normalized == "auto":
		return "auto"
	return str(ALIASES.get(normalized, normalized))


static func evaluate_candidate(role_id: String, candidate: Variant, evaluation: Dictionary = {}) -> Dictionary:
	var profile: Resource = get_profile(role_id)
	var result: Dictionary = {}
	if profile != null and profile.has_method("evaluate_candidate"):
		var value: Variant = profile.call("evaluate_candidate", candidate, evaluation)
		if value is Dictionary:
			result = (value as Dictionary).duplicate(true)
	result["role_id"] = normalize_role_id(str(profile.get("role_id")))
	result["role_name"] = str(profile.get("display_name"))
	return result


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for profile_value: Variant in get_profiles(true):
		if not profile_value is Resource:
			errors.append("Squad role catalog contains a null profile")
			continue
		var profile: Resource = profile_value as Resource
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
		if profile_value is Resource and (profile_value as Resource).has_method("to_debug_data"):
			var row: Variant = (profile_value as Resource).call("to_debug_data")
			if row is Dictionary:
				rows.append((row as Dictionary).duplicate(true))
	return rows
