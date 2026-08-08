extends "res://scripts/soul/soul_duplicate_controller_ready.gd"
class_name SoulDuplicateControllerFinal

const FinalDuplicateActorScript = preload(
	"res://scripts/soul/soul_duplicate_actor_final.gd"
)


func _spawn_duplicates() -> void:
	_clear_duplicates()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for index: int in range(maxi(duplicate_count, 1)):
		var duplicate := FinalDuplicateActorScript.new() as SoulDuplicateActorFinal
		duplicate.name = "SoulDuplicate" + str(index + 1)
		duplicate.default_side_offset = side_spacing
		duplicate.set_meta("clone_spell_replay", true)
		duplicate.set_meta("clone_spell_kind", "soul_duplicate")
		scene_root.add_child(duplicate)
		duplicate.configure(source_actor, index)
		duplicates.append(duplicate)
		duplicate_spawned.emit(duplicate)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["final_duplicate_actor"] = true
	return data
