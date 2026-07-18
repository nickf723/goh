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
		"behavior_avoid_multipliers": {
			"danger": 1.0,
			"slow": 1.0,
			"trap": 1.0,
		},
	},
	"cautious": {
		"display_name": "Cautious",
		"description": "Protects itself, avoids hostile zones early, and commits to attacks more carefully.",
		"zone_awareness_radius_multiplier": 1.15,
		"zone_avoid_strength_multiplier": 1.25,
		"zone_hesitation_time_multiplier": 1.2,
		"attack_commit_time_multiplier": 1.18,
		"behavior_avoid_multipliers": {
			"danger": 1.3,
			"slow": 1.1,
			"trap": 1.2,
		},
	},
	"bold": {
		"display_name": "Bold",
		"description": "Pushes pressure, accepts more risk, and commits to attacks faster.",
		"zone_awareness_radius_multiplier": 0.95,
		"zone_avoid_strength_multiplier": 0.7,
		"zone_hesitation_time_multiplier": 0.55,
		"attack_commit_time_multiplier": 0.78,
		"behavior_avoid_multipliers": {
			"danger": 0.75,
			"slow": 0.65,
			"trap": 0.6,
		},
	},
	"skittish": {
		"display_name": "Skittish",
		"description": "Keeps extra distance from zones and stalls more when caught in control effects.",
		"zone_awareness_radius_multiplier": 1.3,
		"zone_avoid_strength_multiplier": 1.45,
		"zone_hesitation_time_multiplier": 1.4,
		"attack_commit_time_multiplier": 1.25,
		"behavior_avoid_multipliers": {
			"danger": 1.4,
			"slow": 1.2,
			"trap": 1.35,
		},
	},
	"brute": {
		"display_name": "Brute",
		"description": "Ignores softer control, respects major danger, and commits through pressure.",
		"zone_awareness_radius_multiplier": 0.85,
		"zone_avoid_strength_multiplier": 0.65,
		"zone_hesitation_time_multiplier": 0.35,
		"attack_commit_time_multiplier": 0.85,
		"behavior_avoid_multipliers": {
			"danger": 0.95,
			"slow": 0.35,
			"trap": 0.45,
		},
	},
	"opportunist": {
		"display_name": "Opportunist",
		"description": "Avoids big threats but pressures quickly when a route opens.",
		"zone_awareness_radius_multiplier": 1.05,
		"zone_avoid_strength_multiplier": 1.05,
		"zone_hesitation_time_multiplier": 0.8,
		"attack_commit_time_multiplier": 0.9,
		"behavior_avoid_multipliers": {
			"danger": 1.15,
			"slow": 0.85,
			"trap": 0.9,
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


static func get_debug_summary(profile_id: String) -> String:
	var key: String = normalize_profile_id(profile_id)
	return get_display_name(key) + " (" + key + ")"
