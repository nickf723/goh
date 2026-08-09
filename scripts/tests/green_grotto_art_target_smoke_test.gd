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

	_expect(target is PrototypeGreenGrottoArtTarget, "scene uses the Green Grotto art-target controller")
	_expect(target.is_in_group("environment_art_target"), "scene identifies as an environment art target")
	_expect(str(target.get_meta("art_target", "")) == "green_earth_chinese_grotto", "scene keeps Green Earth art direction identity")
	_expect(bool(target.get_meta("production_vfx_deferred", false)), "production VFX are deliberately deferred")
	_expect(bool(target.get_meta("production_audio_deferred", false)), "production audio is deliberately deferred")

	var data: Dictionary = {}
	if target.has_method("get_debug_data"):
		var value: Variant = target.call("get_debug_data")
		if value is Dictionary:
			data = value as Dictionary
	_expect(bool(data.get("green_grotto_art_target", false)), "debug contract identifies Green Grotto")
	_expect(str(data.get("landmark", "")) == "sunset shrine", "sunset shrine remains the hero landmark")
	_expect(str(data.get("route", "")) == "fractured causeway", "fractured causeway remains the hero route")

	var counts: Dictionary = {}
	var counts_value: Variant = data.get("build_counts", {})
	if counts_value is Dictionary:
		counts = counts_value as Dictionary
	_expect(int(counts.get("static_surfaces", 0)) >= 25, "art target builds substantial walkable/collidable geometry")
	_expect(int(counts.get("visual_meshes", 0)) >= 180, "art target has layered visual density beyond graybox geometry")
	_expect(int(counts.get("ruin_modules", 0)) >= 40, "ancient ruin composition has enough authored breakup")
	_expect(int(counts.get("foliage_clusters", 0)) >= 30, "prehistoric foliage density is present")
	_expect(int(counts.get("trees", 0)) >= 5, "dense canopy uses multiple hero trees")
	_expect(int(counts.get("roots", 0)) >= 6, "tree roots visibly invade the ruin structure")
	_expect(int(counts.get("waterfalls", 0)) == 3, "waterfall uses three layered ribbons")
	_expect(int(counts.get("fauna", 0)) == 4, "art target includes three raptors and a distant sauropod")

	var art_root: Node = target.get_node_or_null("GreenGrottoArt")
	_expect(art_root != null, "GreenGrottoArt root exists")
	if art_root != null:
		_expect(art_root.get_node_or_null("AncientRuins/ShrineFoundation") != null, "sunset shrine foundation exists")
		_expect(art_root.get_node_or_null("AncientRuins/CausewaySlab00") != null, "fractured causeway begins at arrival")
		_expect(art_root.get_node_or_null("Lighting/GreenGrottoEnvironment") != null, "grotto environment/atmosphere exists")
		_expect(art_root.get_node_or_null("Lighting/CanopySunset") != null, "warm canopy sunset key light exists")
		_expect(art_root.get_node_or_null("Water/GrottoPool") != null, "cool chasm water counterpoint exists")
		_expect(art_root.get_node_or_null("Fauna/DistantSauropod") != null, "distant prehistoric scale landmark exists")

	var material_data: Dictionary = {}
	var material_value: Variant = data.get("materials", {})
	if material_value is Dictionary:
		material_data = material_value as Dictionary
	_expect(bool(material_data.get("green_grotto_material_library", false)), "procedural material library is active")
	_expect(int(material_data.get("cached_materials", 0)) >= 10, "art target resolves a broad material palette")
	_expect(int(material_data.get("procedural_textures", 0)) >= 10, "surface variation uses procedural textures")
	_expect(not bool(material_data.get("uses_external_textures", true)), "first art target requires no imported texture assets")

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
