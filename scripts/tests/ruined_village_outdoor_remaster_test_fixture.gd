extends RefCounted
class_name RuinedVillageOutdoorRemasterTestFixture

const ModularCatalog = preload("res://scripts/environment/modular_environment_catalog.gd")

const OUTDOOR_PIECE_IDS: Array[String] = [
	"weathered_village_road_4m",
	"weathered_low_wall_4m",
	"weathered_ruined_corner_4m",
	"weathered_ruined_facade_6m",
	"weathered_timber_fence_4m",
	"weathered_rubble_cluster",
	"weathered_olive_tree_cluster",
]


static func run(village: Node) -> Array[String]:
	var failures: Array[String] = []
	if village == null:
		return ["outdoor remaster: village is null"]

	for piece_id: String in OUTDOOR_PIECE_IDS:
		if not ModularCatalog.has_piece(piece_id):
			failures.append("outdoor remaster: catalog is missing " + piece_id)

	var pass_node: Node = village.get_node_or_null("OutdoorRemasterPass")
	var remaster_root: Node3D = village.get_node_or_null("OutdoorRemasterV1") as Node3D
	if pass_node == null:
		failures.append("outdoor remaster: pass node is missing")
		return failures
	if remaster_root == null:
		failures.append("outdoor remaster: composed root is missing")
		return failures

	var debug_data: Dictionary = pass_node.call("get_debug_data")
	if not bool(debug_data.get("installed", false)):
		failures.append("outdoor remaster: pass did not finish installation")
	if str(debug_data.get("layout_id", "")) != "ruined_village_outdoor_remaster_v1":
		failures.append("outdoor remaster: wrong layout id")
	if int(debug_data.get("module_count", 0)) < 48:
		failures.append("outdoor remaster: expected a substantial outdoor modular set")
	if (debug_data.get("retired_nodes", []) as Array).size() < 12:
		failures.append("outdoor remaster: legacy road, house, vegetation, and label presentation was not retired")
	if (debug_data.get("support_shells", []) as Array).size() < 4:
		failures.append("outdoor remaster: ruined-house foundations are not recorded as support shells")

	var categories: Array = debug_data.get("categories", [])
	for category: String in ["architecture", "prop", "terrain", "vegetation"]:
		if not categories.has(category):
			failures.append("outdoor remaster: missing modular category " + category)

	var compose_counts: Dictionary = debug_data.get("compose_counts", {})
	if int(compose_counts.get("modules", 0)) < 48:
		failures.append("outdoor remaster: set composer did not place the expected module count")

	var audit: Dictionary = debug_data.get("audit", {})
	if not bool(audit.get("passed", false)):
		for error: Variant in audit.get("errors", []):
			failures.append("outdoor readability: " + str(error))
	if (audit.get("routes", []) as Array).size() < 6:
		failures.append("outdoor remaster: protected route coverage is incomplete")
	if (audit.get("zones", []) as Array).size() < 10:
		failures.append("outdoor remaster: interaction, combat, and landmark zones are incomplete")

	for required_path: String in [
		"OutdoorRemasterV1/ArrivalRoad00",
		"OutdoorRemasterV1/ArrivalRampRoad01",
		"OutdoorRemasterV1/NorthWestFacade",
		"OutdoorRemasterV1/SouthEastCorner",
		"OutdoorRemasterV1/SquareWallNorthWest",
		"OutdoorRemasterV1/ChurchRoad03",
		"OutdoorRemasterV1/OliveVillageEast",
	]:
		if village.get_node_or_null(required_path) == null:
			failures.append("outdoor remaster: missing " + required_path)

	var road: Node = village.get_node_or_null("OutdoorRemasterV1/ArrivalRoad00")
	if road == null or _has_active_collision(road):
		failures.append("outdoor remaster: road presentation should reuse the existing support terrain")
	var square_wall: Node = village.get_node_or_null("OutdoorRemasterV1/SquareWallNorthWest")
	if square_wall == null or not _has_active_collision(square_wall):
		failures.append("outdoor remaster: freestanding low wall should retain physical collision")
	var rubble: Node = village.get_node_or_null("OutdoorRemasterV1/RubbleNorthWest")
	if rubble == null or _has_active_collision(rubble):
		failures.append("outdoor remaster: decorative rubble should remain nonblocking")

	var legacy_house: Node3D = _find_child_by_prefix(village.get_node_or_null("GeneratedDetails"), "RuinedHouse") as Node3D
	if legacy_house == null or legacy_house.visible:
		failures.append("outdoor remaster: legacy ruined-house presentation remains visible")
	var legacy_road: Node3D = _find_child_by_prefix(village.get_node_or_null("GeneratedGeometry"), "RoadSegment") as Node3D
	if legacy_road == null or legacy_road.visible:
		failures.append("outdoor remaster: legacy road presentation remains visible")

	var support_foundation: Node = _find_child_with_tokens(village.get_node_or_null("GeneratedGeometry"), "RuinedHouse", "CollisionFoundation")
	if support_foundation == null:
		failures.append("outdoor remaster: ruined-house support foundation is missing")
	else:
		if not _has_active_collision(support_foundation):
			failures.append("outdoor remaster: hidden ruined-house support foundation lost collision")
		if not _all_meshes_hidden(support_foundation):
			failures.append("outdoor remaster: support foundation still exposes its legacy mesh")

	for retired_label: String in ["THEVANISHEDVILLAGELabel", "VILLAGESQUARELabel", "ABANDONEDARMORYLabel"]:
		var label: Node3D = village.get_node_or_null(retired_label) as Node3D
		if label == null or label.visible:
			failures.append("outdoor remaster: debug region label remains visible: " + retired_label)

	var player: Node = village.get_node_or_null("Player")
	if player == null or player.get_node_or_null("SpatialProfileController") == null:
		failures.append("outdoor remaster: shared Grace spatial profile is missing")

	return failures


static func _find_child_by_prefix(parent: Node, prefix: String) -> Node:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if str(child.name).begins_with(prefix):
			return child
	return null


static func _find_child_with_tokens(parent: Node, prefix: String, suffix: String) -> Node:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		var child_name: String = str(child.name)
		if child_name.begins_with(prefix) and child_name.ends_with(suffix):
			return child
	return null


static func _has_active_collision(node: Node) -> bool:
	if node is CollisionObject3D and (node as CollisionObject3D).collision_layer != 0:
		for child: Node in node.get_children():
			if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
				return true
	for child: Node in node.get_children():
		if _has_active_collision(child):
			return true
	return false


static func _all_meshes_hidden(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).visible:
		return false
	for child: Node in node.get_children():
		if not _all_meshes_hidden(child):
			return false
	return true
