extends "res://scripts/animals/creature_observation_service.gd"

@export_range(0.5, 10.0, 0.5) var stale_pack_prune_interval: float = 2.0

var stale_pack_prune_remaining: float = 0.0


func _process(delta: float) -> void:
	super._process(delta)
	stale_pack_prune_remaining = maxf(
		stale_pack_prune_remaining - maxf(delta, 0.0),
		0.0
	)
	if stale_pack_prune_remaining > 0.0:
		return
	stale_pack_prune_remaining = maxf(stale_pack_prune_interval, 0.5)
	_prune_stale_packs()


func report_creature_defeated(creature: Node) -> Dictionary:
	if not is_instance_valid(creature):
		return {}
	var pack_key: String = get_pack_key(creature)
	var creature_id: int = creature.get_instance_id()
	var result: Dictionary = super.report_creature_defeated(creature)
	var members_value: Variant = pack_member_ids.get(pack_key, {})
	if members_value is Dictionary:
		var members: Dictionary = members_value as Dictionary
		members.erase(creature_id)
		pack_member_ids[pack_key] = members
	return result


func get_pack_member_count(creature: Node) -> int:
	var pack_key: String = get_pack_key(creature)
	var live_count: int = 0
	for value: Variant in get_tree().get_nodes_in_group("creature_observable"):
		if not value is Node:
			continue
		var member: Node = value as Node
		if not is_instance_valid(member) or member.is_queued_for_deletion():
			continue
		if get_pack_key(member) == pack_key and member.is_in_group("enemy"):
			live_count += 1
	return live_count


func report_reaction(
	target: Node,
	reaction: Dictionary,
	payload: Resource = null
) -> Dictionary:
	var species_id: String = get_species_id(target)
	if species_id == "":
		return {}
	var reaction_id: String = str(reaction.get("reaction_id", "")).strip_edges().to_lower()
	if reaction_id == "":
		reaction_id = str(reaction.get("reaction", "")).strip_edges().to_lower()
	var reaction_name: String = str(reaction.get("reaction_name", "")).strip_edges()
	if reaction_name == "":
		reaction_name = str(reaction.get("reaction", reaction_id))
	var context: Dictionary = {
		"actor_ref": target,
		"target_id": target.get_instance_id() if is_instance_valid(target) else 0,
		"reaction_id": reaction_id,
		"reaction_name": reaction_name,
		"pack_key": get_pack_key(target),
		"pack_member_count": get_pack_member_count(target),
	}
	if payload != null:
		if "element" in payload:
			context["incoming_element"] = str(payload.get("element")).to_lower()
		if "source_name" in payload:
			context["source_name"] = str(payload.get("source_name"))
	return report_event(species_id, "reaction_triggered", context)


func can_player_witness(creature: Node) -> bool:
	if not is_instance_valid(creature):
		return false
	if not creature is Node3D:
		return false
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return true
	var actor: Node3D = creature as Node3D
	var aim_point: Vector3 = _get_aim_point(actor)
	if player.global_position.distance_to(aim_point) > sight_range:
		return false
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return true
	if camera.is_position_behind(aim_point):
		return false
	var to_actor: Vector3 = aim_point - camera.global_position
	if to_actor.length_squared() <= 0.0001:
		return true
	var forward_dot: float = (-camera.global_basis.z).normalized().dot(to_actor.normalized())
	if forward_dot < minimum_camera_dot:
		return false
	return _has_line_of_sight(player, actor, aim_point, camera.global_position)


func clear_runtime_state() -> void:
	super.clear_runtime_state()
	stale_pack_prune_remaining = 0.0


func _evaluate_pack_defeat(species_id: String, pack_key: String) -> void:
	var maximum_members: int = int(pack_max_members.get(pack_key, 0))
	if maximum_members < 2:
		return
	for value: Variant in get_tree().get_nodes_in_group("creature_observable"):
		if not value is Node:
			continue
		var member: Node = value as Node
		if not is_instance_valid(member) or member.is_queued_for_deletion():
			continue
		if get_species_id(member) != species_id or get_pack_key(member) != pack_key:
			continue
		if member.is_in_group("enemy"):
			return
	report_event(
		species_id,
		"pack_defeated",
		{
			"pack_key": pack_key,
			"pack_member_count": maximum_members,
		}
	)
	pack_member_ids.erase(pack_key)
	pack_max_members.erase(pack_key)


func _prune_stale_packs() -> void:
	for pack_key_value: Variant in pack_member_ids.keys():
		var pack_key: String = str(pack_key_value)
		var members_value: Variant = pack_member_ids.get(pack_key, {})
		if not members_value is Dictionary:
			pack_member_ids.erase(pack_key)
			pack_max_members.erase(pack_key)
			continue
		var members: Dictionary = members_value as Dictionary
		var living_ids: Dictionary = {}
		for actor_id_value: Variant in members.keys():
			var actor_id: int = int(actor_id_value)
			var actor_value: Object = instance_from_id(actor_id)
			if actor_value is Node and is_instance_valid(actor_value):
				var actor: Node = actor_value as Node
				if not actor.is_queued_for_deletion():
					living_ids[actor_id] = true
		if living_ids.is_empty():
			pack_member_ids.erase(pack_key)
			pack_max_members.erase(pack_key)
		else:
			pack_member_ids[pack_key] = living_ids
