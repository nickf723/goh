extends "res://scripts/abilities/ability_caster_menu_select.gd"

# Player-owned channeled abilities use the same equipped-spell input as every
# other spell. A matching child component may claim the cast before the normal
# scene-instantiation path runs.

@export_group("Free Aim Convergence")
@export_range(10.0, 200.0, 1.0) var camera_aim_distance: float = 90.0
@export_flags_3d_physics var camera_aim_collision_mask: int = 1

@export_group("Precision Projectile Origin")
@export var prefer_casting_hand_anchor: bool = true
@export_range(0.0, 1.5, 0.01) var projectile_spawn_distance: float = 0.28


func cast_from_player(
	player: Node3D,
	cast_lock_duration: float = 0.18,
	allow_charge: bool = true
) -> bool:
	var ability: AbilityDefinition = get_current_ability()
	var channel_result: Dictionary = try_player_ability_channel(player, ability)
	if bool(channel_result.get("handled", false)):
		return bool(channel_result.get("success", false))
	return super.cast_from_player(player, cast_lock_duration, allow_charge)


# The base caster historically launches from player origin + a fixed height.
# Grace's CharacterBody origin sits near her torso, so that approximation was
# above short targets and forced aimed shots down toward them. Player-owned
# spells instead launch from the animated right-hand anchor when one exists.
func execute_ability_from_player(
	player: Node3D,
	ability: AbilityDefinition,
	cast_lock_duration: float = 0.18,
	action_payload_override: Resource = null,
	power_ratio: float = 0.0,
	extra_mana_cost: int = 0
) -> bool:
	if action_state != null and not action_state.can_cast():
		return false
	if player == null:
		print("No player for ability cast.")
		return false
	if ability == null:
		print("No current ability.")
		return false
	if ability.ability_scene == null:
		print("Ability has no scene: ", ability.display_name)
		return false
	if not pay_ability_cost(ability, extra_mana_cost):
		show_feedback("Not enough resources for " + ability.display_name + ".")
		return false

	if action_state != null:
		action_state.begin_cast(cast_lock_duration)

	var ability_instance: Node = ability.ability_scene.instantiate()
	var action_payload: Resource = action_payload_override
	if action_payload == null:
		if ability.has_method("get_action_payload"):
			action_payload = ability.get_action_payload()
		elif ability.payload != null:
			action_payload = ability.payload

	if action_payload != null and ability_instance.has_method("set_payload"):
		ability_instance.set_payload(action_payload)
	if ability_instance.has_method("set_source_actor"):
		ability_instance.set_source_actor(player)

	var cast_origin: Vector3 = get_player_cast_origin(player)
	var cast_direction: Vector3 = get_cast_direction(player, cast_origin)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		print("AbilityCaster: No current scene to cast into.")
		return false

	scene_root.add_child(ability_instance)
	configure_charged_projectile_visuals(ability_instance, power_ratio)

	if ability_instance.has_method("execute"):
		ability_instance.execute(player, cast_direction)
		return true

	if ability_instance is Node3D:
		var node_3d: Node3D = ability_instance as Node3D
		var resolved_spawn_distance: float = cast_spawn_distance
		if ability.get_delivery_type().strip_edges().to_lower() == "projectile":
			resolved_spawn_distance = minf(
				maxf(projectile_spawn_distance, 0.0),
				maxf(cast_spawn_distance, 0.0)
			)
		node_3d.global_position = (
			cast_origin + cast_direction * resolved_spawn_distance
		)

	if ability_instance.has_method("launch"):
		ability_instance.launch(cast_direction)
	return true


func get_player_cast_origin(player: Node3D) -> Vector3:
	if player == null:
		return Vector3.ZERO
	if prefer_casting_hand_anchor:
		var anchor: Node3D = _find_casting_hand_anchor(player)
		if anchor != null:
			return anchor.global_position
	return player.global_position + Vector3.UP * cast_spawn_height


func _find_casting_hand_anchor(player: Node) -> Node3D:
	if player == null:
		return null
	for anchor_path: String in [
		"GraceVisualV1/RightHandAnchor",
		"RightHandAnchor",
		"CastingHandAnchor",
	]:
		var direct_anchor: Node3D = player.get_node_or_null(anchor_path) as Node3D
		if direct_anchor != null:
			return direct_anchor
	var recursive_anchor: Node = player.find_child(
		"RightHandAnchor",
		true,
		false
	)
	return recursive_anchor as Node3D


func try_player_ability_channel(
	player: Node3D,
	ability: AbilityDefinition
) -> Dictionary:
	if player == null or ability == null:
		return {"handled": false, "success": false}
	if action_state != null and not action_state.can_cast():
		return {"handled": true, "success": false}

	for child: Node in player.get_children():
		if not child.has_method("can_handle_ability"):
			continue
		if not bool(child.call("can_handle_ability", ability)):
			continue
		if not child.has_method("begin_ability_channel"):
			push_warning(
				child.name
				+ " claims an ability but cannot begin its channel."
			)
			return {"handled": true, "success": false}
		return {
			"handled": true,
			"success": bool(
				child.call("begin_ability_channel", player, ability)
			),
		}

	return {"handled": false, "success": false}


# Ground targeting uses the caster's modal input path, but it is not the visible
# spell library. Keeping those states separate prevents the right stick from
# moving an AoE marker and navigating Focus at the same time.
func begin_ground_targeting(
	player: Node3D,
	ability: AbilityDefinition,
	ground_spell: Dictionary
) -> bool:
	var started: bool = super.begin_ground_targeting(
		player,
		ability,
		ground_spell
	)
	if started:
		_hide_focus_library_ui()
	return started


func confirm_ground_targeting() -> bool:
	if not is_ground_targeting():
		return false
	var controller: RefCounted = get_ground_targeting_controller()
	if (
		controller.has_method("is_target_valid")
		and not bool(controller.call("is_target_valid"))
	):
		var reason: String = "That spell cannot be placed there."
		if controller.has_method("get_invalid_reason"):
			var reported: String = str(
				controller.call("get_invalid_reason")
			)
			if reported != "":
				reason = reported
		show_feedback(reason)
		return true
	return super.confirm_ground_targeting()


func is_focus_library_open() -> bool:
	return focus_spell_menu_open and not is_ground_targeting()


func open_focus_spell_menu() -> void:
	if is_ground_targeting():
		return
	super.open_focus_spell_menu()


func update_focus_spell_menu_ui() -> void:
	if is_ground_targeting():
		_hide_focus_library_ui()
		return
	super.update_focus_spell_menu_ui()


func _hide_focus_library_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.call("hide_spell_focus_menu")
	elif ui != null and ui.has_method("hide_spell_menu"):
		ui.call("hide_spell_menu")


# Aimed spells participate in Grace's hard/soft targeting assist. Untargeted
# aimed casts still fall through to the player's camera-center ray, so this is
# one continuous rule rather than separate lock-on and free-fire behaviors.
func get_cast_direction(player: Node3D, cast_origin: Vector3) -> Vector3:
	var ability: AbilityDefinition = get_current_ability()
	if _ability_uses_lock_on_direction(ability):
		return super.get_cast_direction(player, cast_origin)
	return _get_camera_converged_cast_direction(player, cast_origin)


func _get_camera_converged_cast_direction(
	player: Node3D,
	cast_origin: Vector3
) -> Vector3:
	if player == null:
		return Vector3.FORWARD

	# PlayerControllerFreeAimStatus already owns the authoritative camera-center
	# ray and recursively excludes every CollisionObject3D beneath Grace. Reuse it
	# instead of maintaining a subtly different second implementation.
	if player.has_method("get_camera_center_cast_direction"):
		var canonical_value: Variant = player.call(
			"get_camera_center_cast_direction",
			cast_origin
		)
		if canonical_value is Vector3:
			var canonical_direction: Vector3 = canonical_value as Vector3
			if canonical_direction.length_squared() > 0.0001:
				return canonical_direction.normalized()

	var fallback: Vector3 = -player.global_transform.basis.z
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return fallback.normalized() if fallback.length() > 0.01 else Vector3.FORWARD

	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var screen_center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
	var ray_origin: Vector3 = camera.project_ray_origin(screen_center)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_center)
	if ray_direction.length() <= 0.01:
		ray_direction = -camera.global_transform.basis.z
	if ray_direction.length() <= 0.01:
		return fallback.normalized() if fallback.length() > 0.01 else Vector3.FORWARD
	ray_direction = ray_direction.normalized()

	var aim_point: Vector3 = (
		ray_origin
		+ ray_direction * maxf(camera_aim_distance, 1.0)
	)
	var world: World3D = player.get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin,
			aim_point
		)
		query.collision_mask = camera_aim_collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = _get_player_collision_exclusions(player)
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		var hit_position: Variant = hit.get("position")
		if hit_position is Vector3:
			aim_point = hit_position as Vector3

	var direction: Vector3 = aim_point - cast_origin
	if direction.length() <= 0.01:
		direction = ray_direction
	return direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD


func _get_player_collision_exclusions(player: Node) -> Array[RID]:
	var exclusions: Array[RID] = []
	_collect_collision_rids(player, exclusions)
	return exclusions


func _collect_collision_rids(node: Node, exclusions: Array[RID]) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		var rid: RID = collision_object.get_rid()
		if rid.is_valid() and not exclusions.has(rid):
			exclusions.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, exclusions)


func _ability_uses_lock_on_direction(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	var targeting_style: String = ability.get_targeting_style().strip_edges().to_lower()
	var delivery_type: String = ability.get_delivery_type().strip_edges().to_lower()
	return (
		targeting_style in [
			"aimed",
			"soft_aim",
			"target",
			"single_target",
			"target_lock",
			"lock_on",
			"homing",
		]
		or delivery_type in ["homing", "target_lock"]
	)


func get_input_mode_debug_data() -> Dictionary:
	var data: Dictionary = {
		"ground_targeting": is_ground_targeting(),
		"focus_modal": focus_spell_menu_open,
		"focus_library_visible": is_focus_library_open(),
	}
	if is_ground_targeting():
		var controller: RefCounted = get_ground_targeting_controller()
		if controller.has_method("get_debug_data"):
			data["targeting"] = controller.call("get_debug_data")
	return data
