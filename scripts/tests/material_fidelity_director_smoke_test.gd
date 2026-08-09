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

	_expect(target is PrototypeGreenGrottoMaterialPass, "Green Grotto installs Material Fidelity integration")
	_expect(
		str(target.get_meta("material_fidelity_authority", ""))
		== "MaterialFidelityDirector",
		"Green Grotto declares MaterialFidelityDirector authority"
	)

	var director: MaterialFidelityDirector3D = target.get_node_or_null(
		"MaterialFidelityDirector"
	) as MaterialFidelityDirector3D
	_expect(director != null, "MaterialFidelityDirector node exists")
	if director != null:
		_validate_director_contract(director)
		_validate_registration_density(target, director)
		_validate_enhanced_material_contract(director)
		_validate_shared_variant_cache(director)
		_validate_ab_restore(director)
		_validate_exclusions(target, director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_director_contract(director: MaterialFidelityDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("material_fidelity_director", false)), "Director publishes material-fidelity contract")
	_expect(bool(data.get("initialized", false)), "Director initializes with its profile")
	_expect(str(data.get("profile_id", "")) == "green_grotto_material_fidelity", "Director owns Green Grotto material profile")
	_expect(bool(data.get("enabled", false)), "Director starts enabled")
	_expect(bool(data.get("debug_hotkeys", false)), "Green benchmark enables F3 material comparison")
	_expect(bool(data.get("world_triplanar", false)), "Director uses world triplanar projection")
	_expect(bool(data.get("procedural_normals", false)), "Director generates procedural normal detail")
	_expect(bool(data.get("procedural_roughness", false)), "Director generates procedural roughness detail")
	_expect(bool(data.get("shared_variant_cache", false)), "Director shares enhanced material variants")
	_expect(bool(data.get("geometry_unchanged", false)), "material fidelity leaves geometry unchanged")


func _validate_registration_density(
	target: Node,
	director: MaterialFidelityDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	var counts: Dictionary = _dictionary_value(data.get("category_counts", {}))
	_expect(int(data.get("target_count", 0)) >= 420, "Green enrolls a broad authored surface set")
	_expect(int(counts.get("rock", 0)) + int(counts.get("rock_wet", 0)) >= 120, "rock/chasm surfaces dominate fidelity pass")
	_expect(int(counts.get("masonry", 0)) + int(counts.get("trim", 0)) >= 180, "ruin masonry receives continuous material detail")
	_expect(int(counts.get("paving", 0)) + int(counts.get("paving_wet", 0)) >= 100, "walkable paving receives close-range material detail")
	_expect(int(counts.get("wood", 0)) + int(counts.get("roof", 0)) >= 55, "shrine timber and roof receive authored detail")
	_expect(int(data.get("enhanced_materials", 99)) <= director.profile.maximum_shared_variants, "shared material variants stay inside profile budget")
	_expect(int(data.get("detail_textures", 0)) >= 12, "multiple surface families resolve procedural normal/roughness textures")

	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("green_grotto_material_fidelity", false)), "Green pass reports material fidelity")
	_expect(str(pass_data.get("material_fidelity_authority", "")) == "MaterialFidelityDirector", "Green pass reports shared material authority")


func _validate_enhanced_material_contract(director: MaterialFidelityDirector3D) -> void:
	var sample: Dictionary = _first_record_of_category(director, "rock")
	_expect(not sample.is_empty(), "test resolves an enhanced rock surface")
	if sample.is_empty():
		return
	var original: StandardMaterial3D = sample.get("original") as StandardMaterial3D
	var enhanced: StandardMaterial3D = sample.get("enhanced") as StandardMaterial3D
	_expect(original != null and enhanced != null, "rock record retains original and enhanced materials")
	if original == null or enhanced == null:
		return
	_expect(original != enhanced, "enhanced material is a distinct shared resource")
	_expect(enhanced.uv1_triplanar, "enhanced material enables triplanar mapping")
	_expect(enhanced.uv1_world_triplanar, "enhanced material anchors projection in world space")
	_expect(absf(enhanced.uv1_triplanar_sharpness - director.profile.triplanar_sharpness) < 0.01, "enhanced material uses profile triplanar sharpness")
	_expect(enhanced.normal_enabled, "enhanced material enables normal mapping")
	_expect(enhanced.normal_texture is NoiseTexture2D, "enhanced material uses generated NoiseTexture2D normal detail")
	_expect(enhanced.roughness_texture is NoiseTexture2D, "enhanced material uses generated NoiseTexture2D roughness detail")
	_expect(enhanced.uv1_scale.length() < original.uv1_scale.length(), "world-space detail enlarges macro texture scale relative to prototype")


func _validate_shared_variant_cache(director: MaterialFidelityDirector3D) -> void:
	var first_by_original: Dictionary = {}
	var repeated_original_found: bool = false
	var sharing_preserved: bool = true
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		var original: StandardMaterial3D = record.get("original") as StandardMaterial3D
		var enhanced: StandardMaterial3D = record.get("enhanced") as StandardMaterial3D
		if original == null or enhanced == null:
			continue
		var key: String = "%s:%d" % [str(record.get("category", "")), original.get_instance_id()]
		if first_by_original.has(key):
			repeated_original_found = true
			if first_by_original[key] != enhanced:
				sharing_preserved = false
				break
		else:
			first_by_original[key] = enhanced
	_expect(repeated_original_found, "multiple meshes share at least one original material family")
	_expect(sharing_preserved, "meshes sharing an original/category also share one enhanced material")


func _validate_ab_restore(director: MaterialFidelityDirector3D) -> void:
	var sample: Dictionary = _first_record_of_category(director, "masonry")
	_expect(not sample.is_empty(), "A/B test resolves masonry sample")
	if sample.is_empty():
		return
	var weak_value: Variant = sample.get("ref", null)
	if not weak_value is WeakRef:
		_expect(false, "A/B sample keeps weak node reference")
		return
	var target_value: Variant = (weak_value as WeakRef).get_ref()
	if not target_value is MeshInstance3D:
		_expect(false, "A/B sample resolves live mesh")
		return
	var mesh_instance: MeshInstance3D = target_value as MeshInstance3D
	var original: Material = sample.get("original") as Material
	var enhanced: Material = sample.get("enhanced") as Material
	_expect(mesh_instance.material_override == enhanced, "enabled benchmark applies enhanced material")

	director.set_enabled(false)
	_expect(mesh_instance.material_override == original, "F3/OFF restores exact original material resource")
	_expect(int(director.get_debug_data().get("restored_target_count", 0)) == director.targets.size(), "F3/OFF restores every enrolled live mesh")

	director.set_enabled(true)
	_expect(mesh_instance.material_override == enhanced, "F3/ON restores exact enhanced shared material")


func _validate_exclusions(
	target: Node,
	director: MaterialFidelityDirector3D
) -> void:
	var upper_stream: MeshInstance3D = target.get_node_or_null(
		"GreenGrottoArt/HeroPassV3/HeroWater/V3UpperStream"
	) as MeshInstance3D
	_expect(upper_stream != null, "upper stream exists for exclusion check")
	if upper_stream != null:
		_expect(not director.targets.has(upper_stream.get_instance_id()), "transparent water surfaces are excluded from material fidelity")
		var water_uses_world_triplanar: bool = false
		var water_material: StandardMaterial3D = upper_stream.material_override as StandardMaterial3D
		if water_material != null:
			water_uses_world_triplanar = water_material.uv1_world_triplanar
		_expect(not water_uses_world_triplanar, "water does not inherit rock triplanar settings")

	var surface_story: SurfaceStoryDirector3D = target.get_node_or_null("SurfaceStoryDirector") as SurfaceStoryDirector3D
	_expect(surface_story != null and surface_story.decals.size() >= 80, "surface-story decal layer survives material upgrade")


func _first_record_of_category(
	director: MaterialFidelityDirector3D,
	category: String
) -> Dictionary:
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		if str(record.get("category", "")) == category:
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
		print("MATERIAL_FIDELITY_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MATERIAL_FIDELITY_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
