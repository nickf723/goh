extends RefCounted
class_name MobDriveState

const DRIVE_IDS: Array[String] = [
	"hunger",
	"fatigue",
	"fear",
	"social_need",
	"curiosity",
	"territorial_pressure",
]
const DEFAULT_VALUES: Dictionary = {
	"hunger": 0.2,
	"fatigue": 0.12,
	"fear": 0.0,
	"social_need": 0.12,
	"curiosity": 0.3,
	"territorial_pressure": 0.0,
}
const THREAT_TAGS: Array[String] = [
	"threatened",
	"predator_near",
	"attacked",
	"hostile",
	"cornered",
	"overwhelmed",
]
const TERRITORY_TAGS: Array[String] = [
	"intruder",
	"territory_breached",
	"protecting_pack",
	"protecting_young",
	"nest_threatened",
]

var species_id: String = ""
var values: Dictionary = {}
var personality: Dictionary = {}


static func create_for_species(
	new_species_id: String,
	personality_values: Dictionary = {},
	drive_overrides: Dictionary = {}
) -> MobDriveState:
	var state := MobDriveState.new()
	state.reset(new_species_id, personality_values, drive_overrides)
	return state


func reset(
	new_species_id: String,
	personality_values: Dictionary = {},
	drive_overrides: Dictionary = {}
) -> void:
	species_id = new_species_id.to_lower().strip_edges()
	personality = _normalized_number_dictionary(personality_values)
	values = DEFAULT_VALUES.duplicate(true)
	values["curiosity"] = clampf(
		0.18 + get_trait("curiosity", 0.5) * 0.32,
		0.0,
		1.0
	)
	values["social_need"] = clampf(
		0.06 + get_trait("sociability", 0.5) * 0.12,
		0.0,
		1.0
	)
	values["fear"] = clampf(
		(0.5 - get_trait("courage", 0.5)) * 0.12,
		0.0,
		0.12
	)
	apply_overrides(drive_overrides)


func tick(
	delta: float,
	context_value: Variant,
	personality_overrides: Dictionary = {}
) -> void:
	if delta <= 0.0:
		return
	if not personality_overrides.is_empty():
		for raw_key: Variant in personality_overrides.keys():
			personality[str(raw_key).to_lower().strip_edges()] = clampf(
				float(personality_overrides[raw_key]),
				0.0,
				1.0
			)
	var context: MobDecisionContext = _context_from_variant(context_value)
	set_drive("hunger", get_drive("hunger") + delta * 0.004)
	set_drive("fatigue", get_drive("fatigue") + delta * 0.0025)

	var courage: float = get_trait("courage", 0.5)
	var threatened: bool = _has_any_context_tag(context, THREAT_TAGS)
	if threatened:
		var target_fear: float = 0.52 + (1.0 - courage) * 0.32
		if context.has_context_tag("attacked"):
			target_fear += 0.1
		if context.has_context_tag("cornered"):
			target_fear += 0.18
		set_drive(
			"fear",
			move_toward(
				get_drive("fear"),
				clampf(target_fear, 0.0, 1.0),
				delta * (0.3 + (1.0 - courage) * 0.25)
			)
		)
	else:
		set_drive(
			"fear",
			move_toward(
				get_drive("fear"),
				0.0,
				delta * (0.035 + courage * 0.045)
			)
		)

	var sociability: float = get_trait("sociability", 0.5)
	if context.ally_count <= 0:
		set_drive(
			"social_need",
			get_drive("social_need") + delta * 0.004 * (0.4 + sociability)
		)
	else:
		set_drive(
			"social_need",
			get_drive("social_need") - delta * 0.025 * (0.5 + sociability)
		)

	var curiosity_trait: float = get_trait("curiosity", 0.5)
	if context.has_context_tag("safe") and not threatened:
		set_drive(
			"curiosity",
			get_drive("curiosity") + delta * 0.003 * (0.4 + curiosity_trait)
		)
	else:
		set_drive(
			"curiosity",
			get_drive("curiosity") - delta * 0.012
		)

	var territoriality: float = get_trait("territoriality", 0.5)
	if _has_any_context_tag(context, TERRITORY_TAGS):
		set_drive(
			"territorial_pressure",
			move_toward(
				get_drive("territorial_pressure"),
				clampf(0.5 + territoriality * 0.45, 0.0, 1.0),
				delta * (0.25 + territoriality * 0.2)
			)
		)
	else:
		set_drive(
			"territorial_pressure",
			move_toward(
				get_drive("territorial_pressure"),
				0.0,
				delta * 0.04
			)
		)


func observe_context(
	context_value: Variant,
	personality_overrides: Dictionary = {}
) -> void:
	if not personality_overrides.is_empty():
		for raw_key: Variant in personality_overrides.keys():
			personality[str(raw_key).to_lower().strip_edges()] = clampf(
				float(personality_overrides[raw_key]),
				0.0,
				1.0
			)
	var context: MobDecisionContext = _context_from_variant(context_value)
	if context.has_context_tag("hungry"):
		set_drive("hunger", maxf(get_drive("hunger"), 0.62))
	if context.has_context_tag("starving"):
		set_drive("hunger", maxf(get_drive("hunger"), 0.9))
	if context.has_context_tag("tired"):
		set_drive("fatigue", maxf(get_drive("fatigue"), 0.65))
	if context.has_context_tag("exhausted"):
		set_drive("fatigue", maxf(get_drive("fatigue"), 0.9))
	if _has_any_context_tag(context, THREAT_TAGS):
		var fear_floor: float = 0.5 + (1.0 - get_trait("courage", 0.5)) * 0.28
		if context.has_context_tag("attacked"):
			fear_floor += 0.1
		if context.has_context_tag("cornered"):
			fear_floor += 0.2
		set_drive("fear", maxf(get_drive("fear"), clampf(fear_floor, 0.0, 1.0)))
	if _has_any_context_tag(context, TERRITORY_TAGS):
		var territory_floor: float = 0.45 + get_trait("territoriality", 0.5) * 0.45
		set_drive(
			"territorial_pressure",
			maxf(get_drive("territorial_pressure"), territory_floor)
		)


func build_context(context_value: Variant) -> Dictionary:
	var context: Dictionary = _dictionary_from_variant(context_value)
	var context_tags: Array[String] = _string_array(context.get("context_tags", []))
	var scalar_values: Dictionary = _normalized_number_dictionary(
		context.get("scalar_values", {}) as Dictionary
		if context.get("scalar_values", {}) is Dictionary
		else {}
	)
	var tag_modifiers: Dictionary = _normalized_number_dictionary(
		context.get("tag_score_modifiers", {}) as Dictionary
		if context.get("tag_score_modifiers", {}) is Dictionary
		else {}
	)
	var policy_tag_modifiers: Dictionary = _normalized_number_dictionary(
		context.get("policy_tag_score_modifiers", {}) as Dictionary
		if context.get("policy_tag_score_modifiers", {}) is Dictionary
		else {}
	)

	for drive_id: String in DRIVE_IDS:
		scalar_values[drive_id] = get_drive(drive_id)

	var hunger: float = get_drive("hunger")
	var fatigue: float = get_drive("fatigue")
	var fear: float = get_drive("fear")
	var social_need: float = get_drive("social_need")
	var curiosity_value: float = get_drive("curiosity")
	var territory: float = get_drive("territorial_pressure")

	if hunger >= 0.5:
		_add_tag(context_tags, "hungry")
	if hunger >= 0.85:
		_add_tag(context_tags, "starving")
	if fatigue >= 0.62:
		_add_tag(context_tags, "tired")
	if fatigue >= 0.88:
		_add_tag(context_tags, "exhausted")
	if fear >= 0.5:
		_add_tag(context_tags, "frightened")
	if fear >= 0.6:
		_add_tag(context_tags, "threatened")
	if fear >= 0.84:
		_add_tag(context_tags, "panicked")
	if social_need >= 0.6:
		_add_tag(context_tags, "lonely")
		if _species_has_ecology_tag("pack"):
			_add_tag(context_tags, "pack_scattered")
	if curiosity_value >= 0.65:
		_add_tag(context_tags, "curious")
	if territory >= 0.55:
		_add_tag(context_tags, "defending_territory")
	if territory >= 0.72:
		_add_tag(context_tags, "hostile")

	_add_number(tag_modifiers, "forage", hunger * 1.0)
	_add_number(tag_modifiers, "recovery", hunger * 0.15 + fatigue * 0.35)
	_add_number(tag_modifiers, "calm", fatigue * 0.55 + fear * 0.08)
	_add_number(tag_modifiers, "attack", -fatigue * 0.35 - fear * 0.25 + territory * 0.35)
	_add_number(tag_modifiers, "movement", -fatigue * 0.1 + curiosity_value * 0.12)
	_add_number(tag_modifiers, "retreat", fear * 0.55 - territory * 0.25)
	_add_number(tag_modifiers, "survival", fear * 0.45)
	_add_number(tag_modifiers, "defense", fear * 0.2 + territory * 0.25)
	_add_number(tag_modifiers, "social", social_need * 0.45)
	_add_number(tag_modifiers, "support", social_need * 0.3)
	_add_number(tag_modifiers, "pack", social_need * 0.25)
	_add_number(tag_modifiers, "habitat", curiosity_value * 0.32)
	_add_number(tag_modifiers, "ambient", curiosity_value * 0.18)
	_add_number(tag_modifiers, "control", territory * 0.25)

	_add_number(policy_tag_modifiers, "desperation_attack", maxf(fear - 0.65, 0.0) * 0.5)
	_add_number(policy_tag_modifiers, "conditional_defense", fear * 0.25)
	_add_number(policy_tag_modifiers, "pack_support", social_need * 0.3)
	_add_number(policy_tag_modifiers, "survival", fear * 0.3)

	var urgency: float = maxf(float(scalar_values.get("urgency", 0.0)), fear * 0.85)
	if hunger > 0.8:
		urgency = maxf(urgency, (hunger - 0.8) * 0.75)
	if fatigue > 0.88:
		urgency = maxf(urgency, (fatigue - 0.88) * 0.9)
	scalar_values["urgency"] = urgency

	context["context_tags"] = context_tags
	context["scalar_values"] = scalar_values
	context["tag_score_modifiers"] = tag_modifiers
	context["policy_tag_score_modifiers"] = policy_tag_modifiers
	return context


func satisfy_move(move_data: Dictionary) -> void:
	var tags: Array[String] = _string_array(move_data.get("tags", []))
	if tags.has("forage"):
		add_drive("hunger", -0.55)
	if tags.has("recovery"):
		add_drive("hunger", -0.08)
		add_drive("fatigue", -0.18)
	if tags.has("calm"):
		add_drive("fatigue", -0.16)
		add_drive("fear", -0.1)
	if tags.has("retreat") or tags.has("survival"):
		add_drive("fear", -0.06)
	if tags.has("social") or tags.has("support") or tags.has("pack"):
		add_drive("social_need", -0.45)
	if tags.has("habitat"):
		add_drive("curiosity", -0.32)
	if tags.has("attack") or tags.has("defense") or tags.has("control"):
		add_drive("territorial_pressure", -0.08)
	if str(move_data.get("action_kind", "")) == "utility":
		add_drive("fatigue", -0.04)


func set_drive(drive_id: String, value: float) -> void:
	var normalized_id: String = drive_id.to_lower().strip_edges()
	if not DRIVE_IDS.has(normalized_id):
		return
	values[normalized_id] = clampf(value, 0.0, 1.0)


func add_drive(drive_id: String, delta: float) -> void:
	set_drive(drive_id, get_drive(drive_id) + delta)


func get_drive(drive_id: String, fallback: float = 0.0) -> float:
	return clampf(
		float(values.get(drive_id.to_lower().strip_edges(), fallback)),
		0.0,
		1.0
	)


func get_trait(trait_id: String, fallback: float = 0.5) -> float:
	return clampf(
		float(personality.get(trait_id.to_lower().strip_edges(), fallback)),
		0.0,
		1.0
	)


func apply_overrides(overrides: Dictionary) -> void:
	for raw_key: Variant in overrides.keys():
		set_drive(str(raw_key), float(overrides[raw_key]))


func to_dictionary() -> Dictionary:
	return {
		"species_id": species_id,
		"values": values.duplicate(true),
		"personality": personality.duplicate(true),
	}


func _species_has_ecology_tag(tag: String) -> bool:
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	return species != null and species.ecology_tags.has(tag.to_lower().strip_edges())


static func _context_from_variant(value: Variant) -> MobDecisionContext:
	if value is MobDecisionContext:
		return value as MobDecisionContext
	if value is Dictionary:
		return MobDecisionContext.from_dictionary(value as Dictionary)
	return MobDecisionContext.from_dictionary({})


static func _dictionary_from_variant(value: Variant) -> Dictionary:
	if value is MobDecisionContext:
		return (value as MobDecisionContext).to_dictionary()
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _has_any_context_tag(
	context: MobDecisionContext,
	tags: Array[String]
) -> bool:
	for tag: String in tags:
		if context.has_context_tag(tag):
			return true
	return false


static func _add_tag(tags: Array[String], tag: String) -> void:
	var normalized_tag: String = tag.to_lower().strip_edges()
	if normalized_tag != "" and not tags.has(normalized_tag):
		tags.append(normalized_tag)


static func _add_number(target: Dictionary, key: String, amount: float) -> void:
	if is_zero_approx(amount):
		return
	var normalized_key: String = key.to_lower().strip_edges()
	target[normalized_key] = float(target.get(normalized_key, 0.0)) + amount


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).to_lower().strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _normalized_number_dictionary(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key: Variant in value.keys():
		result[str(raw_key).to_lower().strip_edges()] = float(value[raw_key])
	return result
