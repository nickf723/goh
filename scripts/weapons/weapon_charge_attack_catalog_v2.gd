extends RefCounted
class_name WeaponChargeAttackCatalogV2

const BaseCatalogScript = preload(
	"res://scripts/weapons/weapon_charge_attack_catalog_v1.gd"
)

const MODE_SUSTAIN: String = BaseCatalogScript.MODE_SUSTAIN
const MODE_RELEASE: String = BaseCatalogScript.MODE_RELEASE


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
