extends "res://scripts/weapons/chain_weapon_rig_v7.gd"
class_name ChainHeadRig

const HeadContactSolverScript = preload("res://scripts/weapons/chain_head_contact_solver.gd")

func find_weapon_targets(weapon_controller: WeaponController, attack: WeaponAttackDefinition, collision_mask: int) -> Array[Node]:
	var result: Dictionary = HeadContactSolverScript.find_targets(self, weapon_controller, attack, collision_mask, tip_history, _visual_tip, head_contact_radius)
	_contact_strengths = result.get("strengths", {}) as Dictionary
	var targets: Array[Node] = []
	var raw_targets: Array = result.get("targets", []) as Array
	for value: Variant in raw_targets:
		if value is Node:
			targets.append(value as Node)
	return targets

func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "head_authoritative_chain"
	data["head_authoritative_contacts"] = true
	return data
