extends Node

const Whip: WeaponDefinition = preload("res://data/weapons/training_whip.tres")
const LeatherWhip: FlexibleMaterialProfile = preload("res://data/flexible_materials/leather_whip.tres")
const RigScene: PackedScene = preload("res://scenes/weapons/whip_weapon_rig.tscn")
const PullSwitchScene: PackedScene = preload("res://scenes/actors/testing/whip_pull_switch.tscn")
const LabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_whip_weapon_lab_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	run_tests()
	if failures.is_empty():
		print("WHIP_WEAPON_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WHIP_WEAPON_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func run_tests() -> void:
	if Whip == null:
		failures.append("Training Crackwhip resource is missing")
		return
	if Whip.weapon_class != "whip":
		failures.append("Training Crackwhip must use the whip weapon class")
	if Whip.runtime_rig_scene == null:
		failures.append("Training Crackwhip has no runtime rig scene")
	if Whip.moveset == null:
		failures.append("Training Crackwhip has no moveset")
		return

	for graph_error: String in Whip.moveset.validate_graph():
		failures.append("moveset graph: " + graph_error)
	if Whip.moveset.attacks.size() != 6:
		failures.append("expected 6 whip attacks")

	assert_attack("whip_l1", "whip_l2", "whip_h1")
	assert_attack("whip_l2", "whip_l3", "whip_h2")
	assert_attack("whip_l3", "", "")
	assert_attack("whip_h0", "", "")

	var light: WeaponAttackDefinition = Whip.moveset.get_entry_attack("light")
	var heavy: WeaponAttackDefinition = Whip.moveset.get_entry_attack("heavy")
	var wrap: WeaponAttackDefinition = Whip.moveset.get_attack("whip_h1")
	if light == null or heavy == null or wrap == null:
		failures.append("whip entry or wrap attacks are missing")
	else:
		var light_payload: DamagePayload = light.build_payload(Whip)
		for required_tag: String in ["whip", "flexible_weapon", "tip_focused"]:
			if not light_payload.tags.has(required_tag):
				failures.append("light payload missing " + required_tag)
		if not heavy.extra_tags.has("overhead") or not heavy.extra_tags.has("crack"):
			failures.append("neutral heavy must use the overhead crack trajectory")
		if not wrap.extra_tags.has("wrap") or not wrap.extra_tags.has("pull"):
			failures.append("Light to Heavy must branch into a wrap and pull attack")

	if LeatherWhip == null:
		failures.append("Braided Leather Whip material is missing")
	else:
		if LeatherWhip.conductive:
			failures.append("leather whip must not conduct by default")
		if not LeatherWhip.burnable:
			failures.append("leather whip must inherit burnable flexible-material behavior")
		if LeatherWhip.linear_density >= 0.5:
			failures.append("whip must remain materially lighter than an iron chain")

	var rig: Node = RigScene.instantiate()
	add_child(rig)
	if not rig is WhipWeaponRig3D:
		failures.append("runtime rig is not a WhipWeaponRig3D")
	else:
		if rig.get_node_or_null("FlexibleWhip") == null:
			failures.append("runtime rig did not construct its FlexibleWhip")
		if rig.get_node_or_null("WaveFront") == null:
			failures.append("runtime rig did not construct its WaveFront marker")
		rig.set("current_tip_speed", float(rig.get("crack_speed_threshold")) * 1.15)
		rig.set("is_cracking", true)
		var crack_payload: DamagePayload = heavy.build_payload(Whip)
		rig.call("modify_attack_payload", crack_payload, heavy)
		if not crack_payload.tags.has("whip_crack") or not crack_payload.tags.has("sonic"):
			failures.append("a threshold-speed crack must add sonic crack tags")
	rig.queue_free()

	var pull_switch: Node = PullSwitchScene.instantiate()
	add_child(pull_switch)
	if not pull_switch.has_method("receive_whip_pull"):
		failures.append("pull switch does not expose the whip pull contract")
	else:
		pull_switch.call("receive_whip_pull", 5.5, null)
		if not bool(pull_switch.get("pulled")):
			failures.append("pull switch did not materially change state")
	pull_switch.queue_free()

	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("whip weapon laboratory failed to instantiate")
	else:
		if float(lab.get("stamina_regeneration_per_second")) <= 0.0:
			failures.append("whip laboratory must regenerate practice stamina")
		if lab.get_node_or_null("Crosswind") == null:
			failures.append("whip laboratory is missing its airflow station")
		if lab.get_node_or_null("PullSwitch") == null:
			failures.append("whip laboratory is missing its pull interaction")
		lab.queue_free()


func assert_attack(
	attack_id: String,
	expected_light: String,
	expected_heavy: String
) -> void:
	var attack: WeaponAttackDefinition = Whip.moveset.get_attack(attack_id)
	if attack == null:
		failures.append("missing attack " + attack_id)
		return
	if attack.next_light_attack_id != expected_light:
		failures.append(attack_id + " light link mismatch")
	if attack.next_heavy_attack_id != expected_heavy:
		failures.append(attack_id + " heavy link mismatch")
