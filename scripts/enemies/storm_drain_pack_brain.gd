extends "res://scripts/enemies/enemy_threat_aware_action_brain.gd"


@export_group("Storm Drain Pack")
@export_range(1.0, 20.0, 0.25) var guard_support_radius: float = 8.0
@export_range(0, 10, 1) var guard_stance_restore: int = 2
@export_range(0.1, 10.0, 0.1) var guard_status_duration: float = 1.8
@export_range(0.0, 10.0, 0.25) var guard_need_score_per_stance: float = 1.8
@export_range(0.0, 20.0, 0.5) var guard_full_stance_penalty: float = 10.0


func _ready() -> void:
	super._ready()
	if actor != null:
		actor.add_to_group("storm_drain_pack_member")


func score_action_option(option: EnemyActionOption, distance: float) -> float:
	var score: float = super.score_action_option(option, distance)
	if option == null or option.get_action() == null:
		return score
	if option.get_action().get_action_id() != "storm_drain_guard_screech":
		return score
	var missing_stance: int = get_nearby_missing_stance()
	if missing_stance <= 0:
		return score - maxf(guard_full_stance_penalty, 0.0)
	return score + float(missing_stance) * maxf(guard_need_score_per_stance, 0.0)


func process_active_action(action: EnemyCombatActionDefinition) -> void:
	if action == null:
		return
	if _is_projectile_attack(action):
		_perform_projectile_attack(action)
		return
	if action.get_action_id() == "storm_drain_guard_screech":
		_perform_guard_screech(action)
		return
	super.process_active_action(action)


func _is_projectile_attack(action: EnemyCombatActionDefinition) -> bool:
	return (
		action is EnemyAttackDefinition
		and action.has_method("is_projectile_delivery")
		and bool(action.call("is_projectile_delivery"))
	)


func _perform_projectile_attack(action: EnemyCombatActionDefinition) -> void:
	if actor == null or action_runner == null or action_runner.hit_registered:
		return
	var scene_value: Variant = action.call("get_projectile_scene")
	if not scene_value is PackedScene:
		action_runner.mark_hit_registered()
		last_action_summary = action.get_display_name() + " has no projectile scene"
		return
	var projectile_value: Variant = (scene_value as PackedScene).instantiate()
	if not projectile_value is Node3D:
		action_runner.mark_hit_registered()
		last_action_summary = action.get_display_name() + " projectile is invalid"
		return
	var projectile: Node3D = projectile_value as Node3D
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = actor.get_parent()
	if scene_root == null:
		projectile.queue_free()
		return
	scene_root.add_child(projectile)
	var direction: Vector3 = action_runner.get_locked_target_direction()
	direction.y = 0.0
	if direction.length() <= 0.01:
		direction = -actor.global_transform.basis.z
	else:
		direction = direction.normalized()
	var spawn_height: float = float(action.call("get_projectile_spawn_height"))
	var spawn_distance: float = float(action.call("get_projectile_spawn_distance"))
	projectile.global_position = (
		actor.global_position
		+ Vector3.UP * spawn_height
		+ direction * spawn_distance
	)
	if projectile.has_method("set_source_actor"):
		projectile.call("set_source_actor", actor)
	if action is EnemyAttackDefinition and projectile.has_method("set_payload"):
		projectile.call("set_payload", (action as EnemyAttackDefinition).get_payload())
	projectile.set("speed", float(action.call("get_projectile_speed")))
	if projectile.has_method("launch"):
		projectile.call("launch", direction)
	action_runner.mark_hit_registered()
	last_action_summary = "launched: " + action.get_display_name()


func _perform_guard_screech(action: EnemyCombatActionDefinition) -> void:
	if actor == null or action_runner == null or action_runner.hit_registered:
		return
	var affected: int = 0
	for ally_value: Variant in get_tree().get_nodes_in_group("storm_drain_pack_member"):
		if not ally_value is Node3D:
			continue
		var ally: Node3D = ally_value as Node3D
		if not is_instance_valid(ally):
			continue
		if actor.global_position.distance_to(ally.global_position) > guard_support_radius:
			continue
		if _restore_ally_stance(ally):
			affected += 1
		_apply_guard_status(ally)
	action_runner.mark_hit_registered()
	last_action_summary = (
		"support: " + action.get_display_name()
		+ " protected " + str(affected) + " pack member"
		+ ("s" if affected != 1 else "")
	)


func get_nearby_missing_stance() -> int:
	if actor == null:
		return 0
	var missing_stance: int = 0
	for ally_value: Variant in get_tree().get_nodes_in_group("storm_drain_pack_member"):
		if not ally_value is Node3D:
			continue
		var ally: Node3D = ally_value as Node3D
		if not is_instance_valid(ally):
			continue
		if actor.global_position.distance_to(ally.global_position) > guard_support_radius:
			continue
		var hit_receiver: Node = ally.get_node_or_null("HitReceiver")
		if hit_receiver == null:
			continue
		var current: int = int(hit_receiver.get("current_stance"))
		var maximum: int = int(hit_receiver.get("max_stance"))
		missing_stance += maxi(maximum - current, 0)
	return missing_stance


func _restore_ally_stance(ally: Node) -> bool:
	var hit_receiver: Node = ally.get_node_or_null("HitReceiver")
	if hit_receiver == null:
		return false
	var current: int = int(hit_receiver.get("current_stance"))
	var maximum: int = int(hit_receiver.get("max_stance"))
	if maximum <= 0 or current >= maximum:
		return false
	var restored: int = mini(current + maxi(guard_stance_restore, 0), maximum)
	hit_receiver.set("current_stance", restored)
	if hit_receiver.has_signal("stance_changed"):
		hit_receiver.emit_signal("stance_changed", restored, maximum)
	if hit_receiver.has_method("refresh_overhead_hud"):
		hit_receiver.call("refresh_overhead_hud")
	return restored > current


func _apply_guard_status(ally: Node) -> void:
	var status_receiver: Node = ally.get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.call(
			"apply_status",
			"guarded",
			guard_status_duration,
			1.0,
			"Guard Screech"
		)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["storm_drain_pack"] = true
	data["guard_support_radius"] = guard_support_radius
	data["guard_stance_restore"] = guard_stance_restore
	data["guard_missing_stance"] = get_nearby_missing_stance()
	return data
