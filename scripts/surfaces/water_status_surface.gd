extends "res://scripts/surfaces/status_surface.gd"
class_name WaterStatusSurface


# Water patches accept Area3D reaction targets, but player-owned sensor areas
# must not count as standing in the water. Grace is affected only when her
# CharacterBody3D collision actually overlaps the surface.
func register_surface_target(raw_target: Node) -> void:
	var target: Node = find_status_target(raw_target)
	if not _is_valid_water_overlap(raw_target, target):
		return
	super.register_surface_target(raw_target)


func unregister_surface_target(raw_target: Node) -> void:
	var target: Node = find_status_target(raw_target)
	if not _is_valid_water_overlap(raw_target, target):
		return
	super.unregister_surface_target(raw_target)


func _is_valid_water_overlap(raw_target: Node, target: Node) -> bool:
	if raw_target == null or target == null or target == self:
		return false
	if not target.is_in_group("player"):
		return true
	return raw_target == target and target is PhysicsBody3D
