extends CanvasLayer
class_name VisualBenchmarkDirector

signal benchmark_preset_changed(preset_name: String)
signal benchmark_capture_finished(result: Dictionary)

const PRESET_BASELINE: int = 0
const PRESET_BALANCED: int = 1
const PRESET_HERO: int = 2
const ROLLING_SAMPLE_LIMIT: int = 180
const ImageFidelityDirectorScript = preload(
	"res://scripts/image_fidelity/image_fidelity_director.gd"
)
const GreenImageFidelityProfile = preload(
	"res://data/image_fidelity/green_grotto_image_fidelity.tres"
)

@export var debug_hotkeys_enabled: bool = true
@export var overlay_enabled: bool = true
@export_range(1.0, 15.0, 0.5) var capture_seconds: float = 5.0

var vegetation: VegetationPresentationDirector3D = null
var water: WaterPresentationDirector3D = null
var material_fidelity: MaterialFidelityDirector3D = null
var surface_story: SurfaceStoryDirector3D = null
var motion: EnvironmentalMotionDirector3D = null
var camera_director: CameraDirector3D = null
var lighting: LightingDirector3D = null
var shadows: ShadowFidelityDirector3D = null
var reflections: ReflectionFidelityDirector3D = null
var atmosphere: AtmosphericDetailDirector3D = null
var character_materials: CharacterMaterialPresentationDirector3D = null
var visual_lod: VisualLODDirector3D = null
var surface_contact: SurfaceContactPresentationDirector3D = null
var image_fidelity: ImageFidelityDirector = null
var ambient_fauna: Array[GreenGrottoFaunaAmbientBehavior] = []

var panel: PanelContainer = null
var status_label: Label = null
var preset_index: int = PRESET_HERO
var initialized: bool = false
var refresh_timer: float = 0.0
var rolling_frame_times: Array[float] = []
var current_fps: float = 0.0
var current_draw_calls: int = 0
var current_primitives: int = 0
var capture_active: bool = false
var capture_remaining: float = 0.0
var capture_label: String = ""
var capture_frame_times: Array[float] = []
var capture_draw_call_sum: float = 0.0
var capture_primitive_sum: float = 0.0
var capture_samples: int = 0
var last_capture: Dictionary = {}


func _ready() -> void:
	layer = 90
	add_to_group("visual_benchmark_director")
	add_to_group("debuggable")
	call_deferred("_initialize")


func _process(delta: float) -> void:
	if not initialized:
		return
	_sample_performance(maxf(delta, 0.0))
	refresh_timer -= maxf(delta, 0.0)
	if refresh_timer <= 0.0:
		refresh_timer = 0.18
		_refresh_optional_systems()
		_refresh_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys_enabled or not initialized:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F9:
		apply_preset((preset_index + 1) % 3)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F10:
		overlay_enabled = not overlay_enabled
		if panel != null:
			panel.visible = overlay_enabled
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F11:
		start_capture()
		get_viewport().set_input_as_handled()


func _initialize() -> void:
	_ensure_image_fidelity_director()
	_resolve_systems()
	_build_overlay()
	preset_index = _detect_matching_preset()
	if preset_index < 0:
		preset_index = PRESET_HERO
	initialized = _required_systems_ready()
	set_meta("visual_benchmark_initialized", initialized)
	_refresh_overlay()


func _ensure_image_fidelity_director() -> void:
	image_fidelity = get_node_or_null(
		"ImageFidelityDirector"
	) as ImageFidelityDirector
	if image_fidelity != null:
		return
	image_fidelity = ImageFidelityDirectorScript.new() as ImageFidelityDirector
	image_fidelity.name = "ImageFidelityDirector"
	image_fidelity.profile = GreenImageFidelityProfile
	add_child(image_fidelity)


func _resolve_systems() -> void:
	if get_tree() == null:
		return
	vegetation = get_tree().get_first_node_in_group(
		"vegetation_presentation_director"
	) as VegetationPresentationDirector3D
	water = get_tree().get_first_node_in_group(
		"water_presentation_director"
	) as WaterPresentationDirector3D
	material_fidelity = get_tree().get_first_node_in_group(
		"material_fidelity_director"
	) as MaterialFidelityDirector3D
	surface_story = get_tree().get_first_node_in_group(
		"surface_story_director"
	) as SurfaceStoryDirector3D
	motion = get_tree().get_first_node_in_group(
		"environmental_motion_director"
	) as EnvironmentalMotionDirector3D
	camera_director = get_tree().get_first_node_in_group(
		"camera_director"
	) as CameraDirector3D
	lighting = get_tree().get_first_node_in_group(
		"lighting_director"
	) as LightingDirector3D
	shadows = get_tree().get_first_node_in_group(
		"shadow_fidelity_director"
	) as ShadowFidelityDirector3D
	reflections = get_tree().get_first_node_in_group(
		"reflection_fidelity_director"
	) as ReflectionFidelityDirector3D
	_refresh_optional_systems()


func _refresh_optional_systems() -> void:
	if get_tree() == null:
		return
	atmosphere = get_tree().get_first_node_in_group(
		"atmospheric_detail_director"
	) as AtmosphericDetailDirector3D
	character_materials = get_tree().get_first_node_in_group(
		"character_material_presentation_director"
	) as CharacterMaterialPresentationDirector3D
	visual_lod = get_tree().get_first_node_in_group(
		"visual_lod_director"
	) as VisualLODDirector3D
	surface_contact = get_tree().get_first_node_in_group(
		"surface_contact_presentation_director"
	) as SurfaceContactPresentationDirector3D
	var image_candidate: Node = get_tree().get_first_node_in_group(
		"image_fidelity_director"
	)
	if image_candidate is ImageFidelityDirector:
		image_fidelity = image_candidate as ImageFidelityDirector
	ambient_fauna.clear()
	for candidate: Node in get_tree().get_nodes_in_group("ambient_fauna_behavior"):
		if candidate is GreenGrottoFaunaAmbientBehavior:
			ambient_fauna.append(candidate as GreenGrottoFaunaAmbientBehavior)


func _required_systems_ready() -> bool:
	return (
		vegetation != null
		and water != null
		and material_fidelity != null
		and surface_story != null
		and motion != null
		and camera_director != null
		and lighting != null
	)


func apply_preset(index: int) -> void:
	if not _required_systems_ready():
		_resolve_systems()
		if not _required_systems_ready():
			return
	_refresh_optional_systems()
	preset_index = clampi(index, PRESET_BASELINE, PRESET_HERO)
	var presentation_enabled: bool = preset_index != PRESET_BASELINE
	vegetation.set_enabled(presentation_enabled)
	water.set_enabled(presentation_enabled)
	material_fidelity.set_enabled(presentation_enabled)
	surface_story.set_enabled(presentation_enabled)
	motion.set_enabled(presentation_enabled)
	camera_director.set_enabled(presentation_enabled)
	for behavior: GreenGrottoFaunaAmbientBehavior in ambient_fauna:
		if behavior != null and is_instance_valid(behavior):
			behavior.set_enabled(presentation_enabled)

	match preset_index:
		PRESET_BASELINE:
			lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
		PRESET_BALANCED:
			lighting.set_quality(LightingDirector3D.Quality.BALANCED)
		_:
			lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)

	if shadows != null:
		shadows.synchronize_now()
	if reflections != null:
		reflections.synchronize_now()
	if image_fidelity != null:
		image_fidelity.synchronize_now()
	benchmark_preset_changed.emit(_preset_name(preset_index))
	_refresh_overlay()


func start_capture(duration_override: float = -1.0) -> void:
	if not initialized:
		return
	capture_active = true
	capture_remaining = (
		maxf(duration_override, 0.05)
		if duration_override > 0.0
		else maxf(capture_seconds, 0.5)
	)
	var matched: int = _detect_matching_preset()
	capture_label = _preset_name(matched) if matched >= 0 else "CUSTOM"
	capture_frame_times.clear()
	capture_draw_call_sum = 0.0
	capture_primitive_sum = 0.0
	capture_samples = 0
	_refresh_overlay()


func _sample_performance(delta: float) -> void:
	if delta > 0.000001:
		rolling_frame_times.append(delta)
		while rolling_frame_times.size() > ROLLING_SAMPLE_LIMIT:
			rolling_frame_times.pop_front()
	current_fps = Performance.get_monitor(Performance.TIME_FPS)
	current_draw_calls = int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
	))
	current_primitives = int(Performance.get_monitor(
		Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME
	))
	if capture_active:
		_record_capture_sample(
			delta,
			current_draw_calls,
			current_primitives
		)


func _record_capture_sample(
	delta: float,
	draw_calls: int,
	primitives: int
) -> void:
	if not capture_active:
		return
	if delta > 0.000001:
		capture_frame_times.append(delta)
	capture_draw_call_sum += maxf(float(draw_calls), 0.0)
	capture_primitive_sum += maxf(float(primitives), 0.0)
	capture_samples += 1
	capture_remaining -= maxf(delta, 0.0)
	if capture_remaining <= 0.0:
		_finish_capture()


func _finish_capture() -> void:
	capture_active = false
	var average_seconds: float = _average(capture_frame_times)
	var average_ms: float = average_seconds * 1000.0
	var average_fps: float = 0.0
	if average_seconds > 0.000001:
		average_fps = 1.0 / average_seconds
	var one_percent_low_fps: float = _one_percent_low_fps(capture_frame_times)
	var sample_divisor: float = maxf(float(capture_samples), 1.0)
	last_capture = {
		"preset": capture_label,
		"samples": capture_samples,
		"average_fps": average_fps,
		"average_frame_ms": average_ms,
		"one_percent_low_fps": one_percent_low_fps,
		"average_draw_calls": capture_draw_call_sum / sample_divisor,
		"average_primitives": capture_primitive_sum / sample_divisor,
	}
	benchmark_capture_finished.emit(last_capture.duplicate(true))
	print("VISUAL_BENCHMARK_CAPTURE: ", last_capture)
	_refresh_overlay()


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _one_percent_low_fps(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var worst_count: int = maxi(int(ceil(float(sorted.size()) * 0.01)), 1)
	var worst_total: float = 0.0
	for index: int in range(worst_count):
		worst_total += sorted[sorted.size() - 1 - index]
	var worst_average: float = worst_total / float(worst_count)
	return 1.0 / worst_average if worst_average > 0.000001 else 0.0


func _rolling_frame_ms() -> float:
	return _average(rolling_frame_times) * 1000.0


func _detect_matching_preset() -> int:
	if not _required_systems_ready():
		return -1
	var all_presentation_on: bool = (
		vegetation.enabled
		and water.enabled
		and material_fidelity.enabled
		and surface_story.enabled
		and motion.enabled
		and camera_director.enabled
		and _all_ambient_fauna_enabled()
	)
	var all_presentation_off: bool = (
		not vegetation.enabled
		and not water.enabled
		and not material_fidelity.enabled
		and not surface_story.enabled
		and not motion.enabled
		and not camera_director.enabled
		and _all_ambient_fauna_disabled()
	)
	if all_presentation_off and lighting.quality == LightingDirector3D.Quality.PERFORMANCE:
		return PRESET_BASELINE
	if all_presentation_on and lighting.quality == LightingDirector3D.Quality.BALANCED:
		return PRESET_BALANCED
	if all_presentation_on and lighting.quality == LightingDirector3D.Quality.CINEMATIC:
		return PRESET_HERO
	return -1


func _all_ambient_fauna_enabled() -> bool:
	if ambient_fauna.is_empty():
		return true
	for behavior: GreenGrottoFaunaAmbientBehavior in ambient_fauna:
		if behavior == null or not is_instance_valid(behavior) or not behavior.enabled:
			return false
	return true


func _all_ambient_fauna_disabled() -> bool:
	if ambient_fauna.is_empty():
		return true
	for behavior: GreenGrottoFaunaAmbientBehavior in ambient_fauna:
		if behavior != null and is_instance_valid(behavior) and behavior.enabled:
			return false
	return true


func _build_overlay() -> void:
	if panel != null:
		return
	panel = PanelContainer.new()
	panel.name = "BenchmarkStatusPanel"
	panel.position = Vector2(14.0, 14.0)
	panel.custom_minimum_size = Vector2(470.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = overlay_enabled
	add_child(panel)

	status_label = Label.new()
	status_label.name = "BenchmarkStatus"
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_constant_override("outline_size", 3)
	status_label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.82)
	)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status_label)


func _refresh_overlay() -> void:
	if status_label == null:
		return
	var matched: int = _detect_matching_preset()
	var preset_label: String = _preset_name(matched) if matched >= 0 else "CUSTOM"
	var capture_line: String = _capture_status_line()
	status_label.text = (
		"VISUAL LAB  •  %s\n"
		+ "FPS %.0f   %.2f ms   DC %d   Prim %s\n"
		+ "F1 Veg %s   F2 Water %s   F3 Material %s\n"
		+ "F4 Story %s   F5 Motion %s   F6 Camera %s\n"
		+ "F7 %s   •   Refl %d   Atm %d   LOD %d   Img %s\n"
		+ "Grace Q%d   Contact %d   Fauna %s   •   F9 Preset   F10 HUD   F11 Sample%s"
	) % [
		preset_label,
		current_fps,
		_rolling_frame_ms(),
		current_draw_calls,
		_compact_number(current_primitives),
		_on_off(vegetation != null and vegetation.enabled),
		_on_off(water != null and water.enabled),
		_on_off(material_fidelity != null and material_fidelity.enabled),
		_on_off(surface_story != null and surface_story.enabled),
		_on_off(motion != null and motion.enabled),
		_on_off(camera_director != null and camera_director.enabled),
		_lighting_label(),
		_reflection_probe_count(),
		_atmosphere_instance_count(),
		_lod_target_count(),
		_image_quality_label(),
		_character_material_quality(),
		_contact_footstep_count(),
		_on_off(_all_ambient_fauna_enabled()),
		capture_line,
	]
	if panel != null:
		panel.visible = overlay_enabled


func _reflection_probe_count() -> int:
	if reflections == null:
		return 0
	return int(reflections.get_debug_data().get("active_probes", 0))


func _atmosphere_instance_count() -> int:
	if atmosphere == null:
		return 0
	return int(atmosphere.get_debug_data().get("visible_instances", 0))


func _lod_target_count() -> int:
	if visual_lod == null:
		return 0
	return int(visual_lod.get_debug_data().get("target_count", 0))


func _character_material_quality() -> int:
	if character_materials == null:
		return -1
	return int(character_materials.get_debug_data().get("quality", -1))


func _image_quality_label() -> String:
	if image_fidelity == null:
		return "?"
	var data: Dictionary = image_fidelity.get_debug_data()
	var taa: bool = bool(data.get("taa", false))
	var msaa: int = int(data.get("msaa_3d", 0))
	if taa and msaa == Viewport.MSAA_2X:
		return "TAA+2x"
	if taa:
		return "TAA"
	return "RAW"


func _contact_footstep_count() -> int:
	if surface_contact == null or surface_contact.profile == null:
		return 0
	return surface_contact.profile.get_piece_count(
		"footstep",
		lighting.quality if lighting != null else 2
	)


func _capture_status_line() -> String:
	if capture_active:
		return "\nCAPTURING %s  %.1fs" % [
			capture_label,
			maxf(capture_remaining, 0.0),
		]
	if last_capture.is_empty():
		return ""
	return (
		"\nLAST %s  %.1f fps  1%% %.1f  %.2f ms  DC %.0f"
		% [
			str(last_capture.get("preset", "?")),
			float(last_capture.get("average_fps", 0.0)),
			float(last_capture.get("one_percent_low_fps", 0.0)),
			float(last_capture.get("average_frame_ms", 0.0)),
			float(last_capture.get("average_draw_calls", 0.0)),
		]
	)


func _compact_number(value: int) -> String:
	var magnitude: float = float(maxi(value, 0))
	if magnitude >= 1000000.0:
		return "%.2fM" % (magnitude / 1000000.0)
	if magnitude >= 1000.0:
		return "%.1fk" % (magnitude / 1000.0)
	return str(value)


func _lighting_label() -> String:
	if lighting == null:
		return "Lighting ?"
	match lighting.quality:
		LightingDirector3D.Quality.PERFORMANCE:
			return "Performance"
		LightingDirector3D.Quality.BALANCED:
			return "Balanced"
		_:
			return "Cinematic"


func _preset_name(index: int) -> String:
	match index:
		PRESET_BASELINE:
			return "BASELINE"
		PRESET_BALANCED:
			return "BALANCED"
		PRESET_HERO:
			return "HERO"
		_:
			return "CUSTOM"


func _on_off(value: bool) -> String:
	return "ON" if value else "off"


func get_debug_data() -> Dictionary:
	return {
		"visual_benchmark_director": true,
		"initialized": initialized,
		"matched_preset": _preset_name(_detect_matching_preset()),
		"preset_index": preset_index,
		"overlay_enabled": overlay_enabled,
		"f9_preset_cycle": true,
		"f10_overlay_toggle": true,
		"f11_timed_capture": true,
		"baseline_disables_f1_f6": true,
		"baseline_restores_legacy_fauna": _all_ambient_fauna_disabled(),
		"ambient_fauna_count": ambient_fauna.size(),
		"linked_reflection_probes": _reflection_probe_count(),
		"linked_atmosphere_instances": _atmosphere_instance_count(),
		"linked_lod_targets": _lod_target_count(),
		"linked_character_quality": _character_material_quality(),
		"linked_contact_footstep_pieces": _contact_footstep_count(),
		"linked_image_quality": _image_quality_label(),
		"balanced_uses_lighting_balanced": true,
		"hero_uses_lighting_cinematic": true,
		"current_fps": current_fps,
		"rolling_frame_ms": _rolling_frame_ms(),
		"current_draw_calls": current_draw_calls,
		"current_primitives": current_primitives,
		"capture_active": capture_active,
		"last_capture": last_capture.duplicate(true),
	}
