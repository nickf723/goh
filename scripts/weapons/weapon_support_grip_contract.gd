extends Node3D
class_name WeaponSupportGripContract

const WeaponPresentationAssetContractScript = preload(
	"res://scripts/weapons/weapon_presentation_asset_contract.gd"
)

const SUPPORTED_CLASSES: Array[String] = ["hammer", "lance", "halberd", "staff", "scythe"]
const FALLBACK_LOCAL_POSITIONS: Dictionary = {
	"hammer": Vector3(0.12, 0.0, -0.30),
	"lance": Vector3(0.12, 0.0, -0.36),
	"halberd": Vector3(0.0, 0.0, -0.38),
	"staff": Vector3(0.0, 0.0, -0.34),
	"scythe": Vector3(0.0, 0.0, -0.36),
}

@export_range(0.0, 1.0, 0.05) var default_influence: float = 0.88
@export var authored_marker_name: StringName = &"SupportGrip"

var weapon_controller: WeaponController
var support_grip_target: Marker3D
var source_kind: String = "none"
var current_weapon_class: String = ""


func _ready() -> void:
	process_priority = 212
	weapon_controller = get_parent() as WeaponController
	support_grip_target = Marker3D.new()
	support_grip_target.name = "SupportGripTarget"
	add_child(support_grip_target)
	add_to_group("weapon_support_grip_contract")
	add_to_group("debuggable")
	set_process(true)
	_update_target()


func _process(_delta: float) -> void:
	_update_target()


func supports_current_weapon() -> bool:
	return weapon_controller != null and weapon_controller.equipped_weapon != null and SUPPORTED_CLASSES.has(weapon_controller.equipped_weapon.weapon_class)


func get_support_grip_target() -> Node3D:
	return support_grip_target if supports_current_weapon() else null


func get_support_influence() -> float:
	return default_influence if supports_current_weapon() else 0.0


func _update_target() -> void:
	source_kind = "none"
	current_weapon_class = ""
	if support_grip_target == null or weapon_controller == null or weapon_controller.equipped_weapon == null:
		return
	current_weapon_class = weapon_controller.equipped_weapon.weapon_class
	if not SUPPORTED_CLASSES.has(current_weapon_class):
		return
	var authored: Node3D = _find_authored_support_grip()
	if authored != null:
		support_grip_target.global_transform = authored.global_transform
		source_kind = "authored_marker"
		return
	var model_root: Node3D = weapon_controller.weapon_model_root
	if model_root == null:
		return
	var local_position: Vector3 = FALLBACK_LOCAL_POSITIONS.get(current_weapon_class, Vector3.ZERO) as Vector3
	support_grip_target.global_transform = model_root.global_transform * Transform3D(Basis.IDENTITY, local_position)
	source_kind = "prototype_fallback"


func _find_authored_support_grip() -> Node3D:
	if weapon_controller == null or weapon_controller.runtime_weapon_rig == null:
		return null
	var rig: Node3D = weapon_controller.runtime_weapon_rig
	var marker: Node3D = WeaponPresentationAssetContractScript.find_marker(rig, "support_grip")
	if marker != null:
		return marker
	var direct: Node3D = rig.get_node_or_null(NodePath(str(authored_marker_name))) as Node3D
	if direct != null:
		return direct
	return rig.find_child(str(authored_marker_name), true, false) as Node3D


func get_debug_data() -> Dictionary:
	return {
		"support_grip_contract": true,
		"weapon_class": current_weapon_class,
		"supported": supports_current_weapon(),
		"source": source_kind,
		"target_position": support_grip_target.global_position if support_grip_target != null else Vector3.ZERO,
		"influence": get_support_influence(),
		"asset_marker_contract": true,
	}
