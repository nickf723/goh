extends RefCounted
class_name MobMoveCatalog

const DEFINITIONS: Dictionary = {
	"idle": {
		"id": "idle",
		"display_name": "Idle",
		"description": "Wait, watch, or perform a species-specific ambient behavior.",
		"action_kind": "utility",
		"target_mode": "self",
		"tags": ["utility", "ambient", "calm"],
		"minimum_range": 0.0,
		"maximum_range": 999.0,
		"cooldown": 0.4,
		"base_utility": 0.35,
		"timing": {"startup": 0.05, "active": 0.55, "recovery": 0.1},
		"effect": {"kind": "wait", "duration": 0.8},
		"augment_slots": [],
	},
	"graze": {
		"id": "graze",
		"display_name": "Graze",
		"description": "Forage from nearby vegetation and recover a small amount of stamina or health.",
		"action_kind": "utility",
		"target_mode": "environment",
		"tags": ["utility", "forage", "calm", "recovery"],
		"required_body_tags": ["mouth"],
		"minimum_range": 0.0,
		"maximum_range": 1.4,
		"cooldown": 3.0,
		"base_utility": 0.8,
		"timing": {"startup": 0.2, "active": 1.25, "recovery": 0.35},
		"effect": {"kind": "recover", "health": 1, "stamina": 2},
		"augment_slots": ["instinct"],
	},
	"flee": {
		"id": "flee",
		"display_name": "Flee",
		"description": "Create distance from the greatest perceived threat.",
		"action_kind": "movement",
		"target_mode": "away_from_threat",
		"tags": ["movement", "retreat", "survival", "defense"],
		"minimum_range": 0.0,
		"maximum_range": 999.0,
		"cooldown": 0.45,
		"base_utility": 1.0,
		"timing": {"startup": 0.05, "active": 1.0, "recovery": 0.15},
		"effect": {"kind": "movement", "speed_multiplier": 1.35, "duration": 1.2},
		"augment_slots": ["instinct"],
	},
	"bite": {
		"id": "bite",
		"display_name": "Bite",
		"description": "A fast jaw strike whose importance depends entirely on the creature using it.",
		"action_kind": "attack",
		"target_mode": "enemy",
		"tags": ["attack", "melee", "contact", "jaw"],
		"required_body_tags": ["jaw"],
		"minimum_range": 0.0,
		"maximum_range": 1.8,
		"cooldown": 0.9,
		"base_utility": 1.0,
		"timing": {"startup": 0.16, "active": 0.14, "recovery": 0.35, "interruptible_phases": ["startup", "recovery"]},
		"effect": {
			"kind": "damage",
			"damage": 3,
			"stance_damage": 2,
			"element": "body",
			"hit_type": "bite",
			"statuses": [],
		},
		"scaling": {"damage_per_rank": 1.0, "stance_per_rank": 0.5},
		"augment_slots": ["primary", "secondary"],
	},
	"headbutt": {
		"id": "headbutt",
		"display_name": "Headbutt",
		"description": "Drive the skull or horns into a nearby threat with heavy stance damage.",
		"action_kind": "attack",
		"target_mode": "enemy",
		"tags": ["attack", "melee", "contact", "force", "charge"],
		"required_body_tags": ["head"],
		"minimum_range": 0.2,
		"maximum_range": 2.6,
		"cooldown": 2.0,
		"base_utility": 1.1,
		"timing": {"startup": 0.3, "active": 0.18, "recovery": 0.45, "interruptible_phases": ["startup", "recovery"]},
		"effect": {
			"kind": "damage",
			"damage": 4,
			"stance_damage": 5,
			"element": "body",
			"force": 7.0,
			"hit_type": "headbutt",
			"statuses": [],
		},
		"scaling": {"damage_per_rank": 1.0, "stance_per_rank": 1.0},
		"augment_slots": ["primary", "secondary"],
	},
	"pounce": {
		"id": "pounce",
		"display_name": "Pounce",
		"description": "Commit to a leaping gap-closer that converts movement into a strike.",
		"action_kind": "attack",
		"target_mode": "enemy",
		"tags": ["attack", "movement", "gap_closer", "lunge", "contact"],
		"required_body_tags": ["legs"],
		"required_locomotion_tags": ["jumper"],
		"minimum_range": 2.0,
		"maximum_range": 7.0,
		"cooldown": 3.2,
		"base_utility": 1.05,
		"timing": {"startup": 0.25, "active": 0.35, "recovery": 0.5, "interruptible_phases": ["startup", "recovery"]},
		"effect": {
			"kind": "damage",
			"damage": 4,
			"stance_damage": 3,
			"element": "body",
			"movement_distance": 5.5,
			"hit_type": "pounce",
			"statuses": [],
		},
		"scaling": {"damage_per_rank": 1.0, "distance_per_rank": 0.35},
		"augment_slots": ["primary", "secondary"],
	},
	"backstep": {
		"id": "backstep",
		"display_name": "Backstep",
		"description": "Quickly disengage from crowded close combat while keeping attention on the threat.",
		"action_kind": "movement",
		"target_mode": "away_from_threat",
		"tags": ["movement", "retreat", "evade", "defense"],
		"required_body_tags": ["legs"],
		"minimum_range": 0.0,
		"maximum_range": 4.0,
		"cooldown": 2.4,
		"base_utility": 0.9,
		"timing": {"startup": 0.06, "active": 0.28, "recovery": 0.2},
		"effect": {"kind": "movement", "distance": 2.8, "invulnerability": 0.08},
		"augment_slots": ["instinct"],
	},
	"howl": {
		"id": "howl",
		"display_name": "Pack Howl",
		"description": "Signal nearby allies, raise cohesion, or warn competitors away.",
		"action_kind": "support",
		"target_mode": "allies",
		"tags": ["support", "social", "call", "pack"],
		"required_body_tags": ["voice"],
		"minimum_range": 0.0,
		"maximum_range": 14.0,
		"cooldown": 8.0,
		"base_utility": 0.85,
		"timing": {"startup": 0.35, "active": 0.5, "recovery": 0.45},
		"effect": {"kind": "buff", "status": "pack_focus", "duration": 5.0, "radius": 10.0},
		"augment_slots": ["instinct"],
	},
	"mire_spit": {
		"id": "mire_spit",
		"display_name": "Mire Spit",
		"description": "Launch a wetting glob that prepares targets for elemental follow-ups.",
		"action_kind": "attack",
		"target_mode": "enemy",
		"tags": ["attack", "projectile", "ranged", "primer", "water"],
		"required_body_tags": ["mouth"],
		"minimum_range": 3.0,
		"maximum_range": 10.0,
		"cooldown": 4.5,
		"base_utility": 1.0,
		"timing": {"startup": 0.28, "active": 0.12, "recovery": 0.38},
		"effect": {
			"kind": "projectile",
			"damage": 1,
			"stance_damage": 1,
			"element": "water",
			"speed": 12.0,
			"statuses": [{"id": "wet", "duration": 6.0}],
		},
		"scaling": {"damage_per_rank": 0.5, "status_duration_per_rank": 0.5},
		"augment_slots": ["primary", "secondary"],
	},
	"wade": {
		"id": "wade",
		"display_name": "Wade",
		"description": "Enter shallow water to cool down, forage, hide, or reposition through a preferred habitat.",
		"action_kind": "movement",
		"target_mode": "environment",
		"tags": ["movement", "water", "habitat", "calm"],
		"required_body_tags": ["swimmer"],
		"required_locomotion_tags": ["swimmer"],
		"minimum_range": 0.0,
		"maximum_range": 12.0,
		"cooldown": 1.0,
		"base_utility": 0.85,
		"timing": {"startup": 0.05, "active": 1.6, "recovery": 0.25},
		"effect": {"kind": "move_to_tag", "target_tag": "water", "speed_multiplier": 1.0},
		"augment_slots": ["instinct"],
	},
	"stone_gaze": {
		"id": "stone_gaze",
		"display_name": "Stone Gaze",
		"description": "Focus a supernatural gaze that builds petrification on a visible target.",
		"action_kind": "attack",
		"target_mode": "enemy",
		"tags": ["attack", "ranged", "gaze", "control", "petrify"],
		"required_body_tags": ["gaze"],
		"minimum_range": 3.0,
		"maximum_range": 12.0,
		"cooldown": 7.0,
		"base_utility": 1.45,
		"timing": {"startup": 0.45, "active": 1.1, "recovery": 0.55},
		"effect": {
			"kind": "status",
			"status": "petrifying",
			"duration": 3.0,
			"buildup": 40,
			"requires_line_of_sight": true,
		},
		"scaling": {"buildup_per_rank": 8.0},
		"augment_slots": ["primary", "secondary"],
	},
	"tail_sweep": {
		"id": "tail_sweep",
		"display_name": "Tail Sweep",
		"description": "Sweep a powerful tail through nearby opponents.",
		"action_kind": "attack",
		"target_mode": "area",
		"tags": ["attack", "melee", "area", "force", "tail"],
		"required_body_tags": ["tail"],
		"minimum_range": 0.0,
		"maximum_range": 3.2,
		"cooldown": 3.8,
		"base_utility": 1.2,
		"timing": {"startup": 0.32, "active": 0.25, "recovery": 0.48, "interruptible_phases": ["startup", "recovery"]},
		"effect": {
			"kind": "area_damage",
			"damage": 5,
			"stance_damage": 4,
			"element": "body",
			"force": 8.0,
			"radius": 3.0,
			"statuses": [],
		},
		"scaling": {"damage_per_rank": 1.0, "radius_per_rank": 0.15},
		"augment_slots": ["primary", "secondary"],
	},
}


static func has_move(move_id: String) -> bool:
	return DEFINITIONS.has(move_id)


static func get_definition(move_id: String) -> MobMoveDefinition:
	var value: Variant = DEFINITIONS.get(move_id)
	if not value is Dictionary:
		return null
	return MobMoveDefinition.from_dictionary(value as Dictionary)


static func get_move_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw: Variant in DEFINITIONS.keys():
		ids.append(str(raw))
	ids.sort()
	return ids


static func get_definitions() -> Array[MobMoveDefinition]:
	var rows: Array[MobMoveDefinition] = []
	for move_id: String in get_move_ids():
		var definition: MobMoveDefinition = get_definition(move_id)
		if definition != null:
			rows.append(definition)
	return rows


static func get_moves_with_tag(tag: String) -> Array[MobMoveDefinition]:
	var result: Array[MobMoveDefinition] = []
	for definition: MobMoveDefinition in get_definitions():
		if definition.has_tag(tag):
			result.append(definition)
	return result


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	for move_id: String in get_move_ids():
		var definition: MobMoveDefinition = get_definition(move_id)
		if definition == null:
			failures.append("missing move definition: " + move_id)
			continue
		for failure: String in definition.validate():
			failures.append(failure)
	return failures


static func get_debug_data() -> Dictionary:
	var rows: Array[Dictionary] = []
	for definition: MobMoveDefinition in get_definitions():
		rows.append(definition.to_dictionary())
	return {
		"move_count": rows.size(),
		"moves": rows,
		"failures": validate_catalog(),
	}
