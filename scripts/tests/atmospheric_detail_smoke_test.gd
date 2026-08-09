extends Node

const GreenScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var target: Node = GreenScene.instantiate()
	add_child(target)
	for _index: int in range(5):
		await get_tree().process_frame

	var director: AtmosphericDetailDirector3D = target.get_node_or_null(
		"AtmosphericDetailDirector"
	) as AtmosphericDetailDirector3D
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	var motion: EnvironmentalMotionDirector3D = target.get_node_or_null(
		"EnvironmentalMotionDirector"
	) as EnvironmentalMotionDirector3D

	_expect(director != null, "Green installs AtmosphericDetailDirector")
	_expect(lighting != null, "atmosphere test resolves LightingDirector")
	_expect(motion != null, "atmosphere test resolves EnvironmentalMotionDirector")
	if director != null and lighting != null:
		_validate_contract(target, director)
		await _validate_quality_ladder(director, lighting)
		_validate_motion_update(director, motion)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(
	target: Node,
	director: AtmosphericDetailDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("atmospheric_detail_director", false)), "atmosphere publishes debug contract")
	_expect(bool(data.get("initialized", false)), "atmosphere initializes with runtime soft texture")
	_expect(str(data.get("profile_id", "")) == "green_grotto_atmosphere", "Green uses dedicated atmosphere profile")
	_expect(int(data.get("field_count", 0)) == 4, "Green owns four authored atmosphere fields")
	_expect(int(data.get("authored_instances", 0)) == 460, "Green atmosphere budget is exactly 460 authored instances")
	_expect(bool(data.get("multimesh_batched", false)), "atmosphere uses MultiMesh batching")
	_expect(bool(data.get("follows_lighting_quality", false)), "atmosphere follows the F7 lighting tier")
	_expect(bool(data.get("samples_environmental_motion", false)), "atmosphere can inherit Environmental Motion wind")
	_expect(bool(data.get("soft_texture_runtime_generated", false)), "atmosphere generates its soft mote texture in Godot")
	_expect(not bool(data.get("gameplay_authority", true)), "atmosphere owns no gameplay state")
	var counts: Dictionary = _dictionary_value(data.get("field_counts", {}))
	_expect(int(counts.get("dust", 0)) == 140, "entrance and shrine dust total 140 authored motes")
	_expect(int(counts.get("pollen", 0)) == 170, "canopy pollen budget is 170")
	_expect(int(counts.get("mist", 0)) == 150, "waterfall mist budget is 150")

	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("atmospheric_detail", false)), "Green pass reports atmospheric detail")


func _validate_quality_ladder(
	director: AtmosphericDetailDirector3D,
	lighting: LightingDirector3D
) -> void:
	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	await get_tree().process_frame
	await get_tree().process_frame
	var performance: Dictionary = director.get_debug_data()
	_expect(int(performance.get("quality", -1)) == 0, "Performance atmosphere tier follows F7")
	_expect(int(performance.get("visible_instances", -1)) == 0, "Performance removes all atmosphere instances")
	_expect(_visible_field_count(director) == 0, "Performance hides all four atmosphere fields")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	await get_tree().process_frame
	await get_tree().process_frame
	var balanced: Dictionary = director.get_debug_data()
	var balanced_visible: int = int(balanced.get("visible_instances", 0))
	_expect(int(balanced.get("quality", -1)) == 1, "Balanced atmosphere tier follows F7")
	_expect(balanced_visible >= 180 and balanced_visible <= 195, "Balanced runs roughly half-density atmosphere")
	_expect(_visible_field_count(director) == 3, "Balanced skips the Cinematic-only shrine field")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	await get_tree().process_frame
	await get_tree().process_frame
	var cinematic: Dictionary = director.get_debug_data()
	_expect(int(cinematic.get("quality", -1)) == 2, "Cinematic atmosphere tier follows F7")
	_expect(int(cinematic.get("visible_instances", 0)) == 460, "Cinematic restores the full atmosphere budget")
	_expect(_visible_field_count(director) == 4, "Cinematic enables all four atmosphere fields")


func _validate_motion_update(
	director: AtmosphericDetailDirector3D,
	motion: EnvironmentalMotionDirector3D
) -> void:
	_expect(not director.fields.is_empty(), "atmosphere exposes at least one field for motion test")
	if director.fields.is_empty():
		return
	var record: Dictionary = director.fields[0]
	var multi: MultiMesh = record.get("multimesh") as MultiMesh
	_expect(multi != null and multi.visible_instance_count > 0, "motion test resolves visible MultiMesh field")
	if multi == null or multi.visible_instance_count <= 0:
		return
	motion.set_enabled(true)
	director.elapsed = 0.0
	director.call("_update_fields")
	var before: Transform3D = multi.get_instance_transform(0)
	director.elapsed = 1.25
	director.call("_update_fields")
	var after: Transform3D = multi.get_instance_transform(0)
	_expect(before.origin.distance_to(after.origin) > 0.001, "atmospheric instances drift over time")
	_expect(int(director.get_debug_data().get("update_count", 0)) >= 2, "atmosphere records batched transform updates")


func _visible_field_count(director: AtmosphericDetailDirector3D) -> int:
	var count: int = 0
	for record: Dictionary in director.fields:
		var multi: MultiMesh = record.get("multimesh") as MultiMesh
		if multi != null and multi.visible_instance_count > 0:
			count += 1
	return count


func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("ATMOSPHERIC_DETAIL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ATMOSPHERIC_DETAIL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
