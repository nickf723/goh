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

	var director: VisualLODDirector3D = target.get_node_or_null(
		"VisualLODDirector"
	) as VisualLODDirector3D
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	_expect(director != null, "Green installs VisualLODDirector")
	_expect(lighting != null, "LOD test resolves LightingDirector")
	if director != null and lighting != null:
		_validate_contract(target, director)
		await _validate_quality_ranges(director, lighting)
		_validate_exclusions(target, director)
		_validate_restore(director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(target: Node, director: VisualLODDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("visual_lod_director", false)), "LOD Director publishes debug contract")
	_expect(bool(data.get("initialized", false)), "LOD Director initializes with profile")
	_expect(str(data.get("profile_id", "")) == "green_grotto_visual_lod", "Green uses dedicated visual LOD profile")
	_expect(bool(data.get("uses_renderer_visibility_ranges", false)), "LOD delegates distance culling to renderer visibility ranges")
	_expect(str(data.get("fade_mode", "")) == "hysteresis", "LOD uses cheap hysteresis instead of transparent self-fade")
	_expect(not bool(data.get("per_frame_distance_checks", true)), "LOD does not run manual per-target camera distance checks")
	_expect(bool(data.get("collision_unchanged", false)), "LOD contract leaves collision untouched")
	_expect(not bool(data.get("gameplay_authority", true)), "LOD owns no gameplay state")
	_expect(int(data.get("target_count", 0)) >= 300, "Green enrolls a substantial non-silhouette detail set")
	var categories: Dictionary = _dictionary_value(data.get("category_counts", {}))
	_expect(int(categories.get("foliage", 0)) >= 250, "complete fern/cycad/ground-leaf detail dominates the LOD set")
	_expect(int(categories.get("canopy_detail", 0)) >= 20, "canopy detail receives a longer visibility budget")
	_expect(int(categories.get("surface_detail", 0)) >= 20, "moss/litter/crack dressing participates in LOD")
	_expect(int(categories.get("architecture_detail", 0)) >= 30, "small shrine construction detail participates in LOD")
	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("visual_lod", false)), "Green pass reports Visual LOD")
	_expect(int(pass_data.get("visual_lod_target_count", 0)) == int(data.get("target_count", 0)), "Green pass and Director agree on LOD target count")


func _validate_quality_ranges(
	director: VisualLODDirector3D,
	lighting: LightingDirector3D
) -> void:
	var record: Dictionary = _first_record_of_category(director, "foliage")
	_expect(not record.is_empty(), "LOD test resolves a foliage target")
	if record.is_empty():
		return
	var geometry: GeometryInstance3D = _geometry_from_record(record)
	_expect(geometry != null, "LOD foliage record resolves live geometry")
	if geometry == null:
		return

	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(absf(geometry.visibility_range_end - 24.0) < 0.01, "Performance foliage ends at 24m")
	_expect(absf(geometry.visibility_range_end_margin - 2.5) < 0.01, "Performance foliage uses 2.5m hysteresis margin")
	_expect(geometry.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED, "Performance uses fade-disabled visibility range")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(absf(geometry.visibility_range_end - 38.0) < 0.01, "Balanced foliage ends at 38m")
	_expect(absf(geometry.visibility_range_end_margin - 4.0) < 0.01, "Balanced foliage uses 4m hysteresis margin")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(absf(geometry.visibility_range_end - 58.0) < 0.01, "Cinematic foliage extends to 58m")
	_expect(absf(geometry.visibility_range_end_margin - 5.0) < 0.01, "Cinematic foliage uses 5m hysteresis margin")

	var architecture: Dictionary = _first_record_of_category(director, "architecture_detail")
	if not architecture.is_empty():
		var architecture_geometry: GeometryInstance3D = _geometry_from_record(architecture)
		if architecture_geometry != null:
			_expect(absf(architecture_geometry.visibility_range_end - 78.0) < 0.01, "Cinematic shrine detail receives longer 78m range")


func _validate_exclusions(target: Node, director: VisualLODDirector3D) -> void:
	var water: GeometryInstance3D = target.get_node_or_null(
		"GreenGrottoArt/HeroPassV3/HeroWater/V3LowerBasin"
	) as GeometryInstance3D
	_expect(water != null, "LOD exclusion test resolves lower basin")
	if water != null:
		_expect(not director.targets.has(water.get_instance_id()), "water is never enrolled in detail LOD")

	var causeway: GeometryInstance3D = target.get_node_or_null(
		"GreenGrottoArt/AncientRuins/CausewaySlab00/Visual"
	) as GeometryInstance3D
	_expect(causeway != null, "LOD exclusion test resolves original causeway slab visual")
	if causeway != null:
		_expect(not director.targets.has(causeway.get_instance_id()), "major causeway structure is never enrolled in detail LOD")

	for node: Node in target.get_tree().get_nodes_in_group("green_grotto_fauna"):
		if node is GreenGrottoFaunaVisual:
			for descendant: Node in _mesh_descendants(node):
				_expect(not director.targets.has(descendant.get_instance_id()), "fauna geometry remains outside environment detail LOD")

	var grace_visual: Node = target.get_node_or_null("Player/GraceVisualV1")
	_expect(grace_visual != null, "LOD exclusion test resolves Grace visual")
	if grace_visual != null:
		for descendant: Node in _mesh_descendants(grace_visual):
			_expect(not director.targets.has(descendant.get_instance_id()), "Grace geometry remains outside environment detail LOD")


func _validate_restore(director: VisualLODDirector3D) -> void:
	var record: Dictionary = _first_record_of_category(director, "surface_detail")
	if record.is_empty():
		record = _first_record_of_category(director, "foliage")
	_expect(not record.is_empty(), "LOD restore test resolves a managed target")
	if record.is_empty():
		return
	var geometry: GeometryInstance3D = _geometry_from_record(record)
	if geometry == null:
		return
	var original_end: float = float(record.get("original_end", 0.0))
	var original_margin: float = float(record.get("original_end_margin", 0.0))
	var original_mode: int = int(record.get("original_fade_mode", 0))
	director.set_enabled(false)
	_expect(absf(geometry.visibility_range_end - original_end) < 0.0001, "disabling LOD restores original range end")
	_expect(absf(geometry.visibility_range_end_margin - original_margin) < 0.0001, "disabling LOD restores original range margin")
	_expect(int(geometry.visibility_range_fade_mode) == original_mode, "disabling LOD restores original fade mode")
	_expect(int(director.get_debug_data().get("restored_count", 0)) == director.targets.size(), "disabling LOD restores every live managed target")
	director.set_enabled(true)


func _first_record_of_category(
	director: VisualLODDirector3D,
	category: String
) -> Dictionary:
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		if str(record.get("category", "")) == category:
			return record
	return {}


func _geometry_from_record(record: Dictionary) -> GeometryInstance3D:
	var weak_value: Variant = record.get("ref", null)
	if not weak_value is WeakRef:
		return null
	var value: Variant = (weak_value as WeakRef).get_ref()
	return value as GeometryInstance3D if value is GeometryInstance3D else null


func _mesh_descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node is GeometryInstance3D:
		result.append(node)
	for child: Node in node.get_children():
		result.append_array(_mesh_descendants(child))
	return result


func _dictionary_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("VISUAL_LOD_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("VISUAL_LOD_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
