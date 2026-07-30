extends RefCounted
class_name SquadRoleCatalog


const GENERALIST: SquadRoleProfile = preload(
	"res://data/ai/squad_roles/generalist.tres"
)
const PRIMER: SquadRoleProfile = preload(
	"res://data/ai/squad_roles/primer.tres"
)
const PAYOFF_SPECIALIST: SquadRoleProfile = preload(
	"res://data/ai/squad_roles/payoff_specialist.tres"
)
const PROTECTOR: SquadRoleProfile = preload(
	"res://data/ai/squad_roles/protector.tres"
)
const DISRUPTOR: SquadRoleProfile = preload(
	"res://data/ai/squad_roles/disruptor.tres"
)
const SKIRMISHER: SquadRoleProfile = preload(
	"res://data/ai/squad_roles/skirmisher.tres"
)

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


static func get_profiles(include_generalist: bool = true) -> Array[SquadRoleProfile]:
	var profiles: Array[SquadRoleProfile] = [
		PRIMER,
		PAYOFF_SPECIALIST,
		PROTECTOR,
		DISRUPTOR,
		SKIRMISHER,
	]
	if include_generalist:
		profiles.append(GENERALIST)
	return profiles


static func get_profile(role_id: String) -> SquadRoleProfile:
	var normalized: String = normalize_role_id(role_id)
	for profile: SquadRoleProfile in get_profiles(true):
		if profile != null and normalize_role_id(profile.role_id) == normalized:
			return profile
	return GENERALIST


static func has_role(role_id: String) -> bool:
	var normalized: String = normalize_role_id(role_id)
	for profile: SquadRoleProfile in get_profiles(true):
		if profile != null and normalize_role_id(profile.role_id) == normalized:
			return true
	return false


static func normalize_role_id(role_id: String) -> String:
	var normalized: String = role_id.strip_edges().to_lower()
	if normalized == "" or normalized == "auto":
		return "generalist" if normalized == "" else "auto"
	return str(ALIASES.get(normalized, normalized))


static func evaluate_candidate(
	role_id: String,
	candidate: TacticalActionCandidate,
	evaluation: Dictionary = {}
) -> Dictionary:
	var profile: SquadRoleProfile = get_profile(role_id)
	var result: Dictionary = profile.evaluate_candidate(candidate, evaluation)
	result["role_id"] = normalize_role_id(profile.role_id)
	result["role_name"] = profile.display_name
	return result


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for profile: SquadRoleProfile in get_profiles(true):
		if profile == null:
			errors.append("Squad role catalog contains a null profile")
			continue
		var normalized: String = normalize_role_id(profile.role_id)
		if ids.has(normalized):
			errors.append("Duplicate squad role id: " + normalized)
		else:
			ids[normalized] = true
		for error: String in profile.validate_profile():
			errors.append(normalized + ": " + error)
	return errors


static func get_debug_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for profile: SquadRoleProfile in get_profiles(true):
		if profile != null:
			rows.append(profile.to_debug_data())
	return rows
