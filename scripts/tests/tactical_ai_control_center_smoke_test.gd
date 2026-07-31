extends Node


const ControlCenterScene: PackedScene = preload(
	"res://scenes/ui/development_control_center_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var control_center: Node = ControlCenterScene.instantiate()
	add_child(control_center)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(
		control_center.has_method("get_debug_data"),
		"Development Control Center exposes debug data"
	)
	var debug: Dictionary = {}
	if control_center.has_method("get_debug_data"):
		var debug_value: Variant = control_center.call("get_debug_data")
		if debug_value is Dictionary:
			debug = debug_value as Dictionary
	_expect(
		bool(debug.get("tactical_ai_lab_available", false)),
		"Tactical AI Laboratory supplemental entry resolves"
	)
	_expect(
		bool(debug.get("storm_drain_pack_available", false)),
		"Storm Drain Pack supplemental entry resolves"
	)
	_expect(
		int(debug.get("supplemental_feature_count", 0)) == 2,
		"Control Center reports two supplemental development tools"
	)
	var found_lab: bool = false
	var found_encounter: bool = false
	var features_value: Variant = control_center.get("visible_features")
	if features_value is Array:
		for feature_value: Variant in features_value as Array:
			if not feature_value is Dictionary:
				continue
			var feature: Dictionary = feature_value as Dictionary
			var feature_id: String = str(feature.get("id", ""))
			if feature_id == "tactical_ai_lab":
				found_lab = true
				_expect(
					str(feature.get("scene", ""))
					== "res://scenes/levels/prototypes/prototype_tactical_ai_lab_v1.tscn",
					"Launcher entry points to the tactical laboratory scene"
				)
			elif feature_id == "storm_drain_pack_encounter":
				found_encounter = true
				_expect(
					str(feature.get("scene", ""))
					== "res://scenes/levels/prototypes/prototype_storm_drain_pack_encounter_v1.tscn",
					"Launcher entry points to the Storm Drain Pack scene"
				)
	_expect(found_lab, "Tactical AI Laboratory appears in visible features")
	_expect(found_encounter, "Storm Drain Pack appears in visible features")
	control_center.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("TACTICAL_AI_CONTROL_CENTER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("TACTICAL_AI_CONTROL_CENTER_SMOKE_TEST: " + failure)
	get_tree().quit(1)
