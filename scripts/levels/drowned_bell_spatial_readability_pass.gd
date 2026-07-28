extends Node
class_name DrownedBellSpatialReadabilityPass

const ReadabilityAuditor = preload("res://scripts/environment/authored_set_readability_auditor.gd")
const ReadabilityDebug = preload("res://scripts/environment/authored_set_readability_debug.gd")
const GraceSpatialProfile: Resource = preload("res://data/player/grace_spatial_profile.tres")
const READABILITY_LAYOUT_PATH := "res://data/set_layouts/drowned_chapel_readability_v1.json"

@export var show_debug_zones: bool = false

var mission: Node3D
var world: Node3D
var benchmark_root: Node3D
var readability_plan: Dictionary = {}
var audit_result: Dictionary = {}
var installed: bool = false
var install_attempts: int = 0
var retired_nodes: Array[String] = []
var moved_nodes: Array[String] = []
var visible_module_count: int = 0


func _ready() -> void:
	add_to_group("drowned_bell_spatial_readability_pass")
	call_deferred("_install")


func _install() -> void:
	if installed:
		return
	mission = get_parent() as Node3D
	if mission == null:
		return
	world = mission.get_node_or_null("World") as Node3D
	var benchmark_pass: Node = mission.get_node_or_null("BenchmarkRemasterPass")
	var crypt_layout_pass: Node = mission.get_node_or_null("CryptLayoutPass")
	var benchmark_ready: bool = benchmark_pass != null and bool(benchmark_pass.get("installed"))
	var crypt_ready: bool = crypt_layout_pass != null and bool(crypt_layout_pass.get("installed"))
	benchmark_root = world.get_node_or_null("ModularChapelBenchmarkV1") as Node3D if world != null else null
	if world == null or not benchmark_ready or not crypt_ready or benchmark_root == null:
		install_attempts += 1
		if install_attempts < 150:
			call_deferred("_install")
		return

	readability_plan = _load_json(READABILITY_LAYOUT_PATH)
	if readability_plan.is_empty():
		push_error("Drowned Chapel readability plan could not load: " + READABILITY_LAYOUT_PATH)
		return

	_prune_repeated_structure()
	_restage_furnishings()
	_reduce_tunnel_signal_clutter()
	visible_module_count = _count_visible_modules(benchmark_root)
	benchmark_root.set_meta("spatial_readability_profile", str(readability_plan.get("layout_id", "")))
	benchmark_root.set_meta("visible_module_count", visible_module_count)
	benchmark_root.set_meta("readability_retired_count", retired_nodes.size())

	audit_result = ReadabilityAuditor.audit(mission, readability_plan, GraceSpatialProfile)
	benchmark_root.set_meta("readability_audit", audit_result.duplicate(true))
	for error: String in audit_result.get("errors", []):
		push_error("Drowned Chapel readability: " + error)
	for warning: String in audit_result.get("warnings", []):
		push_warning("Drowned Chapel readability: " + warning)

	if show_debug_zones:
		ReadabilityDebug.build(world, readability_plan, GraceSpatialProfile)
	installed = true


func _prune_repeated_structure() -> void:
	for path: String in [
		"NaveStructureModules/NavePillar01",
		"NaveStructureModules/NaveTimberFrame01",
		"NaveStructureModules/NaveSconce_West_01",
		"NaveStructureModules/NaveSconce_East_01",
		"FurnishingModules/CollapsedAisleCrate",
	]:
		_retire_benchmark_node(path)


func _restage_furnishings() -> void:
	_move_benchmark_node("FurnishingModules/VestibuleSupplyCrate", Vector3(6.05, 0.0, 24.15), Vector3(0.0, -0.08, 0.0))
	_move_benchmark_node("FurnishingModules/MemorialStorageBarrel", Vector3(-6.15, 0.0, 34.75), Vector3(0.0, 0.14, 0.0))


func _reduce_tunnel_signal_clutter() -> void:
	for path: String in [
		"BellBelowV3/ComposedCryptPassageV1/CollapsedBurialPassage/PassageRipple01",
		"BellBelowV3/ComposedCryptPassageV1/CollapsedBurialPassage/PassageRipple03",
	]:
		var node: Node = world.get_node_or_null(path)
		if node != null:
			_retire_node(node)
			retired_nodes.append(path)


func _retire_benchmark_node(path: String) -> void:
	var node: Node = benchmark_root.get_node_or_null(path)
	if node == null:
		return
	_retire_node(node)
	retired_nodes.append(path)


func _move_benchmark_node(path: String, position_value: Vector3, rotation_value: Vector3) -> void:
	var node: Node3D = benchmark_root.get_node_or_null(path) as Node3D
	if node == null:
		return
	node.position = position_value
	node.rotation = rotation_value
	node.set_meta("readability_repositioned", true)
	moved_nodes.append(path)


func _retire_node(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", true)
	for child: Node in node.get_children():
		_retire_node(child)
	node.set_meta("readability_retired", true)


func _count_visible_modules(root: Node) -> int:
	if root == null:
		return 0
	var count: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if node is Node3D and node.is_in_group("modular_environment_piece") and (node as Node3D).is_visible_in_tree():
			count += 1
	return count


func _load_json(path: String) -> Dictionary:
	var source: String = FileAccess.get_file_as_string(path)
	if source.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func get_debug_data() -> Dictionary:
	return {
		"installed": installed,
		"layout_id": str(readability_plan.get("layout_id", "")),
		"profile_id": str(readability_plan.get("profile_id", "")),
		"visible_module_count": visible_module_count,
		"retired_nodes": retired_nodes.duplicate(),
		"moved_nodes": moved_nodes.duplicate(),
		"audit": audit_result.duplicate(true),
		"debug_zones": show_debug_zones,
	}
