extends "res://scripts/weapons/chain_weapon_rig_v3.gd"
class_name FlailWeaponRigV2


func _ready() -> void:
	chain_length = 1.9
	tip_mass = 2.9
	contact_radius = 0.45
	segment_count = 7
	head_max_speed = 16.0
	head_response = 9.5
	line_sag = 0.28
	super._ready()
	remove_from_group("chain_weapon_rigs")
	add_to_group("flail_weapon_rigs")


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or controller == null:
		return
	_update_handle()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active_end: float = startup + attack.get_active_duration(attack_speed)
	var total: float = attack.get_total_duration(attack_speed)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var heavy: bool = attack.input_kind == "heavy"
	var rotations: float = 1.25 if heavy else 0.72

	if elapsed < startup:
		var p: float = smoothstep(
			0.0,
			1.0,
			clampf(elapsed / maxf(startup, 0.01), 0.0, 1.0)
		)
		# Complete the visible wind-up orbit exactly at the forward contact lane.
		# The head still lags this request, but the active frame below is authoritative.
		var start_angle: float = -TAU * rotations
		var angle: float = lerpf(start_angle, 0.0, p)
		var radius: float = chain_length * lerpf(0.58, 0.98, minf(p * 1.5, 1.0))
		_desired_tip = (
			handle
			+ forward * cos(angle) * radius
			+ right * sin(angle) * radius
			+ Vector3.UP * (0.12 + sin(p * PI * 2.0) * 0.08)
		)
		_side_bend = sin(angle) * 0.08
		_lift_bend = 0.04
	elif elapsed <= active_end:
		_desired_tip = handle + forward * chain_length * 0.96 + Vector3.UP * 0.08
		_visual_tip = _desired_tip
		_tip_velocity *= 0.35
		_side_bend = 0.0
		_lift_bend = 0.0
		_update_line_points()
		_update_tip_visual()
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		_desired_tip = _desired_tip.lerp(_idle_tip(), recovery)
		_side_bend = lerpf(_side_bend, 0.0, recovery)
		_lift_bend = lerpf(_lift_bend, 0.0, recovery)


func modify_attack_payload(payload: DamagePayload, attack: WeaponAttackDefinition) -> void:
	super.modify_attack_payload(payload, attack)
	if payload == null or attack == null:
		return
	_append_tag(payload, "flail")
	_append_tag(payload, "damped_weighted_head")
	if attack.input_kind == "heavy":
		payload.knockback_strength *= 1.18
		payload.stance_damage += 1
		_append_tag(payload, "momentum")


func modify_payload_for_target(
	payload: DamagePayload,
	target: Node,
	attack: WeaponAttackDefinition
) -> void:
	super.modify_payload_for_target(payload, target, attack)
	if payload == null:
		return
	if payload.tags.has("weighted_tip"):
		payload.knockback_strength *= 1.16
		payload.stance_damage += 1
		_append_tag(payload, "flail_head_contact")
	else:
		_append_tag(payload, "flail_chain_contact")


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "controlled_flail_v2"
	data["simplified_physics"] = true
	data["head_lag_only"] = true
	data["chain_length"] = chain_length
	data["head_mass"] = tip_mass
	return data
