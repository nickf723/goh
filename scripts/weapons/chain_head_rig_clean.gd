extends "res://scripts/weapons/chain_head_rig.gd"
class_name ChainHeadRigClean

func modify_attack_payload(payload: DamagePayload, _attack: WeaponAttackDefinition) -> void:
	if payload == null:
		return
	_append_tag(payload, "flexible_weapon")
	_append_tag(payload, "chain")
	_append_tag(payload, "weighted_head")
	_append_tag(payload, "head_authoritative")

func modify_payload_for_target(payload: DamagePayload, _target: Node, _attack: WeaponAttackDefinition) -> void:
	if payload != null:
		_append_tag(payload, "weighted_head_contact")

func _record_tip_history() -> void:
	if tip_history.is_empty() or tip_history[tip_history.size() - 1].distance_to(_visual_tip) > 0.08:
		tip_history.append(_visual_tip)
	var maximum_samples: int = 26 if _is_charge_orbit_active() else maxi(trail_sample_count, 3)
	while tip_history.size() > maximum_samples:
		tip_history.remove_at(0)

func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["speed_payload_scaling"] = false
	data["target_contact_scaling"] = false
	data["charge_sweep_history"] = 26
	return data
