extends GroundContactPresentationDirector3D
class_name GreenGrottoGroundContactAdapter

var tagged_surface_count: int = 0
var tagged_counts: Dictionary = {}
var retired_legacy_surface_contact_count: int = 0


func _ready() -> void:
	super._ready()
	call_deferred("_finish_green_contact_setup")


func _finish_green_contact_setup() -> void:
	_tag_scene_surfaces()
	_retire_legacy_surface_contact()


func _tag_scene_surfaces() -> void:
	tagged_surface_count = 0
	tagged_counts.clear()
	var scene_root: Node = get_tree().current_scene if get_tree() != null else null
	if scene_root == null:
		return
	var environment_root: Node = scene_root.get_node_or_null("GreenGrottoArt")
	if environment_root == null:
		return
	_tag_recursive(environment_root)
	set_meta("green_grotto_contact_surfaces_tagged", tagged_surface_count)


func _retire_legacy_surface_contact() -> void:
	retired_legacy_surface_contact_count = 0
	if get_tree() == null:
		return
	for candidate: Node in get_tree().get_nodes_in_group(
		"surface_contact_presentation_director"
	):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("set_enabled"):
			continue
		candidate.call("set_enabled", false)
		candidate.set_meta("retired_by_ground_contact_presentation", true)
		retired_legacy_surface_contact_count += 1
	set_meta(
		"retired_legacy_surface_contact_count",
		retired_legacy_surface_contact_count
	)


func _tag_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		var surface: String = _classify_surface(node as CollisionObject3D)
		if surface != "":
			node.set_meta("contact_surface", surface)
			tagged_surface_count += 1
			tagged_counts[surface] = int(tagged_counts.get(surface, 0)) + 1
	for child: Node in node.get_children():
		_tag_recursive(child)


func _classify_surface(node: CollisionObject3D) -> String:
	var node_name: String = str(node.name)
	if node_name == "ArrivalShelf":
		return "moss_soil"
	if node_name.begins_with("CausewaySlab"):
		return "paving"
	if node_name in ["ShrineFoundation", "LeftTerrace"]:
		return "paving"
	if node_name in ["RightTerrace", "RightBrokenLedge"]:
		return "wet_stone"
	if (
		"Cliff" in node_name
		or "Mountain" in node_name
		or "Rock" in node_name
	):
		return "stone"
	if node.has_meta("presentation_material"):
		var material_id: String = str(
			node.get_meta("presentation_material")
		).strip_edges().to_lower()
		if material_id == "stone":
			return "stone"
	return ""


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_ground_contact_adapter"] = true
	data["tagged_surfaces"] = tagged_surface_count
	data["tagged_counts"] = tagged_counts.duplicate(true)
	data["tags_collision_metadata_only"] = true
	data["retired_legacy_surface_contact"] = retired_legacy_surface_contact_count
	data["single_contact_visual_authority"] = true
	return data
