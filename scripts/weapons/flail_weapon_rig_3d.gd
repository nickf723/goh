extends "res://scripts/weapons/chain_weapon_rig_v2.gd"
class_name FlailWeaponRig3D


func _ready() -> void:
	# Configure the inherited weighted-chain foundation before it constructs the
	# tether so Flail is short, head-heavy, and intentionally slower to redirect.
	chain_length = 1.9
	tip_mass = 2.9
	contact_radius = 0.5
	maximum_sweep_samples = 18
	endpoint_max_speed = 18.0
	endpoint_response = 8.5
	body_contact_radius_scale = 0.72
	super._ready()
	remove_from_group("chain_weapon_rigs")
	add_to_group("flail_weapon_rigs")
	if tether != null:
		tether.segment_count = 9
		tether.constraint_iterations = 14
		tether.verlet_damping = 0.915
		tether.gravity_scale = 0.38
		tether.reset_tether()


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or weighted_tip == null:
		return
	_update_handle()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active: float = attack.get_active_duration(attack_speed)
	var active_end: float = startup + active
	var total: float = attack.get_total_duration(attack_speed)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _get_forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	if elapsed <= active_end:
		var swing_progress: float = clampf(
			elapsed / maxf(active_end, 0.01),
			0.0,
			1.0
		)
		var eased: float = smoothstep(0.0, 1.0, swing_progress)
		var heavy: bool = attack.input_kind == "heavy"
		var arc_degrees: float = 500.0 if heavy else 300.0
		var start_degrees: float = -155.0 if heavy else -112.0
		var angle: float = deg_to_rad(start_degrees + arc_degrees * eased)
		var radius: float = chain_length * lerpf(0.62, 0.98, minf(eased * 1.5, 1.0))
		var lift: float = (
			sin(eased * PI * 2.0) * 0.12
			+ (0.12 if heavy else 0.2)
		)
		_desired_tip_position = (
			handle
			+ forward * cos(angle) * radius
			+ right * sin(angle) * radius
			+ Vector3.UP * lift
		)
	else:
		var recovery_weight: float = smoothstep(
			0.0,
			1.0,
			clampf(
				(elapsed - active_end) / maxf(total - active_end, 0.01),
				0.0,
				1.0
			)
		)
		var idle_target: Vector3 = handle + forward * 0.36 + Vector3.DOWN * 0.72
		_desired_tip_position = _desired_tip_position.lerp(idle_target, recovery_weight)


func modify_attack_payload(payload: DamagePayload, attack: WeaponAttackDefinition) -> void:
	super.modify_attack_payload(payload, attack)
	if payload == null or attack == null:
		return
	if not payload.tags.has("flail"):
		payload.tags.append("flail")
	if not payload.tags.has("orbiting_head"):
		payload.tags.append("orbiting_head")
	if attack.input_kind == "heavy":
		payload.knockback_strength *= 1.18
		payload.stance_damage += 1
		if not payload.tags.has("momentum"):
			payload.tags.append("momentum")


func modify_payload_for_target(
	payload: DamagePayload,
	target: Node,
	attack: WeaponAttackDefinition
) -> void:
	super.modify_payload_for_target(payload, target, attack)
	if payload == null:
		return
	if payload.tags.has("weighted_tip"):
		payload.knockback_strength *= 1.18
		payload.stance_damage += 1
		if not payload.tags.has("flail_head_contact"):
			payload.tags.append("flail_head_contact")
	else:
		if not payload.tags.has("flail_chain_contact"):
			payload.tags.append("flail_chain_contact")


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "physical_flail_v1"
	data["chain_length"] = chain_length
	data["head_mass"] = tip_mass
	data["physics_flail"] = true
	return data
