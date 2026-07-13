extends Node

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")
const StatusReceiverScript = preload("res://scripts/combat/status_receiver.gd")

var failures: Array[String] = []
var fixture: Node3D
var status_receiver: Node


func _ready() -> void:
	fixture = Node3D.new()
	fixture.name = "ReactionSmokeFixture"
	add_child(fixture)

	status_receiver = StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	fixture.add_child(status_receiver)

	await get_tree().process_frame
	run_tests()

	if failures.is_empty():
		print("ELEMENTAL_REACTION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("ELEMENTAL_REACTION_SMOKE_TEST: " + failure)

	get_tree().quit(1)


func run_tests() -> void:
	test_ignite()
	test_conduct()
	test_freeze()
	test_shatter()
	test_steam()
	test_debug_matrix()


func test_ignite() -> void:
	reset_statuses()
	status_receiver.apply_status("oily", 8.0, 1.0, "test")
	var reactions: Array[Dictionary] = ComboRuleRegistryScript.resolve_payload_reactions(
		fixture,
		make_payload("fire", ["fire", "projectile"])
	)
	assert_reaction(reactions, "ignite_oil")
	assert_status("burning", true)


func test_conduct() -> void:
	reset_statuses()
	status_receiver.apply_status("wet", 8.0, 1.0, "test")
	var reactions: Array[Dictionary] = ComboRuleRegistryScript.resolve_payload_reactions(
		fixture,
		make_payload("lightning", ["lightning", "shock"])
	)
	assert_reaction(reactions, "wet_conduction")
	assert_status("stunned", true)


func test_freeze() -> void:
	reset_statuses()
	status_receiver.apply_status("wet", 8.0, 1.0, "test")
	var reactions: Array[Dictionary] = ComboRuleRegistryScript.resolve_payload_reactions(
		fixture,
		make_payload("ice", ["ice", "projectile"])
	)
	assert_reaction(reactions, "wet_freeze")
	assert_status("frozen", true)


func test_shatter() -> void:
	reset_statuses()
	status_receiver.apply_status("frozen", 8.0, 1.0, "test")
	var reactions: Array[Dictionary] = ComboRuleRegistryScript.resolve_payload_reactions(
		fixture,
		make_payload("neutral", ["force", "melee"])
	)
	assert_reaction(reactions, "shatter")
	assert_status("frozen", false)


func test_steam() -> void:
	reset_statuses()
	status_receiver.apply_status("frozen", 8.0, 1.0, "test")
	status_receiver.apply_status("burning", 2.0, 1.0, "test_direct_fire")
	var reactions: Array[Dictionary] = ComboRuleRegistryScript.resolve_payload_reactions(
		fixture,
		make_payload("fire", ["fire", "projectile"])
	)
	assert_reaction(reactions, "steam_burst")
	assert_status("frozen", false)
	assert_status("burning", false)
	assert_status("steamed", true)


func test_debug_matrix() -> void:
	var rows: Array[Dictionary] = ComboRuleRegistryScript.get_debug_matrix_rows()

	if rows.size() < 9:
		failures.append("expected at least 9 registered combo rules, found " + str(rows.size()))

	var visual_styles: Array[String] = []
	for row: Dictionary in rows:
		visual_styles.append(str(row.get("visual", "")))

	for required_style: String in ["ignite", "conduct", "freeze", "shatter", "steam"]:
		if not visual_styles.has(required_style):
			failures.append("missing visual style in debug matrix: " + required_style)


func reset_statuses() -> void:
	status_receiver.clear_all_statuses()


func make_payload(element: String, tags: Array[String]) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.element = element
	payload.source_name = "Smoke Test " + element
	payload.hit_type = "test"
	payload.tags = tags
	return payload


func assert_reaction(reactions: Array[Dictionary], expected_reaction: String) -> void:
	for reaction: Dictionary in reactions:
		if str(reaction.get("reaction", "")) == expected_reaction:
			return

	failures.append("expected reaction " + expected_reaction + ", received " + str(reactions))


func assert_status(status_name: String, expected: bool) -> void:
	var actual: bool = status_receiver.has_status(status_name)

	if actual != expected:
		failures.append(
			"status " + status_name + " expected " + str(expected) + " but was " + str(actual)
		)
