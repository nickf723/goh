extends "res://scripts/weapons/weapon_charge_actions_v3.gd"
class_name WeaponStaffFocusControllerV1

const StaffFocusCatalogScript = preload(
	"res://scripts/weapons/staff_weapon_focus_catalog_v1.gd"
)
const StaffReturningProjectileScript = preload(
	"res://scripts/weapons/staff_returning_projectile_v1.gd"
)

const STAFF_VAULT_IDLE: String = "idle"
const STAFF_VAULT_DESCENT: String = "descent"
const STAFF_VAULT_BEND: String = "bend"
const STAFF_VAULT_LAUNCH: String = "launch"
const STAFF_VAULT_DROP: String = "drop"

@export_group("Staff Charge Facing")
@export_range(0.05, 0.8, 0.01) var staff_charge_stick_deadzone: float = 0.34
@export_range(30.0, 360.0, 5.0) var staff_charge_turn_degrees_per_second: float = 150.0
@export_range(30.0, 360.0, 5.0) var staff_vault_turn_degrees_per_second: float = 128.0

@export_group("Staff Aerial Vault")
@export_range(3.0, 20.0, 0.5) var staff_vault_descent_speed: float = 10.5
@export_range(0.05, 0.5, 0.01) var staff_vault_min_release_seconds: float = 0.1
@export_range(0.2, 1.5, 0.01) var staff_vault_full_bend_seconds: float = 0.58
@export_range(0.3, 2.0, 0.01) var staff_vault_overhold_seconds: float = 0.9
@export_range(2.0, 12.0, 0.25) var staff_vault_min_horizontal_distance: float = 5.5
@export_range(8.0, 30.0, 0.25) var staff_vault_max_horizontal_distance: float = 15.5
@export_range(2.0, 10.0, 0.1) var staff_vault_min_vertical_speed: float = 4.8
@export_range(6.0, 18.0, 0.1) var staff_vault_max_vertical_speed: float = 9.4

var staff_charge_heading: Vector3 = Vector3.FORWARD
var staff_charge_heading_initialized: bool = false
var staff_projectile: Node3D

var staff_vault_state: String = STAFF_VAULT_IDLE
var staff_vault_state_elapsed: float = 0.0
var staff_vault_bend_ratio: float = 0.0
var staff_vault_release_requested: bool = false
var staff_vault_rearm_requested: bool = false
var staff_vault_heading: Vector3 = Vector3.FORWARD


func _ready() -> void:
	super._ready()
	_apply_staff_focus_to_equipped_weapon()


func _exit_tree() -> void:
	_clear_staff_projectile()
	super._exit_tree()


func _process(delta: float) -> void:
	super._process(delta)
	_update_staff_aerial_vault(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_staff_aerial_heavy_event(event):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func equip_weapon(new_weapon: WeaponDefinition) -> void:
	_reset_staff_aerial_vault("weapon changed", true)
	_clear_staff_projectile()
	if new_weapon != null and new_weapon.weapon_class == "staff":
		StaffFocusCatalogScript.apply_to_weapon(new_weapon)
	super.equip_weapon(new_weapon)


func queue_attack_input(input_kind: String) -> void:
	if (
		input_kind == INPUT_HEAVY
		and _is_staff_equipped()
		and _actor_is_airborne()
	):
		if staff_vault_state == STAFF_VAULT_IDLE and current_attack == null:
			_begin_staff_aerial_vault_descent()
			return
		if staff_vault_state == STAFF_VAULT_LAUNCH:
			staff_vault_rearm_requested = true
			return
	super.queue_attack_input(input_kind)


func update_current_attack(delta: float) -> void:
	if (
		current_attack != null
		and current_attack.extra_tags.has("staff_vault_hold_state")
	):
		_update_staff_vault_hold_attack(delta)
		return
	super.update_current_attack(delta)


func start_attack(attack: WeaponAttackDefinition) -> bool:
	var started: bool = super.start_attack(attack)
	if not started or current_attack == null:
		return started
	if current_attack.extra_tags.has("staff_returning_throw"):
		_schedule_staff_returning_projectile()
	return started


func finish_current_attack() -> void:
	var completed: WeaponAttackDefinition = current_attack
	var completed_staff_vault: bool = (
		completed != null
		and (
			completed.extra_tags.has("staff_vault_launch")
			or completed.extra_tags.has("staff_vault_overheld_drop")
		)
	)
	var should_rearm: bool = (
		completed != null
		and completed.extra_tags.has("staff_vault_launch")
		and staff_vault_rearm_requested
	)
	super.finish_current_attack()
	if not completed_staff_vault:
		return
	staff_vault_state = STAFF_VAULT_IDLE
	staff_vault_state_elapsed = 0.0
	staff_vault_bend_ratio = 0.0
	staff_vault_release_requested = false
	staff_vault_rearm_requested = false
	if should_rearm and _actor_is_airborne() and Input.is_action_pressed(CHARGE_HEAVY_ACTION):
		call_deferred("_begin_staff_aerial_vault_descent")


func cancel_current_attack(reason: String = "cancelled") -> void:
	var was_staff_vault: bool = (
		staff_vault_state != STAFF_VAULT_IDLE
		or (
			current_attack != null
			and current_attack.extra_tags.has("staff_aerial_vault")
		)
	)
	super.cancel_current_attack(reason)
	if was_staff_vault:
		_reset_staff_aerial_vault(reason, false)


func find_targets(attack: WeaponAttackDefinition) -> Array[Node]:
	if attack != null and attack.extra_tags.has("staff_returning_throw"):
		# The moving staff owns its swept contacts. Do not also fire an invisible
		# instantaneous weapon query when the release attack becomes active.
		return []
	return super.find_targets(attack)


func _apply_staff_focus_to_equipped_weapon() -> void:
	if not _is_staff_equipped():
		return
	StaffFocusCatalogScript.apply_to_weapon(equipped_weapon)
	refresh_weapon_visual()
	emit_weapon_changed()


func _handle_staff_aerial_heavy_event(event: InputEvent) -> bool:
	if not _is_staff_equipped():
		return false
	if staff_vault_state != STAFF_VAULT_IDLE:
		if event.is_action_released(CHARGE_HEAVY_ACTION):
			_release_staff_aerial_vault()
			return true
		if event.is_action_pressed(CHARGE_HEAVY_ACTION):
			if staff_vault_state == STAFF_VAULT_LAUNCH:
				staff_vault_rearm_requested = true
			return true
		return false
	if not event.is_action_pressed(CHARGE_HEAVY_ACTION):
		return false
	if not _actor_is_airborne() or current_attack != null:
		return false
	return _begin_staff_aerial_vault_descent()


func _begin_staff_aerial_vault_descent() -> bool:
	if not _is_staff_equipped() or not _actor_is_airborne() or current_attack != null:
		return false
	var actor: Node3D = get_actor()
	if not actor is CharacterBody3D:
		return false
	staff_vault_heading = _get_actor_planar_forward(actor)
	var input_direction: Vector3 = _get_staff_stick_world_direction()
	if input_direction.length_squared() > 0.0001:
		staff_vault_heading = input_direction
	pending_context_forward = staff_vault_heading
	reset_combo_chain(false)
	var attack: WeaponAttackDefinition = StaffFocusCatalogScript.build_aerial_descent_attack()
	if not start_attack(attack):
		return false
	staff_vault_state = STAFF_VAULT_DESCENT
	staff_vault_state_elapsed = 0.0
	staff_vault_bend_ratio = 0.0
	staff_vault_release_requested = false
	staff_vault_rearm_requested = false
	attack_hit_applied = true
	var body: CharacterBody3D = actor as CharacterBody3D
	body.velocity.x *= 0.55
	body.velocity.z *= 0.55
	body.velocity.y = minf(body.velocity.y, -staff_vault_descent_speed)
	plunge_landing_armed = false
	plunge_max_fall_speed = 0.0
	return true


func _update_staff_vault_hold_attack(delta: float) -> void:
	if current_attack == null:
		return
	if action_state != null and (
		action_state.is_defeated
		or action_state.is_casting
		or action_state.is_dodging
		or action_state.is_staggered
	):
		cancel_current_attack("staff vault interrupted")
		return
	current_attack_elapsed += maxf(delta, 0.0)
	current_phase = "active"
	attack_hit_applied = true
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("update_attack_pose"):
		runtime_weapon_rig.call(
			"update_attack_pose",
			current_attack,
			current_attack_elapsed,
			get_attack_speed()
		)
	update_cancel_permissions()


func _update_staff_aerial_vault(delta: float) -> void:
	if staff_vault_state == STAFF_VAULT_IDLE:
		return
	var actor: Node3D = get_actor()
	if not actor is CharacterBody3D:
		_reset_staff_aerial_vault("missing actor", true)
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	staff_vault_state_elapsed += maxf(delta, 0.0)
	if staff_vault_state in [STAFF_VAULT_DESCENT, STAFF_VAULT_BEND]:
		_update_staff_vault_heading(delta)

	match staff_vault_state:
		STAFF_VAULT_DESCENT:
			if body.is_on_floor():
				_begin_staff_vault_bend()
				return
			body.velocity.x = move_toward(body.velocity.x, 0.0, delta * 5.5)
			body.velocity.z = move_toward(body.velocity.z, 0.0, delta * 5.5)
			body.velocity.y = minf(body.velocity.y, -staff_vault_descent_speed)
		STAFF_VAULT_BEND:
			body.velocity.x = move_toward(body.velocity.x, 0.0, delta * 24.0)
			body.velocity.z = move_toward(body.velocity.z, 0.0, delta * 24.0)
			if body.velocity.y < 0.0:
				body.velocity.y = -0.1
			staff_vault_bend_ratio = smoothstep(
				0.0,
				1.0,
				clampf(
					staff_vault_state_elapsed / maxf(staff_vault_full_bend_seconds, 0.01),
					0.0,
					1.0
				)
			)
			if (
				staff_vault_release_requested
				and staff_vault_state_elapsed >= staff_vault_min_release_seconds
			):
				_launch_staff_aerial_vault()
				return
			if staff_vault_state_elapsed >= staff_vault_overhold_seconds:
				_begin_staff_vault_overheld_drop()


func _begin_staff_vault_bend() -> void:
	if staff_vault_state != STAFF_VAULT_DESCENT:
		return
	_replace_staff_vault_hold_attack(
		StaffFocusCatalogScript.build_aerial_bend_attack(),
		STAFF_VAULT_BEND
	)
	staff_vault_bend_ratio = 0.0
	_execute_staff_pulse(
		StaffFocusCatalogScript.build_aerial_plant_pulse(0.0),
		false
	)


func _release_staff_aerial_vault() -> void:
	match staff_vault_state:
		STAFF_VAULT_DESCENT:
			# Releasing before the pole reaches the floor cancels the technique. The
			# player must actually load the staff before it can return energy.
			_reset_staff_aerial_vault("released before plant", true)
		STAFF_VAULT_BEND:
			staff_vault_release_requested = true
			if staff_vault_state_elapsed >= staff_vault_min_release_seconds:
				_launch_staff_aerial_vault()
		STAFF_VAULT_LAUNCH:
			pass
		STAFF_VAULT_DROP:
			pass


func _launch_staff_aerial_vault() -> void:
	if staff_vault_state != STAFF_VAULT_BEND:
		return
	var actor: Node3D = get_actor()
	if not actor is CharacterBody3D:
		_reset_staff_aerial_vault("missing launch actor", true)
		return
	var bend: float = clampf(staff_vault_bend_ratio, 0.12, 1.0)
	var launch_attack: WeaponAttackDefinition = StaffFocusCatalogScript.build_aerial_launch_attack(bend)
	_end_staff_vault_hold_attack()
	pending_context_forward = staff_vault_heading
	if not start_attack(launch_attack):
		_reset_staff_aerial_vault("launch failed", true)
		return
	staff_vault_state = STAFF_VAULT_LAUNCH
	staff_vault_state_elapsed = 0.0
	staff_vault_release_requested = false
	var body: CharacterBody3D = actor as CharacterBody3D
	if actor.has_method("cancel_combat_motion"):
		actor.call("cancel_combat_motion", "staff vault launch")
	if actor.has_method("begin_combat_motion"):
		actor.call(
			"begin_combat_motion",
			staff_vault_heading,
			lerpf(
				staff_vault_min_horizontal_distance,
				staff_vault_max_horizontal_distance,
				bend
			),
			lerpf(0.52, 0.88, bend)
		)
	body.velocity.y = maxf(
		body.velocity.y,
		lerpf(staff_vault_min_vertical_speed, staff_vault_max_vertical_speed, bend)
	)
	plunge_landing_armed = false
	plunge_max_fall_speed = 0.0


func _begin_staff_vault_overheld_drop() -> void:
	if staff_vault_state != STAFF_VAULT_BEND:
		return
	var actor: Node3D = get_actor()
	_end_staff_vault_hold_attack()
	var drop_attack: WeaponAttackDefinition = StaffFocusCatalogScript.build_aerial_overheld_drop_attack()
	if not start_attack(drop_attack):
		_reset_staff_aerial_vault("drop failed", true)
		return
	staff_vault_state = STAFF_VAULT_DROP
	staff_vault_state_elapsed = 0.0
	staff_vault_release_requested = false
	if actor is CharacterBody3D:
		var body: CharacterBody3D = actor as CharacterBody3D
		body.velocity.x *= 0.25
		body.velocity.z *= 0.25
		body.velocity.y = minf(body.velocity.y, -1.4)


func _replace_staff_vault_hold_attack(
	attack: WeaponAttackDefinition,
	new_state: String
) -> void:
	_end_staff_vault_hold_attack()
	pending_context_forward = staff_vault_heading
	if not start_attack(attack):
		_reset_staff_aerial_vault("state transition failed", true)
		return
	staff_vault_state = new_state
	staff_vault_state_elapsed = 0.0
	staff_vault_release_requested = false
	attack_hit_applied = true


func _end_staff_vault_hold_attack() -> void:
	if current_attack == null:
		return
	current_attack = null
	current_attack_elapsed = 0.0
	current_phase = "idle"
	attack_hit_applied = false
	current_attack_duration_bonus = 0.0
	attack_forward_override = Vector3.ZERO
	active_technique_id = ""
	if action_state != null and action_state.is_attacking:
		action_state.end_attack()
	reset_visual_pose()


func _reset_staff_aerial_vault(
	_reason: String,
	clear_current_attack: bool
) -> void:
	if clear_current_attack and current_attack != null:
		if current_attack.extra_tags.has("staff_aerial_vault"):
			_end_staff_vault_hold_attack()
	staff_vault_state = STAFF_VAULT_IDLE
	staff_vault_state_elapsed = 0.0
	staff_vault_bend_ratio = 0.0
	staff_vault_release_requested = false
	staff_vault_rearm_requested = false


func _update_staff_vault_heading(delta: float) -> void:
	var desired: Vector3 = _get_staff_stick_world_direction()
	if desired.length_squared() <= 0.0001:
		return
	staff_vault_heading = _rotate_heading_toward(
		staff_vault_heading,
		desired,
		staff_vault_turn_degrees_per_second,
		delta,
		_get_staff_stick_strength()
	)
	attack_forward_override = staff_vault_heading
	_apply_actor_heading(staff_vault_heading)


func _update_charge_hold_heading(delta: float) -> void:
	if (
		charge_active
		and _is_staff_equipped()
		and str(charge_profile.get("id", "")) in [
			"staff_returning_throw",
			"staff_angel_ring",
		]
	):
		var actor: Node3D = get_actor()
		if actor == null:
			return
		if not staff_charge_heading_initialized:
			staff_charge_heading = _get_actor_planar_forward(actor)
			staff_charge_heading_initialized = true
		var desired: Vector3 = _get_staff_stick_world_direction()
		if desired.length_squared() > 0.0001:
			staff_charge_heading = _rotate_heading_toward(
				staff_charge_heading,
				desired,
				staff_charge_turn_degrees_per_second,
				delta,
				_get_staff_stick_strength()
			)
		attack_forward_override = staff_charge_heading
		_apply_actor_heading(staff_charge_heading)
		return
	staff_charge_heading_initialized = false
	super._update_charge_hold_heading(delta)


func _stabilize_staff_mount(_delta: float) -> void:
	# The old grounded pole perch no longer exists. Grounded Heavy charge is the
	# planted spinning guard; the pole vault now lives entirely on Aerial Heavy.
	pass


func _release_active_charge() -> void:
	var was_staff_ring: bool = is_staff_angel_ring_charging()
	var ring_charge: float = get_weapon_charge_ratio()
	var ring_heading: Vector3 = staff_charge_heading
	super._release_active_charge()
	staff_charge_heading_initialized = false
	if was_staff_ring and _is_staff_equipped():
		pending_context_forward = ring_heading
		start_attack(StaffFocusCatalogScript.build_ring_release_attack(ring_charge))


func _clear_charge_state(clear_pose: bool) -> void:
	super._clear_charge_state(clear_pose)
	staff_charge_heading_initialized = false


func _execute_sustain_charge_pulse() -> void:
	if is_staff_angel_ring_charging():
		var pulse: WeaponAttackDefinition = ChargeCatalogScript.build_sustain_pulse(
			charge_base_attack,
			"staff",
			get_weapon_charge_ratio()
		)
		_execute_staff_pulse(pulse, false)
		return
	super._execute_sustain_charge_pulse()


func _execute_staff_pulse(
	pulse: WeaponAttackDefinition,
	return_pass: bool
) -> void:
	if pulse == null or equipped_weapon == null:
		return
	var payload: DamagePayload = pulse.build_payload(equipped_weapon)
	if return_pass:
		payload.amount = maxi(roundi(float(payload.amount) * 0.72), 1)
		payload.stance_damage = maxi(roundi(float(payload.stance_damage) * 0.72), 0)
		if not payload.tags.has("return_pass"):
			payload.tags.append("return_pass")
	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	ChargeMasteryCatalogScript.apply_payload_upgrades(
		payload,
		equipped_weapon.weapon_class,
		mastery_rank,
		pulse,
		combo_history.size()
	)
	ChargeInfusionCatalogScript.apply_to_payload(
		payload,
		GameState.get_weapon_infusion()
	)
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("modify_attack_payload"):
		runtime_weapon_rig.call("modify_attack_payload", payload, pulse)
	var held_attack: WeaponAttackDefinition = current_attack
	current_attack = pulse
	var targets: Array[Node] = find_targets(pulse)
	for target: Node in targets:
		send_payload_to_target(target, payload)
		if target.has_method("receive_weapon_impact"):
			target.call("receive_weapon_impact", payload, get_attack_forward(), pulse)
		elif target.has_method("receive_hit_reaction"):
			target.call("receive_hit_reaction", get_attack_forward(), payload.knockback_strength)
	current_attack = held_attack
	if not targets.is_empty():
		last_attack_connected = true
		HitStop.request(pulse.hit_stop_duration, 0.055)


func _schedule_staff_returning_projectile() -> void:
	if current_attack == null or not is_inside_tree():
		return
	var serial: int = flair_attack_serial
	var attack_id: String = current_attack.attack_id
	var delay: float = maxf(
		current_attack.get_startup_duration(get_attack_speed()) * 0.72,
		0.045
	)
	var timer: SceneTreeTimer = get_tree().create_timer(delay)
	var callback := func():
		_spawn_staff_returning_projectile(serial, attack_id)
	timer.timeout.connect(callback, CONNECT_ONE_SHOT)


func _spawn_staff_returning_projectile(
	serial: int,
	attack_id: String
) -> void:
	if (
		serial != flair_attack_serial
		or current_attack == null
		or current_attack.attack_id != attack_id
		or not current_attack.extra_tags.has("staff_returning_throw")
	):
		return
	_clear_staff_projectile()
	var projectile: Node3D = StaffReturningProjectileScript.new() as Node3D
	if projectile == null:
		return
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		projectile.queue_free()
		return
	parent.add_child(projectile)
	projectile.call(
		"configure",
		self,
		current_attack.duplicate(true),
		get_attack_forward(),
		released_charge_ratio
	)
	staff_projectile = projectile
	_set_staff_rig_projectile_out(true)


func apply_staff_projectile_contact(
	target: Node,
	projectile_attack: WeaponAttackDefinition,
	return_pass: bool
) -> void:
	if target == null or projectile_attack == null or equipped_weapon == null:
		return
	var payload: DamagePayload = projectile_attack.build_payload(equipped_weapon)
	payload.hit_type = "projectile"
	if not payload.tags.has("projectile"):
		payload.tags.append("projectile")
	if not payload.tags.has("returning_weapon"):
		payload.tags.append("returning_weapon")
	if return_pass:
		payload.amount = maxi(roundi(float(payload.amount) * 0.72), 1)
		payload.stance_damage = maxi(roundi(float(payload.stance_damage) * 0.68), 0)
		payload.knockback_strength *= 0.72
		if not payload.tags.has("return_pass"):
			payload.tags.append("return_pass")
	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	ChargeMasteryCatalogScript.apply_payload_upgrades(
		payload,
		equipped_weapon.weapon_class,
		mastery_rank,
		projectile_attack,
		combo_history.size()
	)
	ChargeInfusionCatalogScript.apply_to_payload(
		payload,
		GameState.get_weapon_infusion()
	)
	var held_attack: WeaponAttackDefinition = current_attack
	current_attack = projectile_attack
	send_payload_to_target(target, payload)
	if target.has_method("receive_weapon_impact"):
		target.call(
			"receive_weapon_impact",
			payload,
			get_attack_forward(),
			projectile_attack
		)
	current_attack = held_attack
	ElementVisualsScript.spawn_impact(
		get_tree(),
		get_target_position(target),
		payload.element,
		0.48
	)
	HitStop.request(0.035, 0.07)


func on_staff_projectile_returned(projectile: Node) -> void:
	if staff_projectile == projectile:
		staff_projectile = null
	_set_staff_rig_projectile_out(false)


func _clear_staff_projectile() -> void:
	if staff_projectile != null and is_instance_valid(staff_projectile):
		staff_projectile.queue_free()
	staff_projectile = null
	_set_staff_rig_projectile_out(false)


func _set_staff_rig_projectile_out(active: bool) -> void:
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("set_projectile_out"):
		runtime_weapon_rig.call("set_projectile_out", active)


func _get_staff_stick_world_direction() -> Vector3:
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var magnitude: float = input_vector.length()
	if magnitude <= staff_charge_stick_deadzone:
		return Vector3.ZERO
	var actor: Node3D = get_actor()
	if actor == null:
		return Vector3.ZERO
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var right: Vector3 = actor.global_transform.basis.x
	var forward: Vector3 = -actor.global_transform.basis.z
	if camera != null:
		right = camera.global_transform.basis.x
		forward = -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	if right.length_squared() <= 0.0001 or forward.length_squared() <= 0.0001:
		return Vector3.ZERO
	var direction: Vector3 = (
		right.normalized() * input_vector.x
		+ forward.normalized() * -input_vector.y
	)
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func _get_staff_stick_strength() -> float:
	var magnitude: float = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	).length()
	if magnitude <= staff_charge_stick_deadzone:
		return 0.0
	return clampf(
		inverse_lerp(staff_charge_stick_deadzone, 1.0, magnitude),
		0.0,
		1.0
	)


func _rotate_heading_toward(
	current_heading: Vector3,
	desired_heading: Vector3,
	degrees_per_second: float,
	delta: float,
	stick_strength: float
) -> Vector3:
	var current: Vector3 = current_heading
	current.y = 0.0
	var desired: Vector3 = desired_heading
	desired.y = 0.0
	if current.length_squared() <= 0.0001:
		current = desired
	if desired.length_squared() <= 0.0001:
		return current.normalized()
	current = current.normalized()
	desired = desired.normalized()
	var current_angle: float = atan2(-current.x, -current.z)
	var desired_angle: float = atan2(-desired.x, -desired.z)
	var difference: float = wrapf(desired_angle - current_angle, -PI, PI)
	var maximum_step: float = (
		deg_to_rad(degrees_per_second)
		* maxf(delta, 0.0)
		* lerpf(0.28, 1.0, clampf(stick_strength, 0.0, 1.0))
	)
	var resolved_angle: float = current_angle + clampf(
		difference,
		-maximum_step,
		maximum_step
	)
	return Vector3(-sin(resolved_angle), 0.0, -cos(resolved_angle)).normalized()


func _apply_actor_heading(direction: Vector3) -> void:
	var actor: Node3D = get_actor()
	if actor == null or direction.length_squared() <= 0.0001:
		return
	actor.rotation.y = atan2(-direction.x, -direction.z)


func _get_actor_planar_forward(actor: Node3D) -> Vector3:
	if actor == null:
		return Vector3.FORWARD
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func _actor_is_airborne() -> bool:
	var actor: Node3D = get_actor()
	return actor is CharacterBody3D and not (actor as CharacterBody3D).is_on_floor()


func _is_staff_equipped() -> bool:
	return equipped_weapon != null and equipped_weapon.weapon_class == "staff"


func is_staff_returning_throw_charging() -> bool:
	return (
		charge_active
		and str(charge_profile.get("id", "")) == "staff_returning_throw"
	)


func is_staff_angel_ring_charging() -> bool:
	return (
		charge_active
		and str(charge_profile.get("id", "")) == "staff_angel_ring"
	)


func get_staff_aerial_vault_state() -> String:
	return staff_vault_state


func get_staff_vault_bend_ratio() -> float:
	return clampf(staff_vault_bend_ratio, 0.0, 1.0)


func get_staff_focus_debug_data() -> Dictionary:
	return {
		"staff_focus_v1": true,
		"staff_equipped": _is_staff_equipped(),
		"charge_heading_rate_limited": true,
		"staff_charge_heading": staff_charge_heading,
		"aerial_vault_state": staff_vault_state,
		"aerial_vault_bend": snappedf(staff_vault_bend_ratio, 0.01),
		"returning_projectile_active": staff_projectile != null,
		"ground_light_charge": "returning_throw",
		"ground_heavy_charge": "whirling_bastion",
		"aerial_heavy": "timed_bending_pole_vault",
	}
