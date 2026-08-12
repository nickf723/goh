extends "res://scripts/levels/trial_chamber_002_conductive_circuit.gd"
class_name TrialChamber002ConductiveCircuitV2


# Keep the accepted circuit logic untouched. This presentation correction keeps
# the optional reward physically beside the side circuit that unlocks it instead
# of placing the chest on the opposite side of the hall.
func _build_optional_cache() -> void:
	var alcove := _make_room_root("OptionalCacheAlcove", Vector3(5.15, 0.0, -7.0))
	_create_visual_box_under(
		alcove,
		"CacheBench",
		Vector3(0.0, 0.12, 0.0),
		Vector3(8.2, 0.24, 6.2),
		bench_material
	)
	optional_circuit = _build_circuit(
		alcove,
		"optional",
		Vector3.ZERO,
		3.2,
		1.35,
		0.9,
		"metal",
		"solid",
		0.0
	)
	optional_chest = RewardChoiceChestScene.instantiate()
	optional_chest.name = "OptionalRewardChest"
	optional_chest.set("starts_locked", true)
	optional_chest.set("resettable_in_lab", false)
	if optional_chest is Node3D:
		(optional_chest as Node3D).position = Vector3(5.15, 0.0, -10.8)
	if optional_chest.has_signal("reward_chosen"):
		optional_chest.connect("reward_chosen", _on_optional_reward_chosen)
	architecture_root.add_child(optional_chest)
	_create_visual_box(
		"CachePlinth",
		Vector3(5.15, 0.15, -10.8),
		Vector3(3.2, 0.3, 3.0),
		bench_material
	)
