extends Node3D

@export var blink_distance: float = 5.0
@export var wall_buffer: float = 0.8
@export var ray_height: float = 0.8

var hit_flash_scene: PackedScene = preload("res://scenes/effects/hit_flash.tscn")


func execute(player: Node3D, cast_direction: Vector3) -> void:
	var flat_direction: Vector3 = cast_direction
	flat_direction.y = 0.0

	if flat_direction.length() <= 0.01:
		flat_direction = -player.global_transform.basis.z

	flat_direction = flat_direction.normalized()

	var start_position: Vector3 = player.global_position
	var desired_position: Vector3 = start_position + flat_direction * blink_distance

	var ray_start: Vector3 = start_position + Vector3.UP * ray_height
	var ray_end: Vector3 = desired_position + Vector3.UP * ray_height

	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]

	var result: Dictionary = space_state.intersect_ray(query)

	var final_position: Vector3 = desired_position

	if not result.is_empty():
		var hit_position: Vector3 = result["position"]
		final_position = hit_position - flat_direction * wall_buffer
		final_position.y = start_position.y

	spawn_flash(start_position + Vector3.UP * 0.6)
	player.global_position = final_position
	spawn_flash(final_position + Vector3.UP * 0.6)

	queue_free()


func spawn_flash(spawn_position: Vector3) -> void:
	var flash: Node3D = hit_flash_scene.instantiate()
	get_tree().current_scene.add_child(flash)
	flash.global_position = spawn_position
