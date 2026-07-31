extends "res://scripts/actions/generic_projectile.gd"


@export var ignored_target_groups: Array[String] = ["enemy"]


func should_ignore_target(target: Node) -> bool:
	if target != null:
		for group_name: String in ignored_target_groups:
			var normalized: String = group_name.strip_edges()
			if normalized != "" and target.is_in_group(normalized):
				return true
	return super.should_ignore_target(target)
