extends Node
class_name RuinedVillageOutdoorRemasterPass

const BuilderScript = preload("res://scripts/environment/authored_environment_builder.gd")
const ComposerScript = preload("res://scripts/environment/authored_set_composer.gd")
const ReadabilityAuditor = preload("res://scripts/environment/authored_set_readability_auditor.gd")
const ReadabilityDebug = preload("res://scripts/environment/authored_set_readability_debug.gd")
const ModularCatalog = preload("res://scripts/environment/modular_environment_catalog.gd")
const GraceSpatialProfile: Resource = preload("res://data/player/grace_spatial_profile.tres")
const LAYOUT_PATH := "res://data/set_layouts/ruined_village_outdoor_remaster_v1.json"

@export var show_debug_zones: bool = false

var level: Node3D
var geometry_root: Node3D
var detail_root: Node3D
var remaster_root: Node3D
var builder: RefCounted
var composer: RefCounted
var layout_data: Dictionary = {}
var compose_result: Dictionary = {}
var audit_result: Dictionary = {}
var retired_nodes: Array[String] = []
var support_shells: Array[String] = []
var module_categories: Array[String] = []
var installed: bool = false
var install_attempts: int = 0


func _ready() -> void:
	add_to_group("ruined_village_outdoor_remaster_pass")
	call_deferred("_install")


func _install() -> void:
	if installed:
		return
	level = get_parent() as Node3D
	if level == null:
		return
	geometry_root = level.get_node_or_null("GeneratedGeometry") as Node3D
	detail_root = level.get_node_or_null("GeneratedDetails") as Node3D
	var traversal_ready: bool = geometry_root != null and geometry_root.get_node_or_null("ArrivalTraversalRamp") != null
	if geometry_root == null or detail_root == null or not traversal_ready:
		install_attempts += 1
		if install_attempts < 180:
			call_deferred("_install")
		return

	layout_data = _load_json(LAYOUT_PATH)
	if layout_data.is_empty():
		push_error("Ruined Village outdoor remaster could not load: " + LAYOUT_PATH)
		return

	var existing: Node3D = level.get_node_or_null("OutdoorRemasterV1") as Node3D
	if existing != null:
		remaster_root = existing
		installed = true
		return

	_retire_legacy_presentation()
	remaster_root = Node3D.new()
	remaster_root.name = "OutdoorRemasterV1"
	remaster_root.add_to_group("authored_set_composition")
	remaster_root.add_to_group("story_integrated_modular_environment")
	remaster_root.add_to_group("ruined_village_outdoor_remaster")
	remaster_root.set_meta("layout_id", str(layout_data.get("layout_id", "ruined_village_outdoor_remaster_v1")))
	remaster_root.set_meta("layout_source", LAYOUT_PATH)
	remaster_root.set_meta("preserves_support_shell", true)
	level.add_child(remaster_root)

	builder = BuilderScript.new(remaster_root, null) as RefCounted
	composer = ComposerScript.new(builder) as RefCounted
	var raw_result: Variant = composer.call("compose_plan", remaster_root, layout_data)
	compose_result = raw_result as Dictionary if raw_result is Dictionary else {}
	module_categories = _collect_module_categories()

	for child: Node in remaster_root.get_children():
		if child is Node3D:
			child.add_to_group("ruined_village_modular_piece")
			child.set_meta("outdoor_remaster_owner", "ruined_village_outdoor_remaster_v1")

	audit_result = ReadabilityAuditor.audit(level, layout_data, GraceSpatialProfile)
	remaster_root.set_meta("readability_audit", audit_result.duplicate(true))
	remaster_root.set_meta("module_count", remaster_root.get_child_count())
	remaster_root.set_meta("retired_legacy_count", retired_nodes.size())
	remaster_root.set_meta("support_shell_count", support_shells.size())
	for error: String in audit_result.get("errors", []):
		push_error("Ruined Village readability: " + error)
	for warning: String in audit_result.get("warnings", []):
		push_warning("Ruined Village readability: " + warning)

	if show_debug_zones:
		ReadabilityDebug.build(level, layout_data, GraceSpatialProfile)
	installed = true


func _retire_legacy_presentation() -> void:
	for prefix: String in _string_array(layout_data.get("retire_detail_prefixes", [])):
		for child: Node in detail_root.get_children():
			if str(child.name).begins_with(prefix):
				_retire_node(child)
				retired_nodes.append("GeneratedDetails/" + str(child.name))

	for prefix: String in _string_array(layout_data.get("retire_geometry_prefixes", [])):
		for child: Node in geometry_root.get_children():
			if str(child.name).begins_with(prefix):
				_retire_node(child)
				retired_nodes.append("GeneratedGeometry/" + str(child.name))

	for prefix: String in _string_array(layout_data.get("support_shell_prefixes", [])):
		for child: Node in geometry_root.get_children():
			var child_name: String = str(child.name)
			if not child_name.begins_with(prefix):
				continue
			var hidden_count: int = _hide_meshes_under(child)
			if hidden_count > 0:
				child.set_meta("outdoor_remaster_support_shell", true)
				support_shells.append("GeneratedGeometry/" + child_name)

	for node_name: String in _string_array(layout_data.get("retire_root_nodes", [])):
		var node: Node = level.get_node_or_null(node_name)
		if node == null:
			continue
		_retire_node(node)
		retired_nodes.append(node_name)


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
	node.set_meta("outdoor_remaster_retired", true)


func _hide_meshes_under(node: Node) -> int:
	var hidden_count: int = 0
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
		node.set_meta("outdoor_remaster_hidden_support_visual", true)
		hidden_count += 1
	for child: Node in node.get_children():
		hidden_count += _hide_meshes_under(child)
	return hidden_count


func _collect_module_categories() -> Array[String]:
	var categories: Dictionary = {}
	var raw_modules: Variant = layout_data.get("modules", [])
	if not raw_modules is Array:
		return []
	for row_variant: Variant in raw_modules as Array:
		if not row_variant is Dictionary:
			continue
		var row: Dictionary = row_variant as Dictionary
		var definition: Dictionary = ModularCatalog.get_definition(str(row.get("piece_id", "")))
		categories[str(definition.get("category", "unknown"))] = true
	var result: Array[String] = []
	for raw_category: Variant in categories.keys():
		result.append(str(raw_category))
	result.sort()
	return result


func _load_json(path: String) -> Dictionary:
	var source: String = FileAccess.get_file_as_string(path)
	if source.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for row: Variant in value as Array:
		result.append(str(row))
	return result


func get_debug_data() -> Dictionary:
	return {
		"installed": installed,
		"layout_id": str(layout_data.get("layout_id", "")),
		"layout_source": LAYOUT_PATH,
		"module_count": remaster_root.get_child_count() if remaster_root != null else 0,
		"compose_counts": composer.call("get_build_counts") if composer != null else {},
		"categories": module_categories.duplicate(),
		"retired_nodes": retired_nodes.duplicate(),
		"support_shells": support_shells.duplicate(),
		"audit": audit_result.duplicate(true),
		"debug_zones": show_debug_zones,
	}
