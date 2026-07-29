extends "res://scripts/actions/fire_field.gd"
class_name ManifestedFireField


func apply_burning_to_target(target: Node) -> void:
	if _is_manifestation_ally(target):
		return
	super.apply_burning_to_target(target)


func _is_manifestation_ally(target: Node) -> bool:
	if target == null:
		return false
	var current: Node = target
	while current != null:
		if current == authority_owner_actor:
			return true
		if current.is_in_group("friendly_actor") or current.is_in_group("player"):
			return true
		if authority_owner_actor != null:
			var owner_instance_id: int = int(
				authority_owner_actor.get_meta(
					"manifestation_owner_instance_id",
					-1
				)
			)
			if owner_instance_id >= 0 and current.get_instance_id() == owner_instance_id:
				return true
		current = current.get_parent()
	return false
