extends RefCounted
class_name WeaponChargeAttackCatalogV1

const MODE_SUSTAIN: String = "sustain"
const MODE_RELEASE: String = "release"


static func get_profile(weapon_class: String, input_kind: String) -> Dictionary:
	if weapon_class == "chains" and input_kind == "light":
		return {
			"id": "chain_orbit",
			"mode": MODE_SUSTAIN,
			"threshold": 0.24,
			"full_charge": 1.15,
			"pulse_interval": 0.44,
		}
	if weapon_class == "axe" and input_kind == "heavy":
		return {
			"id": "axe_vault_slam",
			"mode": MODE_RELEASE,
			"threshold": 0.28,
			"full_charge": 1.25,
		}
	return {}


static func build_hold_attack(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	input_kind: String
) -> WeaponAttackDefinition:
	if base_attack == null:
		return null
	var profile: Dictionary = get_profile(weapon_class, input_kind)
	if profile.is_empty():
		return null
	var attack: WeaponAttackDefinition = base_attack.duplicate(true) as WeaponAttackDefinition
	if attack == null:
		return null
	attack.attack_id = "charge_hold_" + str(profile.get("id", weapon_class))
	attack.display_name = "Concentrating"
	attack.input_kind = input_kind
	attack.startup_time = 60.0
	attack.active_time = 0.01
	attack.recovery_time = 0.01
	attack.movement_distance = 0.0
	attack.allow_spell_cancel = false
	attack.allow_dodge_cancel = true
	_add_tag(attack, "weapon_charge_hold")
	_add_tag(attack, "charge_" + str(profile.get("id", "generic")))
	if weapon_class == "chains":
		attack.display_name = "Iron Orbit"
		attack.attack_range = maxf(attack.attack_range, 3.1)
		attack.cone_angle_degrees = 360.0
		attack.attack_center_forward_offset = 0.0
		_add_tag(attack, "chain_charge_orbit")
		_add_tag(attack, "chain_head_authoritative")
	elif weapon_class == "axe":
		attack.display_name = "Axe Plant"
		_add_tag(attack, "axe_charge_plant")
	return attack


static func build_sustain_pulse(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	charge_ratio: float
) -> WeaponAttackDefinition:
	if base_attack == null or weapon_class != "chains":
		return null
	var charge: float = clampf(charge_ratio, 0.0, 1.0)
	var attack: WeaponAttackDefinition = base_attack.duplicate(true) as WeaponAttackDefinition
	if attack == null:
		return null
	attack.attack_id = "chain_charge_orbit_pulse"
	attack.display_name = "Iron Orbit"
	attack.input_kind = "light"
	attack.damage_multiplier = lerpf(0.82, 1.22, charge)
	attack.stance_multiplier = lerpf(1.05, 1.65, charge)
	attack.knockback_multiplier = lerpf(0.72, 1.08, charge)
	attack.attack_range = lerpf(2.7, 3.65, charge)
	attack.cone_angle_degrees = 360.0
	attack.attack_center_forward_offset = 0.0
	attack.max_targets = 8
	attack.hit_stop_duration = lerpf(0.045, 0.075, charge)
	attack.movement_distance = 0.0
	_add_tag(attack, "weapon_charge_pulse")
	_add_tag(attack, "chain_charge_orbit")
	_add_tag(attack, "chain_head_authoritative")
	return attack


static func build_release_attack(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	input_kind: String,
	charge_ratio: float
) -> WeaponAttackDefinition:
	if base_attack == null:
		return null
	var profile: Dictionary = get_profile(weapon_class, input_kind)
	if profile.is_empty() or str(profile.get("mode", "")) != MODE_RELEASE:
		return null
	var charge: float = clampf(charge_ratio, 0.0, 1.0)
	var attack: WeaponAttackDefinition = base_attack.duplicate(true) as WeaponAttackDefinition
	if attack == null:
		return null
	if weapon_class == "axe" and input_kind == "heavy":
		attack.attack_id = "axe_charge_vault_slam"
		attack.display_name = "Vaulting Guillotine"
		attack.startup_time = lerpf(0.72, 0.92, charge)
		attack.active_time = 0.14
		attack.recovery_time = lerpf(0.46, 0.58, charge)
		attack.damage_multiplier *= lerpf(1.35, 2.0, charge)
		attack.stance_multiplier *= lerpf(1.28, 1.85, charge)
		attack.knockback_multiplier *= lerpf(1.08, 1.4, charge)
		attack.knockback_up_add = maxf(attack.knockback_up_add, lerpf(0.8, 1.8, charge))
		attack.attack_range = maxf(attack.attack_range, lerpf(3.0, 3.8, charge))
		attack.cone_angle_degrees = 360.0
		attack.attack_center_forward_offset = 0.0
		attack.max_targets = maxi(attack.max_targets, 8)
		attack.movement_distance = 0.0
		attack.hit_stop_duration = maxf(attack.hit_stop_duration, lerpf(0.12, 0.18, charge))
		attack.hit_stop_time_scale = minf(attack.hit_stop_time_scale, 0.03)
		_add_tag(attack, "weapon_charge_release")
		_add_tag(attack, "axe_vault_slam")
		_add_tag(attack, "ground_slam")
		_add_tag(attack, "guard_break")
	return attack


static func _add_tag(attack: WeaponAttackDefinition, tag: String) -> void:
	if attack != null and tag != "" and not attack.extra_tags.has(tag):
		attack.extra_tags.append(tag)
