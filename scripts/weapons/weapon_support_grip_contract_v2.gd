extends "res://scripts/weapons/weapon_support_grip_contract.gd"
class_name WeaponSupportGripContractV2

const AXE_FALLBACK_GRIP: Vector3 = Vector3(0.0, 0.0, -0.44)


func supports_current_weapon() -> bool:
	if super.supports_current_weapon():
		return true
	return (
		weapon_controller != null
		and weapon_controller.equipped_weapon != null
		and weapon_controller.equipped_weapon.weapon_class == "axe"
	)


func get_support_grip_target() -> Node3D:
	return support_grip_target if supports_current_weapon() else null


func get_support_influence() -> float:
	if not supports_current_weapon():
		return 0.0
	var rig: Node3D = weapon_controller.runtime_weapon_rig
	if rig != null and rig.has_method("get_support_grip_influence"):
		return default_influence * clampf(
			float(rig.call("get_support_grip_influence")),
			0.0,
			1.0
		)
	return default_influence


func _update_target() -> void:
	if (
		weapon_controller == null
		or weapon_controller.equipped_weapon == null
		or weapon_controller.equipped_weapon.weapon_class != "axe"
	):
		super._update_target()
		return
	source_kind = "none"
	current_weapon_class = "axe"
	if support_grip_target == null:
		return
	var authored: Node3D = _find_authored_support_grip()
	if authored != null:
		support_grip_target.global_transform = authored.global_transform
		source_kind = "authored_marker"
		return
	var model_root: Node3D = weapon_controller.weapon_model_root
	if model_root == null:
		return
	support_grip_target.global_transform = (
		model_root.global_transform
		* Transform3D(Basis.IDENTITY, AXE_FALLBACK_GRIP)
	)
	source_kind = "axe_fallback"


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["support_grip_contract_v2"] = true
	data["axe_support_grip"] = (
		current_weapon_class == "axe"
		and supports_current_weapon()
	)
	return data
