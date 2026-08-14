extends "res://scripts/weapons/weapon_staff_axe_focus_controller_v1.gd"
class_name WeaponStaffAxeFocusControllerV2

const AxeTechniqueCatalogScript = preload(
	"res://scripts/weapons/axe_weapon_technique_catalog_v2.gd"
)

@export_group("Axe Counter Charge")
@export_range(0.1, 1.0, 0.01) var axe_counter_release_window: float = 0.38
@export_range(0.0, 0.4, 0.01) var axe_counter_sweet_spot_seconds: float = 0.11
@export_range(30.0, 180.0, 1.0) var axe_counter_guard_angle_degrees: float = 150.0
@export_range(0.0, 4.0, 0.05) var axe_counter_recoil_speed: float = 0.55
@export_range(0.01, 0.3, 0.01) var axe_counter_recoil_seconds: float = 0.08

@export_group("Axe Aerial Identity")
@export_range(4.0, 16.0, 0.1) var axe_aerial_light_forward_speed: float = 10.2
@export_range(4.0, 18.0, 0.1) var axe_aerial_heavy_fall_speed: float = 12.6
@export_range(0.0, 10.0, 0.1) var axe_aerial_heavy_forward_speed: float = 4.6

var staff_throw_camera_release_heading: Vector3 = Vector3.ZERO

var axe_counter_caught: bool = false
var axe_counter_spent: bool = false
var axe_counter_elapsed_since_block: float = 0.0
var axe_counter_target: Node3D
var axe_counter_reversal_target: Node3D
var axe_counter_momentum_awarded_serial: int = -1


func _process(delta: float) -> void:
	super._process(delta)
	if axe_counter_caught and not axe_counter_spent:
		axe_counter_elapsed_since_block += maxf(delta, 0.0)
		if axe_counter_elapsed_since_block > axe_counter_release_window:
			axe_counter_spent = true


func equip_weapon(new_weapon: WeaponDefinition) -> void:
	if new_weapon == null or new_weapon.weapon_class != "axe":
		_reset_axe_counter_state(true)
	if new_weapon == null or new_weapon.weapon_class != "staff":
		staff_throw_camera_release_heading = Vector3.ZERO
	super.equip_weapon(new_weapon)


func _update_charge_hold_heading(delta: float) -> void:
	if is_staff_returning_throw_charging():
		_prime_staff_throw_camera_heading()
		staff_throw_camera_release_heading = _get_camera_planar_heading()
		return
	if is_axe_counter_guard_charging():
		var heading: Vector3 = _get_camera_planar_heading()
		if heading.length_squared() > 0.0001:
			attack_forward_override = heading
		return
	super._update_charge_hold_heading(delta)


func _release_active_charge() -> void:
	if is_axe_counter_guard_charging():
		_release_axe_counter_guard()
		return
	if is_staff_returning_throw_charging():
		staff_throw_camera_release_heading = _get_camera_planar_heading()
		if staff_throw_camera_release_heading.length_squared() > 0.0001:
			staff_charge_heading = staff_throw_camera_release_heading
			staff_charge_heading_initialized = true
			attack_forward_override = staff_throw_camera_release_heading
	super._release_active_charge()


func _release_axe_counter_guard() -> void:
	var caught: bool = axe_counter_caught
	var within_window: bool = (
		caught
		and not axe_counter_spent
		and axe_counter_elapsed_since_block <= axe_counter_release_window
	)
	var target: Node3D = axe_counter_target
	var elapsed_after_block: float = axe_counter_elapsed_since_block
	var counter_heading: Vector3 = _get_camera_planar_heading()
	if target != null and is_instance_valid(target):
		var actor: Node3D = get_actor()
		if actor != null:
			counter_heading = target.global_position - actor.global_position
			counter_heading.y = 0.0
			if counter_heading.length_squared() > 0.0001:
				counter_heading = counter_heading.normalized()
	var timing_quality: float = _get_axe_counter_timing_quality(
		elapsed_after_block
	)

	# MODE_COUNTER deliberately has no generic release attack. Clearing the hold
	# first gives the authored reversal a clean action-state and animation start.
	super._release_active_charge()
	if not within_window or target == null or not is_instance_valid(target):
		_reset_axe_counter_state(true)
		return

	axe_counter_reversal_target = target
	_open_axe_target(target)
	pending_context_forward = counter_heading
	var reversal: WeaponAttackDefinition = (
		AxeTechniqueCatalogScript.build_counter_reversal_attack(timing_quality)
	)
	if reversal == null or not start_attack(reversal):
		_clear_axe_target_opening(target)
		_reset_axe_counter_state(true)
		return
	show_message(
		"Perfect Breakwater Reversal!"
		if timing_quality >= 0.72
		else "Breakwater Reversal!"
	)


func _clear_charge_state(clear_pose: bool) -> void:
	var clearing_counter: bool = (
		str(charge_profile.get("id", "")) == "axe_counter_guard"
		or is_axe_counter_guard_charging()
	)
	super._clear_charge_state(clear_pose)
	if clearing_counter:
		_reset_axe_counter_state(false)


func resolve_incoming_weapon_counter(
	payload: DamagePayload,
	attacker: Node3D,
	incoming_direction: Vector3
) -> Dictionary:
	if (
		payload == null
		or attacker == null
		or not is_instance_valid(attacker)
		or not is_axe_counter_guard_charging()
		or current_attack == null
		or not current_attack.extra_tags.has("axe_counter_guard")
		or axe_counter_caught
		or axe_counter_spent
	):
		return {}
	var normalized_hit_type: String = payload.hit_type.strip_edges().to_lower()
	if normalized_hit_type in [
		"status",
		"damage_over_time",
		"surface_hazard",
		"terrain_hazard",
		"grab",
	]:
		return {}
	for raw_tag: String in payload.tags:
		if raw_tag.strip_edges().to_lower() in [
			"unblockable",
			"grab",
			"status_tick",
			"surface_hazard",
			"terrain_hazard",
		]:
			return {}

	var guard_forward: Vector3 = attack_forward_override
	guard_forward.y = 0.0
	var incoming: Vector3 = incoming_direction
	incoming.y = 0.0
	if guard_forward.length_squared() > 0.0001 and incoming.length_squared() > 0.0001:
		var minimum_dot: float = cos(
			deg_to_rad(axe_counter_guard_angle_degrees * 0.5)
		)
		if guard_forward.normalized().dot(incoming.normalized()) < minimum_dot:
			return {}

	axe_counter_caught = true
	axe_counter_spent = false
	axe_counter_elapsed_since_block = 0.0
	axe_counter_target = attacker
	return {
		"handled": true,
		"outcome": "axe_counter_block",
		"message": "Axe Catch! Release Light for the reversal.",
		"damage": 0,
		"stance_damage": 0,
		"health_damage": 0,
		"stamina_cost": 0,
		"stance_cost": 0,
		"counter_window": axe_counter_release_window,
		"recoil_seconds": axe_counter_recoil_seconds,
		"recoil_speed": axe_counter_recoil_speed,
		"feedback_color": Color(0.18, 0.7, 1.0, 0.98),
		"feedback_duration": 0.22,
		"weapon_counter": "axe_breakwater_catch",
	}


func _prepare_combat_flair_attack(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	var resolved: WeaponAttackDefinition = super._prepare_combat_flair_attack(attack)
	if resolved == null or not _is_axe_equipped():
		return resolved
	if resolved.extra_tags.has("aerial_light"):
		return AxeTechniqueCatalogScript.configure_aerial_light(resolved)
	if resolved.extra_tags.has("aerial_heavy"):
		return AxeTechniqueCatalogScript.configure_aerial_heavy(resolved)
	return resolved


func apply_aerial_technique_motion(context_id: String) -> void:
	if not _is_axe_equipped():
		super.apply_aerial_technique_motion(context_id)
		return
	var actor: Node3D = get_actor()
	if not actor is CharacterBody3D:
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	if context_id == WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT:
		body.velocity.y = maxf(body.velocity.y, -0.28)
		_apply_planar_aerial_speed(
			body,
			axe_aerial_light_forward_speed,
			0.92
		)
		plunge_landing_armed = false
		plunge_max_fall_speed = 0.0
		return
	if context_id == WeaponTechniqueCatalogScript.CONTEXT_AERIAL_HEAVY:
		body.velocity.y = minf(body.velocity.y, -axe_aerial_heavy_fall_speed)
		_apply_planar_aerial_speed(
			body,
			axe_aerial_heavy_forward_speed,
			0.72
		)
		plunge_landing_armed = true
		plunge_max_fall_speed = absf(minf(body.velocity.y, 0.0))
		return
	super.apply_aerial_technique_motion(context_id)


func apply_aerial_hit_followthrough(targets: Array[Node]) -> void:
	if (
		_is_axe_equipped()
		and active_technique_id
		== WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT
	):
		var actor: Node3D = get_actor()
		if actor is CharacterBody3D:
			var body: CharacterBody3D = actor as CharacterBody3D
			body.velocity.y = maxf(body.velocity.y, -0.2)
			_apply_planar_aerial_speed(
				body,
				axe_aerial_light_forward_speed * 0.9,
				0.86
			)
		return
	super.apply_aerial_hit_followthrough(targets)


func _apply_axe_momentum_to_attack(
	attack: WeaponAttackDefinition
) -> int:
	if attack != null and attack.extra_tags.has("axe_counter_reversal"):
		return 0
	return super._apply_axe_momentum_to_attack(attack)


func find_targets(attack: WeaponAttackDefinition) -> Array[Node]:
	var targets: Array[Node] = super.find_targets(attack)
	if (
		attack == null
		or not attack.extra_tags.has("axe_counter_reversal")
		or axe_counter_reversal_target == null
		or not is_instance_valid(axe_counter_reversal_target)
	):
		return targets
	var actor: Node3D = get_actor()
	if actor == null:
		return targets
	var offset: Vector3 = (
		axe_counter_reversal_target.global_position - actor.global_position
	)
	offset.y = 0.0
	if offset.length() > get_effective_attack_range(attack) + 1.0:
		return targets
	targets.erase(axe_counter_reversal_target)
	targets.push_front(axe_counter_reversal_target)
	while targets.size() > maxi(attack.max_targets, 1):
		targets.pop_back()
	return targets


func send_payload_to_target(
	target: Node,
	payload: DamagePayload
) -> Dictionary:
	var counter_reversal: bool = (
		_is_axe_equipped()
		and payload != null
		and payload.tags.has("axe_counter_reversal")
	)
	var result: Dictionary = super.send_payload_to_target(target, payload)
	if (
		counter_reversal
		and axe_counter_momentum_awarded_serial != flair_attack_serial
	):
		axe_counter_momentum_awarded_serial = flair_attack_serial
		_gain_axe_momentum(2)
	return result


func finish_current_attack() -> void:
	var completed: WeaponAttackDefinition = current_attack
	super.finish_current_attack()
	if completed != null and completed.extra_tags.has("axe_counter_reversal"):
		_reset_axe_counter_state(true)


func cancel_current_attack(reason: String = "cancelled") -> void:
	var was_counter: bool = (
		current_attack != null
		and (
			current_attack.extra_tags.has("axe_counter_guard")
			or current_attack.extra_tags.has("axe_counter_reversal")
		)
	)
	super.cancel_current_attack(reason)
	if was_counter:
		_reset_axe_counter_state(true)


func get_attack_forward() -> Vector3:
	if (
		current_attack != null
		and current_attack.extra_tags.has("staff_returning_throw")
		and staff_throw_camera_release_heading.length_squared() > 0.0001
	):
		return staff_throw_camera_release_heading.normalized()
	return super.get_attack_forward()


func on_staff_projectile_returned(projectile: Node) -> void:
	super.on_staff_projectile_returned(projectile)
	staff_throw_camera_release_heading = Vector3.ZERO


func is_axe_counter_guard_charging() -> bool:
	return (
		charge_active
		and str(charge_profile.get("id", "")) == "axe_counter_guard"
	)


func get_axe_counter_timing_ratio() -> float:
	if not axe_counter_caught or axe_counter_spent:
		return 0.0
	return clampf(
		1.0
		- axe_counter_elapsed_since_block
		/ maxf(axe_counter_release_window, 0.01),
		0.0,
		1.0
	)


func _get_axe_counter_timing_quality(elapsed_after_block: float) -> float:
	var sweet_spot: float = clampf(
		axe_counter_sweet_spot_seconds,
		0.0,
		axe_counter_release_window
	)
	var early_span: float = maxf(sweet_spot, 0.05)
	var late_span: float = maxf(
		axe_counter_release_window - sweet_spot,
		0.05
	)
	if elapsed_after_block <= sweet_spot:
		return clampf(
			1.0 - (sweet_spot - elapsed_after_block) / early_span * 0.38,
			0.0,
			1.0
		)
	return clampf(
		1.0 - (elapsed_after_block - sweet_spot) / late_span,
		0.0,
		1.0
	)


func _reset_axe_counter_state(clear_reversal_target: bool) -> void:
	axe_counter_caught = false
	axe_counter_spent = false
	axe_counter_elapsed_since_block = 0.0
	axe_counter_target = null
	if clear_reversal_target:
		axe_counter_reversal_target = null


func get_axe_focus_v2_debug_data() -> Dictionary:
	return {
		"axe_focus_v2": true,
		"staff_throw_camera_release_heading": staff_throw_camera_release_heading,
		"axe_aerial_light_drive": axe_aerial_light_forward_speed,
		"axe_aerial_heavy_crash": axe_aerial_heavy_fall_speed,
		"axe_counter_guard": is_axe_counter_guard_charging(),
		"axe_counter_caught": axe_counter_caught,
		"axe_counter_spent": axe_counter_spent,
		"axe_counter_timing_ratio": snappedf(
			get_axe_counter_timing_ratio(),
			0.01
		),
		"axe_counter_target": (
			axe_counter_target.name
			if axe_counter_target != null and is_instance_valid(axe_counter_target)
			else "none"
		),
	}
