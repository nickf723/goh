extends "res://scripts/weapons/chain_weapon_rig_v4.gd"
class_name ChainWeaponRigV5


func _ground_project(candidate: Vector3) -> Vector3:
	if not is_inside_tree():
		return candidate
	var query := PhysicsRayQueryParameters3D.new()
	query.from = candidate + Vector3.UP * 1.8
	query.to = candidate + Vector3.DOWN * 3.8
	query.collision_mask = 0x7fffffff
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var excluded: Array[RID] = []
	var actor: Node3D = controller.get_actor() if controller != null else null
	if actor is CollisionObject3D:
		excluded.append((actor as CollisionObject3D).get_rid())
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if enemy is CollisionObject3D and enemy != actor:
			excluded.append((enemy as CollisionObject3D).get_rid())
	query.exclude = excluded
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return candidate
	return (result.get("position", candidate) as Vector3) + Vector3.UP * 0.16


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "colossal_chain_v5"
	data["terrain_only_drag"] = true
	return data
