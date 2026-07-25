extends RefCounted

const CONTEXT_DASH: String = "dash"
const DASH_REQUIRED_RANK: int = 1

const DASH_DEFINITIONS: Dictionary = {
	"sword": {"name": "Passing Cut", "damage": 1.16, "stance": 1.0, "range": 0.2, "move": 0.9, "tag": "passing_cut"},
	"lance": {"name": "Driving Thrust", "damage": 1.12, "stance": 1.12, "range": 0.65, "move": 1.15, "tag": "driving_thrust"},
	"axe": {"name": "Rushing Cleave", "damage": 1.12, "stance": 1.28, "range": 0.25, "move": 0.82, "tag": "rushing_cleave"},
	"bow": {"name": "Skirmish Shot", "damage": 1.1, "stance": 1.0, "range": 0.5, "move": 0.75, "tag": "skirmish_shot"},
	"hammer": {"name": "Meteor Rush", "damage": 1.08, "stance": 1.48, "range": 0.18, "move": 0.78, "tag": "meteor_rush"},
	"mace": {"name": "Shoulder Break", "damage": 1.1, "stance": 1.38, "range": 0.2, "move": 0.82, "tag": "shoulder_break"},
	"daggers": {"name": "Blinking Fang", "damage": 1.22, "stance": 0.9, "range": 0.18, "move": 1.12, "tag": "blinking_fang"},
	"whip": {"name": "Pursuit Crack", "damage": 1.08, "stance": 1.15, "range": 0.7, "move": 0.72, "tag": "pursuit_crack"},
	"chains": {"name": "Comet Chain", "damage": 1.12, "stance": 1.3, "range": 0.45, "move": 0.84, "tag": "comet_chain"},
	"gauntlets": {"name": "Burst Knuckle", "damage": 1.18, "stance": 1.22, "range": 0.12, "move": 1.0, "tag": "burst_knuckle"},
	"flail": {"name": "Orbit Crash", "damage": 1.14, "stance": 1.3, "range": 0.35, "move": 0.84, "tag": "orbit_crash"},
	"halberd": {"name": "Charging Reap", "damage": 1.12, "stance": 1.24, "range": 0.55, "move": 0.94, "tag": "charging_reap"},
	"boomerang": {"name": "Slipstream Cast", "damage": 1.12, "stance": 1.0, "range": 0.48, "move": 0.88, "tag": "slipstream_cast"},
	"scythe": {"name": "Death's Passage", "damage": 1.16, "stance": 1.18, "range": 0.48, "move": 0.9, "tag": "deaths_passage"},
	"staff": {"name": "Vaulting Sweep", "damage": 1.08, "stance": 1.3, "range": 0.35, "move": 0.95, "tag": "vaulting_sweep"},
	"shuriken": {"name": "Running Volley", "damage": 1.18, "stance": 0.9, "range": 0.42, "move": 1.0, "tag": "running_volley"},
}


static func is_context_unlocked(weapon_class: String, context_id: String, mastery_rank: int) -> bool:
	if context_id == CONTEXT_DASH:
		return DASH_DEFINITIONS.has(weapon_class) and mastery_rank >= DASH_REQUIRED_RANK
	return false


static func get_dash_definition(weapon_class: String) -> Dictionary:
	if not DASH_DEFINITIONS.has(weapon_class):
		return {}
	return (DASH_DEFINITIONS[weapon_class] as Dictionary).duplicate(true)


static func get_dash_technique_name(weapon_class: String) -> String:
	return str(get_dash_definition(weapon_class).get("name", "Dash Strike"))


static func build_dash_attack(
	base_attack: WeaponAttackDefinition,
	weapon_class: String
) -> WeaponAttackDefinition:
	if base_attack == null:
		return null
	var definition: Dictionary = get_dash_definition(weapon_class)
	if definition.is_empty():
		return null
	var attack: WeaponAttackDefinition = base_attack.duplicate(true) as WeaponAttackDefinition
	if attack == null:
		return null
	attack.attack_id = "technique_dash_" + weapon_class + "_" + base_attack.input_kind
	attack.display_name = str(definition.get("name", "Dash Strike"))
	attack.startup_time = maxf(base_attack.startup_time * 0.68, 0.055)
	attack.recovery_time = maxf(base_attack.recovery_time * 0.82, 0.08)
	attack.damage_multiplier *= float(definition.get("damage", 1.0))
	attack.stance_multiplier *= float(definition.get("stance", 1.0))
	attack.attack_range += float(definition.get("range", 0.0))
	attack.movement_distance = maxf(
		base_attack.movement_distance,
		float(definition.get("move", 0.8))
	)
	attack.movement_duration = maxf(minf(base_attack.movement_duration, 0.14), 0.08)
	attack.cancel_window_start_normalized = minf(base_attack.cancel_window_start_normalized, 0.58)
	attack.extra_tags = base_attack.extra_tags.duplicate()
	append_tag(attack.extra_tags, "technique")
	append_tag(attack.extra_tags, "context_dash")
	append_tag(attack.extra_tags, str(definition.get("tag", "dash_strike")))
	return attack


static func append_tag(tags: Array[String], tag: String) -> void:
	if tag != "" and not tags.has(tag):
		tags.append(tag)
