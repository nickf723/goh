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

	_expect(target is PrototypeGreenGrottoShadowPass, "Green Grotto installs Shadow Fidelity integration")
	_expect(str(target.get_meta("shadow_fidelity_authority", "")) == "ShadowFidelityDirector", "Green Grotto declares ShadowFidelityDirector authority")

	var lighting: LightingDirector3D = target.get_node_or_null("LightingDirector") as LightingDirector3D
	var shadows: ShadowFidelityDirector3D = target.get_node_or_null("ShadowFidelityDirector") as ShadowFidelityDirector3D
	_expect(lighting != null, "LightingDirector remains installed")
	_expect(shadows != null, "ShadowFidelityDirector node exists")
	if lighting != null and shadows != null:
		shadows.synchronize_now()
		_validate_contract(shadows)
		_validate_cinematic(shadows)
		_validate_performance(lighting, shadows)
		_validate_balanced(lighting, shadows)
		_validate_cinematic_restore(lighting, shadows)
		_validate_layer_independence(target, shadows)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(shadows: ShadowFidelityDirector3D) -> void:
	var data: Dictionary = shadows.get_debug_data()
	_expect(bool(data.get("shadow_fidelity_director", false)), "Director publishes shadow contract")
	_expect(bool(data.get("initialized", false)), "Director initializes against LightingDirector")
	_expect(str(data.get("profile_id", "")) == "green_grotto_shadows", "Director owns Green shadow profile")
	_expect(bool(data.get("enabled", false)), "Director starts enabled")
	_expect(bool(data.get("follows_lighting_quality", false)), "Shadow quality follows the existing F7 lighting tier")
	_expect(bool(data.get("geometry_unchanged", false)), "Shadow Fidelity leaves geometry unchanged")
	_expect(str(data.get("sun", "")) == "CanopySunset", "Director resolves authored sunset sun")
	_expect(int(data.get("accent_lights", 0)) == 2, "Director still resolves Green local accent lights")
	_expect(int(data.get("managed_foliage", 0)) >= 350, "Director resolves dense foliage shadow targets")


func _validate_cinematic(shadows: ShadowFidelityDirector3D) -> void:
	var data: Dictionary = shadows.get_debug_data()
	_expect(str(data.get("tier", "")) == "Cinematic", "Green starts with Cinematic shadow tier")
	_expect(int(data.get("directional_atlas_size", 0)) == 4096, "Cinematic uses a production-sized directional atlas")
	_expect(int(data.get("positional_atlas_size", 0)) == 2048, "Cinematic keeps local atlas bounded")
	_expect(int(data.get("filter_quality", -1)) == 3, "Cinematic uses useful soft-shadow filtering without maxing the renderer")
	_expect(int(data.get("sun_shadow_mode", -1)) == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "compact Green keeps Cinematic sunlight to two shadow cascades")
	_expect(absf(float(data.get("sun_shadow_distance", 0.0)) - 76.0) < 0.1, "Cinematic shadow range is intentionally bounded")
	_expect(float(data.get("sun_bias", 1.0)) < 0.06, "Cinematic keeps tight enough bias for grounding")
	_expect(float(data.get("sun_normal_bias", 9.0)) < 0.9, "Cinematic keeps controlled normal bias")
	_expect(float(data.get("sun_angular_distance", 0.0)) >= 0.27, "Cinematic keeps restrained sun softness")
	_expect(int(data.get("accent_shadow_lights", 99)) == 0, "Cinematic no longer duplicates local accent shadow maps")
	_expect(int(data.get("double_sided_foliage_shadows", 99)) == 0, "Cinematic no longer doubles the entire foliage shadow workload")


func _validate_performance(
	lighting: LightingDirector3D,
	shadows: ShadowFidelityDirector3D
) -> void:
	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	shadows.synchronize_now()
	var data: Dictionary = shadows.get_debug_data()
	_expect(str(data.get("tier", "")) == "Performance", "Performance lighting selects Performance shadow tier")
	_expect(int(data.get("directional_atlas_size", 0)) == 2048, "Performance tier cuts directional atlas")
	_expect(int(data.get("positional_atlas_size", 0)) == 1024, "Performance tier cuts positional atlas")
	_expect(int(data.get("filter_quality", -1)) == 1, "Performance tier uses cheap shadow filter")
	_expect(int(data.get("sun_shadow_mode", -1)) == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Performance tier uses two sun splits")
	_expect(absf(float(data.get("sun_shadow_distance", 0.0)) - 42.0) < 0.1, "Performance tier shortens shadow range")
	_expect(absf(float(data.get("sun_angular_distance", 99.0))) < 0.001, "Performance tier disables contact-hardening sun cost")
	_expect(int(data.get("accent_shadow_lights", 99)) == 0, "Performance tier disables local accent shadow maps")
	_expect(int(data.get("double_sided_foliage_shadows", 99)) == 0, "Performance tier uses single-sided foliage shadows")


func _validate_balanced(
	lighting: LightingDirector3D,
	shadows: ShadowFidelityDirector3D
) -> void:
	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	shadows.synchronize_now()
	var data: Dictionary = shadows.get_debug_data()
	_expect(str(data.get("tier", "")) == "Balanced", "Balanced lighting selects Balanced shadow tier")
	_expect(int(data.get("directional_atlas_size", 0)) == 4096, "Balanced tier uses standard directional atlas")
	_expect(int(data.get("positional_atlas_size", 0)) == 1536, "Balanced keeps positional atlas modest")
	_expect(int(data.get("filter_quality", -1)) == 2, "Balanced uses medium shadow filtering")
	_expect(int(data.get("sun_shadow_mode", -1)) == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "compact Green keeps Balanced sunlight to two shadow cascades")
	_expect(absf(float(data.get("sun_shadow_distance", 0.0)) - 66.0) < 0.1, "Balanced uses middle shadow distance")
	_expect(float(data.get("sun_angular_distance", 0.0)) >= 0.19, "Balanced keeps restrained sun softness")
	_expect(int(data.get("accent_shadow_lights", 99)) == 0, "Balanced avoids local accent shadows")
	_expect(int(data.get("double_sided_foliage_shadows", 99)) == 0, "Balanced keeps foliage shadows single-sided")


func _validate_cinematic_restore(
	lighting: LightingDirector3D,
	shadows: ShadowFidelityDirector3D
) -> void:
	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	shadows.synchronize_now()
	var data: Dictionary = shadows.get_debug_data()
	_expect(str(data.get("tier", "")) == "Cinematic", "F7 cycle restores Cinematic shadow tier")
	_expect(int(data.get("directional_atlas_size", 0)) == 4096, "Cinematic production atlas returns after tier cycle")
	_expect(int(data.get("sun_shadow_mode", -1)) == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Cinematic two-cascade policy returns after tier cycle")
	_expect(int(data.get("accent_shadow_lights", 99)) == 0, "Cinematic keeps local accent shadows retired after tier cycle")
	_expect(int(data.get("double_sided_foliage_shadows", 99)) == 0, "Cinematic keeps the detoxed foliage policy after tier cycle")


func _validate_layer_independence(
	target: Node,
	shadows: ShadowFidelityDirector3D
) -> void:
	var vegetation: VegetationPresentationDirector3D = target.get_node_or_null("VegetationPresentationDirector") as VegetationPresentationDirector3D
	var water: WaterPresentationDirector3D = target.get_node_or_null("WaterPresentationDirector") as WaterPresentationDirector3D
	var material_fidelity: MaterialFidelityDirector3D = target.get_node_or_null("MaterialFidelityDirector") as MaterialFidelityDirector3D
	_expect(vegetation != null and vegetation.enabled, "Vegetation Presentation remains active beside Shadow Fidelity")
	_expect(water != null and water.enabled, "Water Presentation remains active beside Shadow Fidelity")
	_expect(material_fidelity != null and material_fidelity.enabled, "Material Fidelity remains active beside Shadow Fidelity")

	if vegetation == null or vegetation.targets.is_empty():
		return
	var first_id: int = int(vegetation.targets.keys()[0])
	var record: Dictionary = vegetation.targets[first_id] as Dictionary
	var weak_value: Variant = record.get("ref", null)
	if not weak_value is WeakRef:
		return
	var target_value: Variant = (weak_value as WeakRef).get_ref()
	if not target_value is MeshInstance3D:
		return
	var mesh_instance: MeshInstance3D = target_value as MeshInstance3D
	var mesh_before: Mesh = mesh_instance.mesh
	var material_before: Material = mesh_instance.material_override
	shadows.synchronize_now()
	_expect(mesh_instance.mesh == mesh_before, "Shadow Fidelity never rebuilds foliage meshes")
	_expect(mesh_instance.material_override == material_before, "Shadow Fidelity never steals foliage material authority")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SHADOW_FIDELITY_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SHADOW_FIDELITY_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
