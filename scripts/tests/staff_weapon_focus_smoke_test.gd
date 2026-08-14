extends Node

const ChargeCatalogScript = preload(
	"res://scripts/weapons/weapon_charge_attack_catalog_v2.gd"
)
const StaffControllerScript = preload(
	"res://scripts/weapons/weapon_staff_focus_controller_v3.gd"
)
const StaffRigScene: PackedScene = preload(
	"res://scenes/weapons/staff_weapon_rig.tscn"
)
const CombatPlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player_combat_v2.tscn"
)
const SkeletalStaffScene: PackedScene = preload(
	"res://scenes/actors/player/grace_humanoid_skeletal_proxy_v2.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	_validate_staff_charge_profiles()
	_validate_controller_contract()
	_validate_visible_guard_twirl()
	_validate_live_scene_dependencies()
	if failures.is_empty():
		print("STAFF_WEAPON_FOCUS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("STAFF_WEAPON_FOCUS_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _validate_staff_charge_profiles() -> void:
	var light_profile: Dictionary = ChargeCatalogScript.get_profile("staff", "light")
	var heavy_profile: Dictionary = ChargeCatalogScript.get_profile("staff", "heavy")
	if str(light_profile.get("id", "")) != "staff_returning_throw":
		failures.append("Staff Light charge must remain the returning throw")
	if str(heavy_profile.get("id", "")) != "staff_angel_ring":
		failures.append("Staff Heavy charge must remain Whirling Bastion")


func _validate_controller_contract() -> void:
	var controller: Node = StaffControllerScript.new()
	if controller == null:
		failures.append("Focused Staff controller could not instantiate")
		return
	if not controller.has_method("get_staff_focus_v3_debug_data"):
		failures.append("Focused Staff controller is missing camera-decoupling diagnostics")
	if not controller.has_method("get_staff_aerial_vault_state"):
		failures.append("Focused Staff controller lost the repeatable aerial vault state machine")
	controller.free()


func _validate_visible_guard_twirl() -> void:
	var rig: Node3D = StaffRigScene.instantiate() as Node3D
	if rig == null:
		failures.append("Staff runtime rig could not instantiate")
		return
	add_child(rig)
	var weapon: WeaponDefinition = WeaponDefinition.new()
	weapon.weapon_class = "staff"
	weapon.visual_primary_color = Color(0.08, 0.72, 0.78, 1.0)
	weapon.visual_accent_color = Color(0.32, 1.0, 0.94, 1.0)
	if rig.has_method("configure_weapon"):
		rig.call("configure_weapon", weapon, null)
	var attack: WeaponAttackDefinition = WeaponAttackDefinition.new()
	attack.attack_id = "staff_guard_test"
	attack.extra_tags = ["staff_angel_ring"]
	rig.call("begin_attack", attack, 1.0)
	rig.call("update_attack_pose", attack, 0.1, 1.0)
	var first_axis: Vector3 = rig.transform.basis.z.normalized()
	rig.call("update_attack_pose", attack, 0.24, 1.0)
	var second_axis: Vector3 = rig.transform.basis.z.normalized()
	if first_axis.distance_to(second_axis) <= 0.2:
		failures.append("Whirling Bastion must visibly rotate the staff length axis")
	if not rig.has_method("get_guard_spin_phase_radians"):
		failures.append("Staff rig must expose its guard phase for synchronized body animation")
	rig.queue_free()


func _validate_live_scene_dependencies() -> void:
	if CombatPlayerScene == null:
		failures.append("Combat player scene failed to preload")
	if SkeletalStaffScene == null:
		failures.append("Focused Staff skeletal scene failed to preload")
