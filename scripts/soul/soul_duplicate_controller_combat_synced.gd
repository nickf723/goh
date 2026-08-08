extends "res://scripts/soul/soul_duplicate_controller_final.gd"
class_name SoulDuplicateControllerCombatSynced

const CombatDuplicateActorScript = preload(
	"res://scripts/soul/soul_duplicate_actor_combat_synced.gd"
)


func _spawn_duplicates() -> void:
	_clear_duplicates()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for index: int in range(maxi(duplicate_count, 1)):
		var duplicate := CombatDuplicateActorScript.new() as SoulDuplicateActorCombatSynced
		duplicate.name = "SoulDuplicate" + str(index + 1)
		duplicate.default_side_offset = side_spacing
		duplicate.set_meta("clone_spell_replay", true)
		duplicate.set_meta("clone_spell_kind", "soul_duplicate")
		scene_root.add_child(duplicate)
		duplicate.configure(source_actor, index)
		duplicates.append(duplicate)
		duplicate_spawned.emit(duplicate)


func _on_weapon_attack_started(attack: WeaponAttackDefinition) -> void:
	var weapon: WeaponDefinition = (
		weapon_controller.equipped_weapon
		if weapon_controller != null
		else null
	)
	var attack_forward: Vector3 = Vector3.FORWARD
	if weapon_controller != null and weapon_controller.has_method("get_attack_forward"):
		attack_forward = weapon_controller.call("get_attack_forward") as Vector3
	for duplicate: SoulDuplicateActor in duplicates:
		if duplicate is SoulDuplicateActorCombatSynced:
			(duplicate as SoulDuplicateActorCombatSynced).mirror_weapon_attack_with_forward(
				attack,
				weapon,
				attack_forward
			)
		elif duplicate != null and is_instance_valid(duplicate):
			duplicate.mirror_weapon_attack(attack, weapon)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["combat_aim_forward_bridge"] = true
	data["jump_constants_synced"] = true
	return data
