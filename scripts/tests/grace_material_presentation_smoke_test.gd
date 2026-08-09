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

	var director: CharacterMaterialPresentationDirector3D = target.get_node_or_null(
		"CharacterMaterialPresentationDirector"
	) as CharacterMaterialPresentationDirector3D
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	_expect(director != null, "Green installs CharacterMaterialPresentationDirector")
	_expect(lighting != null, "Grace material test resolves LightingDirector")
	if director != null and lighting != null:
		_validate_contract(target, director)
		await _validate_quality_ladder(director, lighting)
		_validate_geometry_integrity(director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(
	target: Node,
	director: CharacterMaterialPresentationDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("character_material_presentation_director", false)), "Grace material director publishes debug contract")
	_expect(bool(data.get("initialized", false)), "Grace material director initializes with profile")
	_expect(str(data.get("profile_id", "")) == "grace_material_presentation", "Green uses dedicated Grace material profile")
	_expect(int(data.get("target_count", 0)) == 27, "Grace registers exactly 27 semantic material meshes")
	_expect(bool(data.get("follows_lighting_quality", false)), "Grace materials follow F7 quality")
	_expect(bool(data.get("performance_restores_originals", false)), "Performance guarantees exact material restoration")
	_expect(bool(data.get("geometry_unchanged", false)), "Grace material presentation leaves meshes unchanged")
	_expect(not bool(data.get("gameplay_authority", true)), "Grace material presentation owns no gameplay state")

	var roles: Dictionary = _dictionary_value(data.get("role_counts", {}))
	_expect(int(roles.get("skin", 0)) == 3, "Grace skin role contains head and two hands")
	_expect(int(roles.get("hair", 0)) == 5, "Grace hair role contains mass, locks, and brows")
	_expect(int(roles.get("eye", 0)) == 2, "Grace eyes are separated from hair despite sharing base material")
	_expect(int(roles.get("robe", 0)) == 4, "Grace robe role contains skirt, torso, and arms")
	_expect(int(roles.get("sash", 0)) == 3, "Grace sash role contains waist, tail, and ribbon")
	_expect(int(roles.get("gold", 0)) == 5, "Grace gold role contains trim and jewelry")
	_expect(int(roles.get("leather", 0)) == 4, "Grace leather role includes boots and soles")
	_expect(int(roles.get("mouth", 0)) == 1, "Grace mouth receives its own presentation role")

	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("grace_material_presentation", false)), "Green pass reports Grace material presentation")
	_expect(int(pass_data.get("grace_material_target_count", 0)) == 27, "Green pass reports all 27 Grace material targets")


func _validate_quality_ladder(
	director: CharacterMaterialPresentationDirector3D,
	lighting: LightingDirector3D
) -> void:
	var skin_record: Dictionary = _first_record_of_role(director, "skin")
	var robe_record: Dictionary = _first_record_of_role(director, "robe")
	var gold_record: Dictionary = _first_record_of_role(director, "gold")
	_expect(not skin_record.is_empty(), "quality test resolves skin record")
	_expect(not robe_record.is_empty(), "quality test resolves robe record")
	_expect(not gold_record.is_empty(), "quality test resolves gold record")
	if skin_record.is_empty() or robe_record.is_empty() or gold_record.is_empty():
		return

	var skin_mesh: MeshInstance3D = _mesh_from_record(skin_record)
	var robe_mesh: MeshInstance3D = _mesh_from_record(robe_record)
	var gold_mesh: MeshInstance3D = _mesh_from_record(gold_record)
	if skin_mesh == null or robe_mesh == null or gold_mesh == null:
		_expect(false, "quality test resolves live Grace meshes")
		return
	var original_skin: StandardMaterial3D = skin_record.get("original") as StandardMaterial3D
	var original_robe: StandardMaterial3D = robe_record.get("original") as StandardMaterial3D
	var original_gold: StandardMaterial3D = gold_record.get("original") as StandardMaterial3D

	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(skin_mesh.material_override == original_skin, "Performance restores exact original skin material")
	_expect(robe_mesh.material_override == original_robe, "Performance restores exact original robe material")
	_expect(gold_mesh.material_override == original_gold, "Performance restores exact original gold material")
	_expect(int(director.get_debug_data().get("quality", -1)) == 0, "Grace material director follows Performance tier")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	await get_tree().process_frame
	await get_tree().process_frame
	var balanced_skin: StandardMaterial3D = skin_mesh.material_override as StandardMaterial3D
	var balanced_robe: StandardMaterial3D = robe_mesh.material_override as StandardMaterial3D
	_expect(balanced_skin != null and balanced_skin != original_skin, "Balanced applies enhanced shared skin material")
	if balanced_skin != null:
		_expect(balanced_skin.normal_enabled and balanced_skin.normal_texture is NoiseTexture2D, "Balanced skin receives procedural micro-normal")
		_expect(balanced_skin.backlight_enabled, "Balanced skin receives cheap backlight response")
		_expect(not balanced_skin.subsurf_scatter_enabled, "Balanced keeps skin SSS disabled")
	if balanced_robe != null:
		_expect(balanced_robe.normal_enabled and balanced_robe.normal_texture is NoiseTexture2D, "Balanced robe receives cloth microdetail")
		_expect(balanced_robe.roughness < original_robe.roughness, "Balanced robe breaks the perfectly matte prototype response")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	await get_tree().process_frame
	await get_tree().process_frame
	var cinematic_skin: StandardMaterial3D = skin_mesh.material_override as StandardMaterial3D
	var cinematic_gold: StandardMaterial3D = gold_mesh.material_override as StandardMaterial3D
	_expect(cinematic_skin != null and cinematic_skin != balanced_skin, "Cinematic resolves a distinct shared skin variant")
	if cinematic_skin != null:
		_expect(cinematic_skin.subsurf_scatter_enabled, "Cinematic enables restrained skin SSS")
		_expect(cinematic_skin.subsurf_scatter_transmittance_enabled, "Cinematic enables skin transmittance")
		_expect(cinematic_skin.subsurf_scatter_strength > 0.05, "Cinematic skin SSS strength is visibly nonzero")
		_expect(cinematic_skin.roughness < balanced_skin.roughness, "Cinematic skin has richer highlight response than Balanced")
	if cinematic_gold != null:
		_expect(cinematic_gold.roughness < original_gold.roughness, "Cinematic gold sharpens specular response")
		_expect(cinematic_gold.metallic >= original_gold.metallic, "Cinematic gold preserves or strengthens metallic response")

	var data: Dictionary = director.get_debug_data()
	_expect(int(data.get("shared_variants", 99)) <= director.profile.maximum_shared_variants, "Grace material variants remain inside shared resource budget")
	_expect(int(data.get("normal_textures", 99)) <= 6, "Grace shares procedural detail textures by semantic material role")


func _validate_geometry_integrity(
	director: CharacterMaterialPresentationDirector3D
) -> void:
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		var mesh_instance: MeshInstance3D = _mesh_from_record(record)
		if mesh_instance == null:
			continue
		_expect(mesh_instance.mesh == record.get("mesh"), str(mesh_instance.name) + " keeps exact original mesh resource")
	_expect(bool(director.get_debug_data().get("geometry_unchanged", false)), "all Grace mesh resources remain unchanged after F7 cycling")


func _first_record_of_role(
	director: CharacterMaterialPresentationDirector3D,
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
		print("GRACE_MATERIAL_PRESENTATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_MATERIAL_PRESENTATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
