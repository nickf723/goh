extends Node

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")
const ReactionBurstResolverScript = preload("res://scripts/systems/reaction_burst_resolver.gd")
const ElementEmitterScript = preload("res://scripts/environment/element_emitter.gd")
const StatusReceiverScript = preload("res://scripts/combat/status_receiver.gd")
const HitReceiverScript = preload("res://scripts/combat/hit_receiver.gd")
const ForceReceiverScript = preload("res://scripts/combat/force_receiver.gd")
const FireFrozenSteamRule: Resource = preload("res://data/combo_rules/fire_frozen_steam.tres")
const WaterPatchScene: PackedScene = preload("res://scenes/surfaces/water_patch.tscn")

var failures: Array[String] = []
var fixture: Node3D
var status_receiver: Node
var hit_receiver: Node
var force_receiver: Node
var environmental_water: Node
var ice_emitter: ElementEmitter
var fire_emitter: ElementEmitter


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

	environmental_water = WaterPatchScene.instantiate()
	environmental_water.name = "EnvironmentalWaterFixture"
	add_child(environmental_water)

	var ice_source_root := Node3D.new()
	ice_source_root.name = "TestFrostCrystalSource"
	add_child(ice_source_root)

	ice_emitter = ElementEmitterScript.new()
	ice_emitter.name = "TestIceEmitter"
	ice_emitter.pulse_on_ready = false
	ice_emitter.emitter_id = "test_frost_crystal"
	ice_emitter.display_name = "Test Frost Crystal"
	ice_emitter.element = "ice"
	ice_emitter.payload_tags = ["environment", "element_source", "cold", "ice"]
	ice_emitter.required_target_tags = ["wet"]
	ice_emitter.blocked_target_tags = ["frozen", "steamed"]
	ice_emitter.reservoir_mode = "infinite"
	ice_emitter.emit_once_per_contact = true
	ice_emitter.collision_layer = 0
	ice_emitter.collision_mask = 1
	var ice_collision := CollisionShape3D.new()
	ice_collision.name = "CollisionShape3D"
	var ice_shape := SphereShape3D.new()
	ice_shape.radius = 2.0
	ice_collision.shape = ice_shape
	ice_emitter.add_child(ice_collision)
	ice_source_root.add_child(ice_emitter)

	fire_emitter = ElementEmitterScript.new()
	fire_emitter.name = "TestFireEmitter"
	fire_emitter.pulse_on_ready = false
	fire_emitter.emitter_id = "test_brazier"
	fire_emitter.display_name = "Test Brazier"
	fire_emitter.element = "fire"
	fire_emitter.payload_tags = ["environment", "element_source", "heat", "fire"]
	fire_emitter.required_target_tags = ["frozen"]
	fire_emitter.blocked_target_tags = ["steamed"]
	fire_emitter.reservoir_mode = "finite"
	fire_emitter.maximum_units = 8.0
	fire_emitter.starting_units = 8.0
	add_child(fire_emitter)

	await get_tree().process_frame
	await get_tree().physics_frame
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
	test_environmental_sources()
	test_environmental_refreeze_cycle()
	test_source_reservoir_contract()
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


func test_environmental_sources() -> void:
	if environmental_water == null:
		failures.append("environmental source test is missing its water surface")
		return

	environmental_water.call("reset_surface")
	var ice_payload: DamagePayload = ice_emitter.build_payload()
	var ice_result: Dictionary = ice_emitter.send_payload_to_target(environmental_water, ice_payload)

	if ice_payload.hit_type != "environment":
		failures.append("environmental Ice payload must use environment hit type")
	for required_tag: String in ["ice", "environment", "element_source"]:
		if not ice_payload.tags.has(required_tag):
			failures.append("environmental Ice payload missing tag: " + required_tag)

	if str(environmental_water.get("reaction_state")) != "frozen":
		failures.append("Frost Crystal payload should freeze a wet surface")
	if not str(ice_result.get("message", "")).to_lower().contains("freez"):
		failures.append("environmental Ice result should report the freeze reaction")

	var fire_payload: DamagePayload = fire_emitter.build_payload()
	var fire_result: Dictionary = fire_emitter.send_payload_to_target(environmental_water, fire_payload)

	if str(environmental_water.get("reaction_state")) != "steaming":
		failures.append("Brazier payload should turn the frozen surface into steam")
	if str(environmental_water.get("last_reaction_summary")) != "steam_burst":
		failures.append("environmental Fire should resolve through the existing Steam Burst rule")
	if not str(fire_result.get("message", "")).to_lower().contains("steam"):
		failures.append("environmental Fire result should report Steam Burst")


func test_environmental_refreeze_cycle() -> void:
	environmental_water.call("reset_surface")
	ice_emitter.reset_emitter()

	var first_freeze: Array[Dictionary] = ice_emitter.emit_pulse()
	if first_freeze.is_empty():
		failures.append("Frost Crystal should affect an overlapping wet surface")
	if str(environmental_water.get("reaction_state")) != "frozen":
		failures.append("first environmental Ice pulse should freeze the water")

	var water_id: int = environmental_water.get_instance_id()
	if not ice_emitter.emitted_contact_ids.has(water_id):
		failures.append("once-per-contact emitter should remember its eligible frozen target")

	var blocked_pulse: Array[Dictionary] = ice_emitter.emit_pulse()
	if not blocked_pulse.is_empty():
		failures.append("Frost Crystal should not repeatedly pulse while water is already frozen")
	if ice_emitter.emitted_contact_ids.has(water_id):
		failures.append("ineligible frozen state should rearm contact memory for a later thaw")

	environmental_water.call("set_reaction_state", "normal", 0.0)
	var refreeze: Array[Dictionary] = ice_emitter.emit_pulse()
	if refreeze.is_empty():
		failures.append("Frost Crystal should emit again when overlapping water becomes eligible")
	if str(environmental_water.get("reaction_state")) != "frozen":
		failures.append("thawed water should refreeze without separating from the Frost Crystal")


func test_source_reservoir_contract() -> void:
	var supplied_from_infinite: float = ice_emitter.request_element_units(25.0)
	if not is_equal_approx(supplied_from_infinite, 25.0):
		failures.append("infinite environmental source should satisfy the full requested amount")

	fire_emitter.reset_emitter()
	var first_draw: float = fire_emitter.request_element_units(5.0)
	var second_draw: float = fire_emitter.request_element_units(5.0)
	if not is_equal_approx(first_draw, 5.0):
		failures.append("finite source should provide its first requested draw")
	if not is_equal_approx(second_draw, 3.0):
		failures.append("finite source should only provide its remaining reservoir")
	if not is_zero_approx(fire_emitter.current_units):
		failures.append("finite source reservoir should reach zero after exhaustive draws")


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
