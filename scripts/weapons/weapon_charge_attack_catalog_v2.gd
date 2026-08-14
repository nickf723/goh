extends RefCounted
class_name WeaponChargeAttackCatalogV2

const BaseCatalogScript = preload(
	"res://scripts/weapons/weapon_charge_attack_catalog_v1.gd"
)

const MODE_SUSTAIN: String = "sustain"
const MODE_RELEASE: String = "release"


static func get_profile(weapon_class: String, input_kind: String) -> Dictionary:
	return BaseCatalogScript.get_profile(weapon_class, input_kind)


static func build_hold_attack(
	base_attack: WeaponAttackDefinition,
	weapon_class: String,
	input_kind: String
) -> WeaponAttackDefinition:
	var attack: WeaponAttackDefinition = BaseCatalogScript.build_hold_attack(
		base_attack,
		weapon_class,
		input_kind
	)
	if attack == null:
		return null
	# Blend into the held pose quickly, then remain in a long active phase. The
	# previous 60-second startup made the skeleton spend the whole charge barely
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
		# Keep the proxy axe in its authored windup instead of allowing the visual
		# tween to finish at the ordinary downward contact pose while charging.
		attack.strike_rotation_degrees = attack.windup_rotation_degrees
		attack.recovery_rotation_degrees = attack.windup_rotation_degrees
		attack.strike_offset = attack.windup_offset
		attack.recovery_offset = attack.windup_offset
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
	if attack != null:
		attack.footwork_profile_id = ""
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
	return attack
