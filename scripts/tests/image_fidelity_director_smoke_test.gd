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
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	_expect(benchmark != null, "image fidelity test resolves visual benchmark")
	_expect(lighting != null, "image fidelity test resolves LightingDirector")
	var director: ImageFidelityDirector = null
	if benchmark != null:
		director = benchmark.get_node_or_null(
			"ImageFidelityDirector"
		) as ImageFidelityDirector
	_expect(director != null, "visual benchmark installs ImageFidelityDirector")
	if director != null and lighting != null:
		_validate_contract(director)
		await _validate_quality_ladder(director, lighting)
		_validate_restore(director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(director: ImageFidelityDirector) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("image_fidelity_director", false)), "Image Fidelity publishes debug contract")
	_expect(bool(data.get("initialized", false)), "Image Fidelity initializes on the active viewport")
	_expect(str(data.get("profile_id", "")) == "green_grotto_image_fidelity", "Green uses dedicated image fidelity profile")
	_expect(bool(data.get("follows_lighting_quality", false)), "Image Fidelity follows F7")
	_expect(bool(data.get("performance_is_raw", false)), "Performance remains the raw AA baseline")
	_expect(bool(data.get("balanced_temporal_aa", false)), "Balanced contract enables temporal AA")
	_expect(bool(data.get("cinematic_temporal_plus_msaa", false)), "Cinematic contract stacks TAA with 2x geometry MSAA")
	_expect(bool(data.get("restores_on_exit", false)), "Image Fidelity restores viewport state when the lab exits")
	_expect(not bool(data.get("gameplay_authority", true)), "Image Fidelity owns no gameplay state")
	_expect(director.viewport != null, "Image Fidelity resolves the active viewport")


func _validate_quality_ladder(
	director: ImageFidelityDirector,
	lighting: LightingDirector3D
) -> void:
	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	director.synchronize_now()
	await get_tree().process_frame
	var performance: Dictionary = director.get_debug_data()
	_expect(int(performance.get("quality", -1)) == 0, "Performance image tier follows F7")
	_expect(not bool(performance.get("taa", true)), "Performance disables TAA")
	_expect(not bool(performance.get("debanding", true)), "Performance disables debanding")
	_expect(int(performance.get("msaa_3d", -1)) == Viewport.MSAA_DISABLED, "Performance disables 3D MSAA")
	_expect(int(performance.get("screen_space_aa", -1)) == Viewport.SCREEN_SPACE_AA_DISABLED, "Performance disables screen-space AA")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	director.synchronize_now()
	await get_tree().process_frame
	var balanced: Dictionary = director.get_debug_data()
	_expect(int(balanced.get("quality", -1)) == 1, "Balanced image tier follows F7")
	_expect(bool(balanced.get("taa", false)), "Balanced enables TAA")
	_expect(bool(balanced.get("debanding", false)), "Balanced enables debanding")
	_expect(int(balanced.get("msaa_3d", -1)) == Viewport.MSAA_DISABLED, "Balanced avoids extra MSAA cost")
	_expect(int(balanced.get("screen_space_aa", -1)) == Viewport.SCREEN_SPACE_AA_DISABLED, "Balanced does not stack FXAA/SMAA over TAA")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	director.synchronize_now()
	await get_tree().process_frame
	var cinematic: Dictionary = director.get_debug_data()
	_expect(int(cinematic.get("quality", -1)) == 2, "Cinematic image tier follows F7")
	_expect(bool(cinematic.get("taa", false)), "Cinematic keeps TAA")
	_expect(bool(cinematic.get("debanding", false)), "Cinematic keeps debanding")
	_expect(int(cinematic.get("msaa_3d", -1)) == Viewport.MSAA_2X, "Cinematic adds 2x geometry MSAA")
	_expect(int(cinematic.get("screen_space_aa", -1)) == Viewport.SCREEN_SPACE_AA_DISABLED, "Cinematic still avoids redundant screen-space AA")


func _validate_restore(director: ImageFidelityDirector) -> void:
	var original_taa: bool = director.original_taa
	var original_debanding: bool = director.original_debanding
	var original_msaa: int = director.original_msaa_3d
	var original_screen_aa: int = director.original_screen_space_aa
	director.set_enabled(false)
	_expect(director.viewport.use_taa == original_taa, "disabling Image Fidelity restores original TAA")
	_expect(director.viewport.use_debanding == original_debanding, "disabling Image Fidelity restores original debanding")
	_expect(int(director.viewport.msaa_3d) == original_msaa, "disabling Image Fidelity restores original 3D MSAA")
	_expect(int(director.viewport.screen_space_aa) == original_screen_aa, "disabling Image Fidelity restores original screen-space AA")
	director.set_enabled(true)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("IMAGE_FIDELITY_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("IMAGE_FIDELITY_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
