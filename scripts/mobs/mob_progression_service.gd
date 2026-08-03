extends RefCounted
class_name MobProgressionService

const PROFILE_VERSION: int = 1
const PROFILE_PREFIX: String = "__mob_progression__::"
const MAX_MOVE_RANK: int = 5


static func get_profile(species_id: String) -> Dictionary:
	if not MobSpeciesCatalog.has_species(species_id):
		return {}
	var raw: Variant = GameState.story_flags.get(PROFILE_PREFIX + species_id)
	var profile: Dictionary = raw as Dictionary if raw is Dictionary else {}
	profile = _sanitize_profile(species_id, profile)
	_write_profile(species_id, profile)
	return profile.duplicate(true)


static func reset_profile(species_id: String) -> Dictionary:
	if not MobSpeciesCatalog.has_species(species_id):
		return {}
	var profile: Dictionary = _default_profile(species_id)
	_write_profile(species_id, profile)
	return profile.duplicate(true)


static func gain_experience(species_id: String, amount: int) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	if profile.is_empty():
		return {"ok": false, "error": "unknown species"}
	var previous_level: int = int(profile.get("level", 1))
	profile["experience"] = maxi(int(profile.get("experience", 0)) + maxi(amount, 0), 0)
	profile["level"] = _level_for_experience(species_id, int(profile["experience"]))
	var learned_now: Array[String] = _learn_level_moves(species_id, profile)
	_write_profile(species_id, profile)
	return {
		"ok": true,
		"species_id": species_id,
		"experience_gained": maxi(amount, 0),
		"previous_level": previous_level,
		"level": int(profile["level"]),
		"levels_gained": maxi(int(profile["level"]) - previous_level, 0),
		"learned_moves": learned_now,
		"profile": profile.duplicate(true),
	}


static func learn_move(species_id: String, move_id: String, force: bool = false) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	var policy: MobMovePolicy = MobSpeciesCatalog.get_move_policy(species_id, move_id)
	if profile.is_empty() or species == null or policy == null:
		return {"ok": false, "error": "move is not in this species movepool"}
	var required_level: int = _move_unlock_level(species, move_id, policy.minimum_level)
	if not force and int(profile.get("level", 1)) < required_level:
		return {
			"ok": false,
			"error": "move level requirement not met",
			"required_level": required_level,
		}
	var learned: Array[String] = _string_array(profile.get("learned_moves", []))
	var newly_learned: bool = not learned.has(move_id)
	if newly_learned:
		learned.append(move_id)
		profile["learned_moves"] = learned
		var ranks: Dictionary = _dictionary(profile.get("move_ranks", {}))
		ranks[move_id] = maxi(int(ranks.get(move_id, 1)), 1)
		profile["move_ranks"] = ranks
	_write_profile(species_id, profile)
	return {
		"ok": true,
		"newly_learned": newly_learned,
		"move_id": move_id,
		"required_level": required_level,
		"profile": profile.duplicate(true),
	}


static func equip_move(species_id: String, move_id: String) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	if profile.is_empty():
		return {"ok": false, "error": "unknown species"}
	if not _string_array(profile.get("learned_moves", [])).has(move_id):
		return {"ok": false, "error": "move has not been learned"}
	var equipped: Array[String] = _string_array(profile.get("equipped_moves", []))
	if equipped.has(move_id):
		return {"ok": true, "already_equipped": true, "profile": profile}
	var maximum: int = _maximum_equipped(species_id)
	if equipped.size() >= maximum:
		return {"ok": false, "error": "familiar movepool is full", "maximum": maximum}
	equipped.append(move_id)
	profile["equipped_moves"] = equipped
	_write_profile(species_id, profile)
	return {"ok": true, "move_id": move_id, "profile": profile.duplicate(true)}


static func unequip_move(species_id: String, move_id: String) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	if profile.is_empty():
		return {"ok": false, "error": "unknown species"}
	var equipped: Array[String] = _string_array(profile.get("equipped_moves", []))
	if not equipped.has(move_id):
		return {"ok": true, "already_unequipped": true, "profile": profile}
	if equipped.size() <= 1:
		return {"ok": false, "error": "a familiar needs at least one equipped move"}
	equipped.erase(move_id)
	profile["equipped_moves"] = equipped
	_write_profile(species_id, profile)
	return {"ok": true, "move_id": move_id, "profile": profile.duplicate(true)}


static func upgrade_move(species_id: String, move_id: String, amount: int = 1) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	if profile.is_empty() or not _string_array(profile.get("learned_moves", [])).has(move_id):
		return {"ok": false, "error": "move has not been learned"}
	var ranks: Dictionary = _dictionary(profile.get("move_ranks", {}))
	var previous: int = clampi(int(ranks.get(move_id, 1)), 1, MAX_MOVE_RANK)
	var next: int = clampi(previous + maxi(amount, 0), 1, MAX_MOVE_RANK)
	ranks[move_id] = next
	profile["move_ranks"] = ranks
	_write_profile(species_id, profile)
	return {
		"ok": true,
		"move_id": move_id,
		"previous_rank": previous,
		"rank": next,
		"rank_gained": next - previous,
		"profile": profile.duplicate(true),
	}


static func set_move_augment(
	species_id: String,
	move_id: String,
	slot_id: String,
	augment_id: String
) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	var move: MobMoveDefinition = MobMoveCatalog.get_definition(move_id)
	if profile.is_empty() or move == null:
		return {"ok": false, "error": "unknown familiar move"}
	if not _string_array(profile.get("learned_moves", [])).has(move_id):
		return {"ok": false, "error": "move has not been learned"}
	if not move.augment_slots.has(slot_id):
		return {"ok": false, "error": "move does not have that augment slot"}
	if augment_id != "" and not MobMoveAugmentCatalog.is_compatible(move, augment_id):
		return {"ok": false, "error": "augment is incompatible with this move"}
	var all_augments: Dictionary = _dictionary(profile.get("move_augments", {}))
	var move_augments: Dictionary = _dictionary(all_augments.get(move_id, {}))
	if augment_id == "":
		move_augments.erase(slot_id)
	else:
		move_augments[slot_id] = augment_id
	all_augments[move_id] = move_augments
	profile["move_augments"] = all_augments
	_write_profile(species_id, profile)
	return {
		"ok": true,
		"move_id": move_id,
		"slot_id": slot_id,
		"augment_id": augment_id,
		"profile": profile.duplicate(true),
	}


static func set_personality_trait(species_id: String, trait_id: String, value: float) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	if profile.is_empty():
		return {"ok": false, "error": "unknown species"}
	var overrides: Dictionary = _dictionary(profile.get("personality_overrides", {}))
	overrides[trait_id.to_lower().strip_edges()] = clampf(value, 0.0, 1.0)
	profile["personality_overrides"] = overrides
	_write_profile(species_id, profile)
	return {"ok": true, "profile": profile.duplicate(true)}


static func resolve_move(species_id: String, move_id: String) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	var move: MobMoveDefinition = MobMoveCatalog.get_definition(move_id)
	if profile.is_empty() or move == null:
		return {}
	var resolved: Dictionary = move.to_dictionary()
	var ranks: Dictionary = _dictionary(profile.get("move_ranks", {}))
	var rank: int = clampi(int(ranks.get(move_id, 1)), 1, MAX_MOVE_RANK)
	_apply_rank_scaling(resolved, rank)
	var all_augments: Dictionary = _dictionary(profile.get("move_augments", {}))
	var move_augments: Dictionary = _dictionary(all_augments.get(move_id, {}))
	var augment_ids: Array[String] = []
	for slot_id: String in move.augment_slots:
		var augment_id: String = str(move_augments.get(slot_id, ""))
		if augment_id != "":
			augment_ids.append(augment_id)
	resolved = MobMoveAugmentCatalog.apply_augments(resolved, augment_ids)
	resolved["species_id"] = species_id
	resolved["level"] = int(profile.get("level", 1))
	resolved["move_rank"] = rank
	resolved["equipped"] = _string_array(profile.get("equipped_moves", [])).has(move_id)
	return resolved


static func get_decision_context_profile(species_id: String, context: Dictionary) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	if profile.is_empty():
		return context.duplicate(true)
	var result: Dictionary = context.duplicate(true)
	result["level"] = int(profile.get("level", 1))
	result["allowed_move_ids"] = _string_array(profile.get("equipped_moves", []))
	return result


static func get_debug_data(species_id: String) -> Dictionary:
	var profile: Dictionary = get_profile(species_id)
	var resolved_moves: Array[Dictionary] = []
	for move_id: String in _string_array(profile.get("learned_moves", [])):
		resolved_moves.append(resolve_move(species_id, move_id))
	return {
		"species_id": species_id,
		"profile": profile,
		"resolved_moves": resolved_moves,
	}


static func _default_profile(species_id: String) -> Dictionary:
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	if species == null:
		return {}
	var familiar: Dictionary = species.familiar_profile.duplicate(true)
	var starting: Array[String] = _string_array(familiar.get("starting_moves", []))
	var equipped: Array[String] = _string_array(familiar.get("default_equipped_moves", starting))
	var ranks: Dictionary = {}
	for move_id: String in starting:
		ranks[move_id] = 1
	return {
		"version": PROFILE_VERSION,
		"species_id": species_id,
		"level": 1,
		"experience": 0,
		"learned_moves": starting,
		"equipped_moves": equipped.slice(0, _maximum_equipped(species_id)),
		"move_ranks": ranks,
		"move_augments": {},
		"personality_overrides": {},
	}


static func _sanitize_profile(species_id: String, value: Dictionary) -> Dictionary:
	var result: Dictionary = _default_profile(species_id)
	if result.is_empty():
		return result
	result["experience"] = maxi(int(value.get("experience", 0)), 0)
	result["level"] = _level_for_experience(species_id, int(result["experience"]))
	var learned: Array[String] = _string_array(value.get("learned_moves", result["learned_moves"]))
	for starting: String in _string_array(result["learned_moves"]):
		if not learned.has(starting):
			learned.append(starting)
	result["learned_moves"] = _filter_species_moves(species_id, learned)
	var ranks: Dictionary = {}
	var raw_ranks: Dictionary = _dictionary(value.get("move_ranks", {}))
	for move_id: String in result["learned_moves"] as Array[String]:
		ranks[move_id] = clampi(int(raw_ranks.get(move_id, 1)), 1, MAX_MOVE_RANK)
	result["move_ranks"] = ranks
	var equipped: Array[String] = []
	for move_id: String in _string_array(value.get("equipped_moves", result["equipped_moves"])):
		if (result["learned_moves"] as Array[String]).has(move_id) and not equipped.has(move_id):
			equipped.append(move_id)
		if equipped.size() >= _maximum_equipped(species_id):
			break
	if equipped.is_empty() and not (result["learned_moves"] as Array[String]).is_empty():
		equipped.append((result["learned_moves"] as Array[String])[0])
	result["equipped_moves"] = equipped
	var cleaned_augments: Dictionary = {}
	var raw_augments: Dictionary = _dictionary(value.get("move_augments", {}))
	for move_id: String in result["learned_moves"] as Array[String]:
		var move: MobMoveDefinition = MobMoveCatalog.get_definition(move_id)
		if move == null:
			continue
		var raw_move_augments: Dictionary = _dictionary(raw_augments.get(move_id, {}))
		var move_augments: Dictionary = {}
		for slot_id: String in move.augment_slots:
			var augment_id: String = str(raw_move_augments.get(slot_id, ""))
			if augment_id != "" and MobMoveAugmentCatalog.is_compatible(move, augment_id):
				move_augments[slot_id] = augment_id
		if not move_augments.is_empty():
			cleaned_augments[move_id] = move_augments
	result["move_augments"] = cleaned_augments
	var personality: Dictionary = {}
	for raw_key: Variant in _dictionary(value.get("personality_overrides", {})).keys():
		personality[str(raw_key).to_lower().strip_edges()] = clampf(
			float((_dictionary(value.get("personality_overrides", {})))[raw_key]),
			0.0,
			1.0
		)
	result["personality_overrides"] = personality
	_learn_level_moves(species_id, result)
	return result


static func _learn_level_moves(species_id: String, profile: Dictionary) -> Array[String]:
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	if species == null:
		return []
	var learned: Array[String] = _string_array(profile.get("learned_moves", []))
	var newly_learned: Array[String] = []
	var unlocks: Dictionary = _dictionary(species.familiar_profile.get("move_unlock_levels", {}))
	for raw_move_id: Variant in unlocks.keys():
		var move_id: String = str(raw_move_id)
		if int(profile.get("level", 1)) >= maxi(int(unlocks[raw_move_id]), 1) and not learned.has(move_id):
			learned.append(move_id)
			newly_learned.append(move_id)
	profile["learned_moves"] = _filter_species_moves(species_id, learned)
	var ranks: Dictionary = _dictionary(profile.get("move_ranks", {}))
	for move_id: String in profile["learned_moves"] as Array[String]:
		ranks[move_id] = clampi(int(ranks.get(move_id, 1)), 1, MAX_MOVE_RANK)
	profile["move_ranks"] = ranks
	return newly_learned


static func _level_for_experience(species_id: String, experience: int) -> int:
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	if species == null:
		return 1
	var thresholds: Array = species.familiar_profile.get("level_thresholds", [0]) as Array
	var level: int = 1
	for index: int in range(1, thresholds.size()):
		if experience >= int(thresholds[index]):
			level = index + 1
	return level


static func _move_unlock_level(
	species: MobSpeciesDefinition,
	move_id: String,
	fallback: int
) -> int:
	var unlocks: Dictionary = _dictionary(species.familiar_profile.get("move_unlock_levels", {}))
	return maxi(int(unlocks.get(move_id, fallback)), 1)


static func _maximum_equipped(species_id: String) -> int:
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	return maxi(int(species.familiar_profile.get("max_equipped_moves", 4)), 1) if species != null else 4


static func _filter_species_moves(species_id: String, ids: Array[String]) -> Array[String]:
	var allowed: Array[String] = MobSpeciesCatalog.get_move_ids(species_id)
	var result: Array[String] = []
	for move_id: String in ids:
		if allowed.has(move_id) and not result.has(move_id):
			result.append(move_id)
	return result


static func _apply_rank_scaling(move: Dictionary, rank: int) -> void:
	var extra_ranks: int = maxi(rank - 1, 0)
	if extra_ranks <= 0:
		return
	var scaling: Dictionary = _dictionary(move.get("scaling", {}))
	var effect: Dictionary = _dictionary(move.get("effect", {}))
	if scaling.has("damage_per_rank"):
		effect["damage"] = int(round(float(effect.get("damage", 0)) + float(scaling["damage_per_rank"]) * extra_ranks))
	if scaling.has("stance_per_rank"):
		effect["stance_damage"] = int(round(float(effect.get("stance_damage", 0)) + float(scaling["stance_per_rank"]) * extra_ranks))
	if scaling.has("distance_per_rank"):
		effect["movement_distance"] = float(effect.get("movement_distance", 0.0)) + float(scaling["distance_per_rank"]) * extra_ranks
	if scaling.has("radius_per_rank"):
		effect["radius"] = float(effect.get("radius", 0.0)) + float(scaling["radius_per_rank"]) * extra_ranks
	if scaling.has("buildup_per_rank"):
		effect["buildup"] = int(round(float(effect.get("buildup", 0)) + float(scaling["buildup_per_rank"]) * extra_ranks))
	if scaling.has("status_duration_per_rank"):
		var statuses: Array = (effect.get("statuses", []) as Array).duplicate(true)
		for index: int in range(statuses.size()):
			if statuses[index] is Dictionary:
				var status: Dictionary = statuses[index] as Dictionary
				status["duration"] = float(status.get("duration", 0.0)) + float(scaling["status_duration_per_rank"]) * extra_ranks
				statuses[index] = status
		effect["statuses"] = statuses
	move["effect"] = effect


static func _write_profile(species_id: String, profile: Dictionary) -> void:
	GameState.story_flags[PROFILE_PREFIX + species_id] = profile.duplicate(true)


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).to_lower().strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
