extends Node

const TargetScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var target: Node = TargetScene.instantiate()
	add_child(target)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(target is PrototypeGreenGrottoArtTarget, "scene keeps the Green Grotto art-target base contract")
	_expect(target is PrototypeGreenGrottoDetailPass, "scene installs the Green Grotto detail pass")
	_expect(target.is_in_group("environment_art_target"), "scene identifies as an environment art target")
	_expect(str(target.get_meta("art_target", "")) == "green_earth_chinese_grotto", "scene keeps Green Earth art direction identity")
	_expect(str(target.get_meta("detail_pass", "")) == "green_grotto_v2", "scene identifies the v2 detail pass")
	_expect(str(target.get_meta("water_geography", "")) == "upper_stream_to_waterfall_to_lower_basin", "scene records coherent water geography")
	_expect(bool(target.get_meta("production_vfx_deferred", false)), "production VFX are deliberately deferred")
	_expect(bool(target.get_meta("production_audio_deferred", false)), "production audio is deliberately deferred")

	var data: Dictionary = {}
	if target.has_method("get_debug_data"):
		var value: Variant = target.call("get_debug_data")
		if value is Dictionary:
			data = value as Dictionary
	_expect(bool(data.get("green_grotto_art_target", false)), "debug contract identifies Green Grotto")
	_expect(bool(data.get("green_grotto_detail_pass", false)), "debug contract identifies the fine-detail pass")
	_expect(str(data.get("landmark", "")) == "sunset shrine", "sunset shrine remains the hero landmark")
	_expect(str(data.get("route", "")) == "fractured causeway", "fractured causeway remains the hero route")
	_expect(str(data.get("expansion_strategy", "")) == "quality_benchmark_before_larger_set", "detail quality remains the current expansion strategy")

	var counts: Dictionary = {}
	var counts_value: Variant = data.get("build_counts", {})
	if counts_value is Dictionary:
		counts = counts_value as Dictionary
	_expect(int(counts.get("static_surfaces", 0)) >= 25, "art target builds substantial walkable/collidable geometry")
	_expect(int(counts.get("visual_meshes", 0)) >= 300, "detail pass substantially increases layered visual density")
	_expect(int(counts.get("ruin_modules", 0)) >= 40, "ancient ruin composition has enough authored breakup")
	_expect(int(counts.get("foliage_clusters", 0)) >= 35, "ecology pass adds clustered prehistoric foliage")
	_expect(int(counts.get("trees", 0)) >= 5, "dense canopy uses multiple hero trees")
	_expect(int(counts.get("roots", 0)) >= 6, "tree roots visibly invade the ruin structure")
	_expect(int(counts.get("waterfalls", 0)) == 3, "waterfall keeps three layered ribbons")
	_expect(int(counts.get("fauna", 0)) == 4, "art target includes three raptors and a distant sauropod")

	var detail_counts: Dictionary = {}
	var detail_value: Variant = data.get("detail_counts", {})
	if detail_value is Dictionary:
		detail_counts = detail_value as Dictionary
	_expect(int(detail_counts.get("paving_stones", 0)) >= 80, "walkable surfaces use individual paving stones instead of broad flat texture")
	_expect(int(detail_counts.get("water_banks", 0)) >= 40, "water surfaces are enclosed by authored rock banks")
	_expect(int(detail_counts.get("ecology_pockets", 0)) >= 7, "vegetation collects in authored ecology pockets")
	_expect(int(detail_counts.get("shrine_details", 0)) >= 50, "shrine receives roof ribs and eave bracket microdetail")
	_expect(int(detail_counts.get("rubble_details", 0)) >= 24, "broken causeway edges receive loose rubble detail")

	var art_root: Node = target.get_node_or_null("GreenGrottoArt")
	_expect(art_root != null, "GreenGrottoArt root exists")
	if art_root != null:
		_expect(art_root.get_node_or_null("AncientRuins/ShrineFoundation") != null, "sunset shrine foundation exists")
		_expect(art_root.get_node_or_null("AncientRuins/CausewaySlab00") != null, "fractured causeway begins at arrival")
		_expect(art_root.get_node_or_null("Lighting/GreenGrottoEnvironment") != null, "grotto environment/atmosphere exists")
		_expect(art_root.get_node_or_null("Lighting/CanopySunset") != null, "warm canopy sunset key light exists")
		_expect(art_root.get_node_or_null("Water/GrottoPool") != null, "lower basin water exists")
		_expect(art_root.get_node_or_null("Water/UpperStream") != null, "waterfall has a visible upper source stream")
		_expect(art_root.get_node_or_null("Water/UpperStreamBed") != null, "upper stream has a readable dark bed")
		_expect(art_root.get_node_or_null("Water/UpperBankRock00") != null, "upper stream has authored rock banks")
		_expect(art_root.get_node_or_null("Water/LowerBasinRock00") != null, "lower basin has authored rock banks")
		_expect(art_root.get_node_or_null("Fauna/DistantSauropod") != null, "distant prehistoric scale landmark exists")

		var pool: MeshInstance3D = art_root.get_node_or_null("Water/GrottoPool") as MeshInstance3D
		if pool != null and pool.mesh is BoxMesh:
			var pool_size: Vector3 = (pool.mesh as BoxMesh).size
			_expect(pool_size.x <= 10.0 and pool_size.z <= 12.0, "lower pool no longer spans beneath most of the dungeon")
			_expect(pool.position.y > -6.0, "lower pool surface is raised into a readable basin")
		else:
			_expect(false, "lower pool exposes its authored BoxMesh contract")

	var material_data: Dictionary = {}
	var material_value: Variant = data.get("materials", {})
	if material_value is Dictionary:
		material_data = material_value as Dictionary
	_expect(bool(material_data.get("green_grotto_material_library", false)), "base procedural material library is active")
	_expect(int(material_data.get("cached_materials", 0)) >= 10, "art target resolves a broad base material palette")
	_expect(int(material_data.get("procedural_textures", 0)) >= 10, "base surface variation uses procedural textures")
	_expect(not bool(material_data.get("uses_external_textures", true)), "art target still requires no imported texture assets")

	var detail_material_data: Dictionary = {}
	var detail_material_value: Variant = data.get("detail_materials", {})
	if detail_material_value is Dictionary:
		detail_material_data = detail_material_value as Dictionary
	_expect(bool(detail_material_data.get("green_grotto_detail_materials", false)), "detail material vocabulary is active")
	var detail_ids_value: Variant = detail_material_data.get("detail_material_ids", [])
	if detail_ids_value is Array:
		var detail_ids: Array = detail_ids_value as Array
		for material_id: String in ["paving", "paving_wet", "water_shallow", "water_deep", "river_rock"]:
			_expect(detail_ids.has(material_id), "detail palette publishes " + material_id)
	else:
		_expect(false, "detail material vocabulary publishes its IDs")

	var fauna_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("green_grotto_fauna"):
		if target.is_ancestor_of(node):
			fauna_count += 1
	_expect(fauna_count == 4, "all four environmental fauna actors initialize")

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GREEN_GROTTO_ART_TARGET_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GREEN_GROTTO_ART_TARGET_SMOKE_TEST: " + failure)
	get_tree().quit(1)
