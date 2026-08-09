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

	_expect(
		target is PrototypeGreenGrottoVegetationPass,
		"Green Grotto installs Vegetation Presentation integration"
	)
	_expect(
		str(target.get_meta("vegetation_presentation_authority", ""))
		== "VegetationPresentationDirector",
		"Green Grotto declares VegetationPresentationDirector authority"
	)

	var director: VegetationPresentationDirector3D = target.get_node_or_null(
		"VegetationPresentationDirector"
	) as VegetationPresentationDirector3D
	_expect(director != null, "VegetationPresentationDirector node exists")
	if director != null:
		_validate_director_contract(director)
		_validate_registration_density(target, director)
		_validate_ground_material(director)
		_validate_canopy_material(director)
		_validate_shared_materials(director)
		_validate_ab_restore(director)
		_validate_layer_independence(target, director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_director_contract(
	director: VegetationPresentationDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(
		bool(data.get("vegetation_presentation_director", false)),
		"Director publishes vegetation presentation contract"
	)
	_expect(bool(data.get("initialized", false)), "Director initializes with profile")
	_expect(
		str(data.get("profile_id", "")) == "green_grotto_vegetation",
		"Director owns Green vegetation profile"
	)
	_expect(bool(data.get("enabled", false)), "Director starts enabled")
	_expect(bool(data.get("debug_hotkeys", false)), "Green benchmark enables F1 comparison")
	_expect(bool(data.get("two_sided", false)), "vegetation is explicitly two-sided")
	_expect(bool(data.get("lambert_wrap", false)), "vegetation uses wrapped diffuse shading")
	_expect(bool(data.get("backlight", false)), "vegetation enables backlight transport")
	_expect(
		bool(data.get("subsurface_transmittance", false)),
		"vegetation enables restrained subsurface transmittance"
	)
	_expect(bool(data.get("world_triplanar", false)), "vegetation uses world triplanar detail")
	_expect(bool(data.get("geometry_unchanged", false)), "vegetation presentation leaves meshes untouched")
	_expect(not bool(data.get("physics_authority", true)), "vegetation presentation owns no gameplay physics")


func _validate_registration_density(
	target: Node,
	director: VegetationPresentationDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	var roles: Dictionary = _dictionary_value(data.get("role_counts", {}))
	var foliage_count: int = int(roles.get("ground", 0)) + int(roles.get("sunlit", 0))
	_expect(int(data.get("target_count", 0)) >= 350, "Green enrolls a dense foliage mesh set")
	_expect(foliage_count >= 300, "ground and sunlit fronds dominate the enrolled set")
	_expect(int(roles.get("ground", 0)) > 0, "ordinary shaded foliage is present")
	_expect(int(roles.get("sunlit", 0)) > 0, "sunlit foliage is present")
	_expect(int(roles.get("canopy", 0)) >= 28, "canopy crowns receive their cheaper presentation tier")
	_expect(int(data.get("shared_materials", 99)) == 3, "all enrolled vegetation resolves to three shared enhanced materials")
	_expect(int(data.get("normal_textures", 99)) == 3, "each vegetation role shares one procedural normal texture")

	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("green_grotto_vegetation_presentation", false)), "Green pass reports vegetation presentation")
	_expect(bool(pass_data.get("vegetation_geometry_unchanged", false)), "Green pass records unchanged vegetation geometry")


func _validate_ground_material(
	director: VegetationPresentationDirector3D
) -> void:
	var record: Dictionary = _first_record_of_role(director, "ground")
	_expect(not record.is_empty(), "test resolves ordinary ground foliage")
	if record.is_empty():
		return
	var original: StandardMaterial3D = record.get("original") as StandardMaterial3D
	var enhanced: StandardMaterial3D = record.get("enhanced") as StandardMaterial3D
	_expect(original != null and enhanced != null, "ground foliage stores original and enhanced materials")
	if original == null or enhanced == null:
		return
	_expect(original != enhanced, "enhanced foliage is a distinct shared resource")
	_expect(enhanced.cull_mode == BaseMaterial3D.CULL_DISABLED, "enhanced foliage renders both sides")
	_expect(enhanced.diffuse_mode == BaseMaterial3D.DIFFUSE_LAMBERT_WRAP, "enhanced foliage wraps diffuse light around thin forms")
	_expect(enhanced.backlight_enabled, "enhanced ground foliage enables backlight")
	_expect(enhanced.subsurf_scatter_enabled, "enhanced ground foliage enables restrained SSS")
	_expect(enhanced.subsurf_scatter_transmittance_enabled, "enhanced ground foliage enables transmission")
	_expect(enhanced.uv1_triplanar and enhanced.uv1_world_triplanar, "ground foliage receives world triplanar texture continuity")
	_expect(enhanced.normal_enabled and enhanced.normal_texture is NoiseTexture2D, "ground foliage receives procedural normal breakup")


func _validate_canopy_material(
	director: VegetationPresentationDirector3D
) -> void:
	var record: Dictionary = _first_record_of_role(director, "canopy")
	_expect(not record.is_empty(), "test resolves canopy material")
	if record.is_empty():
		return
	var enhanced: StandardMaterial3D = record.get("enhanced") as StandardMaterial3D
	_expect(enhanced != null, "canopy resolves enhanced material")
	if enhanced == null:
		return
	_expect(enhanced.backlight_enabled, "canopy uses cheap backlighting")
	_expect(
		enhanced.subsurf_scatter_strength < director.profile.ground_sss_strength,
		"canopy keeps SSS cheaper than close ground foliage"
	)
	_expect(
		enhanced.roughness >= director.profile.ground_roughness,
		"canopy remains rough rather than becoming glossy plastic"
	)


func _validate_shared_materials(
	director: VegetationPresentationDirector3D
) -> void:
	var enhanced_by_role: Dictionary = {}
	var sharing_preserved: bool = true
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		var role: String = str(record.get("role", ""))
		var enhanced: StandardMaterial3D = record.get("enhanced") as StandardMaterial3D
		if enhanced_by_role.has(role):
			if enhanced_by_role[role] != enhanced:
				sharing_preserved = false
				break
		else:
			enhanced_by_role[role] = enhanced
	_expect(sharing_preserved, "all meshes in each vegetation role share the same enhanced material")


func _validate_ab_restore(
	director: VegetationPresentationDirector3D
) -> void:
	var record: Dictionary = _first_record_of_role(director, "sunlit")
	_expect(not record.is_empty(), "F1 A/B test resolves sunlit foliage")
	if record.is_empty():
		return
	var weak_value: Variant = record.get("ref", null)
	if not weak_value is WeakRef:
		_expect(false, "F1 sample keeps weak mesh reference")
		return
	var target_value: Variant = (weak_value as WeakRef).get_ref()
	if not target_value is MeshInstance3D:
		_expect(false, "F1 sample resolves live foliage mesh")
		return
	var mesh_instance: MeshInstance3D = target_value as MeshInstance3D
	var original: Material = record.get("original") as Material
	var enhanced: Material = record.get("enhanced") as Material
	var mesh_before: Mesh = mesh_instance.mesh
	var transform_before: Transform3D = mesh_instance.transform
	_expect(mesh_instance.material_override == enhanced, "F1/ON applies enhanced foliage material")

	director.set_enabled(false)
	_expect(mesh_instance.material_override == original, "F1/OFF restores exact original foliage material")
	_expect(mesh_instance.mesh == mesh_before, "F1/OFF never rebuilds foliage geometry")
	_expect(mesh_instance.transform == transform_before, "F1/OFF leaves foliage transform untouched")
	_expect(
		int(director.get_debug_data().get("restored_target_count", 0))
		== director.targets.size(),
		"F1/OFF restores every enrolled live vegetation mesh"
	)

	director.set_enabled(true)
	_expect(mesh_instance.material_override == enhanced, "F1/ON restores exact shared enhanced material")


func _validate_layer_independence(
	target: Node,
	director: VegetationPresentationDirector3D
) -> void:
	var motion: EnvironmentalMotionDirector3D = target.get_node_or_null(
		"EnvironmentalMotionDirector"
	) as EnvironmentalMotionDirector3D
	var water: WaterPresentationDirector3D = target.get_node_or_null(
		"WaterPresentationDirector"
	) as WaterPresentationDirector3D
	var material_fidelity: MaterialFidelityDirector3D = target.get_node_or_null(
		"MaterialFidelityDirector"
	) as MaterialFidelityDirector3D
	_expect(motion != null and motion.enabled, "F5 environmental motion remains independent and active")
	_expect(water != null and water.enabled, "F2 water presentation remains active beside foliage shading")
	_expect(material_fidelity != null and material_fidelity.enabled, "F3 material fidelity remains active beside foliage shading")
	if motion != null:
		var motion_before: bool = motion.enabled
		director.set_enabled(false)
		_expect(motion.enabled == motion_before, "F1 does not toggle environmental motion")
		director.set_enabled(true)


func _first_record_of_role(
	director: VegetationPresentationDirector3D,
	role: String
) -> Dictionary:
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		if str(record.get("role", "")) == role:
			return record
	return {}


func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("VEGETATION_PRESENTATION_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("VEGETATION_PRESENTATION_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
