extends Node


const TargetCandidate = preload(
	"res://scripts/ai/tactical_target_candidate.gd"
)
const EncounterScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_storm_drain_pack_encounter_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	TargetCandidate.clear_contract_cache()
	var encounter_value: Variant = EncounterScene.instantiate()
	_expect(encounter_value is Node3D, "Storm Drain encounter instantiates")
	if not encounter_value is Node3D:
		_finish()
		return
	var encounter: Node3D = encounter_value as Node3D
	encounter.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(encounter)
	await get_tree().process_frame
	await get_tree().process_frame

	var player: Node3D = encounter.get_node_or_null("Player") as Node3D
	var enemy_root: Node = encounter.get_node_or_null("EnemyRoot")
	_expect(player != null and enemy_root != null, "Performance test resolves actors")
	if player == null or enemy_root == null:
		encounter.queue_free()
		_finish()
		return

	var first_capture: Dictionary = TargetCandidate.capture(null, player)
	var after_first: Dictionary = TargetCandidate.get_performance_debug_data()
	var second_capture: Dictionary = TargetCandidate.capture(null, player)
	var after_second: Dictionary = TargetCandidate.get_performance_debug_data()
	_expect(not first_capture.is_empty() and not second_capture.is_empty(), "Player target capture succeeds")
	_expect(
		int(after_second.get("reflection_builds", 0))
		== int(after_first.get("reflection_builds", 0)),
		"Repeated target capture reuses reflection contracts"
	)
	_expect(
		int(after_second.get("reflection_cache_hits", 0))
		> int(after_first.get("reflection_cache_hits", 0)),
		"Repeated target capture records reflection cache hits"
	)

	for member: Node in enemy_root.get_children():
		var brain: Node = member.get_node_or_null("EnemyBrain")
		_expect(brain != null, member.name + " has a tactical brain")
		if brain == null:
			continue
		_expect(
			float(brain.get("tactical_decision_interval")) >= 0.2,
			member.name + " uses throttled action decisions"
		)
		_expect(
			float(brain.get("target_decision_interval")) >= 0.3,
			member.name + " uses throttled target decisions"
		)
		_expect(
			float(brain.get("tactical_decision_stagger")) >= 0.08,
			member.name + " spreads tactical work across frames"
		)
		brain.call("_refresh_target_allocation", true)
		var evaluations_before: int = int(brain.get("target_evaluation_count"))
		for _index: int in range(30):
			brain.call("_refresh_target_allocation", false)
		_expect(
			int(brain.get("target_evaluation_count")) == evaluations_before,
			member.name + " reuses its target allocation during the cadence window"
		)

	encounter.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("STORM_DRAIN_AI_PERFORMANCE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("STORM_DRAIN_AI_PERFORMANCE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
