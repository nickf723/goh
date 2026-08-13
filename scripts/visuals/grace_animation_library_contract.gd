extends RefCounted
class_name GraceAnimationLibraryContract

# Semantic bridge between imported AnimationPlayer clip names and Grace
# presentation roles. Gameplay state/timing remains authoritative elsewhere.

const CORE_REQUIRED: Array[String] = [
	"idle", "run", "jump", "fall", "land", "dodge", "hit",
]

const CORE_OPTIONAL: Array[String] = [
	"walk", "locomotion_start", "locomotion_stop", "turn_left", "turn_right", "stagger",
]

const SWORD_CALIBRATION_ROLES: Array[String] = [
	"sword_light_1", "sword_light_2", "sword_light_3", "sword_light_4",
	"sword_heavy_neutral", "sword_dash_light", "sword_dash_heavy",
	"sword_aerial_light", "sword_aerial_heavy",
]

const SEMANTIC_ALIASES: Dictionary = {
	"idle": ["idle", "idle_loop", "standing_idle", "breathing_idle"],
	"walk": ["walk", "walk_loop", "walking"],
	"run": ["run", "run_loop", "running", "jog"],
	"locomotion_start": ["run_start", "locomotion_start", "start_run"],
	"locomotion_stop": ["run_stop", "locomotion_stop", "stop_run"],
	"turn_left": ["turn_left", "left_turn", "turn90_left"],
	"turn_right": ["turn_right", "right_turn", "turn90_right"],
	"jump": ["jump", "jump_start", "jump_up"],
	"fall": ["fall", "fall_loop", "airborne", "in_air"],
	"land": ["land", "landing", "jump_land"],
	"dodge": ["dodge", "roll", "evade", "combat_roll"],
	"hit": ["hit", "hit_reaction", "damage_reaction", "hurt"],
	"stagger": ["stagger", "staggered", "guard_break", "knockback"],
	"sword_light_1": ["sword_light_1", "sword_l1", "light_attack_1", "sword_attack_1"],
	"sword_light_2": ["sword_light_2", "sword_l2", "light_attack_2", "sword_attack_2"],
	"sword_light_3": ["sword_light_3", "sword_l3", "light_attack_3", "sword_attack_3"],
	"sword_light_4": ["sword_light_4", "sword_l4", "light_attack_4", "sword_attack_4"],
	"sword_heavy_neutral": ["sword_heavy", "sword_h0", "heavy_attack", "sword_heavy_neutral"],
	"sword_dash_light": ["sword_dash_light", "passing_cut", "dash_light_sword"],
	"sword_dash_heavy": ["sword_dash_heavy", "rush_break", "dash_heavy_sword"],
	"sword_aerial_light": ["sword_aerial_light", "comet_slash", "aerial_light_sword"],
	"sword_aerial_heavy": ["sword_aerial_heavy", "falling_edge", "aerial_heavy_sword"],
}


static func find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node == null:
		return null
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child: Node in root_node.get_children():
		var found: AnimationPlayer = find_animation_player(child)
		if found != null:
			return found
	return null


static func build_semantic_map(player: AnimationPlayer) -> Dictionary:
	var result: Dictionary = {}
	if player == null:
		return result
	var lookup: Dictionary = {}
	for animation_name_variant: Variant in player.get_animation_list():
		var animation_name: String = str(animation_name_variant)
		for candidate: String in _normalized_candidates(animation_name):
			if candidate != "" and not lookup.has(candidate):
				lookup[candidate] = StringName(animation_name)

	for semantic_variant: Variant in SEMANTIC_ALIASES.keys():
		var semantic: String = str(semantic_variant)
		for alias_variant: Variant in SEMANTIC_ALIASES[semantic] as Array:
			var alias: String = _normalize(str(alias_variant))
			if lookup.has(alias):
				result[semantic] = lookup[alias]
				break
	return result


static func validate_player(player: AnimationPlayer) -> Dictionary:
	var semantic_map: Dictionary = build_semantic_map(player)
	var missing_core: Array[String] = []
	var missing_optional: Array[String] = []
	var missing_sword: Array[String] = []
	for semantic: String in CORE_REQUIRED:
		if not semantic_map.has(semantic):
			missing_core.append(semantic)
	for semantic: String in CORE_OPTIONAL:
		if not semantic_map.has(semantic):
			missing_optional.append(semantic)
	for semantic: String in SWORD_CALIBRATION_ROLES:
		if not semantic_map.has(semantic):
			missing_sword.append(semantic)
	return {
		"compatible_core": player != null and missing_core.is_empty(),
		"sword_calibration_ready": player != null and missing_core.is_empty() and missing_sword.is_empty(),
		"clip_count": player.get_animation_list().size() if player != null else 0,
		"mapped_count": semantic_map.size(),
		"semantic_map": semantic_map,
		"missing_core": missing_core,
		"missing_optional": missing_optional,
		"missing_sword": missing_sword,
	}


static func get_animation_name(player: AnimationPlayer, semantic: String) -> StringName:
	return StringName(build_semantic_map(player).get(semantic, ""))


static func has_semantic(player: AnimationPlayer, semantic: String) -> bool:
	return get_animation_name(player, semantic) != StringName()


static func _normalized_candidates(value: String) -> Array[String]:
	var result: Array[String] = []
	_append_candidate(result, value)
	var pipe_parts: PackedStringArray = value.split("|")
	if pipe_parts.size() > 1:
		_append_candidate(result, pipe_parts[pipe_parts.size() - 1])
	var slash_parts: PackedStringArray = value.split("/")
	if slash_parts.size() > 1:
		_append_candidate(result, slash_parts[slash_parts.size() - 1])
	return result


static func _append_candidate(result: Array[String], value: String) -> void:
	var normalized: String = _normalize(value)
	if normalized != "" and not result.has(normalized):
		result.append(normalized)


static func _normalize(value: String) -> String:
	return value.to_lower().replace("_", "").replace("-", "").replace(" ", "").replace(".", "")
