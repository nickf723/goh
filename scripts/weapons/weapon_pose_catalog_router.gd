extends RefCounted
class_name WeaponPoseCatalogRouter

const WeaponCharacterPoseCatalogScript = preload(
	"res://scripts/weapons/weapon_character_pose_catalog.gd"
)
const RuviaHalberdPoseCatalogScript = preload(
	"res://scripts/weapons/ruvia_halberd_pose_catalog.gd"
)
const WeaponClassMotionCatalogScript = preload(
	"res://scripts/weapons/weapon_class_motion_catalog.gd"
)


static func has_profile(profile_id: String) -> bool:
	return (
		RuviaHalberdPoseCatalogScript.has_profile(profile_id)
		or WeaponCharacterPoseCatalogScript.has_profile(profile_id)
		or WeaponClassMotionCatalogScript.has_profile(profile_id)
	)


static func get_profile(profile_id: String) -> Dictionary:
	if RuviaHalberdPoseCatalogScript.has_profile(profile_id):
		return RuviaHalberdPoseCatalogScript.get_profile(profile_id)
	if WeaponCharacterPoseCatalogScript.has_profile(profile_id):
		return WeaponCharacterPoseCatalogScript.get_profile(profile_id)
	return WeaponClassMotionCatalogScript.get_profile(profile_id)


static func sample_attack(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float = 1.0
) -> Dictionary:
	if attack == null:
		return {}
	if RuviaHalberdPoseCatalogScript.has_profile(attack.character_pose_id):
		return RuviaHalberdPoseCatalogScript.sample_attack(
			attack,
			elapsed,
			attack_speed
		)
	if WeaponCharacterPoseCatalogScript.has_profile(attack.character_pose_id):
		return WeaponCharacterPoseCatalogScript.sample_attack(
			attack,
			elapsed,
			attack_speed
		)
	return WeaponClassMotionCatalogScript.sample_attack(
		attack,
		elapsed,
		attack_speed
	)


static func validate_profiles() -> Array[String]:
	var failures: Array[String] = []
	for failure: String in WeaponCharacterPoseCatalogScript.validate_profiles():
		failures.append(failure)
	for failure: String in RuviaHalberdPoseCatalogScript.validate_profiles():
		failures.append(failure)
	for failure: String in WeaponClassMotionCatalogScript.validate_profiles():
		failures.append(failure)
	return failures
