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
	for _index: int in range(6):
		await get_tree().process_frame

	_expect(target is PrototypeGreenGrottoCalibrationKitPass, "Green visual lab promotes to the calibration-kit pass")
	_expect(str(target.get_meta("environment_kit", "")) == "green_earth_calibration_v0_1", "Green visual lab publishes the calibration kit id")
	_expect(int(target.get_meta("environment_kit_module_count", 0)) == 13, "Green kit defines thirteen replacement-ready module types")
	_expect(int(target.get_meta("calibration_instances", 0)) == 35, "Green blockout assembles thirty-five module instances")
	_expect(
		str(target.get_meta("art_authoring_contract", ""))
		== "external authored meshes replace module visuals; Godot owns placement and systems",
		"Green blockout records the external-authoring boundary"
	)

	var kit_root: Node = target.get_node_or_null(
		"GreenGrottoArt/GreenEarthCalibrationKitV01"
	)
	_expect(kit_root != null, "Green calibration kit root exists")
	var old_study: Node3D = target.get_node_or_null(
		"GreenGrottoArt/ArtDirectionStudyV1"
	) as Node3D
	_expect(old_study != null and not old_study.visible, "previous primitive art-direction study is retained but hidden")

	var module_count: int = 0
	var placeholder_count: int = 0
	var module_ids: Dictionary = {}
	for candidate: Node in get_tree().get_nodes_in_group("environment_kit_module"):
		if not target.is_ancestor_of(candidate):
			continue
		module_count += 1
		if bool(candidate.get_meta("placeholder", false)):
			placeholder_count += 1
		var module_id: String = str(candidate.get_meta("module_id", ""))
		module_ids[module_id] = int(module_ids.get(module_id, 0)) + 1
		_expect(candidate.get_node_or_null("Visual") != null, module_id + " owns a stable Visual replacement seam")
		var collision_policy: String = str(candidate.get_meta("collision_policy", ""))
		_expect(collision_policy in ["external_blockout", "none"], module_id + " does not replace stable gameplay collision during calibration")

	_expect(module_count == 35, "scene tree contains the expected thirty-five kit modules")
	_expect(placeholder_count == module_count, "all v0.1 calibration modules remain explicit placeholders")
	_expect(module_ids.size() == 13, "all thirteen Green module types are exercised in the calibration composition")
	for required_id: String in [
		"green_cliff_a",
		"green_cliff_b",
		"green_path_slab_a",
		"green_path_slab_b",
		"green_shrine_platform",
		"green_shrine_stair",
		"green_shrine_column",
		"green_shrine_beam",
		"green_shrine_roof",
		"green_shrine_bracket",
		"green_shrine_wall",
		"green_lantern",
		"green_fern_cluster",
	]:
		_expect(module_ids.has(required_id), "calibration composition uses " + required_id)

	_expect(target.get_node_or_null("GreenGrottoArt/Terrain/ArrivalShelf/CollisionShape3D") != null, "original arrival collision scaffold remains")
	_expect(target.get_node_or_null("GreenGrottoArt/AncientRuins/CausewaySlab00/CollisionShape3D") != null, "original causeway collision scaffold remains")
	_expect(target.get_node_or_null("Player") != null, "Grace remains in the calibration scene")

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GREEN_EARTH_CALIBRATION_KIT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GREEN_EARTH_CALIBRATION_KIT_SMOKE_TEST: " + failure)
	get_tree().quit(1)
