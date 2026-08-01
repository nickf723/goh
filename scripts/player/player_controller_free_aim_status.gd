extends "res://scripts/player/player_controller_free_aim.gd"
class_name PlayerControllerFreeAimStatus

@export_range(8.0, 160.0, 1.0) var free_aim_ray_distance: float = 80.0

var player_status_receiver: PlayerStatusReceiver
var preserved_step_velocity: Vector3 = Vector3.ZERO
var restore_step_velocity_after_move: bool = false


func _ready() -> void:
	super._ready()
	player_status_receiver = get_node_or_null(
		"StatusReceiver"
	) as PlayerStatusReceiver


func get_lock_on_cast_direction(cast_origin: Vector3 = Vector3.ZERO) -> Vector3:
	if has_lock_on_target():
		return super.get_lock_on_cast_direction(cast_origin)

	var soft_direction: Vector3 = get_soft_aim_cast_direction(cast_origin)
	if soft_direction.length_squared() > 0.0001:
		return soft_direction.normalized()

	var converged_direction: Vector3 = get_camera_center_cast_direction(cast_origin)
	if converged_direction.length_squared() > 0.0001:
		return converged_direction.normalized()

	var fallback: Vector3 = -global_transform.basis.z
	fallback.y = 0.0
	return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector3.FORWARD


func get_camera_center_cast_direction(cast_origin: Vector3 = Vector3.ZERO) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO

	var resolved_origin: Vector3 = cast_origin
	if resolved_origin == Vector3.ZERO:
		resolved_origin = global_position + Vector3.UP * lock_on_cast_origin_height

	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var screen_center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
	var ray_origin: Vector3 = camera.project_ray_origin(screen_center)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_center).normalized()
	if ray_direction.length_squared() <= 0.0001:
		return Vector3.ZERO

	var aim_point: Vector3 = ray_origin + ray_direction * free_aim_ray_distance
	var world: World3D = get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(ray_origin, aim_point)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.exclude = get_free_aim_exclusion_rids()
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		var hit_position: Variant = hit.get("position", null)
		if hit_position is Vector3:
			aim_point = hit_position as Vector3

	return resolve_projectile_direction_to_point(resolved_origin, aim_point)


func resolve_projectile_direction_to_point(
	cast_origin: Vector3,
	aim_point: Vector3
) -> Vector3:
	var direction: Vector3 = aim_point - cast_origin
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	return direction.normalized()


func get_free_aim_exclusion_rids() -> Array[RID]:
	var exclusions: Array[RID] = []
	_collect_collision_rids(self, exclusions)
	return exclusions


func _collect_collision_rids(node: Node, exclusions: Array[RID]) -> void:
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		var rid: RID = collision_object.get_rid()
		if rid.is_valid() and not exclusions.has(rid):
			exclusions.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, exclusions)


func handle_lock_on_target_switch_input() -> void:
	if is_focus_spell_menu_open():
		return
	super.handle_lock_on_target_switch_input()


func _get_requested_ground_velocity() -> Vector3:
	var requested: Vector3 = super._get_requested_ground_velocity()
	if player_status_receiver == null:
		return requested
	return requested * clampf(
		player_status_receiver.get_movement_multiplier(),
		0.0,
		1.0
	)


func _try_step_up(horizontal_velocity: Vector3, delta: float) -> bool:
	restore_step_velocity_after_move = false
	preserved_step_velocity = Vector3.ZERO
	if step_up_controller == null:
		return false

	var actual_planar_velocity: Vector3 = Vector3(
		velocity.x,
		0.0,
		velocity.z
	)
	if actual_planar_velocity.length_squared() <= 0.0001:
		actual_planar_velocity = horizontal_velocity
		actual_planar_velocity.y = 0.0

	var stepped: bool = step_up_controller.try_step_up(
		actual_planar_velocity,
		delta
	)
	if not stepped:
		return false

	# PlayerStepUpController already traversed the intended planar frame and settled
	# onto the next tread. Zero the duplicate move_and_slide motion, then restore the
	# authored velocity in _finish_step_up before the ground motor records its handoff.
	preserved_step_velocity = actual_planar_velocity
	velocity.x = 0.0
	velocity.z = 0.0
	restore_step_velocity_after_move = true
	return true


func _finish_step_up() -> void:
	super._finish_step_up()
	if not restore_step_velocity_after_move:
		return
	velocity.x = preserved_step_velocity.x
	velocity.z = preserved_step_velocity.z
	preserved_step_velocity = Vector3.ZERO
	restore_step_velocity_after_move = false
