extends RefCounted
class_name WeaponSandboxCatalog

const WeaponMasteryCatalogScript = preload(
	"res://scripts/weapons/weapon_mastery_catalog.gd"
)
const ProxyRigScene: PackedScene = preload(
	"res://scenes/weapons/training_proxy_weapon_rig.tscn"
)
const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const TrainingHammer: WeaponDefinition = preload("res://data/weapons/training_hammer.tres")
const TrainingSpear: WeaponDefinition = preload("res://data/weapons/training_spear.tres")
const TrainingWhip: WeaponDefinition = preload("res://data/weapons/training_whip.tres")
const TrainingChain: WeaponDefinition = preload("res://data/weapons/training_chain.tres")

const PROXY_CONFIGS: Dictionary = {
	"axe": {
		"name": "Training Bearded Axe",
		"damage": 3, "stance": 3, "range": 3.0, "speed": 0.86,
		"cone": 145.0, "targets": 5, "light_startup": 0.20, "heavy_startup": 0.38,
		"light_move": 0.32, "heavy_move": 0.30, "heavy_damage": 2.15, "heavy_stance": 2.0,
		"light_tags": ["slash", "cleave"], "heavy_tags": ["force", "slash", "cleave", "sunder"],
		"names": ["Short Hew", "Returning Chop", "Shoulder Cleave", "Sundering Drop", "Hooking Hew", "Broad Split", "Execution Chop"],
		"colors": [Color(0.28, 0.46, 0.9), Color(0.14, 0.11, 0.18), Color(0.52, 0.72, 1.0)],
	},
	"bow": {
		"name": "Training Longbow",
		"damage": 2, "stance": 1, "range": 8.5, "speed": 1.0,
		"cone": 15.0, "targets": 1, "center": 3.4, "light_startup": 0.16, "heavy_startup": 0.42,
		"light_move": 0.0, "heavy_move": 0.0, "heavy_damage": 2.6, "heavy_stance": 1.55,
		"light_tags": ["ranged", "pierce", "shot"], "heavy_tags": ["ranged", "pierce", "shot", "precision"],
		"names": ["Quick Nock", "Walking Shot", "Split Draw", "Full Draw", "Driving Arrow", "Pinning Shot", "Hunter's Mark"],
		"colors": [Color(0.92, 0.55, 0.12), Color(0.18, 0.11, 0.06), Color(1.0, 0.78, 0.22)],
	},
	"mace": {
		"name": "Training Flanged Mace",
		"damage": 3, "stance": 4, "range": 2.75, "speed": 0.9,
		"cone": 118.0, "targets": 4, "light_startup": 0.19, "heavy_startup": 0.34,
		"light_move": 0.28, "heavy_move": 0.24, "heavy_damage": 1.9, "heavy_stance": 2.65,
		"light_tags": ["force", "blunt"], "heavy_tags": ["force", "blunt", "guard_break"],
		"names": ["Temple Tap", "Backhand Bell", "Shoulder Crush", "Dazing Blow", "Knee Break", "Crowd Crusher", "Judgment Bell"],
		"colors": [Color(0.95, 0.38, 0.08), Color(0.18, 0.12, 0.1), Color(1.0, 0.66, 0.14)],
	},
	"daggers": {
		"name": "Training Twin Daggers",
		"damage": 2, "stance": 1, "range": 2.25, "speed": 1.32,
		"cone": 72.0, "targets": 2, "light_startup": 0.085, "heavy_startup": 0.18,
		"light_move": 0.48, "heavy_move": 0.65, "heavy_damage": 1.55, "heavy_stance": 1.35,
		"light_tags": ["slash", "pierce", "flurry"], "heavy_tags": ["pierce", "precision", "finisher"],
		"names": ["First Fang", "Second Fang", "Crosscut", "Lunging Bite", "Vein Step", "Twin Pierce", "Opening Cut"],
		"colors": [Color(0.22, 0.76, 0.34), Color(0.05, 0.15, 0.08), Color(0.55, 1.0, 0.42)],
	},
	"gauntlets": {
		"name": "Training Battle Gauntlets",
		"damage": 2, "stance": 3, "range": 2.0, "speed": 1.24,
		"cone": 66.0, "targets": 2, "light_startup": 0.09, "heavy_startup": 0.22,
		"light_move": 0.56, "heavy_move": 0.72, "heavy_damage": 1.7, "heavy_stance": 2.15,
		"light_tags": ["force", "blunt", "pressure"], "heavy_tags": ["force", "blunt", "launcher"],
		"names": ["Lead Knuckle", "Cross Knuckle", "Body Hook", "Rising Fist", "Shoulder Drive", "Breaker Cross", "Meteor Fist"],
		"colors": [Color(0.92, 0.2, 0.58), Color(0.18, 0.05, 0.14), Color(1.0, 0.46, 0.76)],
	},
	"flail": {
		"name": "Training War Flail",
		"damage": 3, "stance": 3, "range": 3.25, "speed": 0.88,
		"cone": 205.0, "targets": 6, "light_startup": 0.21, "heavy_startup": 0.39,
		"light_move": 0.28, "heavy_move": 0.34, "heavy_damage": 2.05, "heavy_stance": 2.15,
		"light_tags": ["force", "blunt", "orbit"], "heavy_tags": ["force", "blunt", "orbit", "momentum"],
		"names": ["First Orbit", "Back Orbit", "Shoulder Wheel", "Stored Weight", "Chasing Star", "Wide Orbit", "Deadweight Crash"],
		"colors": [Color(0.15, 0.55, 0.92), Color(0.06, 0.1, 0.18), Color(0.35, 0.78, 1.0)],
	},
	"halberd": {
		"name": "Training Halberd",
		"damage": 3, "stance": 3, "range": 3.8, "speed": 0.91,
		"cone": 150.0, "targets": 5, "light_startup": 0.17, "heavy_startup": 0.34,
		"light_move": 0.42, "heavy_move": 0.58, "heavy_damage": 2.0, "heavy_stance": 2.05,
		"light_tags": ["slash", "pierce", "polearm"], "heavy_tags": ["force", "slash", "hook", "polearm"],
		"names": ["Shaft Cut", "Passing Point", "Reaping Return", "Brace Break", "Hooking Reap", "Formation Sweep", "Guillotine Line"],
		"colors": [Color(0.92, 0.2, 0.13), Color(0.18, 0.07, 0.05), Color(1.0, 0.5, 0.18)],
	},
	"boomerang": {
		"name": "Training War Boomerang",
		"damage": 2, "stance": 1, "range": 5.8, "speed": 1.08,
		"cone": 42.0, "targets": 3, "center": 2.5, "light_startup": 0.13, "heavy_startup": 0.28,
		"light_move": 0.18, "heavy_move": 0.3, "heavy_damage": 1.75, "heavy_stance": 1.45,
		"light_tags": ["ranged", "slash", "returning"], "heavy_tags": ["ranged", "slash", "returning", "force"],
		"names": ["Quick Cast", "Crosswind Cast", "Returning Edge", "Long Arc", "Hook Return", "Twin Passage", "Tailwind Finish"],
		"colors": [Color(0.94, 0.35, 0.72), Color(0.2, 0.08, 0.16), Color(1.0, 0.65, 0.86)],
	},
	"scythe": {
		"name": "Training Reaper Scythe",
		"damage": 3, "stance": 2, "range": 3.7, "speed": 0.9,
		"cone": 220.0, "targets": 7, "light_startup": 0.2, "heavy_startup": 0.38,
		"light_move": 0.34, "heavy_move": 0.38, "heavy_damage": 2.2, "heavy_stance": 1.8,
		"light_tags": ["slash", "reap", "cleave"], "heavy_tags": ["force", "slash", "reap", "execution"],
		"names": ["Low Harvest", "Back Harvest", "Pale Crescent", "Grave Hew", "Hooked Reap", "Harvest Wheel", "Execution Sweep"],
		"colors": [Color(0.72, 0.08, 0.1), Color(0.12, 0.03, 0.04), Color(1.0, 0.22, 0.18)],
	},
	"staff": {
		"name": "Training Battle Staff",
		"damage": 2, "stance": 2, "range": 3.35, "speed": 1.08,
		"cone": 155.0, "targets": 5, "light_startup": 0.14, "heavy_startup": 0.28,
		"light_move": 0.38, "heavy_move": 0.48, "heavy_damage": 1.65, "heavy_stance": 2.0,
		"light_tags": ["blunt", "staff", "flow"], "heavy_tags": ["force", "blunt", "staff", "resonance"],
		"names": ["Palm Sweep", "Reverse Sweep", "Passing Thrust", "Pillar Strike", "Vaulting Sweep", "Resonant Thrust", "Spinning Ward"],
		"colors": [Color(0.12, 0.78, 0.82), Color(0.04, 0.14, 0.16), Color(0.32, 1.0, 0.94)],
	},
	"shuriken": {
		"name": "Training Shuriken Set",
		"damage": 1, "stance": 1, "range": 6.8, "speed": 1.36,
		"cone": 30.0, "targets": 4, "center": 2.7, "light_startup": 0.075, "heavy_startup": 0.2,
		"light_move": 0.2, "heavy_move": 0.28, "heavy_damage": 1.7, "heavy_stance": 1.25,
		"light_tags": ["ranged", "pierce", "volley"], "heavy_tags": ["ranged", "pierce", "volley", "mark"],
		"names": ["Fast Draw", "Second Star", "Cross Volley", "Focused Star", "Running Volley", "Pinning Fan", "Marked Finish"],
		"colors": [Color(0.22, 0.24, 0.82), Color(0.05, 0.05, 0.18), Color(0.5, 0.48, 1.0)],
	},
}


static func get_all_weapon_classes() -> Array[String]:
	return WeaponMasteryCatalogScript.WEAPON_CLASSES.duplicate()


static func get_weapon(weapon_class: String) -> WeaponDefinition:
	var authored: WeaponDefinition = _get_authored_weapon(weapon_class)
	if authored != null:
		var copy: WeaponDefinition = authored.duplicate(true) as WeaponDefinition
		if copy != null:
			copy.set_meta("combat_sandbox_authored", true)
			copy.set_meta("combat_sandbox_proxy", false)
			return copy
	return _build_proxy_weapon(weapon_class)


static func is_authored_class(weapon_class: String) -> bool:
	return _get_authored_weapon(weapon_class) != null


static func get_status_label(weapon_class: String) -> String:
	return "AUTHORED" if is_authored_class(weapon_class) else "PROXY"


static func _get_authored_weapon(weapon_class: String) -> WeaponDefinition:
	match weapon_class:
		"sword":
			return PracticeSword
		"hammer":
			return TrainingHammer
		"lance":
			return TrainingSpear
		"whip":
			return TrainingWhip
		"chains":
			return TrainingChain
		_:
			return null


static func _build_proxy_weapon(weapon_class: String) -> WeaponDefinition:
	if not PROXY_CONFIGS.has(weapon_class):
		return null
	var config: Dictionary = PROXY_CONFIGS[weapon_class] as Dictionary
	var weapon := WeaponDefinition.new()
	weapon.weapon_class = weapon_class
	weapon.display_name = str(config.get("name", "Training " + weapon_class.capitalize())) + " [Proxy]"
	weapon.description = (
		"Development-only combat proxy for the " + weapon_class
		+ " class. Replace with an authored weapon after its combat identity survives playtesting."
	)
	weapon.damage = int(config.get("damage", 2))
	weapon.stance_damage = int(config.get("stance", 2))
	weapon.range = float(config.get("range", 2.8))
	weapon.attack_speed = float(config.get("speed", 1.0))
	weapon.cooldown = 0.45
	weapon.cone_angle_degrees = float(config.get("cone", 100.0))
	weapon.max_targets = int(config.get("targets", 3))
	weapon.stamina_cost = 0
	weapon.critical_multiplier = 2.0
	var colors: Array = config.get("colors", []) as Array
	if colors.size() >= 3:
		weapon.visual_primary_color = colors[0] as Color
		weapon.visual_secondary_color = colors[1] as Color
		weapon.visual_accent_color = colors[2] as Color
	weapon.runtime_rig_scene = ProxyRigScene
	weapon.moveset = _build_proxy_moveset(weapon_class, config)
	weapon.scaling_stats = _get_scaling_stats(weapon_class)
	weapon.scaling_note = "Sandbox proxy identity only; final scaling waits for authored weapon balance."
	weapon.set_meta("combat_sandbox_authored", false)
	weapon.set_meta("combat_sandbox_proxy", true)
	return weapon


static func _build_proxy_moveset(
	weapon_class: String,
	config: Dictionary
) -> WeaponMovesetDefinition:
	var moveset := WeaponMovesetDefinition.new()
	moveset.moveset_id = "sandbox_" + weapon_class
	moveset.display_name = weapon_class.capitalize() + " Sandbox Forms"
	moveset.entry_light_attack_id = weapon_class + "_proxy_l1"
	moveset.entry_heavy_attack_id = weapon_class + "_proxy_h0"
	var names: Array = config.get("names", []) as Array
	for index: int in range(3):
		var light := _build_proxy_attack(
			weapon_class,
			"light",
			index,
			str(names[index]) if index < names.size() else "Light " + str(index + 1),
			config
		)
		light.attack_id = weapon_class + "_proxy_l" + str(index + 1)
		if index < 2:
			light.next_light_attack_id = weapon_class + "_proxy_l" + str(index + 2)
		light.next_heavy_attack_id = weapon_class + "_proxy_h" + str(index + 1)
		moveset.attacks.append(light)
	for index: int in range(4):
		var heavy_name_index: int = 3 + index
		var heavy := _build_proxy_attack(
			weapon_class,
			"heavy",
			index,
			str(names[heavy_name_index]) if heavy_name_index < names.size() else "Heavy " + str(index),
			config
		)
		heavy.attack_id = weapon_class + "_proxy_h" + str(index)
		if index == 0:
			heavy.next_light_attack_id = weapon_class + "_proxy_l1"
		elif index < 3:
			heavy.next_light_attack_id = weapon_class + "_proxy_l" + str(index + 1)
		moveset.attacks.append(heavy)
	return moveset


static func _build_proxy_attack(
	weapon_class: String,
	input_kind: String,
	index: int,
	display_name: String,
	config: Dictionary
) -> WeaponAttackDefinition:
	var attack := WeaponAttackDefinition.new()
	attack.display_name = display_name
	attack.input_kind = input_kind
	var is_heavy: bool = input_kind == "heavy"
	var light_startup: float = float(config.get("light_startup", 0.15))
	var heavy_startup: float = float(config.get("heavy_startup", 0.3))
	attack.startup_time = (
		heavy_startup * (1.0 + float(index) * 0.06)
		if is_heavy
		else light_startup * (1.0 + float(index) * 0.04)
	)
	attack.active_time = 0.11 if is_heavy else 0.07
	attack.recovery_time = (
		0.31 + float(index) * 0.045
		if is_heavy
		else 0.14 + float(index) * 0.025
	)
	attack.combo_timeout = 0.74 if not is_heavy else 0.34
	attack.cancel_window_start_normalized = 0.82 if is_heavy else 0.48
	attack.allow_spell_cancel = not is_heavy
	attack.allow_dodge_cancel = not is_heavy or weapon_class in ["daggers", "gauntlets", "shuriken"]
	attack.stamina_cost = 1 if not is_heavy else (2 if index < 3 else 3)
	attack.damage_multiplier = (
		float(config.get("heavy_damage", 1.8)) * (1.0 + float(index) * 0.1)
		if is_heavy
		else 0.92 + float(index) * 0.13
	)
	attack.stance_multiplier = (
		float(config.get("heavy_stance", 2.0)) * (1.0 + float(index) * 0.09)
		if is_heavy
		else 0.9 + float(index) * 0.14
	)
	attack.knockback_multiplier = 1.25 + float(index) * 0.12 if is_heavy else 0.82 + float(index) * 0.08
	if is_heavy and weapon_class in ["gauntlets", "mace", "axe", "halberd"] and index in [1, 3]:
		attack.knockback_up_add = 2.0 + float(index) * 0.35
	attack.attack_range = float(config.get("range", 2.8)) * (1.0 + float(index) * 0.035)
	attack.cone_angle_degrees = float(config.get("cone", 100.0)) * (1.15 if is_heavy and index >= 2 else 1.0)
	attack.attack_center_forward_offset = float(
		config.get("center", minf(attack.attack_range * 0.42, 1.65))
	)
	attack.max_targets = int(config.get("targets", 3)) + (2 if is_heavy and index >= 2 else 0)
	attack.movement_distance = float(
		config.get("heavy_move" if is_heavy else "light_move", 0.3)
	) * (1.0 + float(index) * 0.08)
	attack.movement_duration = 0.17 if is_heavy else 0.12
	attack.hit_stop_duration = (
		0.085 + float(index) * 0.012
		if is_heavy
		else 0.045 + float(index) * 0.006
	)
	attack.hit_stop_time_scale = 0.04
	var colors: Array = config.get("colors", []) as Array
	if colors.size() >= 3:
		var trail: Color = colors[2] as Color
		trail.a = 0.86 if is_heavy else 0.72
		attack.trail_color = trail
	attack.trail_start_scale = Vector3(0.58, 0.92, 1.0) if is_heavy else Vector3(0.34, 0.65, 1.0)
	attack.trail_end_scale = Vector3(1.45, 1.8, 1.0) if is_heavy else Vector3(0.92, 1.25, 1.0)
	_configure_proxy_weapon_pose(attack, weapon_class, is_heavy, index)
	var tags: Array = config.get("heavy_tags" if is_heavy else "light_tags", []) as Array
	for raw_tag: Variant in tags:
		var tag: String = str(raw_tag)
		if tag != "" and not attack.extra_tags.has(tag):
			attack.extra_tags.append(tag)
	attack.extra_tags.append("sandbox_proxy")
	return attack


static func _configure_proxy_weapon_pose(
	attack: WeaponAttackDefinition,
	weapon_class: String,
	is_heavy: bool,
	index: int
) -> void:
	var side: float = -1.0 if index % 2 == 0 else 1.0
	match weapon_class:
		"bow", "shuriken", "boomerang":
			attack.windup_rotation_degrees = Vector3(0.0, side * 24.0, 82.0)
			attack.strike_rotation_degrees = Vector3(-4.0, -side * 8.0, 90.0)
			attack.windup_offset = Vector3(0.0, 0.0, 0.18)
			attack.strike_offset = Vector3(0.0, 0.0, -0.28)
		"gauntlets", "daggers":
			attack.windup_rotation_degrees = Vector3(0.0, side * 28.0, side * 26.0)
			attack.strike_rotation_degrees = Vector3(-8.0, -side * 16.0, -side * 12.0)
			attack.strike_offset = Vector3(0.0, 0.0, -0.26 if not is_heavy else -0.38)
		"staff", "halberd", "scythe":
			attack.windup_rotation_degrees = Vector3(0.0, side * 86.0, 86.0)
			attack.strike_rotation_degrees = Vector3(0.0, -side * 108.0, 94.0)
		"flail":
			attack.windup_rotation_degrees = Vector3(0.0, side * 118.0, 12.0)
			attack.strike_rotation_degrees = Vector3(0.0, -side * 156.0, -12.0)
		"axe", "mace":
			if is_heavy:
				attack.windup_rotation_degrees = Vector3(-104.0, side * 12.0, 0.0)
				attack.strike_rotation_degrees = Vector3(92.0, -side * 8.0, 0.0)
			else:
				attack.windup_rotation_degrees = Vector3(0.0, side * 72.0, side * 12.0)
				attack.strike_rotation_degrees = Vector3(0.0, -side * 92.0, -side * 12.0)
		_:
			attack.windup_rotation_degrees = Vector3(0.0, side * 58.0, 0.0)
			attack.strike_rotation_degrees = Vector3(0.0, -side * 72.0, 0.0)


static func _get_scaling_stats(weapon_class: String) -> Array[String]:
	match weapon_class:
		"axe", "mace", "flail":
			return ["power", "skill"]
		"bow", "daggers", "boomerang", "shuriken":
			return ["dexterity", "focus"]
		"gauntlets":
			return ["power", "dexterity"]
		"staff":
			return ["skill", "arcana"]
		"halberd", "scythe":
			return ["power", "dexterity"]
		_:
			return ["power", "dexterity"]


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	for weapon_class: String in get_all_weapon_classes():
		var weapon: WeaponDefinition = get_weapon(weapon_class)
		if weapon == null:
			failures.append("missing sandbox weapon for " + weapon_class)
			continue
		if weapon.weapon_class != weapon_class:
			failures.append("sandbox weapon class mismatch for " + weapon_class)
		if weapon.get_moveset() == null:
			failures.append("sandbox weapon has no moveset: " + weapon_class)
		elif not weapon.get_moveset().validate_graph().is_empty():
			failures.append("sandbox moveset graph invalid: " + weapon_class)
	return failures
