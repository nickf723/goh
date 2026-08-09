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
	for _index: int in range(8):
		await get_tree().process_frame

	var director: FaunaMaterialPresentationDirector3D = target.get_node_or_null(
		"FaunaMaterialPresentationDirector"
	) as FaunaMaterialPresentationDirector3D
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	_expect(director != null, "Green installs FaunaMaterialPresentationDirector")
	_expect(lighting != null, "fauna material test resolves LightingDirector")
	if director != null and lighting != null:
		director.synchronize_now()
		_validate_contract(target, director)
		await _validate_quality_ladder(director, lighting)
		_validate_behavior_independence(target, director)
		_validate_geometry_integrity(director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(
	target: Node,
	director: FaunaMaterialPresentationDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("fauna_material_presentation_director", false)), "fauna material director publishes debug contract")
	_expect(bool(data.get("initialized", false)), "fauna material director discovers runtime-built fauna")
	_expect(str(data.get("profile_id", "")) == "green_grotto_fauna_materials", "Green uses dedicated fauna material profile")
	_expect(int(data.get("registered_fauna", 0)) == 4, "all four Green fauna actors register")
	_expect(int(data.get("target_count", 0)) == 103, "all 103 authored fauna presentation meshes register")
	var roles: Dictionary = _dictionary_value(data.get("role_counts", {}))
	_expect(int(roles.get("hide", 0)) == 41, "41 hide meshes register")
	_expect(int(roles.get("feather", 0)) == 51, "51 raptor feather/accent meshes register")
	_expect(int(roles.get("eye", 0)) == 6, "six raptor eyes register")
	_expect(int(roles.get("accent_hide", 0)) == 5, "five sauropod accent-hide meshes register")
	_expect(bool(data.get("object_uv_detail", false)), "moving fauna retain object-UV detail instead of world-space texture swimming")
	_expect(bool(data.get("follows_lighting_quality", false)), "fauna materials follow F7")
	_expect(not bool(data.get("behavior_authority", true)), "fauna material director owns no behavior")
	_expect(bool(data.get("geometry_unchanged", false)), "fauna material presentation leaves meshes unchanged")
	_expect(not bool(data.get("gameplay_authority", true)), "fauna materials own no gameplay state")

	var fauna_root: Node = target.get_node_or_null("GreenGrottoArt/Fauna")
	_expect(fauna_root != null, "fauna material test resolves Green fauna hierarchy")


func _validate_quality_ladder(
	director: FaunaMaterialPresentationDirector3D,
	lighting: LightingDirector3D
) -> void:
	var hide_record: Dictionary = _first_record_of_role(director, "hide")
	var feather_record: Dictionary = _first_record_of_role(director, "feather")
	var eye_record: Dictionary = _first_record_of_role(director, "eye")
	var accent_record: Dictionary = _first_record_of_role(director, "accent_hide")
	_expect(not hide_record.is_empty(), "quality test resolves hide sample")
	_expect(not feather_record.is_empty(), "quality test resolves feather sample")
	_expect(not eye_record.is_empty(), "quality test resolves eye sample")
	_expect(not accent_record.is_empty(), "quality test resolves sauropod accent sample")
	if (
		hide_record.is_empty()
		or feather_record.is_empty()
		or eye_record.is_empty()
		or accent_record.is_empty()
	):
		return

	var hide_mesh: MeshInstance3D = _mesh_from_record(hide_record)
	var feather_mesh: MeshInstance3D = _mesh_from_record(feather_record)
	var eye_mesh: MeshInstance3D = _mesh_from_record(eye_record)
	var accent_mesh: MeshInstance3D = _mesh_from_record(accent_record)
	if hide_mesh == null or feather_mesh == null or eye_mesh == null or accent_mesh == null:
		_expect(false, "quality test resolves live fauna mesh samples")
		return

	var original_hide: StandardMaterial3D = hide_record.get("original") as StandardMaterial3D
	var original_feather: StandardMaterial3D = feather_record.get("original") as StandardMaterial3D
	var original_eye: StandardMaterial3D = eye_record.get("original") as StandardMaterial3D
	var original_accent: StandardMaterial3D = accent_record.get("original") as StandardMaterial3D

	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	director.synchronize_now()
	_expect(hide_mesh.material_override == original_hide, "Performance restores exact hide material")
	_expect(feather_mesh.material_override == original_feather, "Performance restores exact feather material")
	_expect(eye_mesh.material_override == original_eye, "Performance restores exact eye material")
	_expect(accent_mesh.material_override == original_accent, "Performance restores exact sauropod accent material")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	director.synchronize_now()
	var balanced_hide: StandardMaterial3D = hide_mesh.material_override as StandardMaterial3D
	var balanced_feather: StandardMaterial3D = feather_mesh.material_override as StandardMaterial3D
	var balanced_eye: StandardMaterial3D = eye_mesh.material_override as StandardMaterial3D
	_expect(balanced_hide != null and balanced_hide != original_hide, "Balanced applies enhanced hide variant")
	_expect(balanced_feather != null and balanced_feather != original_feather, "Balanced applies enhanced feather variant")
	_expect(balanced_eye != null and balanced_eye != original_eye, "Balanced applies enhanced eye variant")
	if balanced_hide != null:
		_expect(balanced_hide.normal_enabled and balanced_hide.normal_texture is NoiseTexture2D, "Balanced hide receives shared procedural normal breakup")
		_expect(not balanced_hide.uv1_world_triplanar, "moving hide avoids world-space triplanar swimming")
		_expect(balanced_hide.roughness < original_hide.roughness, "Balanced hide breaks perfectly matte prototype response")
	if balanced_feather != null:
		_expect(balanced_feather.backlight_enabled, "Balanced raptor feathers receive backlight response")
		_expect(balanced_feather.normal_enabled, "Balanced raptor feathers receive microstructure")
	if balanced_eye != null:
		_expect(not balanced_eye.normal_enabled, "eyes avoid noisy procedural normal detail")
		_expect(absf(balanced_eye.roughness - director.profile.balanced_eye_roughness) < 0.001, "Balanced eyes use authored highlight roughness")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	director.synchronize_now()
	var cinematic_hide: StandardMaterial3D = hide_mesh.material_override as StandardMaterial3D
	var cinematic_feather: StandardMaterial3D = feather_mesh.material_override as StandardMaterial3D
	var cinematic_eye: StandardMaterial3D = eye_mesh.material_override as StandardMaterial3D
	var cinematic_accent: StandardMaterial3D = accent_mesh.material_override as StandardMaterial3D
	if cinematic_hide != null and balanced_hide != null:
		_expect(cinematic_hide.normal_scale > balanced_hide.normal_scale, "Cinematic strengthens hide micro-normal response")
		_expect(cinematic_hide.roughness < balanced_hide.roughness, "Cinematic hide sharpens light response")
		_expect(cinematic_hide.backlight_enabled, "Cinematic hide adds restrained backlight")
	if cinematic_feather != null and balanced_feather != null:
		_expect(cinematic_feather.backlight_enabled, "Cinematic retains raptor feather backlight")
		_expect(cinematic_feather.backlight.get_luminance() > balanced_feather.backlight.get_luminance(), "Cinematic strengthens feather transmission cue")
	if cinematic_eye != null:
		_expect(cinematic_eye.roughness < director.profile.balanced_eye_roughness, "Cinematic eyes sharpen highlights further")
		_expect(cinematic_eye.metallic >= director.profile.cinematic_eye_metallic, "Cinematic eyes gain restrained glossy depth")
	if cinematic_accent != null:
		_expect(cinematic_accent.backlight_enabled, "Cinematic sauropod accent hide gets skin-like backlight rather than feather behavior")

	var data: Dictionary = director.get_debug_data()
	_expect(int(data.get("shared_variants", 99)) <= director.profile.maximum_shared_variants, "fauna variants remain inside bounded shared-resource budget")
	_expect(int(data.get("normal_textures", 99)) == 3, "hide, feather, and accent roles share exactly three normal textures")


func _validate_behavior_independence(
	target: Node,
	director: FaunaMaterialPresentationDirector3D
) -> void:
	var fauna_root: Node = target.get_node_or_null("GreenGrottoArt/Fauna")
	if fauna_root == null:
		return
	var behavior_count: int = 0
	for creature_node: Node in fauna_root.get_children():
		if not creature_node is GreenGrottoFaunaVisual:
			continue
		var behavior: Node = creature_node.get_node_or_null("AmbientBehavior")
		_expect(behavior != null, str(creature_node.name) + " retains ambient behavior beside material presentation")
		if behavior != null:
			behavior_count += 1
	_expect(behavior_count == 4, "all four fauna retain their presentation behavior controllers")
	_expect(not bool(director.get_debug_data().get("behavior_authority", true)), "material layer remains behavior-independent")


func _validate_geometry_integrity(
	director: FaunaMaterialPresentationDirector3D
) -> void:
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		var mesh_instance: MeshInstance3D = _mesh_from_record(record)
		if mesh_instance == null:
			continue
		_expect(mesh_instance.mesh == record.get("mesh"), str(mesh_instance.name) + " keeps exact authored mesh resource")


func _first_record_of_role(
	director: FaunaMaterialPresentationDirector3D,
	role: String
) -> Dictionary:
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		if str(record.get("role", "")) == role:
			return record
	return {}


func _mesh_from_record(record: Dictionary) -> MeshInstance3D:
	var weak_value: Variant = record.get("ref", null)
	if not weak_value is WeakRef:
		return null
	var value: Variant = (weak_value as WeakRef).get_ref()
	return value as MeshInstance3D if value is MeshInstance3D else null


func _dictionary_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("FAUNA_MATERIAL_PRESENTATION_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FAUNA_MATERIAL_PRESENTATION_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
