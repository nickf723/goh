extends "res://scripts/weapons/weapon_charge_actions.gd"
class_name WeaponChargeActionsV2


func _process(delta: float) -> void:
	super._process(delta)
	_update_charge_hold_heading(delta)
	_stabilize_staff_mount(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _should_use_generic_bow_combo_heavy(event):
		queue_attack_input(INPUT_HEAVY)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _should_use_generic_bow_combo_heavy(event: InputEvent) -> bool:
	if not _is_bow_equipped() or bow_aim_active:
		return false
	if not event.is_action_pressed(BOW_HEAVY_ACTION):
		return false
	if current_attack != null:
		return true
	return combo_timeout_timer > 0.0 and last_completed_attack_id != ""


func _prepare_combat_flair_attack(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	var resolved: WeaponAttackDefinition = super._prepare_combat_flair_attack(attack)
	if resolved == null or equipped_weapon == null:
		return resolved
	if (
		equipped_weapon.weapon_class == "staff"
		and resolved.extra_tags.has("aerial_heavy")
		and not resolved.extra_tags.has("staff_charge_vault")
	):
		# The full pole-vault identity now belongs to grounded Heavy charge. The
		# quick aerial Heavy returns to a compact descending staff slam.
		_remove_attack_tag(resolved, "staff_pole_vault")
		_remove_attack_tag(resolved, "pole_vault")
		resolved.display_name = "Falling Staff"
		resolved.damage_multiplier *= 1.08
		resolved.stance_multiplier *= 1.15
		resolved.attack_range = maxf(resolved.attack_range, 2.4)
		resolved.cone_angle_degrees = maxf(resolved.cone_angle_degrees, 125.0)
		resolved.movement_distance = 0.0
		_append_attack_tag(resolved, "staff_aerial_slam")
		_append_attack_tag(resolved, "plunging")
		_append_attack_tag(resolved, "ground_slam")
	return resolved


func apply_aerial_technique_motion(context_id: String) -> void:
	if (
		context_id == WeaponTechniqueCatalogScript.CONTEXT_AERIAL_HEAVY
		and equipped_weapon != null
		and equipped_weapon.weapon_class == "staff"
	):
		var actor: Node3D = get_actor()
		if actor is CharacterBody3D:
			var body: CharacterBody3D = actor as CharacterBody3D
			body.velocity.y = minf(body.velocity.y, -7.4)
			_apply_planar_aerial_speed(body, 2.8, 0.5)
			plunge_landing_armed = true
			plunge_max_fall_speed = absf(minf(body.velocity.y, 0.0))
		return
	super.apply_aerial_technique_motion(context_id)


func request_combat_motion(attack: WeaponAttackDefinition) -> void:
	if attack != null and attack.extra_tags.has("axe_lever_vault"):
		var actor: Node3D = get_actor()
		if actor != null and actor.has_method("begin_combat_motion"):
			var charge: float = clampf(released_charge_ratio, 0.0, 1.0)
			actor.call(
				"begin_combat_motion",
				get_attack_forward(),
				lerpf(0.68, 1.05, charge),
				lerpf(0.18, 0.24, charge)
			)
		return
	if attack != null and attack.extra_tags.has("staff_charge_vault"):
		# The planted staff holds for a beat. The launch timer owns the actual leap.
		return
	super.request_combat_motion(attack)


func start_attack(attack: WeaponAttackDefinition) -> bool:
	var started: bool = super.start_attack(attack)
	if (
		started
		and current_attack != null
		and current_attack.extra_tags.has("staff_charge_vault")
	):
		_schedule_staff_map_vault()
	return started


func _update_charge_hold_heading(delta: float) -> void:
	if not charge_active or current_attack == null:
		return
	var charge_id: String = str(charge_profile.get("id", ""))
	if charge_id not in ["axe_lever_vault", "staff_map_vault"]:
		return
	var direction: Vector3 = _resolve_charge_heading(charge_id == "staff_map_vault")
	if direction.length_squared() <= 0.0001:
		return
	attack_forward_override = direction
	var actor: Node3D = get_actor()
	if actor == null:
		return
	var target_angle: float = atan2(-direction.x, -direction.z)
	actor.rotation.y = lerp_angle(
		actor.rotation.y,
		target_angle,
		clampf(maxf(delta, 0.0) * 7.5, 0.0, 1.0)
	)


func _resolve_charge_heading(prefer_camera: bool) -> Vector3:
	var actor: Node3D = get_actor()
	if actor == null:
		return Vector3.FORWARD
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	if input_vector.length() > 0.18:
		var right: Vector3 = actor.global_transform.basis.x
		var forward: Vector3 = -actor.global_transform.basis.z
		if camera != null:
			right = camera.global_transform.basis.x
			forward = -camera.global_transform.basis.z
		right.y = 0.0
		forward.y = 0.0
		var requested: Vector3 = right.normalized() * input_vector.x + forward.normalized() * -input_vector.y
		if requested.length_squared() > 0.0001:
			return requested.normalized()
	if prefer_camera and camera != null:
		var camera_forward: Vector3 = -camera.global_transform.basis.z
		camera_forward.y = 0.0
		if camera_forward.length_squared() > 0.0001:
			return camera_forward.normalized()
	var actor_forward: Vector3 = -actor.global_transform.basis.z
	actor_forward.y = 0.0
	return actor_forward.normalized() if actor_forward.length_squared() > 0.0001 else Vector3.FORWARD


func _stabilize_staff_mount(delta: float) -> void:
	if not is_staff_map_vault_charging():
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var braking: float = maxf(delta, 0.0) * 16.0
	body.velocity.x = move_toward(body.velocity.x, 0.0, braking)
	body.velocity.z = move_toward(body.velocity.z, 0.0, braking)


func _schedule_axe_vault_motion() -> void:
	if current_attack == null or not is_inside_tree():
		return
	var serial: int = flair_attack_serial
	var attack_id: String = current_attack.attack_id
	var startup: float = current_attack.get_startup_duration(get_attack_speed())
	_schedule_axe_phase(serial, attack_id, maxf(startup * 0.16, 0.08), 1)
	_schedule_axe_phase(serial, attack_id, maxf(startup * 0.3, 0.16), 2)
	_schedule_axe_phase(serial, attack_id, maxf(startup * 0.52, 0.28), 3)
	_schedule_axe_phase(serial, attack_id, maxf(startup * 0.64, 0.36), 4)
	_schedule_axe_phase(serial, attack_id, maxf(startup * 0.87, 0.5), 5)


func _schedule_axe_phase(
	serial: int,
	attack_id: String,
	delay: float,
	phase: int
) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(delay)
	var callback := func():
		_apply_axe_vault_motion(serial, attack_id, phase)
	timer.timeout.connect(callback, CONNECT_ONE_SHOT)


func _apply_axe_vault_motion(serial: int, attack_id: String, phase: int) -> void:
	if serial != flair_attack_serial or current_attack == null or current_attack.attack_id != attack_id:
		return
	if not current_attack.extra_tags.has("axe_lever_vault"):
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
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
			# One or two gathering steps end in the first axe plant.
			if actor.has_method("cancel_combat_motion"):
				actor.call("cancel_combat_motion", "axe planted")
			body.velocity.x *= 0.28
			body.velocity.z *= 0.28
			body.velocity.y = minf(body.velocity.y, -0.1)
			_execute_axe_first_plant()
		2:
			# Grace pushes against the buried head and rises around the handle.
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(0.35, 0.58, charge),
					lerpf(0.25, 0.31, charge)
				)
			body.velocity.y = maxf(body.velocity.y, lerpf(4.4, 5.6, charge))
		3:
			# At the apex she tears the axe free before committing to the twist.
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(0.55, 0.9, charge),
					0.18
				)
			body.velocity.y = maxf(body.velocity.y, lerpf(2.2, 3.0, charge))
		4:
			# The diagonal full-body rotation carries Grace and the axe forward.
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(3.7, 5.45, charge),
					lerpf(0.38, 0.46, charge)
				)
			body.velocity.y = maxf(body.velocity.y, lerpf(3.0, 4.1, charge))
		5:
			# She remains diagonally advancing as the second downstroke lands.
			if actor.has_method("begin_combat_motion"):
				actor.call(
					"begin_combat_motion",
					forward,
					lerpf(1.35, 2.05, charge),
					lerpf(0.18, 0.23, charge)
				)
			body.velocity.y = minf(body.velocity.y, -lerpf(8.8, 10.8, charge))


func _execute_axe_first_plant() -> void:
	if current_attack == null or equipped_weapon == null:
		return
	var pulse: WeaponAttackDefinition = ChargeCatalogScript.build_axe_plant_pulse(
		current_attack,
		released_charge_ratio
	)
	if pulse == null:
		return
	var payload: DamagePayload = pulse.build_payload(equipped_weapon)
	ChargeInfusionCatalogScript.apply_to_payload(
		payload,
		GameState.get_weapon_infusion()
	)
	var targets: Array[Node] = find_targets(pulse)
	for target: Node in targets:
		send_payload_to_target(target, payload)
		if target.has_method("receive_weapon_impact"):
			target.call("receive_weapon_impact", payload, get_attack_forward(), pulse)
		elif target.has_method("receive_hit_reaction"):
			target.call("receive_hit_reaction", get_attack_forward(), payload.knockback_strength)
	if not targets.is_empty():
		HitStop.request(pulse.hit_stop_duration, 0.055)


func _schedule_staff_map_vault() -> void:
	if current_attack == null or not is_inside_tree():
		return
	var serial: int = flair_attack_serial
	var attack_id: String = current_attack.attack_id
	var startup: float = current_attack.get_startup_duration(get_attack_speed())
	var timer: SceneTreeTimer = get_tree().create_timer(maxf(startup * 0.34, 0.1))
	var callback := func():
		_apply_staff_map_vault(serial, attack_id)
	timer.timeout.connect(callback, CONNECT_ONE_SHOT)


func _apply_staff_map_vault(serial: int, attack_id: String) -> void:
	if serial != flair_attack_serial or current_attack == null or current_attack.attack_id != attack_id:
		return
	if not current_attack.extra_tags.has("staff_charge_vault"):
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var forward: Vector3 = get_released_charge_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var charge: float = clampf(released_charge_ratio, 0.0, 1.0)
	if actor.has_method("cancel_combat_motion"):
		actor.call("cancel_combat_motion", "staff map vault")
	if actor.has_method("begin_combat_motion"):
		actor.call(
			"begin_combat_motion",
			forward,
			lerpf(10.5, 18.5, charge),
			lerpf(0.9, 1.25, charge)
		)
	body.velocity.y = maxf(body.velocity.y, lerpf(7.4, 10.2, charge))
	plunge_landing_armed = false
	plunge_max_fall_speed = 0.0


func get_charge_actions_v2_debug_data() -> Dictionary:
	return {
		"bow_free_aim_neutral_heavy_only": true,
		"bow_combo_heavies_generic": true,
		"axe_charge_walk": is_axe_lever_charge_active(),
		"axe_first_plant": current_attack != null and current_attack.extra_tags.has("axe_first_plant"),
		"axe_lever_vault": current_attack != null and current_attack.extra_tags.has("axe_lever_vault"),
		"axe_diagonal_twist": current_attack != null and current_attack.extra_tags.has("axe_diagonal_twist"),
		"staff_mounted_charge": is_staff_map_vault_charging(),
		"staff_map_vault": current_attack != null and current_attack.extra_tags.has("staff_charge_vault"),
		"staff_aerial_heavy_is_slam": true,
	}
