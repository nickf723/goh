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
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(target is PrototypeGreenGrottoLightingPass, "Green Grotto installs the Lighting Director integration layer")
	_expect(str(target.get_meta("lighting_authority", "")) == "LightingDirector", "Green Grotto declares LightingDirector authority")

	var director: LightingDirector3D = target.get_node_or_null("LightingDirector") as LightingDirector3D
	_expect(director != null, "LightingDirector node exists")
	if director != null:
		_validate_director(director)
		_validate_zone_sampling(director)
		_validate_quality_tiers(director)

	_validate_zones(target)
	_validate_legacy_light_retirement(target)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_director(director: LightingDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("lighting_director", false)), "Director publishes debug contract")
	_expect(bool(data.get("initialized", false)), "Director initializes after authored environment construction")
	_expect(str(data.get("default_profile", "")) == "green_grotto_base", "Director owns Green Grotto base profile")
	_expect(str(data.get("world_environment", "")) == "GreenGrottoEnvironment", "Director resolves existing WorldEnvironment")
	_expect(str(data.get("sun", "")) == "CanopySunset", "Director resolves authored sunset key")
	_expect(str(data.get("fill", "")) == "GrottoGreenFill", "Director resolves authored green fill")
	_expect(bool(data.get("camera_attributes", false)), "Director installs practical camera exposure attributes")
	_expect(bool(data.get("debug_hotkeys", false)), "Green art target enables lighting comparison hotkey")
	_expect(str(data.get("quality_label", "")) == "Cinematic", "Green art target starts in Cinematic lighting quality")
	_expect(bool(data.get("sdfgi", false)), "Cinematic tier enables SDFGI")
	_expect(bool(data.get("ssil", false)), "Cinematic tier enables SSIL")
	_expect(bool(data.get("ssr", false)), "Cinematic tier enables SSR")
	_expect(bool(data.get("volumetric_fog", false)), "Cinematic tier enables volumetric fog")

	_expect(director.environment != null, "Director exposes resolved Environment")
	if director.environment != null:
		_expect(director.environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "Director keeps filmic tonemapping")
		_expect(director.environment.sdfgi_cascades == 3, "Green cinematic profile uses three SDFGI cascades")
		_expect(director.environment.ssr_max_steps == 56, "Green cinematic profile uses the detoxed SSR step budget")


func _validate_zone_sampling(director: LightingDirector3D) -> void:
	var entrance_state: Dictionary = director.sample_state_at(Vector3(0.0, 1.2, 16.0))
	var canopy_state: Dictionary = director.sample_state_at(Vector3(0.0, 3.5, 1.5))
	var shrine_state: Dictionary = director.sample_state_at(Vector3(0.0, 4.0, -15.0))

	_expect(float(entrance_state.get("sun_energy", 99.0)) < 1.3, "entrance zone lowers direct sun")
	var canopy_energy: float = float(canopy_state.get("sun_energy", 0.0))
	_expect(canopy_energy > 1.20 and canopy_energy < 1.55, "canopy break is a controlled warm focal key instead of a second sun")
	_expect(float(canopy_state.get("sun_volumetric_energy", 99.0)) < 1.10, "canopy break keeps volumetric sun energy restrained")
	_expect(float(canopy_state.get("tonemap_exposure", 2.0)) < 0.92, "canopy break reins in exposure")
	_expect(float(shrine_state.get("sun_energy", 0.0)) > 1.5, "shrine retains its authored warm focal key")
	_expect(float(shrine_state.get("ambient_energy", 2.0)) < 0.50, "shrine reduces ambient flattening")

	var active: Array[String] = director.active_zone_ids
	var found_shrine: bool = false
	for label: String in active:
		if label.begins_with("green_grotto_shrine:"):
			found_shrine = true
			break
	_expect(found_shrine, "sampling shrine reports shrine zone activity")


func _validate_quality_tiers(director: LightingDirector3D) -> void:
	if director.environment == null:
		_expect(false, "quality test has an Environment")
		return

	director.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	var performance_data: Dictionary = director.get_debug_data()
	_expect(str(performance_data.get("quality_label", "")) == "Performance", "Performance tier publishes its label")
	_expect(not bool(performance_data.get("sdfgi", true)), "Performance tier disables SDFGI")
	_expect(not bool(performance_data.get("ssil", true)), "Performance tier disables SSIL")
	_expect(not bool(performance_data.get("ssr", true)), "Performance tier disables SSR")
	_expect(not bool(performance_data.get("volumetric_fog", true)), "Performance tier disables global volumetric fog")
	_expect(director.environment.ssao_enabled, "Performance tier retains inexpensive depth grounding through SSAO")

	director.set_quality(LightingDirector3D.Quality.BALANCED)
	var balanced_data: Dictionary = director.get_debug_data()
	_expect(str(balanced_data.get("quality_label", "")) == "Balanced", "Balanced tier publishes its label")
	_expect(bool(balanced_data.get("sdfgi", false)), "Balanced tier restores SDFGI")
	_expect(bool(balanced_data.get("ssil", false)), "Balanced tier restores SSIL")
	_expect(not bool(balanced_data.get("ssr", true)), "Balanced tier keeps SSR disabled")
	_expect(bool(balanced_data.get("volumetric_fog", false)), "Balanced tier restores volumetric fog")
	_expect(director.environment.sdfgi_cascades <= 2, "Balanced tier reduces SDFGI cascade cost")

	director.set_quality(LightingDirector3D.Quality.CINEMATIC)
	var cinematic_data: Dictionary = director.get_debug_data()
	_expect(str(cinematic_data.get("quality_label", "")) == "Cinematic", "Cinematic tier publishes its label")
	_expect(bool(cinematic_data.get("sdfgi", false)), "Cinematic tier restores full SDFGI")
	_expect(bool(cinematic_data.get("ssil", false)), "Cinematic tier restores SSIL")
	_expect(bool(cinematic_data.get("ssr", false)), "Cinematic tier restores SSR")
	_expect(bool(cinematic_data.get("volumetric_fog", false)), "Cinematic tier restores volumetric fog")
	_expect(director.environment.sdfgi_cascades == 3, "Cinematic tier restores full Green SDFGI cascade count")


func _validate_zones(target: Node) -> void:
	var expected: Dictionary = {
		"EntranceShadowZone": "green_grotto_entrance",
		"CanopyBreakZone": "green_grotto_canopy_break",
		"WaterfallZone": "green_grotto_waterfall",
		"ShrineZone": "green_grotto_shrine",
	}
	for zone_name: String in expected.keys():
		var zone: LightingZone3D = target.get_node_or_null(zone_name) as LightingZone3D
		_expect(zone != null, zone_name + " exists")
		if zone == null:
			continue
		_expect(zone.profile != null and zone.profile.profile_id == str(expected[zone_name]), zone_name + " owns expected profile")
		_expect(zone.get_blend_weight(zone.global_position) >= 0.99, zone_name + " is full strength at its center")
		_expect(zone.get_blend_weight(zone.global_position + Vector3(zone.zone_extents.x + 1.0, 0.0, 0.0)) == 0.0, zone_name + " is zero outside its bounds")

	var canopy: LightingZone3D = target.get_node_or_null("CanopyBreakZone") as LightingZone3D
	var waterfall: LightingZone3D = target.get_node_or_null("WaterfallZone") as LightingZone3D
	var shrine: LightingZone3D = target.get_node_or_null("ShrineZone") as LightingZone3D
	_expect(canopy != null and canopy.fog_volume != null, "canopy break installs local volumetric shaft medium")
	_expect(waterfall != null and waterfall.fog_volume != null, "waterfall installs localized mist volume")
	_expect(waterfall != null and waterfall.accent_light != null, "waterfall installs cool local bounce")
	_expect(shrine != null and shrine.fog_volume != null, "shrine installs subtle local atmosphere")
	_expect(shrine != null and shrine.accent_light != null, "shrine installs warm local bounce")


func _validate_legacy_light_retirement(target: Node) -> void:
	for path: String in [
		"GreenGrottoArt/Lighting/ShrineSunBounce",
		"GreenGrottoArt/Lighting/WaterCoolBounce",
	]:
		var light: OmniLight3D = target.get_node_or_null(path) as OmniLight3D
		_expect(light != null, path + " remains a stable hierarchy seam")
		if light == null:
			continue
		_expect(light.light_energy == 0.0, path + " no longer contributes manual lighting")
		_expect(not light.visible, path + " is visually retired")
		_expect(bool(light.get_meta("retired_by_lighting_director", false)), path + " records Director retirement")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("LIGHTING_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LIGHTING_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
