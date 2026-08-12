extends "res://scripts/levels/prototype_weapon_arsenal_dojo.gd"
class_name PrototypeWeaponArsenalDojoV2

const FlailRigScene: PackedScene = preload(
	"res://scenes/weapons/flail_weapon_rig.tscn"
)


func _build_pedestals() -> void:
	super._build_pedestals()
	var flail: WeaponDefinition = weapon_cache.get("flail") as WeaponDefinition
	if flail == null:
		return
	flail.runtime_rig_scene = FlailRigScene
	flail.set_meta("physics_flexible_weapon", true)
	var pedestal: SandboxWeaponPedestal = get_node_or_null(
		"FlailPedestal"
	) as SandboxWeaponPedestal
	if pedestal != null:
		pedestal.configure(
			flail,
			WeaponSandboxCatalogScript.get_status_label("flail") + " • PHYSICS"
		)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var flail: WeaponDefinition = weapon_cache.get("flail") as WeaponDefinition
	data["combat_v2"] = true
	data["physical_flail"] = (
		flail != null
		and flail.runtime_rig_scene == FlailRigScene
	)
	return data
