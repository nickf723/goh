extends "res://scripts/weapons/combat_weapon_controller_v4.gd"
class_name WeaponChargeRuntime

const ChargeCatalogScript = preload("res://scripts/weapons/weapon_charge_attack_catalog_v2.gd")
const ChargeMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")
const ChargeInfusionCatalogScript = preload("res://scripts/weapons/weapon_infusion_catalog.gd")
const CHARGE_LIGHT_ACTION: StringName = &"weapon_light_attack"
const CHARGE_HEAVY_ACTION: StringName = &"weapon_heavy_attack"
const CHARGE_MOVEMENT_META: StringName = &"weapon_charge_movement_multiplier"

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
var released_charge_forward: Vector3 = Vector3.FORWARD

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
		return input_kind == charge_input_kind
	if charge_pending:
		if released and input_kind == charge_input_kind:
			_fire_pending_as_tap()
		return input_kind == charge_input_kind
	if not pressed or current_attack != null or equipped_weapon == null:
		return false
	var profile: Dictionary = ChargeCatalogScript.get_profile(
		equipped_weapon.weapon_class,
		input_kind
	)
	if profile.is_empty() or not _can_begin_weapon_charge():
		return false
	var base_attack: WeaponAttackDefinition = resolve_idle_attack(input_kind)
	if base_attack == null:
		return false
	charge_pending = true
	charge_input_kind = input_kind
	charge_profile = profile.duplicate(true)
	charge_base_attack = base_attack.duplicate(true) as WeaponAttackDefinition
	charge_elapsed = 0.0
	charge_pulse_elapsed = 0.0
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


func _update_charge_state(delta: float) -> void:
	if not charge_pending and not charge_active:
		return
	if equipped_weapon == null:
		_cancel_weapon_charge()
		return
	if action_state != null and (
		action_state.is_defeated
		or action_state.is_casting
		or action_state.is_dodging
		or action_state.is_staggered
	):
		_cancel_weapon_charge()
		return
	charge_elapsed += maxf(delta, 0.0)
	if charge_pending:
		if charge_elapsed >= float(charge_profile.get("threshold", 0.25)):
			_activate_weapon_charge()
		return
	if not _is_charge_button_held():
		_release_active_charge()
		return
	if str(charge_profile.get("mode", "")) == ChargeCatalogScript.MODE_SUSTAIN:
		charge_pulse_elapsed += maxf(delta, 0.0)
		var interval: float = maxf(
			float(charge_profile.get("pulse_interval", 0.45)),
			0.12
		)
		if charge_pulse_elapsed >= interval:
			charge_pulse_elapsed = fmod(charge_pulse_elapsed, interval)
			_execute_sustain_charge_pulse()


func _activate_weapon_charge() -> void:
	if charge_base_attack == null or equipped_weapon == null:
		_cancel_weapon_charge()
		return
	var hold_attack: WeaponAttackDefinition = ChargeCatalogScript.build_hold_attack(
		charge_base_attack,
		equipped_weapon.weapon_class,
		charge_input_kind
	)
	if hold_attack == null:
		_cancel_weapon_charge()
		return
	charge_pending = false
	charge_active = true
	current_attack = hold_attack
	current_attack_elapsed = 0.0
	current_phase = "active"
	attack_hit_applied = true
	attack_forward_override = resolve_attack_forward(hold_attack)
	_apply_charge_movement_contract()
	if action_state != null:
		action_state.begin_attack(60.0)
	play_attack_visual(hold_attack)
	attack_started.emit(hold_attack)
	emit_combo_state()


func _release_active_charge() -> void:
	if not charge_active:
		return
	var mode: String = str(charge_profile.get("mode", ""))
	var weapon_class: String = equipped_weapon.weapon_class if equipped_weapon != null else ""
	var input_kind: String = charge_input_kind
	var base_attack: WeaponAttackDefinition = charge_base_attack
	released_charge_ratio = get_weapon_charge_ratio()
	released_charge_forward = attack_forward_override
	if released_charge_forward.length_squared() <= 0.0001:
		released_charge_forward = get_attack_forward()
	released_charge_forward.y = 0.0
	if released_charge_forward.length_squared() <= 0.0001:
		released_charge_forward = Vector3.FORWARD
	else:
		released_charge_forward = released_charge_forward.normalized()
	_clear_charge_state(true)
	if mode == ChargeCatalogScript.MODE_RELEASE and base_attack != null:
		var release_attack: WeaponAttackDefinition = ChargeCatalogScript.build_release_attack(
			base_attack,
			weapon_class,
			input_kind,
			released_charge_ratio
		)
		if release_attack != null:
			pending_context_forward = released_charge_forward
			start_attack(release_attack)


func _cancel_weapon_charge() -> void:
	_clear_charge_state(charge_active)


func _clear_charge_state(clear_pose: bool) -> void:
	_clear_charge_movement_contract()
	if clear_pose and current_attack != null and current_attack.extra_tags.has("weapon_charge_hold"):
		current_attack = null
		current_attack_elapsed = 0.0
		current_phase = "idle"
		attack_hit_applied = false
		attack_forward_override = Vector3.ZERO
		if action_state != null and action_state.is_attacking:
			action_state.end_attack()
		reset_visual_pose()
	charge_pending = false
	charge_active = false
	charge_input_kind = ""
	charge_profile.clear()
	charge_base_attack = null
	charge_elapsed = 0.0
	charge_pulse_elapsed = 0.0
	emit_combo_state()


func cancel_current_attack(reason: String = "cancelled") -> void:
	var charge_was_active: bool = charge_pending or charge_active
	super.cancel_current_attack(reason)
	if charge_was_active:
		_clear_charge_state(false)


func _apply_charge_movement_contract() -> void:
	var actor: Node3D = get_actor()
	if actor == null:
		return
	var multiplier: float = clampf(
		float(charge_profile.get("movement_multiplier", 1.0)),
		0.0,
		1.0
	)
	actor.set_meta(CHARGE_MOVEMENT_META, multiplier)


func _clear_charge_movement_contract() -> void:
	var actor: Node3D = get_actor()
	if actor != null and actor.has_meta(CHARGE_MOVEMENT_META):
		actor.remove_meta(CHARGE_MOVEMENT_META)


func _is_charge_button_held() -> bool:
	if charge_input_kind == INPUT_LIGHT:
		return Input.is_action_pressed(CHARGE_LIGHT_ACTION)
	if charge_input_kind == INPUT_HEAVY:
		return Input.is_action_pressed(CHARGE_HEAVY_ACTION)
	return false


func get_weapon_charge_ratio() -> float:
	if charge_profile.is_empty():
		return 0.0
	var threshold: float = float(charge_profile.get("threshold", 0.25))
	var full_charge: float = maxf(
		float(charge_profile.get("full_charge", 1.0)),
		threshold + 0.01
	)
	return clampf(
		(charge_elapsed - threshold) / (full_charge - threshold),
		0.0,
		1.0
	)


func get_weapon_charge_elapsed() -> float:
	return maxf(charge_elapsed, 0.0)


func get_released_charge_forward() -> Vector3:
	return released_charge_forward


func is_chain_orbit_charging() -> bool:
	return charge_active and str(charge_profile.get("id", "")) == "chain_orbit"


func is_axe_lever_charge_active() -> bool:
	return charge_active and str(charge_profile.get("id", "")) == "axe_lever_vault"


func is_staff_map_vault_charging() -> bool:
	return charge_active and str(charge_profile.get("id", "")) == "staff_map_vault"


func _execute_sustain_charge_pulse() -> void:
	pass


func _apply_chain_charge_tug() -> void:
	pass
