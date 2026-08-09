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

	_expect(target is PrototypeGreenGrottoReflectionPass, "Green Grotto installs Reflection Fidelity integration")
	_expect(str(target.get_meta("reflection_fidelity_authority", "")) == "ReflectionFidelityDirector", "Green declares ReflectionFidelityDirector authority")

	var director: ReflectionFidelityDirector3D = target.get_node_or_null("ReflectionFidelityDirector") as ReflectionFidelityDirector3D
	var lighting: LightingDirector3D = target.get_node_or_null("LightingDirector") as LightingDirector3D
	_expect(director != null, "ReflectionFidelityDirector exists")
	_expect(lighting != null, "LightingDirector remains available")
	if director != null and lighting != null:
		director.synchronize_now()
		_validate_contract(director)
		_validate_regions(target, director)
		_validate_quality_tiers(director, lighting)
		_validate_layer_coexistence(target)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(director: ReflectionFidelityDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("reflection_fidelity_director", false)), "Director publishes reflection contract")
	_expect(bool(data.get("initialized", false)), "Director initializes")
	_expect(str(data.get("profile_id", "")) == "green_grotto_reflections", "Director owns Green reflection profile")
	_expect(bool(data.get("update_once", false)), "reflection captures use update-once policy")
	_expect(bool(data.get("follows_lighting_quality", false)), "reflection quality follows F7")
	_expect(bool(data.get("geometry_unchanged", false)), "reflection system leaves geometry untouched")
	_expect(not bool(data.get("physics_authority", true)), "reflection system owns no gameplay physics")
	_expect(int(data.get("region_count", 0)) == 4, "Green authors exactly four reflection regions")
	_expect(int(data.get("box_projection_probes", 0)) == 2, "only room-like entrance and shrine use box projection")


func _validate_regions(
	target: Node,
	director: ReflectionFidelityDirector3D
) -> void:
	var expected: Dictionary = {
		"EntranceReflectionRegion": "entrance_hollow",
		"CanopyReflectionRegion": "canopy_vista",
		"WaterfallReflectionRegion": "waterfall_bowl",
		"ShrineReflectionRegion": "shrine_court",
	}
	for node_name: String in expected.keys():
		var region: ReflectionRegion3D = target.get_node_or_null(node_name) as ReflectionRegion3D
		_expect(region != null, node_name + " exists")
		if region == null:
			continue
		_expect(region.region_id == str(expected[node_name]), node_name + " has stable semantic id")
		_expect(region.probe != null, node_name + " installs native ReflectionProbe")
		if region.probe != null:
			_expect(region.probe.update_mode == ReflectionProbe.UPDATE_ONCE, node_name + " uses UPDATE_ONCE")
			_expect(region.probe.max_distance <= director.profile.maximum_capture_distance + 0.01, node_name + " obeys capture-distance budget")

	var entrance: ReflectionRegion3D = target.get_node_or_null("EntranceReflectionRegion") as ReflectionRegion3D
	var waterfall: ReflectionRegion3D = target.get_node_or_null("WaterfallReflectionRegion") as ReflectionRegion3D
	var shrine: ReflectionRegion3D = target.get_node_or_null("ShrineReflectionRegion") as ReflectionRegion3D
	_expect(entrance != null and entrance.probe.box_projection, "entrance uses parallax-corrected box projection")
	_expect(shrine != null and shrine.probe.box_projection, "shrine court uses parallax-corrected box projection")
	_expect(waterfall != null and not waterfall.probe.box_projection, "irregular waterfall ravine avoids box projection")


func _validate_quality_tiers(
	director: ReflectionFidelityDirector3D,
	lighting: LightingDirector3D
) -> void:
	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	director.synchronize_now()
	var performance: Dictionary = director.get_debug_data()
	_expect(str(performance.get("tier", "")) == "Performance", "Performance reflection tier follows F7")
	_expect(int(performance.get("active_probes", -1)) == 0, "Performance disables local reflection captures")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	director.synchronize_now()
	var balanced: Dictionary = director.get_debug_data()
	_expect(str(balanced.get("tier", "")) == "Balanced", "Balanced reflection tier follows F7")
	_expect(int(balanced.get("active_probes", 0)) == 3, "Balanced enables entrance, waterfall, and shrine probes")
	_expect(int(balanced.get("shadowed_probes", -1)) == 0, "Balanced captures omit reflection-probe shadows")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	director.synchronize_now()
	var cinematic: Dictionary = director.get_debug_data()
	_expect(str(cinematic.get("tier", "")) == "Cinematic", "Cinematic reflection tier follows F7")
	_expect(int(cinematic.get("active_probes", 0)) == 4, "Cinematic enables all four local reflection regions")
	_expect(int(cinematic.get("shadowed_probes", -1)) == 0, "Cinematic probes stay shadow-free after the performance detox")
	_expect(director.profile.maximum_capture_distance <= 56.0, "Cinematic capture distance stays bounded")


func _validate_layer_coexistence(target: Node) -> void:
	var lighting: LightingDirector3D = target.get_node_or_null("LightingDirector") as LightingDirector3D
	var shadows: ShadowFidelityDirector3D = target.get_node_or_null("ShadowFidelityDirector") as ShadowFidelityDirector3D
	var materials: MaterialFidelityDirector3D = target.get_node_or_null("MaterialFidelityDirector") as MaterialFidelityDirector3D
	var water: WaterPresentationDirector3D = target.get_node_or_null("WaterPresentationDirector") as WaterPresentationDirector3D
	_expect(lighting != null and lighting.environment != null and lighting.environment.ssr_enabled, "Cinematic SSR remains active as near-screen reflection layer")
	_expect(shadows != null and shadows.enabled, "Shadow Fidelity remains active")
	_expect(materials != null and materials.enabled, "Material Fidelity remains active")
	_expect(water != null and water.enabled, "Water Presentation remains active")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("REFLECTION_FIDELITY_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("REFLECTION_FIDELITY_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
