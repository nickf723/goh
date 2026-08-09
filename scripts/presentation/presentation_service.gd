extends RefCounted
class_name PresentationService

const DirectorScript = preload(
	"res://scripts/presentation/presentation_director.gd"
)
const DIRECTOR_NODE_NAME: String = "PresentationDirector"


static func get_or_create(tree: SceneTree) -> GamePresentationDirector:
	if tree == null or tree.root == null:
		return null
	var existing: Node = tree.root.get_node_or_null(DIRECTOR_NODE_NAME)
	if existing is GamePresentationDirector:
		return existing as GamePresentationDirector
	var director: GamePresentationDirector = DirectorScript.new() as GamePresentationDirector
	director.name = DIRECTOR_NODE_NAME
	director.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(director)
	return director


static func get_existing(tree: SceneTree) -> GamePresentationDirector:
	if tree == null or tree.root == null:
		return null
	var existing: Node = tree.root.get_node_or_null(DIRECTOR_NODE_NAME)
	return existing as GamePresentationDirector if existing is GamePresentationDirector else null
