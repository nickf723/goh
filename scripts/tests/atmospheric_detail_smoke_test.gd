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
		_validate_direction_study_posture(director)

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
	_expect(int(data.get("field_count", 0)) == 4, "Green retains four authored atmosphere fields")
	_expect(int(data.get("authored_instances", 0)) == 460, "Green retains 460 deterministic authored atmosphere candidates")
	_expect(bool(data.get("multimesh_batched", false)), "atmosphere uses MultiMesh batching")
	_expect(bool(data.get("follows_lighting_quality", false)), "atmosphere still follows the F7 lighting tier")
	_expect(bool(data.get("samples_environmental_motion", false)), "atmosphere retains Environmental Motion integration")
	_expect(bool(data.get("soft_texture_runtime_generated", false)), "atmosphere retains its runtime mote texture")
	_expect(bool(data.get("camera_safe_fade", false)), "camera-safe fade remains available")
	_expect(is_equal_approx(float(data.get("camera_clear_radius", 0.0)), 2.0), "Green retains a 2m clear camera bubble")
	_expect(is_equal_approx(float(data.get("camera_fade_distance", 0.0)), 2.5), "Green retains the 2.5m fade distance")
	_expect(not bool(data.get("gameplay_authority", true)), "atmosphere owns no gameplay state")
	var counts: Dictionary = _dictionary_value(data.get("field_counts", {}))
	_expect(int(counts.get("dust", 0)) == 140, "dust authoring pool remains intact")
	_expect(int(counts.get("pollen", 0)) == 170, "pollen authoring pool remains intact")
	_expect(int(counts.get("mist", 0)) == 150, "mist authoring pool remains intact")

	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("atmospheric_detail", false)), "Green pass still reports atmospheric detail infrastructure")


func _validate_quality_ladder(
	director: AtmosphericDetailDirector3D,
	lighting: LightingDirector3D
) -> void:
	for quality: int in [
		LightingDirector3D.Quality.PERFORMANCE,
		LightingDirector3D.Quality.BALANCED,
		LightingDirector3D.Quality.CINEMATIC,
	]:
		lighting.set_quality(quality)
		await get_tree().process_frame
		await get_tree().process_frame
		var data: Dictionary = director.get_debug_data()
		_expect(int(data.get("quality", -1)) == quality, "atmosphere tier continues following F7")
		_expect(int(data.get("visible_instances", -1)) == 0, "art-direction study suppresses decorative atmosphere")
		_expect(_visible_field_count(director) == 0, "art-direction study renders no atmosphere fields")


func _validate_direction_study_posture(
	director: AtmosphericDetailDirector3D
) -> void:
	_expect(not director.fields.is_empty(), "atmosphere authoring data remains available for later polish")
	_expect(
		is_zero_approx(director.profile.balanced_density_scale)
		and is_zero_approx(director.profile.cinematic_density_scale),
		"direction study explicitly disables decorative atmosphere"
	)


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
