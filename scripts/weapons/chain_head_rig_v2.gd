extends "res://scripts/weapons/chain_head_motion_v4.gd"
class_name ChainHeadRigV2

const ChainContactSolverV2Script = preload("res://scripts/weapons/chain_contact_solver_v2.gd")


func find_weapon_targets(
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int
) -> Array[Node]:
	var line_samples: Array[Dictionary] = []
	if line != null:
		line_samples = line.get_contact_samples(true)
	var handle_position: Vector3 = handle_anchor.global_position if handle_anchor != null else global_position
	var result: Dictionary = ChainContactSolverV2Script.find_targets(
		self,
		weapon_controller,
		attack,
		collision_mask,
		tip_history,
		_visual_tip,
		head_contact_radius,
		handle_position,
		line_samples
	)
	_contact_strengths = result.get("strengths", {}) as Dictionary
	var targets: Array[Node] = []
	var raw_targets: Array = result.get("targets", []) as Array
	for value: Variant in raw_targets:
		if value is Node:
			targets.append(value as Node)
	return targets


func modify_attack_payload(payload: DamagePayload, _attack: WeaponAttackDefinition) -> void:
	if payload == null:
		return
	_append_tag(payload, "flexible_weapon")
	_append_tag(payload, "chain")
	_append_tag(payload, "weighted_head")
	_append_tag(payload, "dangerous_tether")


func modify_payload_for_target(
	payload: DamagePayload,
	target: Node,
	_attack: WeaponAttackDefinition
) -> void:
	if payload == null or target == null:
		return
	var strength: float = clampf(
		float(_contact_strengths.get(target.get_instance_id(), 0.72)),
		0.5,
		1.0
	)
	payload.amount = maxi(1, roundi(float(payload.amount) * lerpf(0.58, 1.0, strength)))
	payload.stance_damage = maxi(1, roundi(float(payload.stance_damage) * lerpf(0.55, 1.0, strength)))
	payload.knockback_strength *= lerpf(0.45, 1.0, strength)
	if strength >= 0.97:
		_append_tag(payload, "weighted_head_contact")
	else:
		_append_tag(payload, "chain_body_contact")


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "dangerous_tether_chain_v2"
	data["links_deal_damage"] = true
	data["head_full_strength"] = true
	data["contact_targets"] = _contact_strengths.size()
	return data
