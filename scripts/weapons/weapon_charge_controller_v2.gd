extends "res://scripts/weapons/weapon_charge_controller_v1.gd"
class_name WeaponChargeControllerV2

const ChargeMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")
const ChargeInfusionCatalogScript = preload("res://scripts/weapons/weapon_infusion_catalog.gd")


func _update_charge_state(delta: float) -> void:
	if (charge_pending or charge_active) and action_state != null:
		if action_state.is_defeated or action_state.is_casting or action_state.is_dodging or action_state.is_staggered:
			_cancel_weapon_charge()
			return
	super._update_charge_state(delta)


func _execute_sustain_charge_pulse() -> void:
	if not is_chain_orbit_charging() or charge_base_attack == null or equipped_weapon == null:
		return
	var pulse: WeaponAttackDefinition = ChargeCatalogScript.build_sustain_pulse(
		charge_base_attack,
		equipped_weapon.weapon_class,
		get_weapon_charge_ratio()
	)
	if pulse == null:
		return
	var payload: DamagePayload = pulse.build_payload(equipped_weapon)
	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	ChargeMasteryCatalogScript.apply_payload_upgrades(
		payload,
		equipped_weapon.weapon_class,
		mastery_rank,
		pulse,
		combo_history.size()
	)
	ChargeInfusionCatalogScript.apply_to_payload(payload, GameState.get_weapon_infusion())
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("modify_attack_payload"):
		runtime_weapon_rig.call("modify_attack_payload", payload, pulse)
	var targets: Array[Node] = find_targets(pulse)
	for target: Node in targets:
		send_payload_to_target(target, payload)
		if target.has_method("receive_weapon_impact"):
			target.call("receive_weapon_impact", payload, get_attack_forward(), pulse)
		elif target.has_method("receive_hit_reaction"):
			target.call("receive_hit_reaction", get_attack_forward(), payload.knockback_strength)
	if targets.is_empty():
		return
	last_attack_connected = true
	HitStop.request(pulse.hit_stop_duration, 0.055)


func _apply_chain_charge_tug() -> void:
	if not is_chain_orbit_charging():
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var forward: Vector3 = get_attack_forward()
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return
	forward = forward.normalized()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var charge: float = get_weapon_charge_ratio()
	var influence: float = lerpf(0.35, 1.0, charge)
	var phase: float = get_weapon_charge_elapsed() * lerpf(2.15, 3.05, charge)
	var tangent: Vector3 = (-forward * sin(phase) + right * cos(phase)).normalized()
	var tug: Vector3 = tangent * chain_charge_tug_speed * influence
	var blend: float = lerpf(0.055, 0.13, influence)
	body.velocity.x = lerpf(body.velocity.x, body.velocity.x * 0.82 + tug.x, blend)
	body.velocity.z = lerpf(body.velocity.z, body.velocity.z * 0.82 + tug.z, blend)


func start_attack(attack: WeaponAttackDefinition) -> bool:
	var started: bool = super.start_attack(attack)
	if started and current_attack != null and current_attack.extra_tags.has("axe_vault_slam"):
		_schedule_axe_vault_motion()
	return started


func _schedule_axe_vault_motion() -> void:
	if current_attack == null or not is_inside_tree():
		return
	var serial: int = flair_attack_serial
	var attack_id: String = current_attack.attack_id
	var startup: float = current_attack.get_startup_duration(get_attack_speed())
	var lift_timer: SceneTreeTimer = get_tree().create_timer(maxf(startup * 0.24, 0.05))
	var lift_callback := func():
		_apply_axe_vault_motion(serial, attack_id, 1)
	lift_timer.timeout.connect(lift_callback, CONNECT_ONE_SHOT)
	var slam_timer: SceneTreeTimer = get_tree().create_timer(maxf(startup * 0.58, 0.12))
	var slam_callback := func():
		_apply_axe_vault_motion(serial, attack_id, 2)
	slam_timer.timeout.connect(slam_callback, CONNECT_ONE_SHOT)


func _apply_axe_vault_motion(serial: int, attack_id: String, phase: int) -> void:
	if serial != flair_attack_serial or current_attack == null or current_attack.attack_id != attack_id:
		return
	if not current_attack.extra_tags.has("axe_vault_slam"):
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var forward: Vector3 = get_attack_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var charge: float = clampf(released_charge_ratio, 0.0, 1.0)
	if phase == 1:
		body.velocity.x = forward.x * lerpf(3.8, 4.8, charge)
		body.velocity.z = forward.z * lerpf(3.8, 4.8, charge)
		body.velocity.y = maxf(body.velocity.y, lerpf(5.8, 7.0, charge))
	else:
		body.velocity.x = forward.x * lerpf(4.4, 5.5, charge)
		body.velocity.z = forward.z * lerpf(4.4, 5.5, charge)
		body.velocity.y = minf(body.velocity.y, -lerpf(8.8, 11.0, charge))


func _begin_bow_aim() -> bool:
	var started: bool = super._begin_bow_aim()
	if started:
		_enter_bow_aim_camera()
	return started


func _release_bow_aim() -> void:
	super._release_bow_aim()
	_exit_bow_aim_camera()


func _cancel_bow_aim() -> void:
	super._cancel_bow_aim()
	_exit_bow_aim_camera()


func get_bow_aim_screen_uv() -> Vector2:
	return Vector2(0.5, 0.5)


func _enter_bow_aim_camera() -> void:
	var actor: Node3D = get_actor()
	if actor == null:
		return
	bow_aim_camera = get_viewport().get_camera_3d() if is_inside_tree() else null
	bow_aim_spring = actor.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	if bow_aim_camera == null or bow_aim_spring == null:
		return
	bow_original_fov = bow_aim_camera.fov
	bow_original_spring_position = bow_aim_spring.position
	_kill_bow_camera_tween()
	bow_camera_tween = create_tween()
	bow_camera_tween.set_trans(Tween.TRANS_QUAD)
	bow_camera_tween.set_ease(Tween.EASE_OUT)
	var shoulder_position: Vector3 = bow_original_spring_position
	shoulder_position.x += bow_shoulder_offset
	bow_camera_tween.parallel().tween_property(bow_aim_spring, "position", shoulder_position, bow_camera_transition)
	bow_camera_tween.parallel().tween_property(bow_aim_camera, "fov", bow_aim_fov, bow_camera_transition)


func _exit_bow_aim_camera() -> void:
	if bow_aim_camera == null or bow_aim_spring == null:
		return
	_kill_bow_camera_tween()
	bow_camera_tween = create_tween()
	bow_camera_tween.set_trans(Tween.TRANS_QUAD)
	bow_camera_tween.set_ease(Tween.EASE_OUT)
	bow_camera_tween.parallel().tween_property(bow_aim_spring, "position", bow_original_spring_position, bow_camera_transition)
	bow_camera_tween.parallel().tween_property(bow_aim_camera, "fov", bow_original_fov, bow_camera_transition)


func _kill_bow_camera_tween() -> void:
	if bow_camera_tween != null and bow_camera_tween.is_valid():
		bow_camera_tween.kill()
	bow_camera_tween = null


func get_charge_v2_debug_data() -> Dictionary:
	return {
		"charge_attack_grammar": true,
		"charge_pending": charge_pending,
		"charge_active": charge_active,
		"charge_id": str(charge_profile.get("id", "none")),
		"charge_ratio": snappedf(get_weapon_charge_ratio(), 0.01),
		"chain_sustained_orbit": is_chain_orbit_charging(),
		"axe_vault_slam": current_attack != null and current_attack.extra_tags.has("axe_vault_slam"),
		"bow_reticle_convergence": true,
		"bow_shoulder_camera": bow_aim_active,
	}
