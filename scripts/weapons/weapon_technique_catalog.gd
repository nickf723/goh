extends RefCounted

const CONTEXT_DASH: String = "dash"
const CONTEXT_DASH_LIGHT: String = "dash_light"
const CONTEXT_DASH_HEAVY: String = "dash_heavy"
const DASH_REQUIRED_RANK: int = 1

const CONTEXT_AERIAL_LIGHT: String = "aerial_light"
const CONTEXT_AERIAL_HEAVY: String = "aerial_heavy"
# Legacy context ids remain supported for old tests/content, but live player
# input now resolves to the explicit Light / Heavy aerial grammar above.
const CONTEXT_AERIAL_NEUTRAL: String = "aerial_neutral"
const CONTEXT_AERIAL_FORWARD: String = "aerial_forward"
const CONTEXT_AERIAL_DOWN: String = "aerial_down"
const AERIAL_REQUIRED_RANK: int = 1

const AERIAL_NAMES: Dictionary = {
	"sword": ["Orbit Cut", "Comet Slash", "Falling Edge"],
	"lance": ["Needle Wheel", "Skyline Thrust", "Dragon Drop"],
	"axe": ["Cleaving Halo", "Sky Hew", "Timberfall"],
	"bow": ["Cyclone Volley", "Gale Shot", "Raptor Dive"],
	"hammer": ["Bell Orbit", "Thunder Tackle", "Meteor Drop"],
	"mace": ["Dazing Halo", "Ramfall Swing", "Falling Star"],
	"daggers": ["Razor Bloom", "Flying Fang", "Pinning Dive"],
	"whip": ["Ribbon Cyclone", "Sky Crack", "Lashing Descent"],
	"chains": ["Iron Orbit", "Comet Cast", "Anchorfall"],
	"gauntlets": ["Cyclone Guard", "Flying Knuckle", "Meteor Fist"],
	"flail": ["Moon Orbit", "Chasing Star", "Deadweight Drop"],
	"halberd": ["Reaping Wheel", "Skyline Reap", "Guillotine Drop"],
	"boomerang": ["Halo Cast", "Tailwind Cast", "Swooping Return"],
	"scythe": ["Pale Moon", "Sky Harvest", "Gravefall"],
	"staff": ["Spinning Ward", "Cloud Vault", "Falling Pillar"],
	"shuriken": ["Star Halo", "Aerial Volley", "Kunai Rain"],
}

const DASH_DEFINITIONS: Dictionary = {
	"sword": {"name": "Passing Cut", "heavy_name": "Rush Break", "damage": 1.16, "stance": 1.0, "range": 0.2, "move": 0.9, "tag": "passing_cut"},
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


static func is_dash_context(context_id: String) -> bool:
	return context_id in [CONTEXT_DASH, CONTEXT_DASH_LIGHT, CONTEXT_DASH_HEAVY]


static func is_aerial_context(context_id: String) -> bool:
	return context_id in [
		CONTEXT_AERIAL_LIGHT,
		CONTEXT_AERIAL_HEAVY,
		CONTEXT_AERIAL_NEUTRAL,
		CONTEXT_AERIAL_FORWARD,
		CONTEXT_AERIAL_DOWN,
	]


static func is_context_unlocked(weapon_class: String, context_id: String, mastery_rank: int) -> bool:
	if is_dash_context(context_id):
		return DASH_DEFINITIONS.has(weapon_class) and mastery_rank >= DASH_REQUIRED_RANK
	if is_aerial_context(context_id):
		return AERIAL_NAMES.has(weapon_class) and mastery_rank >= AERIAL_REQUIRED_RANK
	return false


static func get_dash_definition(weapon_class: String) -> Dictionary:
	if not DASH_DEFINITIONS.has(weapon_class):
		return {}
	return (DASH_DEFINITIONS[weapon_class] as Dictionary).duplicate(true)


static func get_dash_context(input_kind: String) -> String:
	return CONTEXT_DASH_HEAVY if input_kind == "heavy" else CONTEXT_DASH_LIGHT


static func get_dash_technique_name(weapon_class: String, input_kind: String = "light") -> String:
	var definition: Dictionary = get_dash_definition(weapon_class)
	if input_kind == "heavy":
		return str(definition.get("heavy_name", "Dash Heavy"))
	return str(definition.get("name", "Dash Light"))


static func build_dash_attack(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	context_id: String = ""
) -> WeaponAttackDefinition:
	if base_attack == null:
		return null
	var definition: Dictionary = get_dash_definition(weapon_class)
	if definition.is_empty():
		return null
	var resolved_context: String = context_id
	if resolved_context == "" or resolved_context == CONTEXT_DASH:
		resolved_context = get_dash_context(base_attack.input_kind)
	var attack: WeaponAttackDefinition = base_attack.duplicate(true) as WeaponAttackDefinition
	if attack == null:
		return null
	var heavy: bool = resolved_context == CONTEXT_DASH_HEAVY or base_attack.input_kind == "heavy"
	attack.attack_id = "technique_" + resolved_context + "_" + weapon_class
	attack.display_name = get_dash_technique_name(weapon_class, "heavy" if heavy else "light")
	attack.extra_tags = base_attack.extra_tags.duplicate()
	append_tag(attack.extra_tags, "technique")
	append_tag(attack.extra_tags, "context_dash")
	append_tag(attack.extra_tags, resolved_context)
	append_tag(attack.extra_tags, str(definition.get("tag", "dash_strike")))

	if heavy:
		attack.startup_time = maxf(base_attack.startup_time * 0.78, 0.075)
		attack.recovery_time = maxf(base_attack.recovery_time * 0.9, 0.11)
		attack.damage_multiplier *= float(definition.get("damage", 1.0)) * 1.16
		attack.stance_multiplier *= float(definition.get("stance", 1.0)) * 1.25
		attack.knockback_multiplier *= 1.18
		attack.attack_range += float(definition.get("range", 0.0)) + 0.08
		attack.movement_distance = maxf(
			base_attack.movement_distance,
			float(definition.get("move", 0.8)) * 0.9
		)
		attack.movement_duration = 0.13
		attack.cancel_window_start_normalized = minf(base_attack.cancel_window_start_normalized, 0.66)
		attack.hit_stop_duration = maxf(base_attack.hit_stop_duration, 0.075)
	else:
		attack.startup_time = maxf(base_attack.startup_time * 0.62, 0.05)
		attack.recovery_time = maxf(base_attack.recovery_time * 0.74, 0.075)
		attack.damage_multiplier *= float(definition.get("damage", 1.0))
		attack.stance_multiplier *= float(definition.get("stance", 1.0))
		attack.attack_range += float(definition.get("range", 0.0))
		attack.movement_distance = maxf(
			base_attack.movement_distance,
			float(definition.get("move", 0.8))
		)
		attack.movement_duration = 0.105
		attack.cancel_window_start_normalized = minf(base_attack.cancel_window_start_normalized, 0.5)

	if weapon_class == "sword":
		if heavy:
			attack.character_pose_id = "sword_dash_heavy"
			attack.footwork_profile_id = "sword_dash_heavy"
			attack.windup_rotation_degrees = Vector3(18.0, -30.0, -8.0)
			attack.strike_rotation_degrees = Vector3(-28.0, 42.0, 8.0)
			attack.cone_angle_degrees = 82.0
		else:
			attack.character_pose_id = "sword_dash_light"
			attack.footwork_profile_id = "sword_dash_light"
			attack.windup_rotation_degrees = Vector3(4.0, -34.0, -3.0)
			attack.strike_rotation_degrees = Vector3(-4.0, 42.0, 2.0)
			attack.cone_angle_degrees = 72.0
	return attack


static func get_aerial_context(input_kind: String, _movement_amount: float = 0.0) -> String:
	return CONTEXT_AERIAL_HEAVY if input_kind == "heavy" else CONTEXT_AERIAL_LIGHT


static func get_aerial_technique_name(weapon_class: String, context_id: String) -> String:
	if not AERIAL_NAMES.has(weapon_class):
		return "Aerial Heavy" if context_id in [CONTEXT_AERIAL_HEAVY, CONTEXT_AERIAL_DOWN] else "Aerial Light"
	var names: Array = AERIAL_NAMES[weapon_class] as Array
	var index: int = 0
	if context_id in [CONTEXT_AERIAL_LIGHT, CONTEXT_AERIAL_FORWARD]:
		index = 1
	elif context_id in [CONTEXT_AERIAL_HEAVY, CONTEXT_AERIAL_DOWN]:
		index = 2
	return str(names[index]) if index < names.size() else "Aerial Strike"


static func build_aerial_attack(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	context_id: String
) -> WeaponAttackDefinition:
	if base_attack == null or not AERIAL_NAMES.has(weapon_class):
		return null
	var attack: WeaponAttackDefinition = base_attack.duplicate(true) as WeaponAttackDefinition
	if attack == null:
		return null
	var resolved_context: String = context_id
	if resolved_context == "":
		resolved_context = get_aerial_context(base_attack.input_kind)
	attack.attack_id = "technique_" + resolved_context + "_" + weapon_class
	attack.display_name = get_aerial_technique_name(weapon_class, resolved_context)
	attack.extra_tags = base_attack.extra_tags.duplicate()
	append_tag(attack.extra_tags, "technique")
	append_tag(attack.extra_tags, "context_aerial")
	append_tag(attack.extra_tags, resolved_context)

	match resolved_context:
		CONTEXT_AERIAL_LIGHT:
			attack.startup_time = maxf(base_attack.startup_time * 0.66, 0.055)
			attack.recovery_time = maxf(base_attack.recovery_time * 0.78, 0.085)
			attack.damage_multiplier *= 1.04
			attack.attack_range += 0.3
			attack.cone_angle_degrees = maxf(base_attack.cone_angle_degrees, 92.0)
			attack.movement_distance = maxf(base_attack.movement_distance, 0.46)
			attack.movement_duration = 0.12
			attack.cancel_window_start_normalized = minf(base_attack.cancel_window_start_normalized, 0.56)
			attack.windup_offset += Vector3(0.0, 0.06, 0.08)
			attack.strike_offset += Vector3(0.0, 0.0, -0.28)
			append_tag(attack.extra_tags, "aerial_light")
		CONTEXT_AERIAL_HEAVY:
			attack.startup_time = maxf(base_attack.startup_time * 0.78, 0.08)
			attack.recovery_time = maxf(base_attack.recovery_time * 0.94, 0.12)
			attack.damage_multiplier *= 1.18
			attack.stance_multiplier *= 1.35
			attack.knockback_multiplier *= 1.22
			attack.attack_range += 0.2
			attack.cone_angle_degrees = maxf(base_attack.cone_angle_degrees, 112.0)
			attack.movement_distance = 0.08
			attack.strike_offset += Vector3(0.0, -0.34, -0.1)
			attack.recovery_offset += Vector3(0.0, -0.12, 0.0)
			attack.hit_stop_duration = maxf(base_attack.hit_stop_duration, 0.08)
			append_tag(attack.extra_tags, "aerial_heavy")
			append_tag(attack.extra_tags, "plunging")
		# Legacy variants remain available to authored content that still asks for
		# neutral / forward / down explicitly.
		CONTEXT_AERIAL_NEUTRAL:
			attack.startup_time = maxf(base_attack.startup_time * 0.72, 0.06)
			attack.recovery_time = maxf(base_attack.recovery_time * 0.86, 0.09)
			attack.cone_angle_degrees = 360.0
			attack.attack_center_forward_offset = 0.15
			attack.max_targets += 1
			attack.damage_multiplier *= 0.92
			attack.stance_multiplier *= 0.9
			attack.movement_distance = 0.0
			attack.trail_start_scale = Vector3(0.75, 0.75, 0.75)
			attack.trail_end_scale = Vector3(1.25, 1.25, 1.25)
			attack.windup_rotation_degrees = Vector3(0.0, -145.0, 0.0)
			attack.strike_rotation_degrees = Vector3(0.0, 215.0, 0.0)
			attack.recovery_rotation_degrees = Vector3(0.0, 300.0, 0.0)
		CONTEXT_AERIAL_FORWARD:
			attack.startup_time = maxf(base_attack.startup_time * 0.72, 0.06)
			attack.recovery_time = maxf(base_attack.recovery_time * 0.86, 0.09)
			attack.damage_multiplier *= 1.1
			attack.attack_range += 0.38
			attack.movement_distance = maxf(base_attack.movement_distance, 0.62)
			attack.movement_duration = 0.12
			attack.windup_offset += Vector3(0.0, 0.08, 0.12)
			attack.strike_offset += Vector3(0.0, 0.0, -0.38)
			attack.recovery_offset += Vector3(0.0, -0.06, -0.12)
		CONTEXT_AERIAL_DOWN:
			attack.startup_time = maxf(base_attack.startup_time * 0.72, 0.06)
			attack.recovery_time = maxf(base_attack.recovery_time * 0.86, 0.09)
			attack.damage_multiplier *= 1.16
			attack.stance_multiplier *= 1.42
			attack.knockback_multiplier *= 1.3
			attack.attack_range += 0.2
			attack.cone_angle_degrees = maxf(base_attack.cone_angle_degrees, 120.0)
			attack.movement_distance = 0.08
			attack.windup_rotation_degrees = Vector3(-72.0, -25.0, 0.0)
			attack.strike_rotation_degrees = Vector3(78.0, 18.0, 0.0)
			attack.strike_offset += Vector3(0.0, -0.42, -0.08)
			attack.recovery_offset += Vector3(0.0, -0.18, 0.0)
			attack.hit_stop_duration = maxf(base_attack.hit_stop_duration, 0.075)
			append_tag(attack.extra_tags, "plunging")

	if weapon_class == "sword":
		if resolved_context == CONTEXT_AERIAL_LIGHT:
			attack.character_pose_id = "sword_aerial_light"
			attack.footwork_profile_id = "sword_aerial_light"
			attack.windup_rotation_degrees = Vector3(5.0, -42.0, -8.0)
			attack.strike_rotation_degrees = Vector3(-8.0, 56.0, 8.0)
		elif resolved_context == CONTEXT_AERIAL_HEAVY:
			attack.character_pose_id = "sword_aerial_heavy"
			attack.footwork_profile_id = "sword_aerial_heavy"
			attack.windup_rotation_degrees = Vector3(-44.0, -20.0, -4.0)
			attack.strike_rotation_degrees = Vector3(52.0, 24.0, 4.0)
	return attack


static func apply_ground_launcher(
	payload: DamagePayload,
	attack: WeaponAttackDefinition,
	weapon_class: String,
	combo_depth: int,
	mastery_rank: int,
	actor_grounded: bool
) -> void:
	if payload == null or attack == null or mastery_rank < 1 or not actor_grounded:
		return
	if attack.input_kind != "heavy":
		return
	var is_finisher: bool = attack.next_light_attack_id == "" and attack.next_heavy_attack_id == ""
	if combo_depth < 3 and not is_finisher:
		return
	var launch_strengths: Dictionary = {
		"hammer": 6.4, "gauntlets": 6.2, "staff": 5.8, "mace": 5.7,
		"axe": 5.5, "halberd": 5.5, "lance": 5.4, "flail": 5.3,
		"sword": 5.1, "chains": 5.1, "scythe": 5.0, "whip": 4.9,
		"daggers": 4.7, "boomerang": 4.7, "shuriken": 4.6, "bow": 4.5,
	}
	payload.knockback_up_strength += float(launch_strengths.get(weapon_class, 5.0))
	payload.stance_damage += 1
	append_tag(payload.tags, "technique_launcher")
	append_tag(payload.tags, "context_ground_finisher")


static func apply_context_tags(
	payload: DamagePayload,
	attack: WeaponAttackDefinition,
	combo_depth: int,
	technique_id: String = ""
) -> void:
	if payload == null or attack == null:
		return
	if technique_id != "":
		append_tag(payload.tags, "technique_" + technique_id)
	if combo_depth >= 2:
		append_tag(payload.tags, "context_combo")
	if combo_depth >= 3:
		append_tag(payload.tags, "context_deep_combo")
	if attack.next_light_attack_id == "" and attack.next_heavy_attack_id == "":
		append_tag(payload.tags, "context_finisher")


static func append_tag(tags: Array[String], tag: String) -> void:
	if tag != "" and not tags.has(tag):
		tags.append(tag)
