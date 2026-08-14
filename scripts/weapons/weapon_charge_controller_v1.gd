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


func _handle_charge_input(event: InputEvent) -> bool:
	var input_kind: String = ""
	var pressed: bool = false
	var released: bool = false
	if event.is_action_pressed(CHARGE_LIGHT_ACTION):
		input_kind = INPUT_LIGHT
		pressed = true
	elif event.is_action_released(CHARGE_LIGHT_ACTION):
		input_kind = INPUT_LIGHT
		released = true
	elif event.is_action_pressed(CHARGE_HEAVY_ACTION):
		input_kind = INPUT_HEAVY
		pressed = true
	elif event.is_action_released(CHARGE_HEAVY_ACTION):
		input_kind = INPUT_HEAVY
		released = true
	else:
		return false

	if charge_active:
		if released and input_kind == charge_input_kind:
			_release_active_charge()
			return true
		return input_kind == charge_input_kind

	if charge_pending:
		if released and input_kind == charge_input_kind:
			_fire_pending_as_tap()
			return true
		return input_kind == charge_input_kind

	if not pressed or current_attack != null or equipped_weapon == null:
		return false
	var profile: Dictionary = ChargeCatalogScript.get_profile(
		equipped_weapon.weapon_class,
		input_kind
	)
	if profile.is_empty() or not _can_begin_weapon_charge():
		return false
	return _begin_charge_pending(input_kind, profile)


func _begin_charge_pending(input_kind: String, profile: Dictionary) -> bool:
	var base_attack: WeaponAttackDefinition = resolve_idle_attack(input_kind)
	if base_attack == null:
		return false
	charge_pending = true
	charge_active = false
	charge_input_kind = input_kind
	charge_profile = profile.duplicate(true)
	charge_base_attack = base_attack.duplicate(true) as WeaponAttackDefinition
	charge_elapsed = 0.0
	charge_pulse_elapsed = 0.0
	released_charge_ratio = 0.0
	return charge_base_attack != null


func _fire_pending_as_tap() -> void:
	var attack: WeaponAttackDefinition = charge_base_attack
	_clear_charge_state(false)
	if attack != null:
		start_attack(attack)


func _can_begin_weapon_charge() -> bool:
	if current_attack != null:
		return false
	if action_state != null and not action_state.can_attack():
		return false
	if dodge_controller != null and dodge_controller.is_dodge_active():
		return false
	var actor: Node3D = get_actor()
	return actor is CharacterBody3D and (actor as CharacterBody3D).is_on_floor()
