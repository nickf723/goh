extends "res://scripts/weapons/weapon_charge_runtime.gd"
class_name WeaponChargeActions

func _execute_sustain_charge_pulse() -> void:
	if not is_chain_orbit_charging() or charge_base_attack == null or equipped_weapon == null:
		return
	var pulse: WeaponAttackDefinition = ChargeCatalogScript.build_sustain_pulse(charge_base_attack, equipped_weapon.weapon_class, get_weapon_charge_ratio())
	if pulse == null:
		return
	var payload: DamagePayload = pulse.build_payload(equipped_weapon)
	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	ChargeMasteryCatalogScript.apply_payload_upgrades(payload, equipped_weapon.weapon_class, mastery_rank, pulse, combo_history.size())
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
	if not targets.is_empty():
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

func _apply_chain_momentum_to_attack(_attack: WeaponAttackDefinition) -> void:
	pass

func _update_chain_momentum(_delta: float) -> void:
	chain_momentum_stacks = 0
	chain_momentum_timer = 0.0
	chain_attack_momentum_spent = 0

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
