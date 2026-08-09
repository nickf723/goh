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

	var director: RenderImageQualityDirector = target.get_node_or_null(
		"RenderImageQualityDirector"
	) as RenderImageQualityDirector
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	_expect(director != null, "Green installs RenderImageQualityDirector")
	_expect(lighting != null, "image-quality test resolves LightingDirector")
	if director != null and lighting != null:
		_validate_contract(director)
		await _validate_quality_ladder(director, lighting)
		_validate_restore(director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(director: RenderImageQualityDirector) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("render_image_quality_director", false)), "image-quality director publishes debug contract")
	_expect(bool(data.get("initialized", false)), "image-quality director resolves root viewport and profile")
	_expect(str(data.get("profile_id", "")) == "green_grotto_render_image_quality", "Green owns dedicated image-quality profile")
	_expect(bool(data.get("follows_lighting_quality", false)), "image quality follows F7")
	_expect(bool(data.get("root_viewport_only", false)), "image quality modifies only active root viewport")
	_expect(bool(data.get("project_settings_unchanged", false)), "image quality does not rewrite project settings")
	_expect(bool(data.get("geometry_unchanged", false)), "image quality changes no scene geometry")
	_expect(not bool(data.get("gameplay_authority", true)), "image quality owns no gameplay state")
	_expect(not director.original_state.is_empty(), "image-quality director captures original viewport state")


func _validate_quality_ladder(
	director: RenderImageQualityDirector,
	lighting: LightingDirector3D
) -> void:
	var viewport: Viewport = director.target_viewport
	_expect(viewport != null, "image-quality test resolves target viewport")
	if viewport == null:
		return

	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	director.synchronize_now()
	_expect(not viewport.use_taa, "Performance disables TAA")
	_expect(viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "Performance uses FXAA")
	_expect(viewport.msaa_3d == Viewport.MSAA_DISABLED, "Performance disables MSAA")
	_expect(not viewport.use_debanding, "Performance skips debanding")
	var performance_data: Dictionary = director.get_debug_data()
	_expect(str(performance_data.get("tier", "")) == "Performance", "Performance tier reports correctly")
	_expect(str(performance_data.get("screen_space_aa_label", "")) == "FXAA", "Performance debug contract reports FXAA")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	director.synchronize_now()
	_expect(viewport.use_taa, "Balanced enables TAA")
	_expect(viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Balanced avoids stacking post-process AA over TAA")
	_expect(viewport.msaa_3d == Viewport.MSAA_DISABLED, "Balanced keeps MSAA disabled")
	_expect(viewport.use_debanding, "Balanced enables debanding for fog/sky gradients")
	var balanced_data: Dictionary = director.get_debug_data()
	_expect(str(balanced_data.get("tier", "")) == "Balanced", "Balanced tier reports correctly")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	director.synchronize_now()
	_expect(viewport.use_taa, "Cinematic retains TAA")
	_expect(viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Cinematic leaves screen-space AA disabled")
	_expect(viewport.msaa_3d == Viewport.MSAA_DISABLED, "Cinematic no longer stacks MSAA on top of TAA")
	_expect(viewport.use_debanding, "Cinematic retains debanding")
	var cinematic_data: Dictionary = director.get_debug_data()
	_expect(str(cinematic_data.get("tier", "")) == "Cinematic", "Cinematic tier reports correctly")
	_expect(str(cinematic_data.get("msaa_label", "")) == "Off", "Cinematic debug contract reports MSAA disabled")


func _validate_restore(director: RenderImageQualityDirector) -> void:
	var viewport: Viewport = director.target_viewport
	if viewport == null:
		return
	var original: Dictionary = director.original_state.duplicate(true)
	director.set_enabled(false)
	_expect(viewport.use_taa == bool(original.get("use_taa", false)), "disabling image quality restores original TAA state")
	_expect(int(viewport.screen_space_aa) == int(original.get("screen_space_aa", 0)), "disabling image quality restores original screen-space AA")
	_expect(int(viewport.msaa_3d) == int(original.get("msaa_3d", 0)), "disabling image quality restores original MSAA state")
	_expect(viewport.use_debanding == bool(original.get("use_debanding", false)), "disabling image quality restores original debanding state")
	director.set_enabled(true)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("RENDER_IMAGE_QUALITY_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RENDER_IMAGE_QUALITY_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
