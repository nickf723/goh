extends Node3D

const SafeDestinationQueryScript = preload("res://scripts/quality/safe_destination_query.gd")

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
	var wall_hit: Dictionary = space_state.intersect_ray(query)
	var candidate_position: Vector3 = desired_position
	if not wall_hit.is_empty():
		candidate_position = wall_hit.get("position", desired_position) - flat_direction * wall_buffer
		candidate_position.y = start_position.y

	var body: CharacterBody3D = player as CharacterBody3D
	var final_position: Vector3 = candidate_position
	if body != null:
		var safe_result: Dictionary = SafeDestinationQueryScript.find_safe_destination(body, candidate_position, {
			"start_position": start_position,
			"require_ground": body.is_on_floor(),
			"max_rise": 2.0,
			"max_drop": 4.5,
			"search_steps": 10,
		})
		if bool(safe_result.get("valid", false)):
			final_position = safe_result.get("position", start_position)
		else:
			final_position = start_position
			_show_message("Blink found no safe landing.")
		if final_position.distance_to(start_position) < 0.25:
			_show_message("Blink held Grace at the last safe position.")

	spawn_flash(start_position + Vector3.UP * 0.6)
	player.global_position = final_position
	if body != null and body.is_on_floor():
		body.velocity.y = 0.0
	spawn_flash(final_position + Vector3.UP * 0.6)
	queue_free()


func spawn_flash(spawn_position: Vector3) -> void:
	var flash: Node3D = hit_flash_scene.instantiate()
	get_tree().current_scene.add_child(flash)
	flash.global_position = spawn_position


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
