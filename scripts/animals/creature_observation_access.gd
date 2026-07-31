extends RefCounted

const ObservationServiceScript = preload(
	"res://scripts/animals/creature_observation_service.gd"
)


static func get_service(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	var existing: Node = root.get_node_or_null("CreatureObservation")
	if existing != null and is_instance_valid(existing):
		return existing
	var service: Node = ObservationServiceScript.new()
	service.name = "CreatureObservation"
	root.add_child(service)
	return service


static func call_service(
	tree: SceneTree,
	method_name: String,
	arguments: Array = []
) -> Variant:
	var service: Node = get_service(tree)
	if service == null or not service.has_method(method_name):
		return null
	return service.callv(method_name, arguments)
