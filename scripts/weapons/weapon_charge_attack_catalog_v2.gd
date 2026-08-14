extends RefCounted
class_name WeaponChargeAttackCatalogV2

const BaseCatalogScript = preload(
	"res://scripts/weapons/weapon_charge_attack_catalog_v1.gd"
)

const MODE_SUSTAIN: String = "sustain"
const MODE_RELEASE: String = "release"
const MODE_COUNTER: String = "counter"


static func get_profile(weapon_class: String, input_kind: String) -> Dictionary:
	if weapon_class == "axe" and input_kind == "light":
		return {
			"id": "axe_counter_guard",
			"mode": MODE_COUNTER,
			"threshold": 0.16,
			"full_charge": 0.55,
			"movement_multiplier": 0.0,
		}
	var profile: Dictionary = BaseCatalogScript.get_profile(
		weapon_class,
		input_kind
	)
	if weapon_class == "axe" and input_kind == "heavy":
		profile["id"] = "axe_lever_vault"
		profile["mode"] = MODE_RELEASE
		profile["threshold"] = 0.18
		profile["full_charge"] = 0.9
		profile["movement_multiplier"] = 0.32
	return profile


static func build_hold_attack(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	input_kind: String
) -> WeaponAttackDefinition:
	if base_attack == null:
		return null
	var attack: WeaponAttackDefinition
	if weapon_class == "axe" and input_kind == "light":
		attack = base_attack.duplicate(true) as WeaponAttackDefinition
		if attack == null:
			return null
		attack.attack_id = "charge_hold_axe_counter_guard"
		attack.display_name = "Breakwater Catch"
		attack.input_kind = "light"
		attack.startup_time = 0.08
		attack.active_time = 60.0
		attack.recovery_time = 0.01
		attack.combo_timeout = 0.0
		attack.cancel_window_start_normalized = 0.0
		attack.movement_distance = 0.0
		attack.movement_duration = 0.0
		attack.footwork_profile_id = ""
		attack.allow_spell_cancel = false
		attack.allow_dodge_cancel = true
		var guard_rotation: Vector3 = Vector3(-8.0, -72.0, 88.0)
		var guard_offset: Vector3 = Vector3(0.0, 0.03, -0.18)
		attack.windup_rotation_degrees = guard_rotation
		attack.strike_rotation_degrees = guard_rotation
		attack.recovery_rotation_degrees = guard_rotation
		attack.windup_offset = guard_offset
		attack.strike_offset = guard_offset
		attack.recovery_offset = guard_offset
		_add_tag(attack, "weapon_charge_hold")
		_add_tag(attack, "charge_axe_counter_guard")
		_add_tag(attack, "axe_counter_guard")
		_add_tag(attack, "weapon_counter_guard")
		_add_tag(attack, "axe_edge_aligned")
		_add_tag(attack, "counter")
		return attack

	attack = BaseCatalogScript.build_hold_attack(
		base_attack,
		weapon_class,
		input_kind
	)
	if attack == null:
		return null
	# Blend into the held pose quickly, then remain in a long active phase. The
	# original 60-second startup made the skeleton spend the whole charge barely
	# leaving its neutral pose.
	attack.startup_time = 0.16
	attack.active_time = 60.0
	attack.recovery_time = 0.01
	attack.combo_timeout = 0.0
	attack.cancel_window_start_normalized = 0.0
	attack.movement_distance = 0.0
	attack.movement_duration = 0.0
	attack.footwork_profile_id = ""

	if weapon_class == "axe":
		# The bright edge is rolled into the vertical swing plane before Grace
		# begins walking the charge forward.
		var ready_rotation: Vector3 = Vector3(-108.0, -4.0, 90.0)
		var ready_offset: Vector3 = Vector3(0.0, 0.06, 0.05)
		attack.startup_time = 0.1
		attack.windup_rotation_degrees = ready_rotation
		attack.strike_rotation_degrees = ready_rotation
		attack.recovery_rotation_degrees = ready_rotation
		attack.windup_offset = ready_offset
		attack.strike_offset = ready_offset
		attack.recovery_offset = ready_offset
		_add_tag(attack, "axe_edge_aligned")
	elif weapon_class == "staff" and input_kind == "light":
		# Low, almost horizontal preparation for the returning toss.
		var throw_rotation: Vector3 = Vector3(-4.0, -22.0, 88.0)
		var throw_offset: Vector3 = Vector3(0.0, -0.04, -0.12)
		attack.windup_rotation_degrees = throw_rotation
		attack.strike_rotation_degrees = throw_rotation
		attack.recovery_rotation_degrees = throw_rotation
		attack.windup_offset = throw_offset
		attack.strike_offset = throw_offset
		attack.recovery_offset = throw_offset
	elif weapon_class == "staff" and input_kind == "heavy":
		# The grounded Heavy charge is a front-facing spinning guard, not a perch.
		var guard_rotation: Vector3 = Vector3(-88.0, 0.0, 0.0)
		var guard_offset: Vector3 = Vector3(0.0, -0.12, -0.42)
		attack.windup_rotation_degrees = guard_rotation
		attack.strike_rotation_degrees = guard_rotation
		attack.recovery_rotation_degrees = guard_rotation
		attack.windup_offset = guard_offset
		attack.strike_offset = guard_offset
		attack.recovery_offset = guard_offset
	return attack


static func build_sustain_pulse(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	charge_ratio: float
) -> WeaponAttackDefinition:
	var attack: WeaponAttackDefinition = BaseCatalogScript.build_sustain_pulse(
		base_attack,
		weapon_class,
		charge_ratio
	)
	if attack != null:
		attack.footwork_profile_id = ""
	return attack


static func build_release_attack(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	input_kind: String,
	charge_ratio: float
) -> WeaponAttackDefinition:
	var attack: WeaponAttackDefinition = BaseCatalogScript.build_release_attack(
		base_attack,
		weapon_class,
		input_kind,
		charge_ratio
	)
	if attack == null:
		return null
	attack.footwork_profile_id = ""
	if weapon_class == "axe" and input_kind == "heavy":
		var charge: float = clampf(charge_ratio, 0.0, 1.0)
		attack.display_name = "Levering Guillotine"
		attack.startup_time = lerpf(0.68, 0.8, charge)
		attack.active_time = 0.13
		attack.recovery_time = lerpf(0.32, 0.4, charge)
		attack.combo_timeout = 0.42
		attack.cancel_window_start_normalized = 0.82
		attack.attack_range = maxf(attack.attack_range, lerpf(3.15, 3.8, charge))
		attack.cone_angle_degrees = 128.0
		attack.attack_center_forward_offset = lerpf(1.0, 1.34, charge)
		attack.max_targets = maxi(attack.max_targets, 7)
		attack.windup_rotation_degrees = Vector3(-108.0, -4.0, 90.0)
		attack.strike_rotation_degrees = Vector3(94.0, 4.0, 90.0)
		attack.recovery_rotation_degrees = Vector3(28.0, 2.0, 88.0)
		attack.windup_offset = Vector3(0.0, 0.07, 0.06)
		attack.strike_offset = Vector3(0.0, -0.14, -0.38)
		attack.recovery_offset = Vector3(0.0, -0.03, -0.08)
		_add_tag(attack, "axe_edge_aligned")
		_add_tag(attack, "axe_exploit")
		_add_tag(attack, "opening_exploit")
		_add_tag(attack, "axe_charge_fast")
	return attack


static func build_axe_plant_pulse(
	base_attack: WeaponAttackDefinition,
	charge_ratio: float
) -> WeaponAttackDefinition:
	var attack: WeaponAttackDefinition = BaseCatalogScript.build_axe_plant_pulse(
		base_attack,
		charge_ratio
	)
	if attack != null:
		attack.footwork_profile_id = ""
		_add_tag(attack, "axe_opener")
		_add_tag(attack, "opening_pressure")
		_add_tag(attack, "axe_edge_aligned")
	return attack


static func _add_tag(
	attack: WeaponAttackDefinition,
	tag: String
) -> void:
	if attack != null and tag != "" and not attack.extra_tags.has(tag):
		attack.extra_tags.append(tag)