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

	_expect(target is PrototypeGreenGrottoArtTarget, "scene keeps the Green Grotto base contract")
	_expect(target is PrototypeGreenGrottoDetailPass, "scene keeps the V2 detail layer")
	_expect(target is PrototypeGreenGrottoHeroPass, "scene promotes to the V3 hero layer")
	_expect(target is PrototypeGreenGrottoHeroSurfaceFinish, "scene installs the completed V3 visible-surface finish")
	_expect(str(target.get_meta("hero_pass", "")) == "green_grotto_v3", "scene identifies the V3 hero pass")
	_expect(
		str(target.get_meta("water_contract", ""))
		== "localized_surface_meshes_no_global_plane",
		"scene records the no-global-water-plane contract"
	)
	_expect(
		str(target.get_meta("hero_surface_finish", ""))
		== "v3_complete_visible_surface_replacement",
		"scene records completed visible-surface replacement"
	)
	_expect(
		str(target.get_meta("prototype_geometry_role", ""))
		== "collision_scaffold_only",
		"prototype geometry is retained as collision scaffolding only"
	)
	_expect(bool(target.get_meta("production_vfx_deferred", false)), "production VFX remain deliberately deferred")
	_expect(bool(target.get_meta("production_audio_deferred", false)), "production audio remains deliberately deferred")

	var data: Dictionary = _debug_data(target)
	_expect(bool(data.get("green_grotto_hero_pass", false)), "debug contract identifies the hero pass")
	_expect(bool(data.get("green_grotto_hero_surface_finish", false)), "debug contract identifies the visible-surface finish")
	_expect(str(data.get("hero_pass", "")) == "v3_structural_hero_rewrite", "debug data names the structural rewrite")
	_expect(
		str(data.get("expansion_strategy", ""))
		== "hero_quality_gate_before_room_expansion",
		"quality gate remains ahead of map expansion"
	)

	_validate_water_contract(target)
	_validate_prototype_retirement(target)
	_validate_hero_density(data)
	_validate_surface_finish(target, data)
	_validate_material_contract(data)
	_validate_preserved_gameplay_contract(target)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_water_contract(target: Node) -> void:
	var legacy_water: Node = target.get_node_or_null("GreenGrottoArt/Water")
	_expect(legacy_water != null, "legacy Water root remains as a stable hierarchy seam")
	if legacy_water != null:
		_expect(legacy_water.get_child_count() == 0, "legacy V1/V2 water fixture is completely retired")
		_expect(bool(legacy_water.get_meta("legacy_water_retired", false)), "legacy Water root records retirement")

	var hero_water: Node = target.get_node_or_null("GreenGrottoArt/HeroPassV3/HeroWater")
	_expect(hero_water != null, "V3 owns a dedicated HeroWater root")
	if hero_water == null:
		return

	var upper: MeshInstance3D = hero_water.get_node_or_null("V3UpperStream") as MeshInstance3D
	var lower: MeshInstance3D = hero_water.get_node_or_null("V3LowerBasin") as MeshInstance3D
	var bed: MeshInstance3D = hero_water.get_node_or_null("V3UpperStreamBed") as MeshInstance3D
	_expect(upper != null, "upper stream exists as localized water")
	_expect(lower != null, "lower basin exists as localized water")
	_expect(bed != null, "upper stream has a visible bed")
	if upper != null:
		_expect(upper.mesh is ArrayMesh, "upper stream uses an irregular polygon surface, not a box plane")
		_expect(str(upper.get_meta("water_role", "")) == "upper_stream", "upper stream publishes its water role")
	if lower != null:
		_expect(lower.mesh is ArrayMesh, "lower basin uses an irregular polygon surface, not a box plane")
		_expect(str(lower.get_meta("water_role", "")) == "lower_basin", "lower basin publishes its water role")

	var waterfall_count: int = 0
	var broad_horizontal_box_found: bool = false
	for child: Node in hero_water.get_children():
		if str(child.name).begins_with("V3WaterfallSheet"):
			waterfall_count += 1
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.mesh is BoxMesh:
				var size: Vector3 = (mesh_instance.mesh as BoxMesh).size
				if size.y <= 0.20 and size.x >= 9.0 and size.z >= 9.0:
					broad_horizontal_box_found = true
	_expect(waterfall_count == 4, "localized waterfall uses four narrow vertical sheets")
	_expect(not broad_horizontal_box_found, "HeroWater contains no giant horizontal under-level box")


func _validate_prototype_retirement(target: Node) -> void:
	for body_path: String in [
		"GreenGrottoArt/Terrain/ArrivalShelf",
		"GreenGrottoArt/Terrain/CliffLeftNear",
		"GreenGrottoArt/Terrain/CliffRightNear",
		"GreenGrottoArt/AncientRuins/CausewaySlab00",
		"GreenGrottoArt/AncientRuins/ShrineFoundation",
	]:
		var body: Node = target.get_node_or_null(body_path)
		_expect(body != null, body_path + " collision scaffold remains")
		if body == null:
			continue
		var visual: MeshInstance3D = body.get_node_or_null("Visual") as MeshInstance3D
		_expect(visual != null and not visual.visible, body_path + " broad prototype visual is hidden")
		_expect(bool(body.get_meta("prototype_visual_hidden", false)), body_path + " records visual retirement")


func _validate_hero_density(data: Dictionary) -> void:
	var counts: Dictionary = _dictionary_value(data.get("build_counts", {}))
	var hero_counts: Dictionary = _dictionary_value(data.get("hero_counts", {}))
	_expect(int(counts.get("visual_meshes", 0)) >= 700, "V3 reaches a substantially denser environment tier")
	_expect(int(counts.get("foliage_clusters", 0)) >= 55, "V3 deepens clustered prehistoric ecology")
	_expect(int(hero_counts.get("retired_water_nodes", 0)) >= 10, "V3 retires the old water fixture instead of covering it")
	_expect(int(hero_counts.get("hidden_prototype_surfaces", 0)) >= 15, "V3 hides broad prototype surfaces")
	_expect(int(hero_counts.get("localized_water_surfaces", 0)) == 3, "V3 publishes exactly three localized horizontal water/bed surfaces")
	_expect(int(hero_counts.get("rock_sculptures", 0)) >= 120, "V3 sculpts the chasm, banks and arrival edge with dense rock masses")
	_expect(int(hero_counts.get("causeway_face_blocks", 0)) >= 45, "causeway gains authored masonry faces")
	_expect(int(hero_counts.get("causeway_supports", 0)) >= 6, "causeway gains visible ruined supports")
	_expect(int(hero_counts.get("shrine_masonry_blocks", 0)) >= 80, "shrine foundation is rebuilt from individual masonry")
	_expect(int(hero_counts.get("shrine_brackets", 0)) >= 50, "shrine gains a strong bracket/eave construction rhythm")
	_expect(int(hero_counts.get("railings", 0)) >= 20, "human-scale broken railings define ruin edges")
	_expect(int(hero_counts.get("hero_foliage_masses", 0)) >= 24, "foliage is grouped into hero ecology masses")
	_expect(int(hero_counts.get("hero_roots", 0)) >= 5, "large roots physically frame and invade the ruins")


func _validate_surface_finish(target: Node, data: Dictionary) -> void:
	var counts: Dictionary = _dictionary_value(data.get("hero_surface_counts", {}))
	_expect(int(counts.get("terrace_tiles", 0)) >= 35, "side terraces receive individually fitted hero tiles")
	_expect(int(counts.get("terrace_edge_blocks", 0)) >= 180, "terrace edges receive full masonry skirts")
	_expect(int(counts.get("shrine_deck_tiles", 0)) >= 25, "shrine deck replaces the hidden broad foundation top")
	_expect(int(counts.get("arrival_edge_rocks", 0)) == 16, "arrival shelf receives a sculpted rock perimeter")
	var hero_architecture: Node = target.get_node_or_null("GreenGrottoArt/HeroPassV3/HeroArchitecture")
	_expect(hero_architecture != null, "HeroArchitecture root exists")
	if hero_architecture != null:
		_expect(hero_architecture.get_node_or_null("LeftHeroTerraceTile00") != null, "left terrace has a visible hero deck")
		_expect(hero_architecture.get_node_or_null("RightHeroTerraceTile01") != null, "right terrace has a visible hero deck")
		_expect(hero_architecture.get_node_or_null("HeroShrineDeck01") != null, "shrine foundation has a visible hero deck")


func _validate_material_contract(data: Dictionary) -> void:
	var hero_materials: Dictionary = _dictionary_value(data.get("hero_materials", {}))
	_expect(bool(hero_materials.get("green_grotto_hero_materials", false)), "V3 hero material vocabulary is active")
	var ids_value: Variant = hero_materials.get("hero_material_ids", [])
	if not ids_value is Array:
		_expect(false, "hero material vocabulary publishes its IDs")
		return
	var ids: Array = ids_value as Array
	for material_id: String in [
		"hero_paving",
		"hero_paving_wet",
		"hero_rock",
		"hero_masonry",
		"hero_roof",
		"hero_water_shallow",
		"hero_water_deep",
	]:
		_expect(ids.has(material_id), "hero palette publishes " + material_id)


func _validate_preserved_gameplay_contract(target: Node) -> void:
	_expect(target.get_node_or_null("Player") != null, "Grace remains in the production player scene")
	_expect(target.get_node_or_null("FocusTime") != null, "Focus system remains available")
	_expect(target.get_node_or_null("LabResourceRegenerator") != null, "art target still supports repeated spell testing")
	var fauna_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("green_grotto_fauna"):
		if target.is_ancestor_of(node):
			fauna_count += 1
	_expect(fauna_count == 4, "environmental prehistoric fauna survive the hero rewrite")


func _debug_data(target: Node) -> Dictionary:
	if target == null or not target.has_method("get_debug_data"):
		return {}
	var value: Variant = target.call("get_debug_data")
	return _dictionary_value(value)


func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


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
