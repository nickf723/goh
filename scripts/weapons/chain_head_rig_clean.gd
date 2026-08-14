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

func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["speed_payload_scaling"] = false
	data["target_contact_scaling"] = false
	return data
