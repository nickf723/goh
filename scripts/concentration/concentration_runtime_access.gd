extends RefCounted
class_name ConcentrationRuntimeAccess

const ConcentrationManagerScript = preload(
	"res://scripts/concentration/concentration_manager.gd"
)


static func ensure_manager(
	tree: SceneTree,
	preferred_parent: Node = null
) -> Node:
	if tree == null:
		return null
	var existing: Node = tree.get_first_node_in_group("concentration_manager")
	if (
		existing != null
		and is_instance_valid(existing)
		and not existing.is_queued_for_deletion()
	):
		return existing

	var parent: Node = tree.current_scene
	if parent == null and preferred_parent != null:
		parent = preferred_parent.get_parent()
	if parent == null:
		parent = tree.root
	if parent == null:
		return null

	var named_existing: Node = parent.get_node_or_null("ConcentrationManager")
	if named_existing != null and is_instance_valid(named_existing):
		return named_existing

	var manager: Node = ConcentrationManagerScript.new()
	manager.name = "ConcentrationManager"
	manager.set("show_hud", true)
	manager.set("passive_mana_regeneration_per_second", 0.0)
	manager.set_meta("runtime_spell_library_service", true)
	parent.add_child(manager)
	return manager


static func get_debug_data(tree: SceneTree) -> Dictionary:
	var manager: Node = (
		tree.get_first_node_in_group("concentration_manager")
		if tree != null
		else null
	)
	return {
		"manager_ready": manager != null and is_instance_valid(manager),
		"runtime_created": (
			bool(manager.get_meta("runtime_spell_library_service", false))
			if manager != null and is_instance_valid(manager)
			else false
		),
		"manager_name": str(manager.name) if manager != null else "none",
	}
