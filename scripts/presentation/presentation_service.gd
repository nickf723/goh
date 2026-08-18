extends RefCounted
class_name PresentationService

const DirectorScript = preload(
	"res://scripts/presentation/presentation_director_audio_fidelity_v2.gd"
)
const DIRECTOR_NODE_NAME: String = "PresentationDirector"
const PENDING_DIRECTOR_META: StringName = &"_goh_pending_presentation_director"


static func get_or_create(tree: SceneTree) -> GamePresentationDirector:
	if tree == null or tree.root == null:
		return null
	var root: Window = tree.root
	var existing: Node = root.get_node_or_null(DIRECTOR_NODE_NAME)
	if existing is GamePresentationDirector:
		if existing.has_method("present_spell"):
			return existing as GamePresentationDirector
		# Hot-reload/dev sessions can retain the older Director at the scene-tree
		# root. Retire it without competing for the canonical name while the new
		# service waits for the root to finish constructing its current children.
		existing.name = DIRECTOR_NODE_NAME + "Retired"
		existing.queue_free()

	var pending_value: Variant = root.get_meta(PENDING_DIRECTOR_META, null)
	if (
		pending_value is GamePresentationDirector
		and is_instance_valid(pending_value)
	):
		return pending_value as GamePresentationDirector

	var director: GamePresentationDirector = (
		DirectorScript.new() as GamePresentationDirector
	)
	director.name = DIRECTOR_NODE_NAME
	director.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_meta(PENDING_DIRECTOR_META, director)
	var clear_pending := func() -> void:
		if not is_instance_valid(root):
			return
		if root.get_meta(PENDING_DIRECTOR_META, null) == director:
			root.remove_meta(PENDING_DIRECTOR_META)
	director.tree_entered.connect(clear_pending, CONNECT_ONE_SHOT)
	# PlayerMotionFeedback requests this service from _ready(). At that moment the
	# scene-tree root may still be traversing its child setup, so direct add_child
	# is illegal. The pending metadata also prevents duplicate directors while the
	# deferred attachment is waiting for the safe point.
	root.add_child.call_deferred(director)
	return director


static func get_existing(tree: SceneTree) -> GamePresentationDirector:
	if tree == null or tree.root == null:
		return null
	var root: Window = tree.root
	var existing: Node = root.get_node_or_null(DIRECTOR_NODE_NAME)
	if existing is GamePresentationDirector:
		return existing as GamePresentationDirector
	var pending_value: Variant = root.get_meta(PENDING_DIRECTOR_META, null)
	return (
		pending_value as GamePresentationDirector
		if (
			pending_value is GamePresentationDirector
			and is_instance_valid(pending_value)
		)
		else null
	)
