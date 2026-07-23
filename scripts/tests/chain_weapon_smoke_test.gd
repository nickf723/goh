extends Node

const Chain: WeaponDefinition = preload("res://data/weapons/training_chain.tres")
const RigScene: PackedScene = preload("res://scenes/weapons/chain_weapon_rig.tscn")
const LabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_chain_weapon_lab_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	run_tests()
	if failures.is_empty():
		print("CHAIN_WEAPON_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CHAIN_WEAPON_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func run_tests() -> void:
	if Chain == null:
		failures.append("Training Chain resource is missing")
		return
	if Chain.weapon_class != "chains":
		failures.append("Training Chain must use the chains weapon class")
	if Chain.runtime_rig_scene == null:
		failures.append("Training Chain has no runtime rig scene")
	if Chain.moveset == null:
		failures.append("Training Chain has no moveset")
		return

	for graph_error: String in Chain.moveset.validate_graph():
		failures.append("moveset graph: " + graph_error)
	if Chain.moveset.attacks.size() != 7:
		failures.append("expected 7 chain attacks")

	assert_attack("chain_l1", "chain_l2", "chain_h1")
	assert_attack("chain_l2", "chain_l3", "chain_h2")
	assert_attack("chain_l3", "", "chain_h3")
	assert_attack("chain_h0", "", "")

	var light: WeaponAttackDefinition = Chain.moveset.get_entry_attack("light")
	var heavy: WeaponAttackDefinition = Chain.moveset.get_entry_attack("heavy")
	if light == null or heavy == null:
		failures.append("chain entry attacks are missing")
	else:
		var light_payload: DamagePayload = light.build_payload(Chain)
		var heavy_payload: DamagePayload = heavy.build_payload(Chain)
		for required_tag: String in ["chain", "weighted_tip", "force", "blunt"]:
			if not light_payload.tags.has(required_tag):
				failures.append("light payload missing " + required_tag)
		if not heavy.extra_tags.has("slam"):
			failures.append("neutral heavy must use the slam trajectory")
		if heavy.stance_multiplier <= light.stance_multiplier:
			failures.append("neutral heavy must exceed light stance pressure")

	var rig: Node = RigScene.instantiate()
	add_child(rig)
	if not rig is ChainWeaponRig3D:
		failures.append("runtime rig is not a ChainWeaponRig3D")
	elif rig.get_node_or_null("FlexibleChain") == null:
		failures.append("runtime rig did not construct its FlexibleChain")
	rig.queue_free()

	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("chain weapon laboratory failed to instantiate")
	else:
		lab.queue_free()


func assert_attack(
	attack_id: String,
	expected_light: String,
	expected_heavy: String
) -> void:
	var attack: WeaponAttackDefinition = Chain.moveset.get_attack(attack_id)
	if attack == null:
		failures.append("missing attack " + attack_id)
		return
	if attack.next_light_attack_id != expected_light:
		failures.append(attack_id + " light link mismatch")
	if attack.next_heavy_attack_id != expected_heavy:
		failures.append(attack_id + " heavy link mismatch")
