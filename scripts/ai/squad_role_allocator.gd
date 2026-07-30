extends RefCounted
class_name SquadRoleAllocator


const RoleCatalog = preload("res://scripts/ai/squad_role_catalog.gd")
const ActionCandidate = preload("res://scripts/ai/tactical_action_candidate.gd")

const AUTO_ROLE_ID: String = "auto"
const GENERALIST_ROLE_ID: String = "generalist"
const MINIMUM_SPECIALIST_FIT: float = 1.0

static var assignments: Dictionary = {}


static func assign_from_enemy_options(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	configured_role_id: String,
	action_options: Array
) -> Dictionary:
	var candidates: Array = []
	for option_value: Variant in action_options:
		if option_value != null:
			candidates.append(ActionCandidate.from_enemy_option(option_value))
	return assign_role(squad_id, owner_id, owner_name, configured_role_id, candidates)


static func assign_role(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	configured_role_id: String,
	candidates: Array
) -> Dictionary:
	var normalized_squad: String = _normalize_squad(squad_id)
	var existing: Dictionary = get_assignment(owner_id, normalized_squad)
	if not existing.is_empty():
		return existing

	var configured: String = configured_role_id.strip_edges().to_lower()
	if configured != "" and configured != AUTO_ROLE_ID:
		var explicit_role: String = RoleCatalog.normalize_role_id(configured)
		if not RoleCatalog.has_role(explicit_role):
			explicit_role = GENERALIST_ROLE_ID
		return _store_assignment(normalized_squad, owner_id, owner_name, explicit_role, 0.0, true, "Explicit role")

	var best_role: String = GENERALIST_ROLE_ID
	var best_score: float = -INF
	for profile_value: Variant in RoleCatalog.get_profiles(false):
		if not profile_value is Resource:
			continue
		var profile: Resource = profile_value as Resource
		var role_id: String = RoleCatalog.normalize_role_id(str(profile.get("role_id")))
		var role_count: int = get_role_count(normalized_squad, role_id)
		var maximum_per_squad: int = int(profile.get("maximum_per_squad"))
		if role_count >= maximum_per_squad:
			continue
		if not profile.has_method("get_assignment_fit"):
			continue
		var fit: float = float(profile.call("get_assignment_fit", candidates))
		if is_inf(fit) and fit < 0.0:
			continue
		var score: float = fit - float(role_count) * float(profile.get("duplicate_penalty"))
		if score > best_score or (is_equal_approx(score, best_score) and role_id < best_role):
			best_role = role_id
			best_score = score

	if best_score < MINIMUM_SPECIALIST_FIT:
		best_role = GENERALIST_ROLE_ID
		var generalist: Resource = RoleCatalog.get_profile(GENERALIST_ROLE_ID)
		best_score = float(generalist.call("get_assignment_fit", candidates)) if generalist.has_method("get_assignment_fit") else 0.0

	return _store_assignment(normalized_squad, owner_id, owner_name, best_role, best_score, false, "Best eligible complementary role")


static func get_assignment(owner_id: int, squad_id: String = "") -> Dictionary:
	for value: Variant in assignments.values():
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if int(row.get("owner_id", 0)) != owner_id:
			continue
		if squad_id != "" and str(row.get("squad_id", "")) != _normalize_squad(squad_id):
			continue
		return row.duplicate(true)
	return {}


static func get_role_id(owner_id: int, squad_id: String = "") -> String:
	return str(get_assignment(owner_id, squad_id).get("role_id", GENERALIST_ROLE_ID))


static func get_role_count(squad_id: String, role_id: String) -> int:
	var normalized_squad: String = _normalize_squad(squad_id)
	var normalized_role: String = RoleCatalog.normalize_role_id(role_id)
	var count: int = 0
	for value: Variant in assignments.values():
		if value is Dictionary:
			var row: Dictionary = value as Dictionary
			if str(row.get("squad_id", "")) == normalized_squad and str(row.get("role_id", "")) == normalized_role:
				count += 1
	return count


static func get_squad_context(squad_id: String) -> Dictionary:
	var normalized_squad: String = _normalize_squad(squad_id)
	var rows: Array[Dictionary] = []
	var counts: Dictionary = {}
	for value: Variant in assignments.values():
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if str(row.get("squad_id", "")) != normalized_squad:
			continue
		var copy: Dictionary = row.duplicate(true)
		rows.append(copy)
		var role_id: String = str(copy.get("role_id", GENERALIST_ROLE_ID))
		counts[role_id] = int(counts.get(role_id, 0)) + 1
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("owner_id", 0)) < int(b.get("owner_id", 0))
	)
	return {
		"squad_id": normalized_squad,
		"squad_roles": rows,
		"squad_role_counts": counts,
	}


static func release_owner(owner_id: int, squad_id: String = "") -> int:
	var released: int = 0
	var normalized_squad: String = _normalize_squad(squad_id) if squad_id.strip_edges() != "" else ""
	for key: Variant in assignments.keys():
		var value: Variant = assignments.get(key)
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if int(row.get("owner_id", 0)) != owner_id:
			continue
		if normalized_squad != "" and str(row.get("squad_id", "")) != normalized_squad:
			continue
		assignments.erase(key)
		released += 1
	return released


static func clear_all() -> void:
	assignments.clear()


static func get_debug_data() -> Dictionary:
	var rows: Array[Dictionary] = []
	for value: Variant in assignments.values():
		if value is Dictionary:
			rows.append((value as Dictionary).duplicate(true))
	return {
		"assignment_count": rows.size(),
		"assignments": rows,
	}


static func _store_assignment(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	role_id: String,
	score: float,
	explicit: bool,
	reason: String
) -> Dictionary:
	var profile: Resource = RoleCatalog.get_profile(role_id)
	var row: Dictionary = {
		"assignment_id": squad_id + "@" + str(owner_id),
		"squad_id": squad_id,
		"owner_id": owner_id,
		"owner_name": owner_name,
		"role_id": RoleCatalog.normalize_role_id(str(profile.get("role_id"))),
		"role_name": str(profile.get("display_name")),
		"score": score,
		"explicit": explicit,
		"reason": reason,
		"assigned_at_msec": Time.get_ticks_msec(),
	}
	assignments[row["assignment_id"]] = row
	return row.duplicate(true)


static func _normalize_squad(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	return normalized if normalized != "" else "default_squad"
