extends "res://scripts/tests/duplicate_spell_smoke_test.gd"


func _count_live_clone_spell_nodes() -> int:
	return _count_clone_nodes_recursive(get_tree().current_scene, 0)
