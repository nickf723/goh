extends Node3D
class_name RepeatFirewallEcho

@export_range(0.05, 2.0, 0.05) var path_width: float = 0.18
@export_range(0.2, 4.0, 0.05) var flame_height: float = 2.2
@export_range(0.05, 1.0, 0.01) var contact_radius: float = 0.36
@export_range(0.05, 1.0, 0.01) var contact_tick_seconds: float = 0.25

var source_proxy: Node3D = null
var payload: DamagePayload = null
var path_points: Array[Dictionary] = []
var ignited: bool = false
var finished: bool = false
var contact_remaining: float = 0.0
var visual: MultiMeshInstance3D = null
var multimesh: MultiMesh = null
var unit_box: BoxMesh = null
var material: StandardMaterial3D = null
var sample_count: int = 0
var contact_query_count: int = 0
var target_hit_count: int = 0


func configure(proxy: Node3D, payload_override: Resource = null) -> void:
	source_proxy = proxy
	if payload_override is DamagePayload:
		payload = (payload_override as DamagePayload).duplicate(true) as DamagePayload
	if payload == null:
		payload = _fallback_payload()
	name = "RepeatFirewall"
	add_to_group("repeat_firewall_echoes")
	add_to_group("repeat_spell_replays")
	add_to_group("clone_spell_replays")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("debuggable")
	_build_visual()


func apply_sample(sample: Dictionary, delta: float) -> void:
	if finished:
		return
	var points_value: Variant = sample.get("path_points", [])
	if points_value is Array:
		path_points.clear()
		for value: Variant in points_value as Array:
			if value is Dictionary:
				path_points.append((value as Dictionary).duplicate(true))
	var phase: int = int(sample.get("phase", 0))
	# Firewall phase 0 is drawing in the authored implementation. Anything after
	# that represents eruption/linger/fade and therefore becomes hazardous.
	ignited = phase > 0
	_rebuild_visual()
	if ignited:
		contact_remaining -= maxf(delta, 0.0)
		if contact_remaining <= 0.0:
			contact_remaining += contact_tick_seconds
			_apply_contacts()
	sample_count += 1


func finish_replay() -> void:
	if finished:
		return
	finished = true
	queue_free()


func _build_visual() -> void:
	unit_box = BoxMesh.new()
	unit_box.size = Vector3.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = unit_box
	visual = MultiMeshInstance3D.new()
	visual.name = "RepeatFirewallSegments"
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.5, 0.28, 1.0, 1.0)
	material.emission_energy_multiplier = 3.6
	visual.material_override = material
	add_child(visual)


func _rebuild_visual() -> void:
	if multimesh == null:
		return
	var segment_count: int = maxi(path_points.size() - 1, 0)
	multimesh.instance_count = segment_count
	for index: int in range(segment_count):
		var a: Dictionary = path_points[index]
		var b: Dictionary = path_points[index + 1]
		var start: Vector3 = a.get("position", Vector3.ZERO) as Vector3
		var finish: Vector3 = b.get("position", start) as Vector3
		var normal_a: Vector3 = a.get("normal", Vector3.UP) as Vector3
		var normal_b: Vector3 = b.get("normal", normal_a) as Vector3
		var normal: Vector3 = (normal_a + normal_b).normalized()
		if normal.length_squared() <= 0.0001:
			normal = Vector3.UP
		var delta: Vector3 = finish - start
		var length: float = maxf(delta.length(), 0.02)
		var forward: Vector3 = delta.normalized() if delta.length_squared() > 0.0001 else Vector3.FORWARD
		var right: Vector3 = normal.cross(forward)
		if right.length_squared() <= 0.0001:
			right = Vector3.RIGHT
		right = right.normalized()
		forward = right.cross(normal).normalized()
		var height: float = flame_height if ignited else path_width
		var center: Vector3 = (start + finish) * 0.5 + normal * height * 0.5
		var basis := Basis(
			right * path_width,
			normal * height,
			forward * length
		)
		multimesh.set_instance_transform(index, Transform3D(basis, center))
		multimesh.set_instance_color(
			index,
			Color(1.0, 0.25, 0.06, 0.54) if ignited else Color(0.52, 0.34, 1.0, 0.52)
		)


func _apply_contacts() -> void:
	if get_world_3d() == null or path_points.size() < 2:
		return
	var seen: Dictionary = {}
	for point: Dictionary in path_points:
		var center: Vector3 = point.get("position", Vector3.ZERO) as Vector3
		var normal: Vector3 = point.get("normal", Vector3.UP) as Vector3
		if normal.length_squared() <= 0.0001:
			normal = Vector3.UP
		center += normal.normalized() * flame_height * 0.45
		var shape := SphereShape3D.new()
		shape.radius = maxf(contact_radius + flame_height * 0.28, 0.1)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, center)
		query.collision_mask = 0xFFFFFFFF
		query.collide_with_bodies = true
		query.collide_with_areas = true
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 48):
			var collider_value: Variant = hit.get("collider")
			if not collider_value is Node:
				continue
			var target: Node = _find_target(collider_value as Node)
			if target == null or _ignored(target):
				continue
			var target_id: int = target.get_instance_id()
			if seen.has(target_id):
				continue
			seen[target_id] = true
			_send_payload(target)
	contact_query_count += 1


func _find_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if (
			current.get_node_or_null("PayloadReceiver") != null
			or current.get_node_or_null("HitReceiver") != null
			or current.has_method("receive_damage_payload")
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _ignored(target: Node) -> bool:
	if source_proxy != null and (target == source_proxy or source_proxy.is_ancestor_of(target)):
		return true
	return target.is_in_group("repeat_echoes") or target.is_in_group("clone_spell_replays")


func _send_payload(target: Node) -> void:
	var resolved: DamagePayload = payload.duplicate(true) as DamagePayload
	resolved.source_name = "Repeat • Firewall"
	for tag: String in ["time", "repeat", "echo", "timeline_replay"]:
		if not resolved.tags.has(tag):
			resolved.tags.append(tag)
	var receiver: Node = target.get_node_or_null("PayloadReceiver")
	if receiver != null and receiver.has_method("receive_payload"):
		receiver.call("receive_payload", resolved)
	elif target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", resolved)
	else:
		var hit_receiver: Node = target.get_node_or_null("HitReceiver")
		if hit_receiver != null and hit_receiver.has_method("receive_payload"):
			hit_receiver.call("receive_payload", resolved)
	target_hit_count += 1


func _fallback_payload() -> DamagePayload:
	var result := DamagePayload.new()
	result.amount = 2
	result.stance_damage = 1
	result.element = "fire"
	result.source_name = "Firewall"
	result.hit_type = "lingering_wall"
	result.status_effect = "burning"
	result.status_duration = 1.4
	result.status_strength = 0.9
	result.tags = ["fire", "magic", "field", "hazard", "firewall"]
	return result


func get_debug_data() -> Dictionary:
	return {
		"repeat_firewall_echo": true,
		"points": path_points.size(),
		"ignited": ignited,
		"samples": sample_count,
		"contact_queries": contact_query_count,
		"target_hits": target_hit_count,
		"path_is_prerecorded": true,
		"finished": finished,
	}
