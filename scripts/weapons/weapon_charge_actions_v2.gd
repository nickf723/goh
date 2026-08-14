extends "res://scripts/weapons/weapon_charge_actions.gd"
class_name WeaponChargeActionsV2


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
	# Neutral Heavy owns the free-aim draw. Any Heavy entered during a Bow string
	# stays inside the normal combo graph and fires immediately instead of opening
	# the shoulder-aim state.
	if current_attack != null:
		return true
	return combo_timeout_timer > 0.0 and last_completed_attack_id != ""


func request_combat_motion(attack: WeaponAttackDefinition) -> void:
	if attack != null and attack.extra_tags.has("axe_forward_drive"):
		var actor: Node3D = get_actor()
		if actor != null and actor.has_method("begin_combat_motion"):
			actor.call(
				"begin_combat_motion",
				get_attack_forward(),
				attack.movement_distance,
				maxf(attack.movement_duration, 0.01)
			)
			return
	super.request_combat_motion(attack)


func _schedule_axe_vault_motion() -> void:
	if current_attack == null or not is_inside_tree():
		return
	var serial: int = flair_attack_serial
	var attack_id: String = current_attack.attack_id
	var startup: float = current_attack.get_startup_duration(get_attack_speed())
	var lift_timer: SceneTreeTimer = get_tree().create_timer(maxf(startup * 0.18, 0.05))
	var lift_callback := func():
		_apply_axe_vault_motion(serial, attack_id, 1)
	lift_timer.timeout.connect(lift_callback, CONNECT_ONE_SHOT)
	var carry_timer: SceneTreeTimer = get_tree().create_timer(maxf(startup * 0.46, 0.11))
	var carry_callback := func():
		_apply_axe_vault_motion(serial, attack_id, 2)
	carry_timer.timeout.connect(carry_callback, CONNECT_ONE_SHOT)
	var slam_timer: SceneTreeTimer = get_tree().create_timer(maxf(startup * 0.72, 0.17))
	var slam_callback := func():
		_apply_axe_vault_motion(serial, attack_id, 3)
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
	match phase:
		1:
			# Low forward vault off the planted axe. The horizontal combat-motion
			# contract supplies the march; this impulse gives the body its hop.
			body.velocity.y = maxf(body.velocity.y, lerpf(3.7, 4.7, charge))
		2:
			# Carry forward through the rotation instead of hanging above the plant.
			body.velocity.x = maxf(absf(body.velocity.x), 0.01) * signf(body.velocity.x) if absf(body.velocity.x) > 0.01 else forward.x * lerpf(6.0, 7.4, charge)
			body.velocity.z = maxf(absf(body.velocity.z), 0.01) * signf(body.velocity.z) if absf(body.velocity.z) > 0.01 else forward.z * lerpf(6.0, 7.4, charge)
			body.velocity.y = minf(maxf(body.velocity.y, 0.8), lerpf(2.2, 2.8, charge))
		3:
			# The axe and Grace arrive together: still advancing, now aggressively down.
			body.velocity.x = forward.x * lerpf(7.6, 9.2, charge)
			body.velocity.z = forward.z * lerpf(7.6, 9.2, charge)
			body.velocity.y = minf(body.velocity.y, -lerpf(7.6, 9.4, charge))


func get_charge_actions_v2_debug_data() -> Dictionary:
	return {
		"bow_free_aim_neutral_heavy_only": true,
		"bow_combo_heavies_generic": true,
		"axe_forward_drive": current_attack != null and current_attack.extra_tags.has("axe_forward_drive"),
		"axe_three_phase_march": true,
	}
