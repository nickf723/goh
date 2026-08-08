extends Node3D
class_name IllusionCast

const IllusionDecoyScript = preload(
	"res://scripts/dream/illusion_decoy.gd"
)

@export_range(2.0, 30.0, 0.5) var maximum_range: float = 14.0
@export_range(1.0, 20.0, 0.5) var fallback_distance: float = 8.0
@export_range(1.0, 20.0, 0.5) var ground_probe_height: float = 7.0
@export_range(1.0, 30.0, 0.5) var ground_probe_depth: float = 14.0
@export_flags_3d_physics var collision_mask: int = 1
@export_range(0.0, 0.2, 0.005) var surface_offset: float = 0.04

var source_actor: Node3D = null
var last_target_position: Vector3 = Vector3.ZERO
var last_cast_serial: int = 0
var target_was_replay_metadata: bool = false


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	last_target_position = _resolve_target_position(cast_direction)
	_replace_existing_source_illusion()
	last_cast_serial = int(source_actor.get_meta("illusion_cast_serial", 0)) + 1
	source_actor.set_meta("illusion_cast_serial", last_cast_serial)

	var decoy := IllusionDecoyScript.new() as DreamIllusionDecoy
	decoy.name = "DreamIllusion_%d" % last_cast_serial
	decoy.position = last_target_position
	decoy.set_meta("clone_spell_replay", bool(get_meta("clone_spell_replay", false)))
	decoy.set_meta("clone_spell_kind", str(get_meta("clone_spell_kind", "original")))
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		queue_free()
		return
	scene_root.add_child(decoy)
	decoy.global_position = last_target_position
	decoy.configure(source_actor, last_cast_serial)
	_notify_repeat_metadata()
	queue_free()


func get_clone_cast_metadata() -> Dictionary:
	return {
		"target_world_position": last_target_position,
		"illusion_cast_serial": last_cast_serial,
	}


func _resolve_target_position(cast_direction: Vector3) -> Vector3:
	if source_actor.has_meta("clone_cast_target_world_position"):
		var metadata_value: Variant = source_actor.get_meta(
			"clone_cast_target_world_position"
		)
		if metadata_value is Vector3:
			target_was_replay_metadata = true
			return metadata_value as Vector3

	var world: World3D = source_actor.get_world_3d()
	var direction: Vector3 = cast_direction
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_transform.basis.z
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var ray_origin: Vector3 = source_actor.global_position + Vector3.UP * 1.05
	var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
	if camera != null:
		ray_origin = camera.global_position
	var ray_end: Vector3 = ray_origin + direction * maximum_range
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_end,
			collision_mask,
			_collect_source_rids()
		)
		query.collide_with_areas = false
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_position: Vector3 = hit.get("position", ray_end) as Vector3
			var hit_normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
			if hit_normal.y >= 0.45:
				return hit_position + hit_normal * surface_offset
			return _probe_ground(hit_position - direction * 0.45)

	var planar: Vector3 = direction
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		planar = -source_actor.global_transform.basis.z
		planar.y = 0.0
	planar = planar.normalized() if planar.length_squared() > 0.0001 else Vector3.FORWARD
	return _probe_ground(source_actor.global_position + planar * fallback_distance)


func _probe_ground(near_position: Vector3) -> Vector3:
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return near_position
	var from: Vector3 = near_position + Vector3.UP * ground_probe_height
	var to: Vector3 = near_position - Vector3.UP * ground_probe_depth
	var query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		collision_mask,
		_collect_source_rids()
	)
	query.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		var fallback: Vector3 = near_position
		fallback.y = source_actor.global_position.y - 0.92
		return fallback
	var position_value: Vector3 = hit.get("position", near_position) as Vector3
	var normal_value: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	return position_value + normal_value * surface_offset


func _replace_existing_source_illusion() -> void:
	var source_id: int = source_actor.get_instance_id()
	for node: Node in get_tree().get_nodes_in_group("illusion_decoys"):
		if node == null or not is_instance_valid(node):
			continue
		if int(node.get_meta("illusion_source_id", 0)) != source_id:
			continue
		if node.has_method("expire_illusion"):
			node.call("expire_illusion", "recast")
		else:
			node.queue_free()


func _notify_repeat_metadata() -> void:
	var repeat_controller: Node = get_tree().get_first_node_in_group(
		"repeat_echo_controller"
	)
	if repeat_controller == null:
		return
	if repeat_controller.has_method("record_illusion_cast_metadata"):
		repeat_controller.call(
			"record_illusion_cast_metadata",
			self,
			get_clone_cast_metadata()
		)


func _collect_source_rids() -> Array[RID]:
	var result: Array[RID] = []
	_collect_collision_rids(source_actor, result)
	return result


func _collect_collision_rids(node: Node, result: Array[RID]) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not result.has(rid):
			result.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, result)


func get_debug_data() -> Dictionary:
	return {
		"illusion_cast": true,
		"target_position": last_target_position,
		"cast_serial": last_cast_serial,
		"used_replay_metadata": target_was_replay_metadata,
		"maximum_range": maximum_range,
	}
