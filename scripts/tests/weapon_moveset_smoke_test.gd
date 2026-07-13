extends Node

const Sword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const Hammer: WeaponDefinition = preload("res://data/weapons/training_hammer.tres")
const Spear: WeaponDefinition = preload("res://data/weapons/training_spear.tres")

var failures: Array[String] = []


func _ready() -> void:
	run_tests()

	if failures.is_empty():
		print("WEAPON_MOVESET_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("WEAPON_MOVESET_SMOKE_TEST: " + failure)

	get_tree().quit(1)


func run_tests() -> void:
	validate_weapon(Sword, "sword", 9)
	validate_weapon(Hammer, "hammer", 7)
	validate_weapon(Spear, "lance", 7)
	validate_sword_branch_tree()
	validate_hammer_identity()
	validate_spear_identity()
	validate_payload_contracts()


func validate_weapon(weapon: WeaponDefinition, expected_class: String, expected_attacks: int) -> void:
	if weapon == null:
		failures.append("missing weapon resource for " + expected_class)
		return

	if weapon.weapon_class != expected_class:
		failures.append(weapon.display_name + " expected class " + expected_class + " but was " + weapon.weapon_class)

	if weapon.moveset == null:
		failures.append(weapon.display_name + " has no moveset")
		return

	var graph_errors: Array[String] = weapon.moveset.validate_graph()
	for graph_error: String in graph_errors:
		failures.append(weapon.display_name + " graph: " + graph_error)

	if weapon.moveset.attacks.size() != expected_attacks:
		failures.append(
			weapon.display_name
			+ " expected "
			+ str(expected_attacks)
			+ " attacks but found "
			+ str(weapon.moveset.attacks.size())
		)

	for attack: WeaponAttackDefinition in weapon.moveset.attacks:
		if attack == null:
			continue
		if attack.get_total_duration(weapon.attack_speed) <= 0.0:
			failures.append(weapon.display_name + " attack has non-positive duration: " + attack.attack_id)
		if attack.attack_range <= 0.0:
			failures.append(weapon.display_name + " attack has non-positive range: " + attack.attack_id)
		if attack.cone_angle_degrees <= 0.0:
			failures.append(weapon.display_name + " attack has non-positive cone: " + attack.attack_id)


func validate_sword_branch_tree() -> void:
	var moveset: WeaponMovesetDefinition = Sword.moveset
	assert_attack_id(moveset.get_entry_attack("light"), "sword_l1", "Sword light entry")
	assert_attack_id(moveset.get_entry_attack("heavy"), "sword_h0", "Sword heavy entry")
	assert_follow_up(moveset, "sword_l1", "light", "sword_l2")
	assert_follow_up(moveset, "sword_l1", "heavy", "sword_h1")
	assert_follow_up(moveset, "sword_l2", "light", "sword_l3")
	assert_follow_up(moveset, "sword_l2", "heavy", "sword_h2")
	assert_follow_up(moveset, "sword_l3", "light", "sword_l4")
	assert_follow_up(moveset, "sword_l3", "heavy", "sword_h3")
	assert_follow_up(moveset, "sword_l4", "heavy", "sword_h4")

	var light_one: WeaponAttackDefinition = moveset.get_attack("sword_l1")
	var heavy_four: WeaponAttackDefinition = moveset.get_attack("sword_h4")

	if light_one == null or not light_one.allow_spell_cancel or not light_one.allow_dodge_cancel:
		failures.append("Sword opening light must support both late spell and dodge cancel")

	if heavy_four == null or heavy_four.damage_multiplier <= light_one.damage_multiplier:
		failures.append("Sword final heavy must out-damage the opening light")


func validate_hammer_identity() -> void:
	var moveset: WeaponMovesetDefinition = Hammer.moveset
	var opening: WeaponAttackDefinition = moveset.get_entry_attack("light")
	var heavy: WeaponAttackDefinition = moveset.get_entry_attack("heavy")

	if opening == null or heavy == null:
		failures.append("Hammer is missing an entry attack")
		return

	if not opening.extra_tags.has("force") or not heavy.extra_tags.has("force"):
		failures.append("Hammer entries must carry force tags")

	if heavy.stance_multiplier <= opening.stance_multiplier:
		failures.append("Hammer neutral heavy must exceed opening light stance pressure")

	if heavy.allow_spell_cancel or heavy.allow_dodge_cancel:
		failures.append("Hammer neutral heavy must remain fully committed")


func validate_spear_identity() -> void:
	var moveset: WeaponMovesetDefinition = Spear.moveset
	var opening: WeaponAttackDefinition = moveset.get_entry_attack("light")
	var heavy: WeaponAttackDefinition = moveset.get_entry_attack("heavy")

	if opening == null or heavy == null:
		failures.append("Spear is missing an entry attack")
		return

	if opening.attack_range <= Sword.moveset.get_entry_attack("light").attack_range:
		failures.append("Spear opening light must outrange Sword opening light")

	if opening.cone_angle_degrees >= Sword.moveset.get_entry_attack("light").cone_angle_degrees:
		failures.append("Spear opening light must be narrower than Sword opening light")

	if heavy.movement_distance <= opening.movement_distance:
		failures.append("Spear neutral heavy must advance farther than its opening light")


func validate_payload_contracts() -> void:
	var sword_light: WeaponAttackDefinition = Sword.moveset.get_entry_attack("light")
	var sword_heavy: WeaponAttackDefinition = Sword.moveset.get_entry_attack("heavy")
	var hammer_heavy: WeaponAttackDefinition = Hammer.moveset.get_entry_attack("heavy")
	var spear_light: WeaponAttackDefinition = Spear.moveset.get_entry_attack("light")

	var sword_light_payload: DamagePayload = sword_light.build_payload(Sword)
	var sword_heavy_payload: DamagePayload = sword_heavy.build_payload(Sword)
	var hammer_payload: DamagePayload = hammer_heavy.build_payload(Hammer)
	var spear_payload: DamagePayload = spear_light.build_payload(Spear)

	assert_payload_tag(sword_light_payload, "light", "Sword opening light")
	assert_payload_tag(sword_heavy_payload, "heavy", "Sword neutral heavy")
	assert_payload_tag(sword_heavy_payload, "force", "Sword neutral heavy")
	assert_payload_tag(hammer_payload, "force", "Hammer neutral heavy")
	assert_payload_tag(hammer_payload, "blunt", "Hammer neutral heavy")
	assert_payload_tag(spear_payload, "pierce", "Spear opening light")

	for payload: DamagePayload in [sword_light_payload, sword_heavy_payload, hammer_payload, spear_payload]:
		if payload == null:
			failures.append("Attack failed to build a DamagePayload")
			continue
		if payload.hit_type != "melee":
			failures.append(payload.source_name + " expected melee hit type")
		if not payload.tags.has("weapon") or not payload.tags.has("melee"):
			failures.append(payload.source_name + " missing standard weapon/melee tags")


func assert_follow_up(
	moveset: WeaponMovesetDefinition,
	current_attack_id: String,
	input_kind: String,
	expected_attack_id: String
) -> void:
	var current_attack: WeaponAttackDefinition = moveset.get_attack(current_attack_id)
	var next_attack: WeaponAttackDefinition = moveset.get_follow_up(current_attack, input_kind)
	assert_attack_id(next_attack, expected_attack_id, current_attack_id + " + " + input_kind)


func assert_attack_id(attack: WeaponAttackDefinition, expected_attack_id: String, context: String) -> void:
	if attack == null:
		failures.append(context + " resolved to null; expected " + expected_attack_id)
		return

	if attack.attack_id != expected_attack_id:
		failures.append(context + " expected " + expected_attack_id + " but found " + attack.attack_id)


func assert_payload_tag(payload: DamagePayload, tag: String, context: String) -> void:
	if payload == null or not payload.tags.has(tag):
		failures.append(context + " missing payload tag: " + tag)
