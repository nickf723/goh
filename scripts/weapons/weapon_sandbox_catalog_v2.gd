extends RefCounted
class_name WeaponSandboxCatalogV2

const BaseCatalogScript = preload(
	"res://scripts/weapons/weapon_sandbox_catalog.gd"
)
const AxeFocusCatalogScript = preload(
	"res://scripts/weapons/axe_weapon_focus_catalog_v1.gd"
)


static func get_all_weapon_classes() -> Array[String]:
	return BaseCatalogScript.get_all_weapon_classes()


static func get_weapon(weapon_class: String) -> WeaponDefinition:
	if weapon_class == "axe":
		return AxeFocusCatalogScript.build_weapon()
	return BaseCatalogScript.get_weapon(weapon_class)


static func is_authored_class(weapon_class: String) -> bool:
	return weapon_class == "axe" or BaseCatalogScript.is_authored_class(weapon_class)


static func get_status_label(weapon_class: String) -> String:
	return "AUTHORED" if is_authored_class(weapon_class) else "PROXY"


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
