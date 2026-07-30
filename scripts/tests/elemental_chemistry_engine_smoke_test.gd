extends Node


const ReactionTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/goblin_reaction_target.tscn"
)
const ReactionResolverScript = preload(
	"res://scripts/systems/reaction_resolver.gd"
)
const StatePolicy = preload(
	"res://scripts/systems/reaction_state_policy.gd"
)

var failures: Array[String] = []
var target: Node
var status_receiver: Node
var payload_receiver: Node
var hit_receiver: Node


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_test_catalog_contract()
	target = ReactionTargetScene.instantiate()
	target.name = "ChemistryTransactionTarget"
	add_child(target)
	for _frame: int in range(4):
		await get_tree().process_frame
	await get_tree().physics_frame
	status_receiver = target.get_node_or_null("StatusReceiver")
	payload_receiver = target.get_node_or_null("PayloadReceiver")
	hit_receiver = target.get_node_or_null("HitReceiver")
	_expect(status_receiver != null, "Reaction target has StatusReceiver")
	_expect(payload_receiver != null, "Reaction target has PayloadReceiver")
	_expect(hit_receiver != null, "Reaction target has HitReceiver")
	if status_receiver == null or payload_receiver == null:
		_finish()
		return

	_test_same_impact_setup_isolation()
	_test_legacy_wet_conduction()
	_test_quench()
	_test_deep_freeze()
	_test_resonant_reveal()
	_test_conductive_overload()
	_test_depth_guard()
	_finish()


func _test_catalog_contract() -> void:
	var errors: Array[String] = ReactionResolverScript.validate_rules()
	_expect(errors.is_empty(), "Reaction rule catalog validates: " + str(errors))
	var rows: Array[Dictionary] = ReactionResolverScript.get_debug_matrix_rows()
	_expect(rows.size() >= 12, "Expanded catalog exposes at least twelve reactions")
	var previous_priority: int = 999999
	var seen_rules: Dictionary = {}
	for row: Dictionary in rows:
		var priority: int = int(row.get("priority", 0))
		_expect(priority <= previous_priority, "Reaction catalog is priority sorted")
		previous_priority = priority
		var rule_id: String = str(row.get("rule", ""))
		_expect(rule_id != "" and not seen_rules.has(rule_id), "Reaction rule IDs are unique")
		seen_rules[rule_id] = true
	for expected_rule: String in [
		"water_x_burning",
		"ice_x_chill",
		"sound_x_obscured",
		"lightning_x_conductive",
	]:
		_expect(seen_rules.has(expected_rule), "Catalog includes " + expected_rule)


func _test_same_impact_setup_isolation() -> void:
	_reset_target()
	var payload: DamagePayload = _make_payload("lightning", ["lightning"])
	payload.status_effect = "wet"
	payload.status_duration = 4.0
	target.call("receive_damage_payload", payload)
	_expect(
		str(payload_receiver.get("last_reaction_summary")) == "none",
		"A payload cannot react with the status it applies on the same impact"
	)
	_expect(status_receiver.call("has_status", "wet"), "Direct Wet applies after chemistry")


func _test_legacy_wet_conduction() -> void:
	_reset_target()
	status_receiver.call("apply_status", "wet", 5.0, 1.0, "setup")
	var payload: DamagePayload = _make_payload("lightning", ["lightning"])
	target.call("receive_damage_payload", payload)
	_expect(
		str(payload_receiver.get("last_reaction_summary")).contains("wet_conduction"),
		"Legacy Wet Conduction still resolves"
	)
	_expect(status_receiver.call("has_status", "stunned"), "Wet Conduction applies Stunned")
	_expect(_transaction_id() != "", "Legacy reaction receives a transaction ID")


func _test_quench() -> void:
	_reset_target()
	status_receiver.call("apply_status", "burning", 5.0, 1.0, "setup")
	var payload: DamagePayload = _make_payload("water", ["water"])
	payload.status_effect = "wet"
	payload.status_duration = 5.0
	target.call("receive_damage_payload", payload)
	_expect(
		str(payload_receiver.get("last_reaction_summary")).contains("quench"),
		"Water plus Burning resolves Quench"
	)
	_expect(status_receiver.call("has_status", "steamed"), "Quench produces Steamed")
	_expect(not status_receiver.call("has_status", "burning"), "Quench removes Burning")
	_expect(not status_receiver.call("has_status", "wet"), "Quench consumes incoming Wet")
	var snapshot: Dictionary = _transaction_snapshot()
	_expect(
		StatePolicy.snapshot_has_status(snapshot, "burning"),
		"Quench transaction records pre-impact Burning"
	)


func _test_deep_freeze() -> void:
	_reset_target()
	status_receiver.call("apply_status", "chilled", 5.0, 0.55, "setup")
	var payload: DamagePayload = _make_payload("ice", ["ice"])
	payload.status_effect = "chill"
	payload.status_duration = 5.0
	target.call("receive_damage_payload", payload)
	_expect(
		str(payload_receiver.get("last_reaction_summary")).contains("deep_freeze"),
		"Ice plus Chill resolves Deep Freeze"
	)
	_expect(status_receiver.call("has_status", "frozen"), "Deep Freeze applies Frozen")
	_expect(not status_receiver.call("has_status", "chill"), "Deep Freeze consumes Chill")


func _test_resonant_reveal() -> void:
	_reset_target()
	status_receiver.call("apply_status", "obscured", 5.0, 1.0, "setup")
	var payload: DamagePayload = _make_payload("sound", ["sound", "detection"])
	target.call("receive_damage_payload", payload)
	_expect(
		str(payload_receiver.get("last_reaction_summary")).contains("resonant_reveal"),
		"Sound plus Obscured resolves Resonant Reveal"
	)
	_expect(status_receiver.call("has_status", "revealed"), "Resonant Reveal applies Revealed")
	_expect(not status_receiver.call("has_status", "obscured"), "Reveal removes Obscured")


func _test_conductive_overload() -> void:
	_reset_target()
	status_receiver.call("apply_status", "conducting", 5.0, 1.0, "setup")
	var payload: DamagePayload = _make_payload("lightning", ["lightning"])
	target.call("receive_damage_payload", payload)
	_expect(
		str(payload_receiver.get("last_reaction_summary")).contains("conductive_overload"),
		"Lightning plus Conductive resolves Overload"
	)
	_expect(status_receiver.call("has_status", "stunned"), "Overload applies Stunned")
	_expect(not status_receiver.call("has_status", "conductive"), "Overload consumes Conductive")
	var transaction: Dictionary = payload_receiver.get("last_transaction_data") as Dictionary
	var triggered: Variant = transaction.get("triggered_rules", [])
	_expect(
		triggered is Array and (triggered as Array).has("lightning_x_conductive"),
		"Overload transaction records its winning rule"
	)


func _test_depth_guard() -> void:
	_reset_target()
	status_receiver.call("apply_status", "wet", 5.0, 1.0, "setup")
	var payload: DamagePayload = _make_payload(
		"lightning",
		["lightning", "reaction"]
	)
	payload.reaction_chain_id = "depth-guard-test"
	payload.reaction_depth = 4
	payload.reaction_history = ["ancestor_rule"]
	target.call("receive_damage_payload", payload)
	_expect(
		str(payload_receiver.get("last_reaction_summary")) == "none",
		"Reaction depth limit suppresses additional chemistry"
	)
	var transaction: Dictionary = payload_receiver.get("last_transaction_data") as Dictionary
	var suppressed: Variant = transaction.get("suppressed", [])
	_expect(
		suppressed is Array and not (suppressed as Array).is_empty(),
		"Depth suppression is inspectable"
	)
	_expect(
		str(transaction.get("transaction_id", "")) == "depth-guard-test",
		"Reaction descendants preserve their chain ID"
	)


func _make_payload(element: String, tags: Array[String]) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = 0
	payload.stance_damage = 0
	payload.element = element
	payload.source_name = "Chemistry Test " + element.capitalize()
	payload.hit_type = "magic"
	payload.tags = tags.duplicate()
	return payload


func _reset_target() -> void:
	if target != null and target.has_method("reset_target"):
		target.call("reset_target")
	if payload_receiver != null:
		payload_receiver.set("last_payload_summary", "none")
		payload_receiver.set("last_reaction_summary", "none")
		payload_receiver.set("last_reaction_data", {})
		payload_receiver.set("last_transaction_data", {})
	if hit_receiver != null:
		if hit_receiver.has_method("reset_health"):
			hit_receiver.call("reset_health")
		if hit_receiver.has_method("reset_stance"):
			hit_receiver.call("reset_stance")


func _transaction_id() -> String:
	var transaction: Dictionary = payload_receiver.get("last_transaction_data") as Dictionary
	return str(transaction.get("transaction_id", ""))


func _transaction_snapshot() -> Dictionary:
	var transaction: Dictionary = payload_receiver.get("last_transaction_data") as Dictionary
	var snapshot: Variant = transaction.get("target_snapshot", {})
	return snapshot as Dictionary if snapshot is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if is_instance_valid(target):
		target.queue_free()
	if failures.is_empty():
		print("ELEMENTAL_CHEMISTRY_ENGINE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ELEMENTAL_CHEMISTRY_ENGINE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
