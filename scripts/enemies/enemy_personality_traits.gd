extends RefCounted
class_name EnemyPersonalityTraits

# Reusable enemy behavior profiles for combat decision tuning.
# These are intentionally small numeric modifiers so different enemy families can
# share the same brain while feeling less identical.

const DEFAULT_PROFILE_ID: String = "balanced"

const PROFILES: Dictionary = {
	"balanced": {
		"display_name": "Balanced",
		"description": "Default behavior with ordinary zone awareness and attack commitment.",
		"zone_awareness_radius_multiplier": 1.0,
		"zone_avoid_strength_multiplier": 1.0,
		"zone_hesitation_time_multiplier": 1.0,
		"attack_commit_time_multiplier": 1.0,
		"post_miss_retreat_time": 0.0,
		"post_miss_retreat_speed_multiplier": 1.0,
		"behavior_avoid_multipliers": {
			"danger": 1.0,
			"slow": 1.0,
			"trap": 1.0,
		},
		"action_role_multipliers": {
			"melee": 1.0,
			"close": 1.0,
			"lunge": 1.0,
			"gap_closer": 1.0,
			"defense": 1.0,
			"evade": 1.0,
			"guard": 1.0,
		},
	},
	"cautious": {
		"display_name": "Cautious",
		"description": "Protects itself, avoids hostile zones early, and commits to attacks more carefully.",
		"zone_awareness_radius_multiplier": 1.4,
		"zone_avoid_strength_multiplier": 1.8,
		"zone_hesitation_time_multiplier": 1.2,
		"attack_commit_time_multiplier": 1.18,
		"post_miss_retreat_time": 0.2,
		"post_miss_retreat_speed_multiplier": 0.9,
		"move_speed_multiplier": 0.8,
		"zone_approach_slowdown": 0.5,
		"behavior_avoid_multipliers": {
			"danger": 1.6,
			"slow": 1.1,
			"trap": 1.2,
		},
		"action_role_multipliers": {
			"melee": 1.0,
			"close": 0.95,
			"lunge": 0.85,
			"gap_closer": 0.9,
			"defense": 1.25,
			"evade": 1.2,
			"guard": 1.3,
		},
	},
	"bold": {
		"display_name": "Bold",
		"description": "Pushes pressure, accepts more risk, and commits to attacks faster.",
		"zone_awareness_radius_multiplier": 0.8,
		"zone_avoid_strength_multiplier": 0.35,
		"zone_hesitation_time_multiplier": 0.55,
		"attack_commit_time_multiplier": 0.78,
		"post_miss_retreat_time": 0.0,
		"post_miss_retreat_speed_multiplier": 1.0,
		"move_speed_multiplier": 1.25,
		"zone_approach_slowdown": 0.0,
		"behavior_avoid_multipliers": {
			"danger": 0.35,
			"slow": 0.65,
			"trap": 0.6,
		},
		"action_role_multipliers": {
			"melee": 1.05,
			"close": 1.1,
			"lunge": 1.25,
			"gap_closer": 1.15,
			"defense": 0.65,
			"evade": 0.7,
			"guard": 0.6,
		},
	},
	"skittish": {
		"display_name": "Skittish",
		"description": "Keeps extra distance from zones, prefers committed darting attacks, and retreats after misses.",
		"zone_awareness_radius_multiplier": 2.2,
		"zone_avoid_strength_multiplier": 4.0,
		"zone_hesitation_time_multiplier": 1.4,
		"attack_commit_time_multiplier": 1.25,
		"post_miss_retreat_time": 0.55,
		"post_miss_retreat_speed_multiplier": 1.12,
		"move_speed_multiplier": 1.05,
		"zone_approach_slowdown": 0.75,
		"behavior_avoid_multipliers": {
			"danger": 2.5,
			"slow": 1.2,
			"trap": 1.35,
		},
		"action_role_multipliers": {
			"melee": 0.9,
			"close": 0.75,
			"lunge": 1.1,
			"gap_closer": 1.15,
			"defense": 1.35,
			"evade": 1.45,
			"guard": 0.8,
		},
	},
	"brute": {
		"display_name": "Brute",
		"description": "Ignores softer control, respects major danger, and commits through pressure.",
		"zone_awareness_radius_multiplier": 0.4,
		"zone_avoid_strength_multiplier": 0.05,
		"zone_hesitation_time_multiplier": 0.35,
		"attack_commit_time_multiplier": 0.85,
		"post_miss_retreat_time": 0.0,
		"post_miss_retreat_speed_multiplier": 0.8,
		"move_speed_multiplier": 0.7,
		"zone_approach_slowdown": 0.0,
		"behavior_avoid_multipliers": {
			"danger": 0.05,
			"slow": 0.35,
			"trap": 0.45,
		},
		"action_role_multipliers": {
			"melee": 1.15,
			"close": 1.25,
			"lunge": 0.9,
			"gap_closer": 0.85,
			"defense": 0.45,
			"evade": 0.35,
			"guard": 1.05,
		},
	},
	"opportunist": {
		"display_name": "Opportunist",
		"description": "Avoids big threats but pressures quickly when a route opens.",
		"zone_awareness_radius_multiplier": 1.05,
		"zone_avoid_strength_multiplier": 1.05,
		"zone_hesitation_time_multiplier": 0.8,
		"attack_commit_time_multiplier": 0.9,
		"post_miss_retreat_time": 0.15,
		"post_miss_retreat_speed_multiplier": 1.0,
		"behavior_avoid_multipliers": {
			"danger": 1.15,
			"slow": 0.85,
			"trap": 0.9,
		},
		"action_role_multipliers": {
			"melee": 1.0,
			"close": 1.1,
			"lunge": 1.15,
			"gap_closer": 1.25,
			"defense": 0.95,
			"evade": 1.0,
			"guard": 0.9,
		},
	},
}


static func get_profile(profile_id: String) -> Dictionary:
	var key: String = normalize_profile_id(profile_id)
	return (PROFILES[key] as Dictionary).duplicate(true)


static func normalize_profile_id(profile_id: String) -> String:
	var key: String = profile_id.to_lower().strip_edges()
	if key == "":
		key = DEFAULT_PROFILE_ID
	if not PROFILES.has(key):
		key = DEFAULT_PROFILE_ID
	return key


static func get_display_name(profile_id: String) -> String:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("display_name", "Balanced"))


static func get_description(profile_id: String) -> String:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("description", ""))


static func get_number(profile_id: String, key: String, fallback: float = 1.0) -> float:
	var profile: Dictionary = get_profile(profile_id)
	var value: Variant = profile.get(key, fallback)
	return fallback if value == null else float(value)


static func get_behavior_avoid_multiplier(profile_id: String, behavior: String, fallback: float = 1.0) -> float:
	var profile: Dictionary = get_profile(profile_id)
	var behavior_multipliers: Variant = profile.get("behavior_avoid_multipliers", {})
	if not behavior_multipliers is Dictionary:
		return fallback

	var value: Variant = (behavior_multipliers as Dictionary).get(behavior, fallback)
	return fallback if value == null else float(value)


static func get_action_role_multiplier(profile_id: String, role: String, fallback: float = 1.0) -> float:
	var profile: Dictionary = get_profile(profile_id)
	var role_multipliers: Variant = profile.get("action_role_multipliers", {})
	if not role_multipliers is Dictionary:
		return fallback

	var normalized_role: String = role.to_lower().strip_edges()
	var value: Variant = (role_multipliers as Dictionary).get(normalized_role, fallback)
	return fallback if value == null else float(value)


static func get_debug_summary(profile_id: String) -> String:
	var key: String = normalize_profile_id(profile_id)
	return get_display_name(key) + " (" + key + ")"
