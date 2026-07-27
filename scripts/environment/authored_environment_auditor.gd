extends RefCounted
class_name AuthoredEnvironmentAuditor


static func audit(root: Node) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var surfaces: Array[Node] = _nodes_in_group_under(root, "authored_environment_surface")
	var decor: Array[Node] = _nodes_in_group_under(root, "authored_environment_decor")
	var stair_runs: Array[Node] = _nodes_in_group_under(root, "authored_environment_stair_run")
	var lights: Array[Node] = _nodes_in_group_under(root, "authored_environment_light")
	var environment_roots: Array[Node] = _nodes_in_group_under(root, "authored_environment_root")

	if environment_roots.is_empty():
		errors.append("No authored environment root is present.")
	if surfaces.is_empty():
		errors.append("No authored collision surfaces are present.")
	if decor.is_empty():
		warnings.append("Authored environment contains no decorative geometry.")
	if lights.is_empty():
		warnings.append("Authored environment contains no authored local lights.")

	for surface: Node in surfaces:
		if not bool(surface.get_meta("collision_required", false)):
			continue
		var collision: CollisionShape3D = surface.find_child("CollisionShape3D", true, false) as CollisionShape3D
		if collision == null or collision.shape == null:
			errors.append("Surface %s has no valid CollisionShape3D." % surface.name)
		var visual: MeshInstance3D = surface.find_child("Visual", true, false) as MeshInstance3D
		if visual == null and not bool(surface.get_meta("allow_invisible_surface", false)):
			warnings.append("Surface %s has collision but no authored visual." % surface.name)

	for stair_run: Node in stair_runs:
		var expected: int = int(stair_run.get_meta("step_count", 0))
		var actual: int = 0
		for child: Node in stair_run.get_children():
			if child is StaticBody3D and child.name.begins_with("Step"):
				actual += 1
		if expected <= 0:
			errors.append("Stair run %s has no positive step_count metadata." % stair_run.name)
		elif actual != expected:
			errors.append("Stair run %s expected %d steps but contains %d." % [stair_run.name, expected, actual])

	return {
		"passed": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"surface_count": surfaces.size(),
		"decor_count": decor.size(),
		"stair_run_count": stair_runs.size(),
		"light_count": lights.size(),
	}


static func _nodes_in_group_under(root: Node, group_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if root == null or root.get_tree() == null:
		return result
	for candidate: Node in root.get_tree().get_nodes_in_group(group_name):
		if candidate == root or root.is_ancestor_of(candidate):
			result.append(candidate)
	return result
