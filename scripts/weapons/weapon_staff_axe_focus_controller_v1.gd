extends "res://scripts/weapons/weapon_staff_focus_controller_v3.gd"
class_name WeaponStaffAxeFocusControllerV1

const AxeFocusCatalogScript = preload(
	"res://scripts/weapons/axe_weapon_focus_catalog_v1.gd"
)

const AXE_OPEN_UNTIL_META: StringName = &"axe_open_until_msec"

@export_group("Axe Momentum")
@export_range(1, 6, 1) var axe_max_momentum: int = 3
@export_range(0.2, 8.0, 0.1) var axe_momentum_lifetime: float = 2.6
@export_range(0.0, 1.0, 0.01) var axe_light_startup_reduction_per_stack: float = 0.04
@export_range(0.0, 1.0, 0.01) var axe_heavy_startup_reduction_per_stack: float = 0.11
@export_range(0.0, 1.0, 0.01) var axe_heavy_damage_bonus_per_stack: float = 0.18
@export_range(0.0, 1.0, 0.01) var axe_heavy_stance_bonus_per_stack: float = 0.14

@export_group("Axe Openings")
@export_range(0.2, 8.0, 0.1) var axe_opening_seconds: float = 2.5
@export_range(1.0, 3.0, 0.05) var axe_opening_damage_multiplier: float = 1.45
@export_range(1.0, 3.0, 0.05) var axe_opening_stance_multiplier: float = 1.3

var axe_momentum_stacks: int = 0
var axe_momentum_timer: float = 0.0
var axe_momentum_awarded_serial: int = -1
var axe_last_cashout_stacks: int = 0
var axe_charge_motion_serial: int = -1
var axe_charge_motion_attack_id: String = ""


func _ready() -> void:
	super._ready()
	_apply_axe_focus_to_equipped_weapon()


func _process(delta: float) -> void:
	super._process(delta)
	_update_axe_momentum(delta)


func equip_weapon(new_weapon: WeaponDefinition) -> void:
	if new_weapon == null or new_weapon.weapon_class != "axe":
		_clear_axe_momentum()
	if new_weapon != null and new_weapon.weapon_class == "axe":
		AxeFocusCatalogScript.apply_to_weapon(new_weapon)
	super.equip_weapon(new_weapon)


func _apply_axe_focus_to_equipped_weapon() -> void:
	if not _is_axe_equipped():
		return
	AxeFocusCatalogScript.apply_to_weapon(equipped_weapon)
	refresh_weapon_visual()
	emit_weapon_changed()


# Returning Comet is a projectile, so its release follows camera aim rather than
# the independently steered staff model. Whirling Bastion and the aerial vault
# keep their left-stick facing grammar.
func _update_charge_hold_heading(delta: float) -> void:
	if is_staff_returning_throw_charging():
		_prime_staff_throw_camera_heading()
		return
	if is_axe_lever_charge_active():
		var axe_heading: Vector3 = _get_camera_planar_heading()
		if axe_heading.length_squared() > 0.0001:
			attack_forward_override = axe_heading
		return
	super._update_charge_hold_heading(delta)


func _release_active_charge() -> void:
	if is_staff_returning_throw_charging():
		_prime_staff_throw_camera_heading()
	elif is_axe_lever_charge_active():
		var axe_heading: Vector3 = _get_camera_planar_heading()
		if axe_heading.length_squared() > 0.0001:
			attack_forward_override = axe_heading
	super._release_active_charge()


func _prime_staff_throw_camera_heading() -> void:
	var heading: Vector3 = _get_camera_planar_heading()
	if heading.length_squared() <= 0.0001:
		return
	staff_charge_heading = heading
	staff_charge_heading_initialized = true
	attack_forward_override = heading
	_apply_actor_heading(heading)


func _get_camera_planar_heading() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		var forward: Vector3 = -camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.0001:
			return forward.normalized()
	var actor: Node3D = get_actor()
	if actor == null:
		return Vector3.FORWARD
	var actor_forward: Vector3 = -actor.global_transform.basis.z
	actor_forward.y = 0.0
	return actor_forward.normalized() if actor_forward.length_squared() > 0.0001 else Vector3.FORWARD


func _prepare_combat_flair_attack(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	var resolved: WeaponAttackDefinition = super._prepare_combat_flair_attack(attack)
	if resolved == null or not _is_axe_equipped():
		return resolved
	if resolved.extra_tags.has("aerial_light"):
		resolved.display_name = "Falling Crescent"
		resolved.startup_time = minf(resolved.startup_time, 0.13)
		resolved.recovery_time = minf(resolved.recovery_time, 0.18)
		resolved.damage_multiplier *= 0.94
		resolved.stance_multiplier *= 1.08
		resolved.movement_distance = maxf(resolved.movement_distance, 0.62)
		_append_attack_tag(resolved, "axe_side_hew")
		_append_attack_tag(resolved, "axe_momentum_builder")
	elif resolved.extra_tags.has("aerial_heavy"):
		resolved.display_name = "Drop Splitter"
		resolved.damage_multiplier *= 1.25
		resolved.stance_multiplier *= 1.38
		resolved.cone_angle_degrees = maxf(resolved.cone_angle_degrees, 118.0)
		_append_attack_tag(resolved, "axe_overhead")
		_append_attack_tag(resolved, "axe_edge_aligned")
		_append_attack_tag(resolved, "axe_exploit")
		_append_attack_tag(resolved, "opening_exploit")
	elif resolved.extra_tags.has("context_dash"):
		if resolved.extra_tags.has("dash_heavy"):
			resolved.display_name = "Breach Step"
			resolved.stance_multiplier *= 1.28
			resolved.movement_distance = maxf(resolved.movement_distance, 1.05)
			_append_attack_tag(resolved, "axe_opener")
			_append_attack_tag(resolved, "opening_pressure")
			_append_attack_tag(resolved, "axe_edge_aligned")
		else:
			resolved.display_name = "Chasing Hew"
			resolved.movement_distance = maxf(resolved.movement_distance, 1.22)
			_append_attack_tag(resolved, "axe_side_hew")
			_append_attack_tag(resolved, "axe_momentum_builder")
	return resolved


func start_attack(attack: WeaponAttackDefinition) -> bool:
	var resolved: WeaponAttackDefinition = attack
	var momentum_to_spend: int = 0
	if _is_axe_equipped() and attack != null:
		resolved = attack.duplicate(true) as WeaponAttackDefinition
		if resolved == null:
			resolved = attack
		momentum_to_spend = _apply_axe_momentum_to_attack(resolved)
	var started: bool = super.start_attack(resolved)
	if not started or not _is_axe_equipped():
		return started
	if momentum_to_spend > 0:
		axe_last_cashout_stacks = momentum_to_spend
		axe_momentum_stacks = 0
		axe_momentum_timer = 0.0
	return started


func _apply_axe_momentum_to_attack(
	attack: WeaponAttackDefinition
) -> int:
	if attack == null or axe_momentum_stacks <= 0:
		return 0
	if (
		attack.extra_tags.has("weapon_charge_hold")
		or attack.extra_tags.has("weapon_charge_pulse")
	):
		return 0
	var stacks: int = mini(axe_momentum_stacks, axe_max_momentum)
	if attack.input_kind == "light":
		attack.startup_time *= maxf(
			1.0 - axe_light_startup_reduction_per_stack * float(stacks),
			0.62
		)
		attack.recovery_time *= maxf(1.0 - 0.05 * float(stacks), 0.68)
		attack.damage_multiplier *= 1.0 + 0.035 * float(stacks)
		attack.movement_distance += 0.1 * float(stacks)
		_append_attack_tag(attack, "axe_momentum_flow")
		return 0
	attack.startup_time *= maxf(
		1.0 - axe_heavy_startup_reduction_per_stack * float(stacks),
		0.58
	)
	attack.recovery_time *= maxf(1.0 - 0.08 * float(stacks), 0.64)
	attack.damage_multiplier *= (
		1.0 + axe_heavy_damage_bonus_per_stack * float(stacks)
	)
	attack.stance_multiplier *= (
		1.0 + axe_heavy_stance_bonus_per_stack * float(stacks)
	)
	attack.knockback_multiplier *= 1.0 + 0.08 * float(stacks)
	attack.movement_distance += 0.14 * float(stacks)
	attack.hit_stop_duration += 0.008 * float(stacks)
	_append_attack_tag(attack, "axe_momentum_cashout")
	_append_attack_tag(attack, "axe_momentum_cashout_" + str(stacks))
	return stacks


func send_payload_to_target(
	target: Node,
	payload: DamagePayload
) -> Dictionary:
	if not _is_axe_equipped() or payload == null:
		return super.send_payload_to_target(target, payload)
	var resolved: DamagePayload = payload.duplicate(true) as DamagePayload
	if resolved == null:
		resolved = payload
	var target_open: bool = _target_has_axe_opening(target)
	var exploits_opening: bool = (
		target_open
		and resolved.tags.has("axe_exploit")
	)
	if exploits_opening:
		resolved.amount = maxi(
			roundi(float(resolved.amount) * axe_opening_damage_multiplier),
			1
		)
		resolved.stance_damage = maxi(
			roundi(float(resolved.stance_damage) * axe_opening_stance_multiplier),
			0
		)
		resolved.critical_multiplier += 0.45
		resolved.knockback_strength *= 1.15
		_append_payload_tag(resolved, "axe_opening_exploited")
	if resolved.tags.has("axe_opener"):
		resolved.status_effect = "staggered"
		resolved.status_duration = maxf(resolved.status_duration, 0.34)
		resolved.status_strength = maxf(resolved.status_strength, 1.0)
	var result: Dictionary = super.send_payload_to_target(target, resolved)
	if target != null and is_instance_valid(target):
		if resolved.tags.has("axe_opener"):
			_open_axe_target(target)
		if exploits_opening:
			_clear_axe_target_opening(target)
	if (
		resolved.tags.has("axe_momentum_builder")
		and axe_momentum_awarded_serial != flair_attack_serial
	):
		axe_momentum_awarded_serial = flair_attack_serial
		_gain_axe_momentum(1)
	return result


func finish_current_attack() -> void:
	var completed: WeaponAttackDefinition = current_attack
	var connected: bool = last_attack_connected
	super.finish_current_attack()
	if (
		completed != null
		and _is_axe_equipped()
		and completed.input_kind == "light"
		and completed.extra_tags.has("axe_momentum_builder")
		and not connected
	):
		axe_momentum_stacks = maxi(axe_momentum_stacks - 1, 0)
		if axe_momentum_stacks <= 0:
			axe_momentum_timer = 0.0


func cancel_current_attack(reason: String = "cancelled") -> void:
	super.cancel_current_attack(reason)
	axe_charge_motion_serial = -1
	axe_charge_motion_attack_id = ""


func _gain_axe_momentum(amount: int) -> void:
	axe_momentum_stacks = mini(
		axe_momentum_stacks + maxi(amount, 0),
		axe_max_momentum
	)
	axe_momentum_timer = axe_momentum_lifetime


func _update_axe_momentum(delta: float) -> void:
	if axe_momentum_stacks <= 0:
		return
	axe_momentum_timer -= maxf(delta, 0.0)
	if axe_momentum_timer <= 0.0:
		_clear_axe_momentum()


func _clear_axe_momentum() -> void:
	axe_momentum_stacks = 0
	axe_momentum_timer = 0.0
	axe_momentum_awarded_serial = -1
	axe_last_cashout_stacks = 0


func _open_axe_target(target: Node) -> void:
	if target == null:
		return
	var until_msec: int = Time.get_ticks_msec() + roundi(
		axe_opening_seconds * 1000.0
	)
	target.set_meta(AXE_OPEN_UNTIL_META, until_msec)


func _target_has_axe_opening(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var until_msec: int = int(target.get_meta(AXE_OPEN_UNTIL_META, 0))
	if until_msec > Time.get_ticks_msec():
		return true
	if until_msec > 0:
		target.remove_meta(AXE_OPEN_UNTIL_META)
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	return (
		status_receiver != null
		and status_receiver.has_method("has_status")
		and bool(status_receiver.call("has_status", "staggered"))
	)


func _clear_axe_target_opening(target: Node) -> void:
	if target != null and target.has_meta(AXE_OPEN_UNTIL_META):
		target.remove_meta(AXE_OPEN_UNTIL_META)


func _append_payload_tag(
	payload: DamagePayload,
	tag: String
) -> void:
	if payload != null and tag != "" and not payload.tags.has(tag):
		payload.tags.append(tag)


# The legacy release used five widely separated impulses over a long startup.
# Keep the same plant, leverage, extraction, corkscrew, and second slam, but pack
# them into one continuous beat with overlapping forward motion.
func _schedule_axe_vault_motion() -> void:
	if current_attack == null or not is_inside_tree():
		return
	axe_charge_motion_serial = flair_attack_serial
	axe_charge_motion_attack_id = current_attack.attack_id
	var startup: float = current_attack.get_startup_duration(get_attack_speed())
	_schedule_axe_phase(
		axe_charge_motion_serial,
		axe_charge_motion_attack_id,
		maxf(startup * 0.12, 0.055),
		1
	)
	_schedule_axe_phase(
		axe_charge_motion_serial,
		axe_charge_motion_attack_id,
		maxf(startup * 0.24, 0.11),
		2
	)
	_schedule_axe_phase(
		axe_charge_motion_serial,
		axe_charge_motion_attack_id,
		maxf(startup * 0.42, 0.19),
		3
	)
	_schedule_axe_phase(
		axe_charge_motion_serial,
		axe_charge_motion_attack_id,
		maxf(startup * 0.58, 0.28),
		4
	)
	_schedule_axe_phase(
		axe_charge_motion_serial,
		axe_charge_motion_attack_id,
		maxf(startup * 0.82, 0.42),
		5
	)


func _apply_axe_vault_motion(
	serial: int,
	attack_id: String,
	phase: int
) -> void:
	if (
		serial != flair_attack_serial
		or serial != axe_charge_motion_serial
		or current_attack == null
		or current_attack.attack_id != attack_id
		or not current_attack.extra_tags.has("axe_lever_vault")
	):
		return
	var actor: Node3D = get_actor()
	if not actor is CharacterBody3D:
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var forward: Vector3 = get_released_charge_forward()
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = get_attack_forward()
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var charge: float = clampf(released_charge_ratio, 0.0, 1.0)
	match phase:
		1:
			# A final compact gathering step ends in the first edge-first plant.
			if actor.has_method("cancel_combat_motion"):
				actor.call("cancel_combat_motion", "axe first plant")
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(0.48, 0.68, charge),
					0.12
				)
			body.velocity.y = minf(body.velocity.y, -0.1)
			_execute_axe_first_plant()
		2:
			# Grace immediately levers upward without the old dead pause.
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(0.38, 0.56, charge),
					0.16
				)
			body.velocity.y = maxf(body.velocity.y, lerpf(5.2, 6.1, charge))
		3:
			# The head comes free near the apex while forward speed is already rising.
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(0.68, 0.94, charge),
					0.15
				)
			body.velocity.y = maxf(body.velocity.y, lerpf(3.0, 3.8, charge))
		4:
			# The diagonal revolution carries the largest uninterrupted travel beat.
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(3.2, 4.8, charge),
					0.27
				)
			body.velocity.y = maxf(body.velocity.y, lerpf(2.4, 3.2, charge))
		5:
			# The second edge-first downstroke keeps advancing as it accelerates down.
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(1.1, 1.7, charge),
					0.15
				)
			body.velocity.y = minf(body.velocity.y, -lerpf(9.8, 12.0, charge))


func get_axe_momentum_ratio() -> float:
	return (
		float(axe_momentum_stacks) / float(maxi(axe_max_momentum, 1))
	)


func get_axe_focus_debug_data() -> Dictionary:
	return {
		"staff_throw_uses_camera_heading": true,
		"axe_focus_v1": true,
		"axe_equipped": _is_axe_equipped(),
		"axe_momentum": axe_momentum_stacks,
		"axe_momentum_ratio": snappedf(get_axe_momentum_ratio(), 0.01),
		"axe_last_cashout": axe_last_cashout_stacks,
		"axe_opening_seconds": axe_opening_seconds,
		"axe_charge_fast_timeline": true,
		"axe_playstyle": "power_momentum_openings",
	}


func _is_axe_equipped() -> bool:
	return equipped_weapon != null and equipped_weapon.weapon_class == "axe"
