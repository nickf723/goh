extends Node


const RecorderScript = preload(
	"res://scripts/ai/tactical_decision_recorder.gd"
)
const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_tactical_ai_lab_v1.tscn"
)
const ManifestedAvatarScene: PackedScene = preload(
	"res://scenes/actors/avatars/manifested_avatar_actor.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_test_recorder_contract()
	await _test_lab_scenarios_and_overlay()
	await _test_runtime_adapters()
	_finish()


func _test_recorder_contract() -> void:
	var recorder: TacticalDecisionRecorder = RecorderScript.new().configure(3)
	var live_node := Node.new()
	live_node.name = "TemporaryActor"
	var first: Dictionary = recorder.record_frame(
		1,
		"Actor",
		"decision",
		{
			"selected_id": "lightning_spark",
			"source_ref": live_node,
			"target": live_node,
		},
		{},
		{"position": Vector3(1.0, 2.0, 3.0)}
	)
	var repeated: Dictionary = recorder.record_frame(
		1,
		"Actor",
		"decision",
		{
			"selected_id": "lightning_spark",
			"source_ref": live_node,
			"target": live_node,
		},
		{},
		{"position": Vector3(1.0, 2.0, 3.0)}
	)
	_expect(bool(first.get("recorded", false)), "First decision creates a frame")
	_expect(
		bool(repeated.get("deduplicated", false)),
		"Identical decision is deduplicated"
	)
	_expect(recorder.get_frame_count() == 1, "Deduplication keeps one frame")
	_expect(
		int(recorder.get_current_frame().get("repeat_count", 0)) == 2,
		"Deduplicated frame tracks its repeat count"
	)
	_expect(
		not recorder.has_live_object_references(),
		"Recorder stores no live object references"
	)
	for index: int in range(4):
		recorder.record_frame(
			2 + index,
			"Actor " + str(index),
			"decision",
			{"selected_id": "action_" + str(index)}
		)
	_expect(recorder.get_frame_count() == 3, "Recorder history respects its cap")
	var current_sequence: int = int(recorder.get_current_frame().get("sequence", 0))
	recorder.step_back()
	_expect(
		int(recorder.get_current_frame().get("sequence", 0)) < current_sequence,
		"Recorder steps backward"
	)
	recorder.step_forward()
	_expect(
		int(recorder.get_current_frame().get("sequence", 0)) == current_sequence,
		"Recorder steps forward"
	)
	var parsed: Variant = JSON.parse_string(recorder.to_json())
	_expect(parsed is Dictionary, "Recorder exports valid JSON")
	live_node.free()


func _test_lab_scenarios_and_overlay() -> void:
	var lab: Node = LabScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	_expect(lab.has_method("run_scenario_by_id"), "Tactical lab exposes scenario stepping")
	var expected: Dictionary = {
		"wet_conduction": "lightning_spark",
		"protected_shatter": "arcane_spark",
		"cover_withdrawal": "stone_throw",
		"occupied_lane": "spit",
		"emergency_defense": "guard",
	}
	for scenario_value: Variant in expected.keys():
		var scenario_id: String = str(scenario_value)
		var plan_value: Variant = lab.call("run_scenario_by_id", scenario_id)
		var plan: Dictionary = plan_value as Dictionary if plan_value is Dictionary else {}
		_expect(
			str(plan.get("selected_id", "")) == str(expected[scenario_id]),
			"Scenario `" + scenario_id + "` selects " + str(expected[scenario_id])
		)
	var recorder_value: Variant = lab.call("get_decision_recorder")
	var recorder: TacticalDecisionRecorder = (
		recorder_value as TacticalDecisionRecorder
		if recorder_value is TacticalDecisionRecorder
		else null
	)
	_expect(recorder != null, "Laboratory exposes its recorder")
	if recorder != null:
		_expect(recorder.get_frame_count() == 5, "Five lab scenarios create five replay frames")
		_expect(not recorder.has_live_object_references(), "Lab replay is serializable")
	var overlay_value: Variant = lab.call("get_decision_overlay")
	var overlay: TacticalDecisionOverlay = (
		overlay_value as TacticalDecisionOverlay
		if overlay_value is TacticalDecisionOverlay
		else null
	)
	_expect(overlay != null, "Laboratory exposes its decision overlay")
	if overlay != null:
		overlay.set_telemetry_visible(false)
		_expect(not overlay.is_processing(), "Hidden overlay stops processing")
		overlay.set_telemetry_visible(true)
		_expect(overlay.is_processing(), "Visible overlay resumes processing")
	var export_path: String = "user://tactical_ai_reports/smoke_replay.json"
	var export_value: Variant = lab.call("export_replay", export_path)
	var export_result: Dictionary = (
		export_value as Dictionary if export_value is Dictionary else {}
	)
	_expect(bool(export_result.get("ok", false)), "Laboratory exports replay JSON")
	var file: FileAccess = FileAccess.open(export_path, FileAccess.READ)
	_expect(file != null, "Replay export file can be reopened")
	if file != null:
		var parsed_export: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		_expect(parsed_export is Dictionary, "Replay export parses as JSON")
	lab.queue_free()
	await get_tree().process_frame


func _test_runtime_adapters() -> void:
	var threat_script: Script = load(
		"res://scripts/enemies/enemy_threat_aware_action_brain.gd"
	) as Script
	var threat_brain: Node = (
		threat_script.new() as Node if threat_script != null else null
	)
	_expect(threat_brain != null, "Threat-aware enemy brain still instantiates")
	if threat_brain != null:
		_expect(
			threat_brain.has_method("get_tactical_decision_recorder"),
			"Enemy squad brain exposes a decision recorder"
		)
		threat_brain.free()

	var manifestation: Node = ManifestedAvatarScene.instantiate()
	add_child(manifestation)
	await get_tree().process_frame
	var driver: Node = manifestation.get_node_or_null("CompanionControlDriver")
	_expect(driver != null, "Ruvia companion driver remains installed")
	if driver != null:
		_expect(
			driver.has_method("get_tactical_decision_recorder"),
			"Ruvia exposes a decision recorder"
		)
	manifestation.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("TACTICAL_AI_LAB_REPLAY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("TACTICAL_AI_LAB_REPLAY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
