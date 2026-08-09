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

	_expect(target is PrototypeGreenGrottoSurfaceStoryPass, "Green installs the Surface Story pass")
	_expect(
		str(target.get_meta("surface_story_authority", ""))
		== "SurfaceStoryDirector",
		"Green declares SurfaceStoryDirector authority"
	)

	var director: SurfaceStoryDirector3D = target.get_node_or_null(
		"SurfaceStoryDirector"
	) as SurfaceStoryDirector3D
	_expect(director != null, "SurfaceStoryDirector node exists")
	if director != null:
		_validate_director(director)
		_validate_distribution(target, director)
		_validate_native_decals(director)
		_validate_texture_vocabulary(director)
		_validate_ab_toggle(director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_director(director: SurfaceStoryDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("surface_story_director", false)), "Director publishes surface-story contract")
	_expect(bool(data.get("initialized", false)), "Director initializes procedural texture factory")
	_expect(str(data.get("profile_id", "")) == "green_grotto_surface_story", "Director owns Green surface profile")
	_expect(bool(data.get("enabled", false)), "surface story starts enabled")
	_expect(bool(data.get("debug_hotkeys", false)), "Green benchmark enables F4 surface comparison")
	_expect(bool(data.get("native_decals", false)), "surface detail uses Godot native Decal nodes")
	_expect(bool(data.get("geometry_unchanged", false)), "surface pass leaves collision and mesh topology unchanged")
	_expect(int(data.get("stamp_count", 0)) == 80, "Green authors exactly eighty concentrated surface stamps")


func _validate_distribution(
	target: Node,
	director: SurfaceStoryDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	var kinds: Dictionary = _dictionary_value(data.get("counts_by_kind", {}))
	_expect(int(kinds.get("wear", 0)) == 24, "traffic wear is concentrated along walkable routes")
	_expect(int(kinds.get("crack", 0)) == 7, "each fractured causeway slab receives one structural crack story")
	_expect(int(kinds.get("wet", 0)) == 16, "water geography owns the wetness/runoff story")
	_expect(int(kinds.get("moss", 0)) == 13, "moss collects at joints, shade, and ruin margins")
	_expect(int(kinds.get("grime", 0)) == 12, "age grime remains secondary to structural/material cues")
	_expect(int(kinds.get("carving", 0)) == 8, "protected ruin faces retain a limited human-history motif layer")

	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("green_grotto_surface_story", false)), "Green pass reports surface storytelling")
	_expect(
		str(pass_data.get("story_logic", ""))
		== "traffic + stress + water + shade + age + human history",
		"Green records its causal surface-story grammar"
	)
	var areas: Dictionary = _dictionary_value(pass_data.get("surface_story_counts", {}))
	_expect(int(areas.get("arrival", 0)) == 9, "arrival remains lightly dressed")
	_expect(int(areas.get("causeway", 0)) == 17, "causeway concentrates stress and traffic detail")
	_expect(int(areas.get("waterfall", 0)) == 16, "waterfall dressing matches hydrology")
	_expect(int(areas.get("shrine", 0)) == 30, "shrine carries the richest authored history")
	_expect(int(areas.get("ruins", 0)) == 8, "secondary ruins stay subordinate to hero landmark")


func _validate_native_decals(director: SurfaceStoryDirector3D) -> void:
	var shallow_projection_count: int = 0
	var distance_faded_count: int = 0
	var wall_or_floor_count: int = 0
	for decal: Decal in director.decals:
		if decal == null or not is_instance_valid(decal):
			continue
		_expect(decal.texture_albedo != null, decal.name + " has albedo mask")
		_expect(decal.texture_orm != null, decal.name + " has ORM detail")
		if decal.size.y <= 0.30:
			shallow_projection_count += 1
		if decal.distance_fade_enabled:
			distance_faded_count += 1
		if decal.normal_fade >= 0.70:
			wall_or_floor_count += 1
	_expect(shallow_projection_count == director.decals.size(), "every stamp uses a shallow projection volume")
	_expect(distance_faded_count == director.decals.size(), "every stamp fades with camera distance")
	_expect(wall_or_floor_count == director.decals.size(), "every stamp rejects strongly misaligned receiving surfaces")


func _validate_texture_vocabulary(director: SurfaceStoryDirector3D) -> void:
	_expect(director.texture_factory != null, "texture factory exists")
	if director.texture_factory == null:
		return
	var factory_data: Dictionary = director.texture_factory.get_debug_data()
	_expect(int(factory_data.get("resolution", 0)) == 128, "Green uses bounded 128px procedural decal masks")
	_expect(int(factory_data.get("cached_sets", 0)) == 6, "all six surface languages share cached texture sets")
	for kind: String in ["crack", "moss", "wet", "grime", "wear", "carving"]:
		var texture_set: Dictionary = director.texture_factory.get_texture_set(kind)
		var albedo: Texture2D = texture_set.get("albedo") as Texture2D
		var orm: Texture2D = texture_set.get("orm") as Texture2D
		_expect(albedo != null, kind + " generates albedo texture")
		_expect(orm != null, kind + " generates ORM texture")
		if albedo != null:
			var image: Image = albedo.get_image()
			_expect(image != null and not image.is_empty(), kind + " albedo has image data")
			_expect(image != null and not image.is_invisible(), kind + " albedo mask contains visible pixels")


func _validate_ab_toggle(director: SurfaceStoryDirector3D) -> void:
	_expect(not director.decals.is_empty(), "toggle test has stamps")
	if director.decals.is_empty():
		return
	director.set_enabled(false)
	var hidden_count: int = 0
	for decal: Decal in director.decals:
		if decal != null and is_instance_valid(decal) and not decal.visible:
			hidden_count += 1
	_expect(hidden_count == director.decals.size(), "F4/OFF hides every surface-story stamp")
	director.set_enabled(true)
	var visible_count: int = 0
	for decal: Decal in director.decals:
		if decal != null and is_instance_valid(decal) and decal.visible:
			visible_count += 1
	_expect(visible_count == director.decals.size(), "F4/ON restores every surface-story stamp")


func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SURFACE_STORY_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SURFACE_STORY_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
