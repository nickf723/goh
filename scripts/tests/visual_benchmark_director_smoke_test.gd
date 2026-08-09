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

	var benchmark: VisualBenchmarkDirector = target.get_node_or_null(
		"VisualBenchmarkDirector"
	) as VisualBenchmarkDirector
	_expect(benchmark != null, "Green installs benchmark preset director")
	if benchmark != null:
		_validate_contract(benchmark)
		_validate_baseline(benchmark)
		_validate_balanced(benchmark)
		_validate_hero(benchmark)
		_validate_custom_detection(benchmark)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(benchmark: VisualBenchmarkDirector) -> void:
	var data: Dictionary = benchmark.get_debug_data()
	_expect(bool(data.get("visual_benchmark_director", false)), "benchmark publishes debug contract")
	_expect(bool(data.get("initialized", false)), "benchmark resolves the visual stack")
	_expect(bool(data.get("f9_preset_cycle", false)), "F9 preset cycle is part of the contract")
	_expect(bool(data.get("f10_overlay_toggle", false)), "F10 overlay toggle is part of the contract")
	_expect(bool(data.get("baseline_disables_f1_f6", false)), "baseline explicitly disables F1-F6 presentation layers")
	_expect(benchmark.panel != null and benchmark.status_label != null, "benchmark installs its development-only status readout")


func _validate_baseline(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_BASELINE)
	await get_tree().process_frame
	_expect(not benchmark.vegetation.enabled, "Baseline disables vegetation presentation")
	_expect(not benchmark.water.enabled, "Baseline disables water presentation")
	_expect(not benchmark.material_fidelity.enabled, "Baseline disables material fidelity")
	_expect(not benchmark.surface_story.enabled, "Baseline disables surface story")
	_expect(not benchmark.motion.enabled, "Baseline disables environmental motion")
	_expect(not benchmark.camera_director.enabled, "Baseline restores the authored camera")
	_expect(benchmark.lighting.quality == LightingDirector3D.Quality.PERFORMANCE, "Baseline selects Performance lighting")
	if benchmark.reflections != null:
		benchmark.reflections.synchronize_now()
		_expect(int(benchmark.reflections.get_debug_data().get("active_probes", -1)) == 0, "Baseline also collapses local reflection probes")
	_expect(str(benchmark.get_debug_data().get("matched_preset", "")) == "BASELINE", "Baseline is detected exactly")


func _validate_balanced(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_BALANCED)
	await get_tree().process_frame
	_expect(_all_presentation_enabled(benchmark), "Balanced enables all F1-F6 presentation systems")
	_expect(benchmark.lighting.quality == LightingDirector3D.Quality.BALANCED, "Balanced selects Balanced lighting")
	if benchmark.reflections != null:
		benchmark.reflections.synchronize_now()
		_expect(int(benchmark.reflections.get_debug_data().get("active_probes", 0)) == 3, "Balanced includes three local reflection regions")
	_expect(str(benchmark.get_debug_data().get("matched_preset", "")) == "BALANCED", "Balanced is detected exactly")


func _validate_hero(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_HERO)
	await get_tree().process_frame
	_expect(_all_presentation_enabled(benchmark), "Hero enables all F1-F6 presentation systems")
	_expect(benchmark.lighting.quality == LightingDirector3D.Quality.CINEMATIC, "Hero selects Cinematic lighting")
	if benchmark.reflections != null:
		benchmark.reflections.synchronize_now()
		_expect(int(benchmark.reflections.get_debug_data().get("active_probes", 0)) == 4, "Hero includes all four local reflection regions")
	if benchmark.shadows != null:
		benchmark.shadows.synchronize_now()
		_expect(str(benchmark.shadows.get_debug_data().get("tier", "")) == "Cinematic", "Hero synchronizes Cinematic shadow fidelity")
	_expect(str(benchmark.get_debug_data().get("matched_preset", "")) == "HERO", "Hero is detected exactly")


func _validate_custom_detection(benchmark: VisualBenchmarkDirector) -> void:
	benchmark.surface_story.set_enabled(false)
	await get_tree().process_frame
	_expect(str(benchmark.get_debug_data().get("matched_preset", "")) == "CUSTOM", "manual F-key-style changes report CUSTOM")
	benchmark.apply_preset(VisualBenchmarkDirector.PRESET_HERO)


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
