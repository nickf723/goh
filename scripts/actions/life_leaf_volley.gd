extends Node3D
class_name LifeLeafVolley

const LeafProjectileScene: PackedScene = preload(
	"res://scenes/actions/life_leaf_projectile.tscn"
)

@export_group("Volley")
@export_range(1, 8, 1) var projectiles_per_cast: int = 3
@export_range(0.02, 0.5, 0.01) var burst_interval: float = 0.11
@export_range(4.0, 40.0, 0.5) var target_range: float = 24.0
@export_range(5.0, 80.0, 1.0) var acquisition_cone_degrees: float = 38.0
@export_range(0.0, 0.5, 0.01) var spawn_forward_offset: float = 0.24
@export_range(0.0, 0.3, 0.01) var spawn_side_offset: float = 0.055

var source_actor: Node3D = null
var runtime_payload: DamagePayload = null
var cast_direction: Vector3 = Vector3.FORWARD
var resolved_targets: Array[Node3D] = []
var shots_spawned: int = 0
var burst_timer: float = 0.0
var burst_active: bool = false


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("leaf_volley_runtime")


func set_source_actor(actor: Node) -> void:
	if actor is Node3D:
		source_actor = actor as Node3D


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = new_payload as DamagePayload


func execute(player: Node3D, direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return
	cast_direction = direction.normalized() if direction.length_squared() > 0.0001 else -source_actor.global_basis.z
	resolved_targets = acquire_volley_targets()
	shots_spawned = 0
	burst_timer = 0.0
	burst_active = true
	_spawn_next_leaf()


func _process(delta: float) -> void:
	if not burst_active:
		return
	burst_timer -= maxf(delta, 0.0)
	if burst_timer > 0.0:
		return
	if shots_spawned >= projectiles_per_cast:
		burst_active = false
		queue_free()
		return
	_spawn_next_leaf()


func _spawn_next_leaf() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		burst_active = false
		queue_free()
		return
	if get_tree() == null or get_tree().current_scene == null:
		burst_active = false
		queue_free()
		return

	var projectile: LifeLeafProjectile = LeafProjectileScene.instantiate() as LifeLeafProjectile
	if projectile == null:
		burst_active = false
		queue_free()
		return

	get_tree().current_scene.add_child(projectile)
	projectile.set_source_actor(source_actor)
	if runtime_payload != null:
		projectile.set_payload(runtime_payload)

	var shot_index: int = shots_spawned
	var side_pattern: Array[float] = [-1.0, 0.0, 1.0]
	var side_sign: float = side_pattern[shot_index % side_pattern.size()]
	var origin: Vector3 = _get_cast_origin()
	var right: Vector3 = source_actor.global_basis.x.normalized()
	projectile.global_position = (
		origin
		+ cast_direction * spawn_forward_offset
		+ right * side_sign * spawn_side_offset
	)
	var target: Node3D = _get_target_for_shot(shot_index)
	projectile.set_homing_target(target)
	projectile.launch(cast_direction)

	shots_spawned += 1
	burst_timer = burst_interval
	if shots_spawned >= projectiles_per_cast:
		call_deferred("_finish_if_complete")


func _finish_if_complete() -> void:
	if shots_spawned >= projectiles_per_cast and burst_timer <= 0.0:
		burst_active = false
		queue_free()


func acquire_volley_targets() -> Array[Node3D]:
	var targets: Array[Node3D] = []
	if source_actor == null or not is_instance_valid(source_actor) or get_tree() == null:
		return targets

	var hard_target: Node3D = _get_hard_target()
	if hard_target != null:
		for _shot: int in range(projectiles_per_cast):
			targets.append(hard_target)
		return targets

	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
	var soft_target: Node3D = null
	if assist != null and is_instance_valid(assist):
		soft_target = _valid_node3d_reference(assist.get("soft_target"))

	for raw_candidate: Node in get_tree().get_nodes_in_group("enemy"):
		if not raw_candidate is Node3D:
			continue
		var candidate: Node3D = raw_candidate as Node3D
		if candidate == source_actor or not is_instance_valid(candidate):
			continue
		var candidate_id: int = candidate.get_instance_id()
		if seen.has(candidate_id):
			continue
		seen[candidate_id] = true

		var point: Vector3 = _get_target_point(candidate)
		var offset: Vector3 = point - _get_cast_origin()
		var distance: float = offset.length()
		if distance <= 0.1 or distance > target_range:
			continue
		var aim_dot: float = cast_direction.dot(offset.normalized())
		if aim_dot < cos(deg_to_rad(acquisition_cone_degrees)):
			continue
		if assist != null and assist.has_method("is_target_visible"):
			if not bool(assist.call("is_target_visible", candidate)):
				continue
		var score: float = (1.0 - aim_dot) * 18.0 + distance / target_range
		if candidate == soft_target:
			score -= 2.5
		rows.append({"target": candidate, "score": score})

	rows.sort_custom(_sort_target_rows)
	for row: Dictionary in rows:
		var candidate: Node3D = _valid_node3d_reference(row.get("target"))
		if candidate != null:
			targets.append(candidate)
		if targets.size() >= projectiles_per_cast:
			break
	return targets


func _sort_target_rows(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", INF)) < float(b.get("score", INF))


func _get_target_for_shot(shot_index: int) -> Node3D:
	if resolved_targets.is_empty():
		return null
	var index: int = posmod(shot_index, resolved_targets.size())
	return _valid_node3d_reference(resolved_targets[index])


func _get_hard_target() -> Node3D:
	if source_actor == null or not is_instance_valid(source_actor):
		return null

	# A killed target can remain in the player's property until the next player
	# update clears lock-on. Never run `is Node3D` on that freed Object reference:
	# is_instance_valid must be the first authority check.
	var lock_target: Node3D = _valid_node3d_reference(
		source_actor.get("lock_on_target")
	)
	if lock_target != null:
		return lock_target

	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
	if assist == null or not is_instance_valid(assist):
		return null
	return _valid_node3d_reference(assist.get("hard_target"))


func _valid_node3d_reference(value: Variant) -> Node3D:
	if typeof(value) != TYPE_OBJECT:
		return null
	if not is_instance_valid(value):
		return null
	if value is Node3D:
		return value as Node3D
	return null


func _get_target_point(target: Node3D) -> Vector3:
	if target == null or not is_instance_valid(target):
		return _get_cast_origin()
	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
	if assist != null and assist.has_method("get_target_aim_point"):
		var point_value: Variant = assist.call("get_target_aim_point", target)
		if point_value is Vector3:
			return point_value as Vector3
	return target.global_position + Vector3.UP * 0.65


func _get_cast_origin() -> Vector3:
	if source_actor == null or not is_instance_valid(source_actor):
		return global_position
	for anchor_path: String in [
		"GraceVisualV1/RightHandAnchor",
		"RightHandAnchor",
		"CastingHandAnchor",
	]:
		var anchor: Node3D = source_actor.get_node_or_null(anchor_path) as Node3D
		if anchor != null:
			return anchor.global_position
	var recursive_anchor: Node = source_actor.find_child("RightHandAnchor", true, false)
	if recursive_anchor is Node3D:
		return (recursive_anchor as Node3D).global_position
	return source_actor.global_position + Vector3.UP * 0.72


func get_debug_data() -> Dictionary:
	var target_names: Array[String] = []
	for target: Node3D in resolved_targets:
		if not is_instance_valid(target):
			continue
		target_names.append(target.name)
	return {
		"spell": "leaf_volley",
		"projectiles_per_cast": projectiles_per_cast,
		"shots_spawned": shots_spawned,
		"burst_interval": burst_interval,
		"targets": target_names,
		"distributes_without_lock": true,
		"focuses_hard_lock": true,
		"freed_target_safe": true,
	}
