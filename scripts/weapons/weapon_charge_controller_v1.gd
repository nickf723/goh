extends "res://scripts/weapons/combat_weapon_controller_v4.gd"
class_name WeaponChargeControllerV1

const ChargeCatalogScript = preload("res://scripts/weapons/weapon_charge_attack_catalog_v1.gd")
const CHARGE_LIGHT_ACTION: StringName = &"weapon_light_attack"
const CHARGE_HEAVY_ACTION: StringName = &"weapon_heavy_attack"

@export_group("Charge Attacks")
@export_range(0.0, 4.0, 0.05) var chain_charge_tug_speed: float = 2.15

@export_group("Bow Aim Camera")
@export_range(0.0, 1.5, 0.05) var bow_shoulder_offset: float = 0.72
@export_range(35.0, 80.0, 1.0) var bow_aim_fov: float = 58.0
@export_range(0.05, 0.4, 0.01) var bow_camera_transition: float = 0.14

var charge_pending: bool = false
var charge_active: bool = false
var charge_input_kind: String = ""
var charge_profile: Dictionary = {}
var charge_base_attack: WeaponAttackDefinition
var charge_elapsed: float = 0.0
var charge_pulse_elapsed: float = 0.0
var released_charge_ratio: float = 0.0

var bow_aim_camera: Camera3D
var bow_aim_spring: SpringArm3D
var bow_original_fov: float = 75.0
var bow_original_spring_position: Vector3 = Vector3.ZERO
var bow_camera_tween: Tween


func _process(delta: float) -> void:
	super._process(delta)
	_update_charge_state(delta)
	_apply_chain_charge_tug()


func _unhandled_input(event: InputEvent) -> void:
	if _handle_charge_input(event):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
