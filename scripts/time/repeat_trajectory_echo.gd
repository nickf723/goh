extends Node3D
class_name RepeatTrajectoryEcho

const EchoTintScript = preload(
	"res://scripts/time/repeat_echo_spell_tint.gd"
)

@export_range(0.02, 3.0, 0.01) var default_hit_radius: float = 0.28
@export_range(0.02, 2.0, 0.01) var repeat_target_cooldown: float = 0.25
@export_range(1, 128, 1) var maximum_overlap_results: int = 48

var ability: AbilityDefinition = null
var source_proxy: Node3D = null
var payload: DamagePayload = null
var visual_shell: Node = null
var hit_radius: float = 0.28
var previous_position: Vector3 = Vector3.ZERO
var has_previous_position: bool = false
var hit_elapsed: float = 0.0
var target_last_hit: Dictionary = {}
var unique_target_hits: int = 0
var sweep_count: int = 0
var sample_count: int = 0
var replay_finished: bool = false


func configure(
	ability_definition: AbilityDefinition,
	proxy: Node3D,
	payload_override: Resource = null
) -> void:
	ability = ability_definition
	source_proxy = proxy
	if payload_override is DamagePayload:
		payload = (payload_override as DamagePayload).duplicate(true) as DamagePayload
	elif ability != null and ability.get_action_payload() is DamagePayload:
		payload = (
			ability.get_action_payload() as DamagePayload
		).duplicate(true) as DamagePayload
	name = "RepeatTrajectory_" + (
		ability.get_spell_id() if ability != null else "spell"
	)
	set_meta("clone_spell_replay", true)
	set_meta("repeat_memory_root", true)
	add_to_group("repeat_trajectory_echoes")
	add_to_group("clone_spell_replays")
	add_to_group("repeat_spell_replays")
	add_to_group("spell_effects")
	add_to_group("debuggable")
	_build_visual_shell()


func advance_to(transform_value: Transform3D, delta: float) -> void:
	if replay_finished:
		return
	hit_elapsed += maxf(delta, 0.0)
	var next_position: Vector3 = transform_value.origin
	if has_previous_position:
		_sweep_new_targets(previous_position, next_position)
	global_transform = transform_value
	previous_position = next_position
	has_previous_position = true
	sample_count += 1


func finish_replay() -> void:
	if replay_finished:
		return
	replay_finished = true
	queue_free()


func _build_visual_shell() -> void:
	if ability == null or ability.ability_scene == null:
		return
	visual_shell = ability.ability_scene.instantiate()
	if visual_shell == null:
		return
	visual_shell.name = "RememberedSpellVisual"
	# This metadata must exist before the shell enters the SceneTree. Otherwise
	# Repeat's node-added observer sees the original scene path and mistakes its
	# own visual memory for another player cast, recursively creating memories.
	_tag_clone_subtree(visual_shell)
	_neutralize_recursive(visual_shell)
	var tint: Node = EchoTintScript.new()
	tint.name = "RepeatTimelineTint"
	visual_shell.add_child(tint)
	add_child(visual_shell)
	hit_radius = maxf(_infer_collision_radius(visual_shell), default_hit_radius)


func _tag_clone_subtree(node: Node) -> void:
	if node == null:
		return
	node.set_meta("clone_spell_replay", true)
	node.set_meta("clone_spell_kind", "repeat")
	node.set_meta("repeat_memory_visual", true)
	for child: Node in node.get_children():
		_tag_clone_subtree(child)


func _neutralize_recursive(node: Node) -> void:
	if node == null:
		return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	if node is RigidBody3D:
		var rigid := node as RigidBody3D
		rigid.freeze = true
		rigid.sleeping = true
		rigid.linear_velocity = Vector3.ZERO
		rigid.angular_velocity = Vector3.ZERO
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is Area3D:
		var area := node as Area3D
		area.monitoring = false
		area.monitorable = false
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is Light3D:
		(node as Light3D).shadow_enabled = false
	for child: Node in node.get_children():
		_neutralize_recursive(child)


func _infer_collision_radius(node: Node) -> float:
	var best: float = default_hit_radius
	if node is CollisionShape3D:
		var shape: Shape3D = (node as CollisionShape3D).shape
		if shape is SphereShape3D:
			best = maxf(best, (shape as SphereShape3D).radius)
		elif shape is CapsuleShape3D:
			best = maxf(best, (shape as CapsuleShape3D).radius)
		elif shape is CylinderShape3D:
			best = maxf(best, (shape as CylinderShape3D).radius)
		elif shape is BoxShape3D:
			var size: Vector3 = (shape as BoxShape3D).size
			best = maxf(best, maxf(size.x, size.z) * 0.5)
	for child: Node in node.get_children():
		best = maxf(best, _infer_collision_radius(child))
	return best


func _sweep_new_targets(from: Vector3, to: Vector3) -> void:
	if payload == null or get_world_3d() == null:
		return
	var displacement: Vector3 = to - from
	var distance: float = displacement.length()
	var steps: int = maxi(ceili(distance / maxf(hit_radius * 0.8, 0.12)), 1)
	var seen_this_sweep: Dictionary = {}
	for step_index: int in range(steps + 1):
		var ratio: float = float(step_index) / float(steps)
		var center: Vector3 = from.lerp(to, ratio)
		var shape := SphereShape3D.new()
		shape.radius = hit_radius
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, center)
		query.collision_mask = 0xFFFFFFFF
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(
			query,
			maximum_overlap_results
		)
		for hit: Dictionary in hits:
			var collider_value: Variant = hit.get("collider")
			if not collider_value is Node:
				continue
			var target: Node = _find_payload_target(collider_value as Node)
			if target == null or _is_ignored_target(target):
				continue
			var target_id: int = target.get_instance_id()
			if seen_this_sweep.has(target_id):
				continue
			seen_this_sweep[target_id] = true
			var previous_hit_time: float = float(
				target_last_hit.get(target_id, -INF)
			)
			if hit_elapsed - previous_hit_time < repeat_target_cooldown:
				continue
			target_last_hit[target_id] = hit_elapsed
			_send_payload(target)
			unique_target_hits += 1
	sweep_count += 1


func _find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if _is_payload_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_payload_target(node: Node) -> bool:
	return (
		node.get_node_or_null("PayloadReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.has_method("receive_damage_payload")
		or node.has_method("receive_magic_hit")
	)


func _is_ignored_target(target: Node) -> bool:
	if target == null:
		return true
	if source_proxy != null and (
		target == source_proxy or source_proxy.is_ancestor_of(target)
	):
		return true
	if target.is_in_group("repeat_echoes") or target.is_in_group("clone_spell_replays"):
		return true
	return false


func _send_payload(target: Node) -> Dictionary:
	var resolved: DamagePayload = payload.duplicate(true) as DamagePayload
	resolved.source_name = "Repeat • " + resolved.source_name
	for tag: String in ["time", "repeat", "echo", "timeline_replay"]:
		if not resolved.tags.has(tag):
			resolved.tags.append(tag)
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		var received: Variant = payload_receiver.call("receive_payload", resolved)
		return received as Dictionary if received is Dictionary else {}
	if target.has_method("receive_damage_payload"):
		var direct: Variant = target.call("receive_damage_payload", resolved)
		return direct as Dictionary if direct is Dictionary else {}
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		var hit_value: Variant = hit_receiver.call("receive_payload", resolved)
		return hit_value as Dictionary if hit_value is Dictionary else {}
	if target.has_method("receive_magic_hit"):
		target.call("receive_magic_hit", resolved.amount)
	return {}


func get_debug_data() -> Dictionary:
	return {
		"repeat_trajectory_echo": true,
		"spell_id": ability.get_spell_id() if ability != null else "",
		"sample_count": sample_count,
		"sweeps": sweep_count,
		"new_target_hits": unique_target_hits,
		"hit_radius": hit_radius,
		"path_is_timeline_authoritative": true,
		"collisions_cannot_redirect_replay": true,
		"visual_shell_clone_tagged": (
			visual_shell != null
			and bool(visual_shell.get_meta("clone_spell_replay", false))
		),
		"finished": replay_finished,
	}
