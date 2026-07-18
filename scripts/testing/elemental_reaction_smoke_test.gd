extends Node

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")
const ReactionBurstResolverScript = preload("res://scripts/systems/reaction_burst_resolver.gd")
const StatusReceiverScript = preload("res://scripts/combat/status_receiver.gd")
const HitReceiverScript = preload("res://scripts/combat/hit_receiver.gd")
const ForceReceiverScript = preload("res://scripts/combat/force_receiver.gd")
const FireFrozenSteamRule: Resource = preload("res://data/combo_rules/fire_frozen_steam.tres")

var failures: Array[String] = []
var fixture: Node3D
var status_receiver: Node
var hit_receiver: Node
var force_receiver: Node


func _ready() -> void:
	fixture = Node3D.new()
	fixture.name = "ReactionSmokeFixture"
	add_child(fixture)

	status_receiver = StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	fixture.add_child(status_receiver)

	hit_receiver = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", "Reaction Smoke Fixture")
	hit_receiver.set("hit_mode", 1)
	hit_receiver.set("max_stance", 10)
	hit_receiver.set("current_stance", 10)
	fixture.add_child(hit_receiver)

	force_receiver = ForceReceiverScript.new()
	force_receiver.name = "ForceReceiver"
	fixture.add_child(force_receiver)

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
	test_steam_area_effect()
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


func test_steam_area_effect() -> void:
	reset_statuses()
	hit_receiver.call("reset_stance")
	force_receiver.set("external_velocity", Vector3.ZERO)

	var test_rule: Resource = FireFrozenSteamRule.duplicate(true)
	test_rule.set("area_show_status_feedback", false)
	var result: Dictionary = ReactionBurstResolverScript.apply_effect_to_target(
		test_rule,
		fixture,
		fixture.global_position - Vector3.RIGHT
	)

	assert_status("steamed", true)

	if int(hit_receiver.get("current_stance")) != 9:
		failures.append(
			"Steam Burst area effect should deal 1 stance damage; stance was "
			+ str(hit_receiver.get("current_stance"))
		)

	if not bool(force_receiver.call("has_force")):
		failures.append("Steam Burst area effect should apply outward force")

	if str(result.get("status", "")) != "steamed":
		failures.append("Steam Burst area result should report steamed status")
	if int(result.get("stance_damage", 0)) != 1:
		failures.append("Steam Burst area result should report 1 stance damage")


func test_debug_matrix() -> void:
	var rows: Array[Dictionary] = ComboRuleRegistryScript.get_debug_matrix_rows()

	if rows.size() < 8:
		failures.append("expected at least 8 registered combo rules, found " + str(rows.size()))

	var visual_styles: Array[String] = []
	var steam_row: Dictionary = {}
	for row: Dictionary in rows:
		visual_styles.append(str(row.get("visual", "")))
		if str(row.get("reaction", "")) == "steam_burst":
			steam_row = row

	for required_style: String in ["ignite", "conduct", "freeze", "shatter", "steam"]:
		if not visual_styles.has(required_style):
			failures.append("missing visual style in debug matrix: " + required_style)

	if steam_row.is_empty():
		failures.append("debug matrix is missing Steam Burst")
	else:
		if float(steam_row.get("area_radius", 0.0)) <= 0.0:
			failures.append("Steam Burst debug row must expose a positive area radius")
		if str(steam_row.get("area_status", "")) != "steamed":
			failures.append("Steam Burst debug row must expose steamed area status")


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
