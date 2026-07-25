extends RefCounted
class_name WeaponMasteryCatalog

const WEAPON_CLASSES: Array[String] = [
	"sword", "lance", "axe", "bow", "hammer", "mace", "daggers", "whip",
	"chains", "gauntlets", "flail", "halberd", "boomerang", "scythe", "staff", "shuriken",
]
const RANK_THRESHOLDS: Array[int] = [0, 8, 22, 45]
const RANK_NAMES: Array[String] = ["Initiate", "Familiar", "Adept", "Master"]

const DEFINITIONS: Dictionary = {
	"sword": {"name": "Sword", "icon": "⚔", "rank_1": "Flow — attacks recover 6% faster.", "rank_2": "Measured Edge — third and later combo hits gain damage and stance pressure.", "rank_3": "Finishing Form — Heavy combo finishers gain critical force."},
	"lance": {"name": "Lance", "icon": "↟", "rank_1": "Long Practice — attacks gain a little reach.", "rank_2": "Tip Precision — narrow thrusts gain damage and critical force.", "rank_3": "Driving Point — deep-combo thrusts gain stance pressure and knockback."},
	"axe": {"name": "Axe", "icon": "◒", "rank_1": "Heft Familiarity — attacks recover 6% faster.", "rank_2": "Committed Cleave — Heavy attacks gain damage and knockback.", "rank_3": "Sundering Arc — combo finishers strike another target."},
	"bow": {"name": "Bow", "icon": "➶", "rank_1": "Quick Nock — attacks recover 6% faster.", "rank_2": "Steady Aim — Heavy shots gain damage and critical force.", "rank_3": "Hunter's Rhythm — combo finishers cost less stamina."},
	"hammer": {"name": "Hammer", "icon": "◆", "rank_1": "Balanced Grip — attacks recover 6% faster.", "rank_2": "Armor Breaker — Heavy attacks deal greatly increased stance damage.", "rank_3": "Shattering Blow — Heavy finishers gain force and the shatter tag."},
	"mace": {"name": "Mace", "icon": "✹", "rank_1": "Weighted Rhythm — attacks recover 6% faster.", "rank_2": "Dazing Impact — Heavy attacks gain stance pressure and stagger duration.", "rank_3": "Crushing Cadence — combo finishers gain damage."},
	"daggers": {"name": "Daggers", "icon": "⋈", "rank_1": "Light Hands — attacks recover 9% faster.", "rank_2": "Flurry — later Light attacks gain damage.", "rank_3": "Opening Cut — deep combos gain critical force."},
	"whip": {"name": "Whip", "icon": "〰", "rank_1": "Line Control — attacks gain reach.", "rank_2": "Tip Crack — narrow attacks gain damage and stagger.", "rank_3": "Entangling Finish — Heavy finishers gain stance pressure and the bind tag."},
	"chains": {"name": "Chains", "icon": "⛓", "rank_1": "Momentum Sense — attacks recover 6% faster.", "rank_2": "Tension Impact — Heavy attacks gain force and stance pressure.", "rank_3": "Capturing Orbit — finishers strike another target and gain the pull tag."},
	"gauntlets": {"name": "Gauntlets", "icon": "✊", "rank_1": "Close Rhythm — attacks recover 9% faster.", "rank_2": "Pressure String — every later combo hit gains stance damage.", "rank_3": "Body Breaker — Heavy finishers gain damage and force."},
	"flail": {"name": "Flail", "icon": "⊙", "rank_1": "Orbit Control — attacks recover 6% faster.", "rank_2": "Stored Momentum — Heavy attacks gain knockback and damage.", "rank_3": "Unbroken Circle — finishers strike another target."},
	"halberd": {"name": "Halberd", "icon": "⚜", "rank_1": "Polearm Footwork — attacks gain reach.", "rank_2": "Hook and Sweep — Heavy attacks gain stance pressure.", "rank_3": "Reaping Formation — finishers strike another target and gain pull."},
	"boomerang": {"name": "Boomerang", "icon": "⌁", "rank_1": "Return Timing — attacks recover 6% faster.", "rank_2": "Returning Edge — later combo hits gain damage.", "rank_3": "Double Passage — finishers gain the returning-strike tag."},
	"scythe": {"name": "Scythe", "icon": "☾", "rank_1": "Reaper's Reach — attacks gain reach.", "rank_2": "Harvest Arc — Heavy attacks strike another target.", "rank_3": "Execution Sweep — finishers gain damage and critical force."},
	"staff": {"name": "Staff", "icon": "│", "rank_1": "Efficient Forms — stamina costs fall.", "rank_2": "Resonant Strike — Heavy attacks gain stance pressure and magical resonance.", "rank_3": "Spellweave — finishers gain damage and the spell-cancel tag."},
	"shuriken": {"name": "Shuriken", "icon": "✥", "rank_1": "Fast Draw — attacks recover 9% faster.", "rank_2": "Precision Volley — later Light attacks gain damage.", "rank_3": "Marked Finish — finishers gain critical force and the mark tag."},
}


static func is_weapon_class(weapon_class: String) -> bool:
	return WEAPON_CLASSES.has(weapon_class)


static func get_definition(weapon_class: String) -> Dictionary:
	if not DEFINITIONS.has(weapon_class):
		return {"name": weapon_class.capitalize(), "icon": "◇"}
	return (DEFINITIONS[weapon_class] as Dictionary).duplicate(true)


static func get_display_name(weapon_class: String) -> String:
	return str(get_definition(weapon_class).get("name", weapon_class.capitalize()))


static func get_icon(weapon_class: String) -> String:
	return str(get_definition(weapon_class).get("icon", "◇"))


static func get_rank(points: int) -> int:
	var rank: int = 0
	for index: int in range(RANK_THRESHOLDS.size()):
		if points >= RANK_THRESHOLDS[index]:
			rank = index
	return rank


static func get_rank_name(rank: int) -> String:
	return RANK_NAMES[clampi(rank, 0, RANK_NAMES.size() - 1)]


static func get_rank_threshold(rank: int) -> int:
	return RANK_THRESHOLDS[clampi(rank, 0, RANK_THRESHOLDS.size() - 1)]


static func get_next_rank_threshold(rank: int) -> int:
	if rank + 1 >= RANK_THRESHOLDS.size():
		return RANK_THRESHOLDS.back()
	return RANK_THRESHOLDS[rank + 1]


static func get_upgrade_description(weapon_class: String, rank: int) -> String:
	return str(get_definition(weapon_class).get("rank_" + str(rank), ""))


static func get_attack_speed_multiplier(weapon_class: String, rank: int) -> float:
	if rank <= 0:
		return 1.0
	return 1.09 if weapon_class in ["daggers", "gauntlets", "shuriken"] else 1.06


static func get_stamina_multiplier(weapon_class: String, rank: int) -> float:
	if rank <= 0:
		return 1.0
	if weapon_class == "staff":
		return 0.82
	return 0.92 if rank >= 3 else 0.96


static func get_range_bonus(weapon_class: String, rank: int) -> float:
	if rank <= 0:
		return 0.0
	return 0.35 if weapon_class in ["lance", "whip", "halberd", "scythe"] else 0.0


static func get_extra_targets(weapon_class: String, rank: int, attack: WeaponAttackDefinition, combo_depth: int) -> int:
	if rank < 3 or attack == null or combo_depth < 3:
		return 0
	return 1 if weapon_class in ["axe", "chains", "flail", "halberd", "scythe"] else 0


static func apply_payload_upgrades(
	payload: DamagePayload,
	weapon_class: String,
	rank: int,
	attack: WeaponAttackDefinition,
	combo_depth: int
) -> void:
	if payload == null or attack == null or rank < 2:
		return
	var is_heavy: bool = attack.input_kind == "heavy"
	var deep_combo: bool = combo_depth >= 3
	match weapon_class:
		"sword":
			if deep_combo:
				payload.amount += 1
				payload.stance_damage += 1
			if rank >= 3 and is_heavy and deep_combo:
				payload.critical_multiplier += 0.3
				payload.knockback_strength += 1.0
		"lance":
			if attack.cone_angle_degrees <= 70.0:
				payload.amount += 1
				payload.critical_multiplier += 0.2
			if rank >= 3 and deep_combo:
				payload.stance_damage += 1
				payload.knockback_strength += 1.0
		"axe":
			if is_heavy:
				payload.amount += 1
				payload.knockback_strength += 1.5
		"bow":
			if is_heavy:
				payload.amount += 1
				payload.critical_multiplier += 0.25
		"hammer":
			if is_heavy:
				payload.stance_damage += 2
				if rank >= 3 and deep_combo:
					payload.knockback_strength += 2.0
					append_tag(payload, "shatter")
		"mace":
			if is_heavy:
				payload.stance_damage += 2
				payload.status_effect = "staggered"
				payload.status_duration = maxf(payload.status_duration, 0.45)
			if rank >= 3 and deep_combo:
				payload.amount += 1
		"daggers":
			if not is_heavy and combo_depth >= 2:
				payload.amount += 1
			if rank >= 3 and deep_combo:
				payload.critical_multiplier += 0.25
		"whip":
			if attack.cone_angle_degrees <= 80.0:
				payload.amount += 1
				payload.status_effect = "staggered"
			if rank >= 3 and is_heavy and deep_combo:
				payload.stance_damage += 1
				append_tag(payload, "bind")
		"chains":
			if is_heavy:
				payload.stance_damage += 1
				payload.knockback_strength += 2.0
			if rank >= 3 and deep_combo:
				append_tag(payload, "pull")
		"gauntlets":
			if combo_depth >= 2:
				payload.stance_damage += 1
			if rank >= 3 and is_heavy and deep_combo:
				payload.amount += 1
		"flail":
			if is_heavy:
				payload.amount += 1
				payload.knockback_strength += 2.0
		"halberd":
			if is_heavy:
				payload.stance_damage += 1
			if rank >= 3 and deep_combo:
				append_tag(payload, "pull")
		"boomerang":
			if combo_depth >= 2:
				payload.amount += 1
			if rank >= 3 and deep_combo:
				append_tag(payload, "returning_strike")
		"scythe":
			if is_heavy:
				payload.amount += 1
			if rank >= 3 and deep_combo:
				payload.critical_multiplier += 0.3
		"staff":
			if is_heavy:
				payload.stance_damage += 1
				append_tag(payload, "resonance")
			if rank >= 3 and deep_combo:
				payload.amount += 1
				append_tag(payload, "spellweave")
		"shuriken":
			if not is_heavy and combo_depth >= 2:
				payload.amount += 1
			if rank >= 3 and deep_combo:
				payload.critical_multiplier += 0.25
				append_tag(payload, "mark")


static func append_tag(payload: DamagePayload, tag: String) -> void:
	if tag != "" and not payload.tags.has(tag):
		payload.tags.append(tag)
