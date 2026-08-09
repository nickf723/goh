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
	for _index: int in range(6):
		await get_tree().process_frame

	var benchmark: VisualBenchmarkDirector = target.get_node_or_null(
		"VisualBenchmarkDirector"
	) as VisualBenchmarkDirector
	_expect(benchmark != null, "Green installs benchmark preset director")
	if benchmark != null:
		_validate_contract(benchmark)
		await _validate_baseline(benchmark)
		await _validate_balanced(benchmark)
		await _validate_hero(benchmark)
		await _validate_custom_detection(benchmark)
		await _validate_timed_capture(benchmark)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(benchmark: VisualBenchmarkDirector) -> void:
	var data: Dictionary = benchmark.get_debug_data()
	_expect(bool(data.get("visual_benchmark_director", false)), "benchmark publishes debug contract")
	_expect(bool(data.get("initialized", false)), "benchmark resolves the visual stack")
	_expect(bool(data.get("f9_preset_cycle", false)), "F9 preset cycle is part of the contract")
	_expect(bool(data.get("f10_overlay_toggle", false)), "F10 overlay toggle is part of the contract")
	_expect(bool(data.get("f11_timed_capture", false)), "F11 timed capture is part of the contract")
	_expect(not bool(data.get("overlay_enabled", true)), "development overlay starts hidden for presentation review")
	_expect(bool(data.get("baseline_disables_f1_f6", false)), "baseline explicitly disables F1-F6 presentation layers")
	_expect(int(data.get("ambient_fauna_count", 0)) == 4, "benchmark discovers all four ambient fauna behavior adapters")
	_expect(benchmark.atmosphere != null, "benchmark resolves F7-linked atmospheric detail")
	_expect(benchmark.character_materials != null, "benchmark resolves F7-linked Grace material presentation")
	_expect(benchmark.visual_lod != null, "benchmark resolves F7-linked visual LOD")
	_expect(benchmark.surface_contact != null, "benchmark resolves F7-linked surface contact presentation")
	_expect(benchmark.panel != null and benchmark.status_label != null, "benchmark installs its development-only status readout")
	_expect(benchmark.panel != null and not benchmark.panel.visible, "benchmark readout is hidden until F10 requests it")


func _validate_baseline(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_BASELINE)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not benchmark.vegetation.enabled, "Baseline disables vegetation presentation")
	_expect(not benchmark.water.enabled, "Baseline disables water presentation")
	_expect(not benchmark.material_fidelity.enabled, "Baseline disables material fidelity")
	_expect(not benchmark.surface_story.enabled, "Baseline disables surface story")
	_expect(not benchmark.motion.enabled, "Baseline disables environmental motion")
	_expect(not benchmark.camera_director.enabled, "Baseline restores the authored camera")
	_expect(benchmark.lighting.quality == LightingDirector3D.Quality.PERFORMANCE, "Baseline selects Performance lighting")
	_expect(benchmark.call("_all_ambient_fauna_disabled"), "Baseline disables ambient fauna acting")
	for behavior: GreenGrottoFaunaAmbientBehavior in benchmark.ambient_fauna:
		_expect(behavior.fauna != null and behavior.fauna.animate_creature, "Baseline hands fauna back to the original simple animator")
	if benchmark.reflections != null:
		benchmark.reflections.synchronize_now()
		_expect(int(benchmark.reflections.get_debug_data().get("active_probes", -1)) == 0, "Baseline collapses local reflection probes")
	if benchmark.atmosphere != null:
		_expect(int(benchmark.atmosphere.get_debug_data().get("visible_instances", -1)) == 0, "Baseline removes micro-atmosphere instances")
	if benchmark.character_materials != null:
		_expect(int(benchmark.character_materials.get_debug_data().get("quality", -1)) == 0, "Baseline restores original Grace material tier")
	if benchmark.surface_contact != null:
		_expect(benchmark.call("_contact_footstep_count") == 0, "Baseline disables micro surface-contact pieces")
	var data: Dictionary = benchmark.get_debug_data()
	_expect(bool(data.get("baseline_restores_legacy_fauna", false)), "Baseline debug contract records legacy fauna restoration")
	_expect(str(data.get("matched_preset", "")) == "BASELINE", "Baseline is detected exactly")
	_expect(str(data.get("linked_image_quality", "")) == "RAW", "Baseline reports raw image fidelity")


func _validate_balanced(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_BALANCED)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_all_presentation_enabled(benchmark), "Balanced enables all F1-F6 presentation systems")
	_expect(benchmark.call("_all_ambient_fauna_enabled"), "Balanced enables ambient fauna acting")
	for behavior: GreenGrottoFaunaAmbientBehavior in benchmark.ambient_fauna:
		_expect(behavior.fauna != null and not behavior.fauna.animate_creature, "Balanced retires the legacy fauna animator")
	_expect(benchmark.lighting.quality == LightingDirector3D.Quality.BALANCED, "Balanced selects Balanced lighting")
	if benchmark.reflections != null:
		benchmark.reflections.synchronize_now()
		_expect(int(benchmark.reflections.get_debug_data().get("active_probes", 0)) == 3, "Balanced includes three local reflection regions")
	if benchmark.atmosphere != null:
		var atmosphere_count: int = int(benchmark.atmosphere.get_debug_data().get("visible_instances", 0))
		_expect(atmosphere_count >= 22 and atmosphere_count <= 24, "Balanced reports the sparse readability atmosphere budget")
	if benchmark.character_materials != null:
		_expect(int(benchmark.character_materials.get_debug_data().get("quality", -1)) == 1, "Balanced reports Grace material quality 1")
	_expect(benchmark.call("_contact_footstep_count") == 3, "Balanced reports three contact pieces per footstep")
	var data: Dictionary = benchmark.get_debug_data()
	_expect(str(data.get("matched_preset", "")) == "BALANCED", "Balanced is detected exactly")
	_expect(str(data.get("linked_image_quality", "")) == "2x MSAA", "Balanced reports crisp non-temporal MSAA")


func _validate_hero(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_HERO)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_all_presentation_enabled(benchmark), "Hero enables all F1-F6 presentation systems")
	_expect(benchmark.call("_all_ambient_fauna_enabled"), "Hero enables ambient fauna acting")
	_expect(benchmark.lighting.quality == LightingDirector3D.Quality.CINEMATIC, "Hero selects Cinematic lighting")
	if benchmark.reflections != null:
		benchmark.reflections.synchronize_now()
		_expect(int(benchmark.reflections.get_debug_data().get("active_probes", 0)) == 4, "Hero includes all four local reflection regions")
	if benchmark.shadows != null:
		benchmark.shadows.synchronize_now()
		_expect(str(benchmark.shadows.get_debug_data().get("tier", "")) == "Cinematic", "Hero synchronizes Cinematic shadow fidelity")
	if benchmark.atmosphere != null:
		var atmosphere_count: int = int(benchmark.atmosphere.get_debug_data().get("visible_instances", 0))
		_expect(atmosphere_count >= 45 and atmosphere_count <= 47, "Hero keeps the full field set within the readability budget")
	if benchmark.character_materials != null:
		_expect(int(benchmark.character_materials.get_debug_data().get("quality", -1)) == 2, "Hero reports Cinematic Grace material quality")
	if benchmark.visual_lod != null:
		_expect(int(benchmark.visual_lod.get_debug_data().get("quality", -1)) == 2, "Hero reports Cinematic visual LOD tier")
	_expect(benchmark.call("_contact_footstep_count") == 5, "Hero reports five contact pieces per footstep")
	var data: Dictionary = benchmark.get_debug_data()
	_expect(str(data.get("matched_preset", "")) == "HERO", "Hero is detected exactly")
	_expect(str(data.get("linked_image_quality", "")) == "2x MSAA", "Hero preserves crisp non-temporal MSAA")


func _validate_custom_detection(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.surface_story.set_enabled(false)
	await get_tree().process_frame
	_expect(str(benchmark.get_debug_data().get("matched_preset", "")) == "CUSTOM", "manual F-key-style changes report CUSTOM")
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_HERO)
	await get_tree().process_frame


func _validate_timed_capture(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_HERO)
	benchmark.start_capture(0.05)
	for _index: int in range(8):
		benchmark.call("_record_capture_sample", 0.01, 420, 180000)
		if not benchmark.capture_active:
			break
	var data: Dictionary = benchmark.get_debug_data()
	var capture: Dictionary = data.get("last_capture", {}) as Dictionary
	_expect(not benchmark.capture_active, "short benchmark capture completes")
	_expect(not capture.is_empty(), "F11 capture produces a result object")
	_expect(str(capture.get("preset", "")) == "HERO", "capture records active preset")
	_expect(int(capture.get("samples", 0)) >= 5, "capture records multiple frame samples")
	_expect(float(capture.get("average_fps", 0.0)) > 90.0, "capture derives average FPS from frame samples")
	_expect(absf(float(capture.get("average_frame_ms", 0.0)) - 10.0) < 0.2, "capture derives average frame time")
	_expect(float(capture.get("one_percent_low_fps", 0.0)) > 90.0, "capture derives a 1 percent low estimate")
	_expect(absf(float(capture.get("average_draw_calls", 0.0)) - 420.0) < 0.1, "capture averages draw calls")
	_expect(absf(float(capture.get("average_primitives", 0.0)) - 180000.0) < 0.1, "capture averages rendered primitives")


func _all_presentation_enabled(benchmark: VisualBenchmarkDirector) -> bool:
	return (
		benchmark.vegetation.enabled
		and benchmark.water.enabled
		and benchmark.material_fidelity.enabled
		and benchmark.surface_story.enabled
		and benchmark.motion.enabled
		and benchmark.camera_director.enabled
	)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("VISUAL_BENCHMARK_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("VISUAL_BENCHMARK_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
