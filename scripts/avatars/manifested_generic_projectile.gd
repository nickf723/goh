extends "res://scripts/actions/generic_projectile.gd"
class_name ManifestedGenericProjectile


func should_ignore_target(target: Node) -> bool:
	if super.should_ignore_target(target):
		return true
	if target == null:
		return false
	var current: Node = target
	while current != null:
		if current.is_in_group("friendly_actor") or current.is_in_group("player"):
			return true
		if source_actor != null:
			if current == source_actor:
				return true
			var owner_instance_id: int = int(
				source_actor.get_meta(
					"manifestation_owner_instance_id",
					-1
				)
			)
			if owner_instance_id >= 0 and current.get_instance_id() == owner_instance_id:
				return true
		current = current.get_parent()
	return false
