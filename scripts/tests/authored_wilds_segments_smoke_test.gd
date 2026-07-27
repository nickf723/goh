extends Node

const FamiliaritySegmentScript = preload("res://scripts/expedition/familiarity_expedition_segment_3d.gd")
const CypressDefinition: ExpeditionSegmentDefinition = preload("res://data/expedition_segments/cypress_basin.tres")
const WoodlandDefinition: ExpeditionSegmentDefinition = preload("res://data/expedition_segments/wet_woodland.tres")
const PineDefinition: ExpeditionSegmentDefinition = preload("res://data/expedition_segments/pine_ridge.tres")


func _ready() -> void:
	await verify_segment(CypressDefinition, "cypress_basin", false)
	await verify_segment(WoodlandDefinition, "wet_woodland", true)
	await verify_segment(PineDefinition, "pine_ridge", false)
	print("AUTHORED_WILDS_SEGMENTS_SMOKE_TEST: PASS")
	get_tree().quit(0)


func verify_segment(
	definition: ExpeditionSegmentDefinition,
	expected_layout: String,
	expect_branch: bool
) -> void:
	var segment := FamiliaritySegmentScript.new() as FamiliarityExpeditionSegment3D
	assert(segment != null)
	add_child(segment)
	segment.configure_familiarity(definition, 8675309, {
		"threat_multiplier": 1.0,
		"obstacle_multiplier": 1.0,
		"resource_multiplier": 1.0,
		"guaranteed_rest_cache": false,
	}, false)
	await get_tree().process_frame
	assert(segment.uses_authored_layout())
	assert(segment.authored_layout != null)
	assert(segment.authored_layout.layout_id == expected_layout)
	assert(segment.get_node_or_null("EntrySocket") != null)
	assert(segment.get_node_or_null("ExitSocket") != null)
	assert((segment.get_node_or_null("BranchSocket") != null) == expect_branch)
	assert(segment.authored_layout.get_child_count() >= 8)
	assert(segment.authored_layout.get_tree().get_nodes_in_group("authored_wilds_layout").has(segment.authored_layout))

	# Authored scenes own their route composition. The procedural role pass must
	# not add its old blocking rocks or ruin pillars on top of the authored path.
	assert(segment.get_node_or_null("Rock") == null)
	assert(segment.get_node_or_null("RuinPillar") == null)

	if expected_layout == "wet_woodland":
		assert(segment.authored_layout.get_node_or_null("TransitionThroat_WoodlandToPine") != null)
	elif expected_layout == "pine_ridge":
		assert(segment.authored_layout.get_node_or_null("TransitionThroat_WetlandToPine") != null)
		assert(segment.authored_layout.get_node_or_null("LowerRidgeRamp") != null)
		assert(segment.authored_layout.get_node_or_null("MiddleRidgeRamp") != null)
		assert(segment.authored_layout.get_node_or_null("UpperRidgeRamp") != null)
		assert(segment.authored_layout.get_node_or_null("OverlookShelf") != null)
		assert(segment.authored_layout.get_node_or_null("WetlandOverlook") != null)
		assert(segment.authored_layout.get_tree().get_nodes_in_group("authored_wilds_layout").has(segment.authored_layout))
		var exit_socket := segment.get_node("ExitSocket") as Marker3D
		assert(is_equal_approx(exit_socket.position.y, PineDefinition.elevation_delta))

	segment.queue_free()
	await get_tree().process_frame
