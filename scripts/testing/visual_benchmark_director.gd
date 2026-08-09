extends CanvasLayer
class_name VisualBenchmarkDirector

signal benchmark_preset_changed(preset_name: String)

const PRESET_BASELINE: int = 0
const PRESET_BALANCED: int = 1
const PRESET_HERO: int = 2

@export var debug_hotkeys_enabled: bool = true
@export var overlay_enabled: bool = true

var vegetation: VegetationPresentationDirector3D = null
var water: WaterPresentationDirector3D = null
var material_fidelity: MaterialFidelityDirector3D = null
var surface_story: SurfaceStoryDirector3D = null
var motion: EnvironmentalMotionDirector3D = null
var camera_director: CameraDirector3D = null
var lighting: LightingDirector3D = null
var shadows: ShadowFidelityDirector3D = null
var reflections: ReflectionFidelityDirector3D = null

var panel: PanelContainer = null
var status_label: Label = null
var preset_index: int = PRESET_HERO
var initialized: bool = false
var refresh_timer: float = 0.0


func _ready() -> void:
	layer = 90
	add_to_group("visual_benchmark_director")
	add_to_group("debuggable")
	call_deferred("_initialize")


func _process(delta: float) -> void:
	if not initialized:
		return
	refresh_timer -= maxf(delta, 0.0)
	if refresh_timer <= 0.0:
		refresh_timer = 0.18
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


func _initialize() -> void:
	_resolve_systems()
	_build_overlay()
	preset_index = _detect_matching_preset()
	if preset_index < 0:
		preset_index = PRESET_HERO
	initialized = _required_systems_ready()
	set_meta("visual_benchmark_initialized", initialized)
	_refresh_overlay()


func _resolve_systems() -> void:
	if get_tree() == null:
		return
	vegetation = get_tree().get_first_node_in_group("vegetation_presentation_director") as VegetationPresentationDirector3D
	water = get_tree().get_first_node_in_group("water_presentation_director") as WaterPresentationDirector3D
	material_fidelity = get_tree().get_first_node_in_group("material_fidelity_director") as MaterialFidelityDirector3D
	surface_story = get_tree().get_first_node_in_group("surface_story_director") as SurfaceStoryDirector3D
	motion = get_tree().get_first_node_in_group("environmental_motion_director") as EnvironmentalMotionDirector3D
	camera_director = get_tree().get_first_node_in_group("camera_director") as CameraDirector3D
	lighting = get_tree().get_first_node_in_group("lighting_director") as LightingDirector3D
	shadows = get_tree().get_first_node_in_group("shadow_fidelity_director") as ShadowFidelityDirector3D
	reflections = get_tree().get_first_node_in_group("reflection_fidelity_director") as ReflectionFidelityDirector3D


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
	preset_index = clampi(index, PRESET_BASELINE, PRESET_HERO)
	var presentation_enabled: bool = preset_index != PRESET_BASELINE
	vegetation.set_enabled(presentation_enabled)
	water.set_enabled(presentation_enabled)
	material_fidelity.set_enabled(presentation_enabled)
	surface_story.set_enabled(presentation_enabled)
	motion.set_enabled(presentation_enabled)
	camera_director.set_enabled(presentation_enabled)

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
	benchmark_preset_changed.emit(_preset_name(preset_index))
	_refresh_overlay()


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
	)
	var all_presentation_off: bool = (
		not vegetation.enabled
		and not water.enabled
		and not material_fidelity.enabled
		and not surface_story.enabled
		and not motion.enabled
		and not camera_director.enabled
	)
	if all_presentation_off and lighting.quality == LightingDirector3D.Quality.PERFORMANCE:
		return PRESET_BASELINE
	if all_presentation_on and lighting.quality == LightingDirector3D.Quality.BALANCED:
		return PRESET_BALANCED
	if all_presentation_on and lighting.quality == LightingDirector3D.Quality.CINEMATIC:
		return PRESET_HERO
	return -1


func _build_overlay() -> void:
	if panel != null:
		return
	panel = PanelContainer.new()
	panel.name = "BenchmarkStatusPanel"
	panel.position = Vector2(14.0, 14.0)
	panel.custom_minimum_size = Vector2(310.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = overlay_enabled
	add_child(panel)

	status_label = Label.new()
	status_label.name = "BenchmarkStatus"
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_constant_override("outline_size", 3)
	status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status_label)


func _refresh_overlay() -> void:
	if status_label == null:
		return
	var matched: int = _detect_matching_preset()
	var preset_label: String = _preset_name(matched) if matched >= 0 else "CUSTOM"
	status_label.text = (
		"VISUAL LAB  •  %s\n"
		+ "F1 Veg %s   F2 Water %s   F3 Material %s\n"
		+ "F4 Story %s   F5 Motion %s   F6 Camera %s\n"
		+ "F7 %s   •   F9 Preset   F10 HUD"
	) % [
		preset_label,
		_on_off(vegetation != null and vegetation.enabled),
		_on_off(water != null and water.enabled),
		_on_off(material_fidelity != null and material_fidelity.enabled),
		_on_off(surface_story != null and surface_story.enabled),
		_on_off(motion != null and motion.enabled),
		_on_off(camera_director != null and camera_director.enabled),
		_lighting_label(),
	]
	if panel != null:
		panel.visible = overlay_enabled


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
		"baseline_disables_f1_f6": true,
		"balanced_uses_lighting_balanced": true,
		"hero_uses_lighting_cinematic": true,
	}
