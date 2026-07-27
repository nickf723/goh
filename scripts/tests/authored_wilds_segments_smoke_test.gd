extends Node

const FamiliaritySegmentScript = preload("res://scripts/expedition/familiarity_expedition_segment_3d.gd")
const CypressDefinition: ExpeditionSegmentDefinition = preload("res://data/expedition_segments/cypress_basin.tres")
const WoodlandDefinition: ExpeditionSegmentDefinition = preload("res://data/expedition_segments/wet_woodland.tres")


func _ready() -> void:
	await verify_segment(CypressDefinition, "cypress_basin", false)
	await verify_segment(WoodlandDefinition, "wet_woodland", true)
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
	segment.queue_free()
	await get_tree().process_frame
