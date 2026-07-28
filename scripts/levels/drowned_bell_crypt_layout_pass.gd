extends Node
class_name DrownedBellCryptLayoutPass

const BuilderScript = preload("res://scripts/environment/authored_environment_builder.gd")
const ComposerScript = preload("res://scripts/environment/authored_set_composer.gd")
const ClearanceAuditor = preload("res://scripts/environment/authored_set_clearance_auditor.gd")
const ChapelPalette = preload("res://data/environment_palettes/drowned_chapel_palette.tres")
const LAYOUT_PATH := "res://data/set_layouts/drowned_bell_crypt_passage_v1.json"

var mission: Node3D
var world: Node3D
var crypt_root: Node3D
var composed_root: Node3D
var builder: AuthoredEnvironmentBuilder
var composer: RefCounted
var layout_data: Dictionary = {}
var compose_result: Dictionary = {}
var audit_result: Dictionary = {}
var installed: bool = false
var install_attempts: int = 0


func _ready() -> void:
	add_to_group("authored_set_layout_pass")
	call_deferred("_install")


func _install() -> void:
	if installed:
		return
	mission = get_parent() as Node3D
	if mission == null:
		return
	world = mission.get_node_or_null("World") as Node3D
	var crypt_pass: Node = mission.get_node_or_null("CryptPass")
	var crypt_ready: bool = crypt_pass != null and bool(crypt_pass.get("installed"))
	crypt_root = world.get_node_or_null("BellBelowV3") as Node3D if world != null else null
	if world == null or not crypt_ready or crypt_root == null or crypt_root.get_node_or_null("CryptSwimPassage") == null:
		install_attempts += 1
		if install_attempts < 120:
			call_deferred("_install")
		return

	var existing: Node3D = crypt_root.get_node_or_null("ComposedCryptPassageV1") as Node3D
	if existing != null:
		composed_root = existing
		installed = true
		return

	layout_data = _load_layout()
	if layout_data.is_empty():
		push_error("Drowned Bell crypt layout could not load: " + LAYOUT_PATH)
		return

	_disable_replaced_geometry()
	composed_root = Node3D.new()
	composed_root.name = "ComposedCryptPassageV1"
	composed_root.add_to_group("authored_set_composition")
	composed_root.set_meta("layout_id", str(layout_data.get("layout_id", "drowned_bell_crypt_passage_v1")))
	composed_root.set_meta("layout_source", LAYOUT_PATH)
	crypt_root.add_child(composed_root)

	builder = BuilderScript.new(composed_root, ChapelPalette) as AuthoredEnvironmentBuilder
	composer = ComposerScript.new(builder) as RefCounted
	var raw_compose_result: Variant = composer.call("compose_plan", composed_root, layout_data)
	compose_result = raw_compose_result as Dictionary if raw_compose_result is Dictionary else {}
	_configure_passage_water()
	_configure_drained_walkway()
	_configure_exit_anchors()
	_build_passage_dressing()

	audit_result = ClearanceAuditor.audit(composed_root)
	composed_root.set_meta("clearance_audit", audit_result.duplicate(true))
	composed_root.set_meta("compose_counts", _get_compose_counts())
	for error: String in audit_result.get("errors", []):
		push_error("Drowned Bell set clearance: " + error)
	for warning: String in audit_result.get("warnings", []):
		push_warning("Drowned Bell set clearance: " + warning)
	installed = true


func _load_layout() -> Dictionary:
	var source: String = FileAccess.get_file_as_string(LAYOUT_PATH)
	if source.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _disable_replaced_geometry() -> void:
	var raw_paths: Variant = layout_data.get("replace_paths", [])
	if not raw_paths is Array:
		return
	for path_variant: Variant in raw_paths as Array:
		var path: String = str(path_variant)
		var node: Node = crypt_root.get_node_or_null(path)
		if node == null:
			continue
		_disable_node_recursive(node)
		node.set_meta("replaced_by_layout", str(layout_data.get("layout_id", "drowned_bell_crypt_passage_v1")))


func _disable_node_recursive(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", true)
	for child: Node in node.get_children():
		_disable_node_recursive(child)


func _configure_passage_water() -> void:
	var raw_water: Variant = layout_data.get("water", {})
	if not raw_water is Dictionary:
		return
	var water_data: Dictionary = raw_water as Dictionary
	var passage_water: Area3D = crypt_root.get_node_or_null("CryptSwimPassage") as Area3D
	if passage_water == null:
		return
	passage_water.position = ComposerScript.vector3_from(water_data.get("position", passage_water.position), passage_water.position)
	passage_water.set("surface_height_offset", float(water_data.get("surface_height_offset", 2.25)))
	passage_water.set("current_velocity", ComposerScript.vector3_from(water_data.get("current_velocity", Vector3.ZERO), Vector3.ZERO))
	passage_water.set("water_label", "Collapsed Burial Passage")
	passage_water.set_meta("authored_set_layout_id", str(layout_data.get("layout_id", "")))
	var water_size: Vector3 = ComposerScript.vector3_from(water_data.get("size", Vector3(5.7, 4.7, 10.5)), Vector3(5.7, 4.7, 10.5))
	var collision: CollisionShape3D = passage_water.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = water_size

	for child: Node in passage_water.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	var surface_size: Vector3 = ComposerScript.vector3_from(water_data.get("surface_size", Vector3(5.65, 0.12, 10.45)), Vector3(5.65, 0.12, 10.45))
	var depth_size: Vector3 = ComposerScript.vector3_from(water_data.get("depth_size", Vector3(5.55, 0.08, 10.25)), Vector3(5.55, 0.08, 10.25))
	var surface_offset: float = float(water_data.get("surface_height_offset", 2.25))
	builder.add_visual_box(
		passage_water,
		"ComposedPassageWater",
		surface_size,
		Vector3(0.0, surface_offset - surface_size.y * 0.5, 0.0),
		"water_surface",
		Vector3.ZERO,
		0.94,
		0.16,
		"water"
	)
	builder.add_visual_box(
		passage_water,
		"ComposedPassageDepth",
		depth_size,
		Vector3(0.0, -water_size.y * 0.5 + 0.18, 0.0),
		"water_deep",
		Vector3.ZERO,
		0.82,
		0.0,
		"water_depth"
	)
	for index: int in range(6):
		builder.add_visual_box(
			passage_water,
			"ComposedCurrentRibbon%02d" % index,
			Vector3(0.12, 0.025, 1.15),
			Vector3(-1.2 + float(index % 3) * 1.2, surface_offset + 0.06, -3.6 + float(index) * 1.45),
			"water_highlight",
			Vector3.ZERO,
			0.52,
			0.22,
			"current_marker"
		)


func _configure_drained_walkway() -> void:
	var raw_walkway: Variant = layout_data.get("drained_walkway", {})
	if not raw_walkway is Dictionary:
		return
	var walkway_data: Dictionary = raw_walkway as Dictionary
	var walkway: StaticBody3D = crypt_root.get_node_or_null("DrainedPassageWalkway") as StaticBody3D
	if walkway == null:
		return
	walkway.position = ComposerScript.vector3_from(walkway_data.get("position", walkway.position), walkway.position)
	var size: Vector3 = ComposerScript.vector3_from(walkway_data.get("size", Vector3(5.2, 0.38, 10.4)), Vector3(5.2, 0.38, 10.4))
	var collision: CollisionShape3D = walkway.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = size
	var visual: MeshInstance3D = walkway.get_node_or_null("Visual") as MeshInstance3D
	if visual != null and visual.mesh is BoxMesh:
		(visual.mesh as BoxMesh).size = size
	walkway.set_meta("authored_set_layout_id", str(layout_data.get("layout_id", "")))


func _configure_exit_anchors() -> void:
	var raw_rows: Variant = layout_data.get("exit_anchors", [])
	if not raw_rows is Array:
		return
	for row_variant: Variant in raw_rows as Array:
		if not row_variant is Dictionary:
			continue
		var row: Dictionary = row_variant as Dictionary
		var anchor: Node3D = crypt_root.get_node_or_null(str(row.get("node", ""))) as Node3D
		if anchor == null:
			continue
		anchor.position = ComposerScript.vector3_from(row.get("position", anchor.position), anchor.position)
		if _has_property(anchor, "activation_radius"):
			anchor.set("activation_radius", float(row.get("activation_radius", 3.8)))
		anchor.set_meta("authored_set_layout_id", str(layout_data.get("layout_id", "")))


func _build_passage_dressing() -> void:
	var corridor: Node3D = composed_root.get_node_or_null("CollapsedBurialPassage") as Node3D
	if corridor == null:
		return
	for index: int in range(4):
		var z_value: float = -3.2 + float(index) * 2.1
		builder.add_visual_box(
			corridor,
			"GraveMarker%02d" % index,
			Vector3(0.12, 1.15, 1.15),
			Vector3(-2.82, 1.85, z_value),
			"stone_secondary",
			Vector3.ZERO,
			1.0,
			0.0,
			"memorial_marker"
		)
		builder.add_visual_torus(
			corridor,
			"PassageRipple%02d" % index,
			0.38,
			0.43,
			Vector3(0.0, 3.72, z_value),
			"accent_cool",
			Vector3(PI / 2.0, 0.0, 0.0),
			0.32,
			0.28,
			"resonance"
		)


func _get_compose_counts() -> Dictionary:
	if composer == null:
		return {}
	var raw_counts: Variant = composer.call("get_build_counts")
	return raw_counts as Dictionary if raw_counts is Dictionary else {}


func _has_property(object: Object, property_name: String) -> bool:
	for property_variant: Variant in object.get_property_list():
		if not property_variant is Dictionary:
			continue
		var property_data: Dictionary = property_variant as Dictionary
		if str(property_data.get("name", "")) == property_name:
			return true
	return false


func get_debug_data() -> Dictionary:
	return {
		"installed": installed,
		"layout_id": str(layout_data.get("layout_id", "")),
		"layout_source": LAYOUT_PATH,
		"compose_counts": _get_compose_counts(),
		"audit": audit_result.duplicate(true),
		"composed_root": composed_root != null,
	}
