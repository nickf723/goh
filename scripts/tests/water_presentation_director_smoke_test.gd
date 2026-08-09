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

	_expect(target is PrototypeGreenGrottoWaterPass, "Green Grotto installs Water Presentation integration")
	_expect(
		str(target.get_meta("water_presentation_authority", ""))
		== "WaterPresentationDirector",
		"Green Grotto declares WaterPresentationDirector authority"
	)

	var director: WaterPresentationDirector3D = target.get_node_or_null(
		"WaterPresentationDirector"
	) as WaterPresentationDirector3D
	_expect(director != null, "WaterPresentationDirector node exists")
	if director != null:
		_validate_director_contract(director)
		_validate_green_surfaces(target, director)
		_validate_shared_waterfall_material(director)
		_validate_ab_restore(target, director)
		_validate_other_visual_layers(target)

	await _validate_legacy_fluid_defaults()

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_director_contract(director: WaterPresentationDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("water_presentation_director", false)), "Director publishes water presentation contract")
	_expect(bool(data.get("initialized", false)), "Director initializes with its profile")
	_expect(str(data.get("profile_id", "")) == "green_grotto_water", "Director owns Green Grotto water profile")
	_expect(bool(data.get("enabled", false)), "Director starts enabled")
	_expect(bool(data.get("debug_hotkeys", false)), "Green benchmark enables F2 comparison")
	_expect(bool(data.get("depth_aware", false)), "horizontal water uses depth-aware presentation")
	_expect(bool(data.get("screen_refraction", false)), "water presentation uses screen-space refraction")
	_expect(bool(data.get("world_space_horizontal_flow", false)), "irregular Green polygons use world-space flow coordinates")
	_expect(not bool(data.get("physics_authority", true)), "Water Presentation never owns fluid physics")
	_expect(int(data.get("target_count", 0)) == 6, "Green registers exactly six authored water surfaces")
	var roles: Dictionary = _dictionary_value(data.get("role_counts", {}))
	_expect(int(roles.get("stream", 0)) == 1, "one upper stream is registered")
	_expect(int(roles.get("basin", 0)) == 1, "one lower basin is registered")
	_expect(int(roles.get("waterfall", 0)) == 4, "four waterfall sheets are registered")
	_expect(int(data.get("shared_materials", 0)) == 3, "six water meshes resolve to three shared presentation materials")


func _validate_green_surfaces(
	target: Node,
	director: WaterPresentationDirector3D
) -> void:
	var water_root: Node = target.get_node_or_null(
		"GreenGrottoArt/HeroPassV3/HeroWater"
	)
	_expect(water_root != null, "HeroWater hierarchy remains stable")
	if water_root == null:
		return

	var upper: MeshInstance3D = water_root.get_node_or_null("V3UpperStream") as MeshInstance3D
	var basin: MeshInstance3D = water_root.get_node_or_null("V3LowerBasin") as MeshInstance3D
	_expect(upper != null and upper.mesh is ArrayMesh, "upper stream keeps irregular polygon geometry")
	_expect(basin != null and basin.mesh is ArrayMesh, "lower basin keeps irregular polygon geometry")
	if upper != null:
		_validate_horizontal_material(upper, director, "stream")
	if basin != null:
		_validate_horizontal_material(basin, director, "basin")

	for index: int in range(4):
		var waterfall: MeshInstance3D = water_root.get_node_or_null(
			"V3WaterfallSheet%02d" % index
		) as MeshInstance3D
		_expect(waterfall != null, "waterfall sheet %d exists" % index)
		if waterfall == null:
			continue
		var material: ShaderMaterial = waterfall.material_override as ShaderMaterial
		_expect(material != null, "waterfall sheet %d receives ShaderMaterial" % index)
		if material != null:
			_expect(
				material.shader != null
				and material.shader.resource_path == "res://shaders/waterfall_surface_v1.gdshader",
				"waterfall sheet %d uses directional waterfall shader" % index
			)
			_expect(float(material.get_shader_parameter("flow_speed")) > 1.0, "waterfall shader has visible directional flow")
			_expect(float(material.get_shader_parameter("refraction_strength")) > 0.4, "waterfall shader refracts the background")


func _validate_horizontal_material(
	mesh_instance: MeshInstance3D,
	director: WaterPresentationDirector3D,
	role: String
) -> void:
	var material: ShaderMaterial = mesh_instance.material_override as ShaderMaterial
	_expect(material != null, role + " receives ShaderMaterial")
	if material == null:
		return
	_expect(
		material.shader != null
		and material.shader.resource_path == "res://shaders/water_surface_v1.gdshader",
		role + " evolves the shared FluidForceVolume water shader"
	)
	_expect(float(material.get_shader_parameter("world_space_flow")) > 0.99, role + " opts into world-space flow")
	_expect(float(material.get_shader_parameter("refraction_strength")) > 0.5, role + " opts into screen refraction")
	_expect(float(material.get_shader_parameter("depth_tint_distance")) > 0.5, role + " opts into depth tint")
	_expect(float(material.get_shader_parameter("shoreline_depth")) > 0.1, role + " derives shallow-edge treatment from scene depth")
	_expect(float(material.get_shader_parameter("micro_wave_strength")) > 0.05, role + " adds restrained micro-wave breakup")


func _validate_shared_waterfall_material(director: WaterPresentationDirector3D) -> void:
	var first: ShaderMaterial = null
	var waterfall_count: int = 0
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		if str(record.get("role", "")) != "waterfall":
			continue
		waterfall_count += 1
		var enhanced: ShaderMaterial = record.get("enhanced") as ShaderMaterial
		if first == null:
			first = enhanced
		else:
			_expect(enhanced == first, "all four waterfall sheets share one presentation material")
	_expect(waterfall_count == 4, "shared-material test sees all waterfall sheets")


func _validate_ab_restore(
	target: Node,
	director: WaterPresentationDirector3D
) -> void:
	var upper: MeshInstance3D = target.get_node_or_null(
		"GreenGrottoArt/HeroPassV3/HeroWater/V3UpperStream"
	) as MeshInstance3D
	_expect(upper != null, "F2 A/B test resolves upper stream")
	if upper == null:
		return
	var record: Dictionary = director.targets.get(upper.get_instance_id(), {}) as Dictionary
	_expect(not record.is_empty(), "upper stream has a water presentation record")
	if record.is_empty():
		return
	var original: Material = record.get("original") as Material
	var enhanced: Material = record.get("enhanced") as Material
	var mesh_before: Mesh = upper.mesh
	_expect(upper.material_override == enhanced, "F2/ON applies enhanced stream material")

	director.set_enabled(false)
	_expect(upper.material_override == original, "F2/OFF restores exact original stream material")
	_expect(upper.mesh == mesh_before, "F2/OFF never rebuilds water geometry")
	_expect(int(director.get_debug_data().get("restored_target_count", 0)) == 6, "F2/OFF restores all six registered surfaces")

	director.set_enabled(true)
	_expect(upper.material_override == enhanced, "F2/ON restores exact enhanced stream material")
	_expect(upper.mesh == mesh_before, "F2/ON leaves water geometry untouched")


func _validate_other_visual_layers(target: Node) -> void:
	var material_director: MaterialFidelityDirector3D = target.get_node_or_null(
		"MaterialFidelityDirector"
	) as MaterialFidelityDirector3D
	var surface_story: SurfaceStoryDirector3D = target.get_node_or_null(
		"SurfaceStoryDirector"
	) as SurfaceStoryDirector3D
	var motion_director: EnvironmentalMotionDirector3D = target.get_node_or_null(
		"EnvironmentalMotionDirector"
	) as EnvironmentalMotionDirector3D
	_expect(material_director != null and material_director.enabled, "Material Fidelity remains active beside water presentation")
	_expect(surface_story != null and surface_story.decals.size() >= 80, "Surface Story remains active beside water presentation")
	_expect(motion_director != null and motion_director.enabled, "Environmental Motion remains active beside water presentation")


func _validate_legacy_fluid_defaults() -> void:
	var fluid := FluidForceVolume.new()
	fluid.name = "LegacyFluidCompatibilityProbe"
	add_child(fluid)
	await get_tree().process_frame
	_expect(fluid.surface_material != null, "legacy FluidForceVolume still builds shared water material")
	if fluid.surface_material != null:
		_expect(
			fluid.surface_material.shader != null
			and fluid.surface_material.shader.resource_path == "res://shaders/water_surface_v1.gdshader",
			"legacy fluid still uses the same evolved shared shader"
		)
		_expect(absf(float(fluid.surface_material.get_shader_parameter("refraction_strength"))) < 0.0001, "legacy fluid refraction remains opt-in")
		_expect(absf(float(fluid.surface_material.get_shader_parameter("depth_tint_distance"))) < 0.0001, "legacy fluid depth tint remains opt-in")
		_expect(absf(float(fluid.surface_material.get_shader_parameter("shoreline_foam_strength"))) < 0.0001, "legacy fluid shoreline foam remains opt-in")
		_expect(absf(float(fluid.surface_material.get_shader_parameter("world_space_flow"))) < 0.0001, "legacy fluid retains UV-space flow by default")
	fluid.queue_free()
	await get_tree().process_frame


func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("WATER_PRESENTATION_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WATER_PRESENTATION_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
