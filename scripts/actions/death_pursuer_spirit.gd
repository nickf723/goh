extends Node3D
class_name DeathPursuerSpirit

const MODE_STALK: String = "stalk"
const MODE_DASH: String = "dash"
const MODE_DISSOLVE: String = "dissolve"

@export_group("Haunt")
@export_range(1, 10, 1) var maximum_passes: int = 4
@export_range(1.0, 12.0, 0.1) var maximum_lifetime: float = 6.4
@export_range(0.5, 5.0, 0.05) var stalk_radius: float = 2.35
@export_range(0.0, 3.0, 0.05) var stalk_height: float = 0.75
@export_range(1.0, 20.0, 0.1) var stalk_speed: float = 7.8
@export_range(0.1, 2.0, 0.05) var stalk_duration: float = 0.5
@export_range(4.0, 30.0, 0.25) var dash_speed: float = 16.5
@export_range(0.5, 5.0, 0.05) var dash_overshoot: float = 2.25
@export_range(0.2, 2.0, 0.05) var pass_hit_radius: float = 0.72
@export_range(0.1, 1.5, 0.05) var recovery_duration: float = 0.42
@export_range(0.0, 1.0, 0.01) var target_velocity_lead: float = 0.12

@export_group("Presentation")
@export_range(0.02, 0.3, 0.01) var trail_interval: float = 0.075
@export_range(0.1, 2.0, 0.05) var dissolve_duration: float = 0.28

var target_node: Node3D = null
var source_actor: Node = null
var runtime_payload: DamagePayload = null
var mode: String = MODE_STALK
var phase_timer: float = 0.0
var lifetime_timer: float = 0.0
var passes_completed: int = 0
var pass_damage_done: bool = false
var orbit_angle: float = 0.0
var dash_axis: Vector3 = Vector3.FORWARD
var trail_timer: float = 0.0
var last_motion_direction: Vector3 = Vector3.FORWARD
var visual_root: Node3D = null
var spirit_material: StandardMaterial3D = null
var pale_material: StandardMaterial3D = null
var dark_material: StandardMaterial3D = null
var dissolving: bool = false

const SPIRIT_RED: Color = Color(0.72, 0.09, 0.11, 0.72)
const SPIRIT_PALE: Color = Color(1.0, 0.58, 0.55, 0.82)
const SPIRIT_DARK: Color = Color(0.09, 0.015, 0.025, 0.82)


func _ready() -> void:
	add_to_group("death_pursuer_spirits")
	add_to_group("debuggable")
	lifetime_timer = maximum_lifetime
	phase_timer = stalk_duration
	_build_visual()


func configure(
	new_target: Node3D,
	new_source_actor: Node,
	new_payload: DamagePayload,
	entry_direction: Vector3 = Vector3.FORWARD
) -> bool:
	if new_target == null or not is_instance_valid(new_target):
		return false
	target_node = new_target
	source_actor = new_source_actor if new_source_actor != null and is_instance_valid(new_source_actor) else null
	runtime_payload = new_payload.duplicate(true) as DamagePayload if new_payload != null else _make_fallback_payload()
	var entry: Vector3 = entry_direction
	entry.y = 0.0
	if entry.length_squared() <= 0.0001:
		entry = Vector3.FORWARD
	entry = entry.normalized()
	orbit_angle = atan2(entry.z, entry.x) + PI * 0.5
	mode = MODE_STALK
	phase_timer = stalk_duration
	lifetime_timer = maximum_lifetime
	passes_completed = 0
	pass_damage_done = false
	return true


func _process(delta: float) -> void:
	if dissolving:
		return
	var step: float = maxf(delta, 0.0)
	lifetime_timer -= step
	if lifetime_timer <= 0.0:
		_begin_dissolve("expired")
		return
	if not _target_is_alive():
		_begin_dissolve("target_lost")
		return

	match mode:
		MODE_STALK:
			_advance_stalk(step)
		MODE_DASH:
			_advance_dash(step)
		_:
			_begin_dissolve("invalid_mode")
			return

	_update_visual(step)
	_update_trail(step)


func _advance_stalk(delta: float) -> void:
	phase_timer -= delta
	orbit_angle += delta * 0.7
	var target_point: Vector3 = _get_target_point()
	var orbit_offset := Vector3(
		cos(orbit_angle) * stalk_radius,
		stalk_height + sin(orbit_angle * 1.7) * 0.22,
		sin(orbit_angle) * stalk_radius
	)
	var desired_position: Vector3 = target_point + orbit_offset
	var previous: Vector3 = global_position
	global_position = global_position.move_toward(
		desired_position,
		stalk_speed * delta
	)
	_update_motion_direction(previous)
	if phase_timer <= 0.0:
		_start_dash()


func _start_dash() -> void:
	if not _target_is_alive():
		_begin_dissolve("target_lost")
		return
	var target_point: Vector3 = _get_target_point()
	dash_axis = target_point - global_position
	if dash_axis.length_squared() <= 0.0001:
		dash_axis = Vector3(cos(orbit_angle), 0.0, sin(orbit_angle))
	if dash_axis.length_squared() <= 0.0001:
		dash_axis = Vector3.FORWARD
	dash_axis = dash_axis.normalized()
	mode = MODE_DASH
	pass_damage_done = false


func _advance_dash(delta: float) -> void:
	var previous: Vector3 = global_position
	var target_point: Vector3 = _get_target_point()
	var target_velocity: Vector3 = _get_target_velocity()
	var damage_point: Vector3 = target_point + target_velocity * target_velocity_lead
	var dash_end: Vector3 = damage_point + dash_axis * dash_overshoot
	global_position = global_position.move_toward(
		dash_end,
		dash_speed * delta
	)
	_update_motion_direction(previous)

	if (
		not pass_damage_done
		and _segment_point_distance(previous, global_position, damage_point)
		<= pass_hit_radius
	):
		_apply_pass_damage()

	if global_position.distance_to(dash_end) <= 0.12:
		passes_completed += 1
		if passes_completed >= maximum_passes:
			_begin_dissolve("passes_complete")
			return
		mode = MODE_STALK
		phase_timer = recovery_duration
		orbit_angle += PI * (0.55 + float(passes_completed % 2) * 0.18)


func _apply_pass_damage() -> void:
	if pass_damage_done or not _target_is_alive():
		return
	pass_damage_done = true
	var impact_position: Vector3 = _get_target_point()
	var payload_to_send: DamagePayload = (
		runtime_payload.duplicate(true) as DamagePayload
		if runtime_payload != null
		else _make_fallback_payload()
	)
	payload_to_send.source_name = "Wraith Pursuit"
	payload_to_send.element = "death"
	payload_to_send.hit_type = "spirit_pass"
	if not payload_to_send.tags.has("spirit_pass"):
		payload_to_send.tags.append("spirit_pass")
	_send_payload(target_node, payload_to_send)
	_spawn_pass_flash(impact_position)


func _send_payload(target: Node, damage_payload: DamagePayload) -> void:
	if target == null or not is_instance_valid(target) or damage_payload == null:
		return
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		payload_receiver.call("receive_payload", damage_payload)
		return
	if target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", damage_payload)
		return
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			hit_receiver.call("receive_payload", damage_payload)
			return
		if hit_receiver.has_method("receive_hit"):
			hit_receiver.call("receive_hit", damage_payload.amount)
			return
	if target.has_method("receive_magic_hit"):
		target.call("receive_magic_hit", damage_payload.amount)


func _target_is_alive() -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if not target_node.is_inside_tree():
		return false
	var hit_receiver: Node = target_node.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		var health_value: Variant = hit_receiver.get("current_health")
		if health_value != null and int(health_value) <= 0:
			return false
	return true


func _get_target_point() -> Vector3:
	if not _target_is_alive():
		return global_position
	if target_node.has_method("get_targeting_aim_point"):
		var custom_value: Variant = target_node.call("get_targeting_aim_point")
		if custom_value is Vector3:
			return custom_value as Vector3
	if source_actor != null and is_instance_valid(source_actor) and source_actor is Node3D:
		var assist: Node = (source_actor as Node3D).get_node_or_null("CombatTargetingAssist")
		if assist != null and is_instance_valid(assist) and assist.has_method("get_target_aim_point"):
			var aim_value: Variant = assist.call("get_target_aim_point", target_node)
			if aim_value is Vector3:
				return aim_value as Vector3
	return target_node.global_position + Vector3.UP * 0.65


func _get_target_velocity() -> Vector3:
	if not _target_is_alive():
		return Vector3.ZERO
	if target_node is CharacterBody3D:
		return (target_node as CharacterBody3D).velocity
	if target_node is RigidBody3D:
		return (target_node as RigidBody3D).linear_velocity
	var velocity_value: Variant = target_node.get("velocity")
	return velocity_value as Vector3 if velocity_value is Vector3 else Vector3.ZERO


func _segment_point_distance(
	segment_start: Vector3,
	segment_end: Vector3,
	point: Vector3
) -> float:
	var segment: Vector3 = segment_end - segment_start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.000001:
		return segment_start.distance_to(point)
	var ratio: float = clampf(
		(point - segment_start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return (segment_start + segment * ratio).distance_to(point)


func _update_motion_direction(previous_position: Vector3) -> void:
	var motion: Vector3 = global_position - previous_position
	if motion.length_squared() <= 0.0001:
		return
	last_motion_direction = motion.normalized()
	if absf(last_motion_direction.dot(Vector3.UP)) < 0.98:
		look_at(global_position + last_motion_direction, Vector3.UP)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "WraithVisual"
	add_child(visual_root)

	spirit_material = _make_material(SPIRIT_RED, 1.8, 0.72)
	pale_material = _make_material(SPIRIT_PALE, 2.6, 0.82)
	dark_material = _make_material(SPIRIT_DARK, 0.45, 0.82)

	var head := MeshInstance3D.new()
	head.name = "WraithHead"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.42
	head_mesh.radial_segments = 12
	head_mesh.rings = 6
	head.mesh = head_mesh
	head.material_override = spirit_material
	head.position = Vector3(0.0, 0.08, -0.08)
	visual_root.add_child(head)

	for eye_x: float in [-0.075, 0.075]:
		var eye := MeshInstance3D.new()
		eye.name = "WraithEye"
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.036
		eye_mesh.height = 0.072
		eye_mesh.radial_segments = 7
		eye_mesh.rings = 4
		eye.mesh = eye_mesh
		eye.material_override = pale_material
		eye.position = Vector3(eye_x, 0.11, -0.285)
		visual_root.add_child(eye)

	for index: int in range(3):
		var tail := MeshInstance3D.new()
		tail.name = "WraithTail" + str(index + 1)
		var tail_mesh := SphereMesh.new()
		tail_mesh.radius = 0.13 - float(index) * 0.022
		tail_mesh.height = 0.24
		tail_mesh.radial_segments = 8
		tail_mesh.rings = 4
		tail.mesh = tail_mesh
		tail.material_override = spirit_material if index < 2 else dark_material
		tail.position = Vector3(
			sin(float(index) * 1.8) * 0.08,
			-0.02 - float(index) * 0.045,
			0.22 + float(index) * 0.2
		)
		tail.scale = Vector3(0.8, 0.72, 1.4 + float(index) * 0.3)
		visual_root.add_child(tail)


func _update_visual(delta: float) -> void:
	if visual_root == null:
		return
	var bob: float = sin(Time.get_ticks_msec() * 0.009 + float(get_instance_id() % 17)) * 0.055
	visual_root.position.y = bob
	visual_root.rotation.z = sin(Time.get_ticks_msec() * 0.007) * 0.08
	var desired_scale: Vector3 = (
		Vector3(0.82, 0.82, 1.55)
		if mode == MODE_DASH
		else Vector3.ONE
	)
	visual_root.scale = visual_root.scale.lerp(
		desired_scale,
		clampf(delta * 10.0, 0.0, 1.0)
	)


func _update_trail(delta: float) -> void:
	trail_timer -= delta
	if trail_timer > 0.0:
		return
	trail_timer = trail_interval
	if get_tree() == null or get_tree().current_scene == null:
		return
	var wisp := MeshInstance3D.new()
	wisp.name = "WraithAfterimage"
	wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	mesh.radial_segments = 7
	mesh.rings = 4
	wisp.mesh = mesh
	wisp.material_override = _make_material(SPIRIT_RED, 0.85, 0.34)
	get_tree().current_scene.add_child(wisp)
	wisp.global_position = global_position - last_motion_direction * 0.18
	var tween := wisp.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wisp, "scale", Vector3.ZERO, 0.32)
	tween.tween_property(wisp, "global_position", wisp.global_position + Vector3.UP * 0.22, 0.32)
	tween.set_parallel(false)
	tween.tween_callback(Callable(wisp, "queue_free"))


func _spawn_pass_flash(impact_position: Vector3) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var flash := MeshInstance3D.new()
	flash.name = "SpiritPassFlash"
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.24
	mesh.outer_radius = 0.32
	mesh.rings = 14
	mesh.ring_segments = 7
	flash.mesh = mesh
	flash.material_override = _make_material(SPIRIT_PALE, 2.2, 0.72)
	get_tree().current_scene.add_child(flash)
	flash.global_position = impact_position
	flash.scale = Vector3.ONE * 0.45
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.8, 0.2)
	tween.tween_callback(Callable(flash, "queue_free"))


func _begin_dissolve(_reason: String) -> void:
	if dissolving:
		return
	dissolving = true
	mode = MODE_DISSOLVE
	target_node = null
	if visual_root == null or not is_instance_valid(visual_root):
		queue_free()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector3.ZERO, dissolve_duration)
	tween.tween_property(visual_root, "rotation:y", visual_root.rotation.y + PI, dissolve_duration)
	tween.set_parallel(false)
	tween.tween_callback(Callable(self, "queue_free"))


func _make_material(
	color: Color,
	emission_energy: float,
	alpha: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.35
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _make_fallback_payload() -> DamagePayload:
	var fallback := DamagePayload.new()
	fallback.amount = 1
	fallback.stance_damage = 1
	fallback.element = "death"
	fallback.source_name = "Wraith Pursuit"
	fallback.hit_type = "spirit_pass"
	fallback.tags = ["death", "magic", "spirit", "spirit_pass"]
	return fallback


func get_debug_data() -> Dictionary:
	return {
		"spell": "wraith_pursuit",
		"mode": mode,
		"target": target_node.name if _target_is_alive() else "none",
		"passes_completed": passes_completed,
		"maximum_passes": maximum_passes,
		"pass_damage_done": pass_damage_done,
		"lifetime_remaining": snappedf(maxf(lifetime_timer, 0.0), 0.01),
		"follows_target": true,
		"damages_only_on_crossing": true,
		"freed_target_safe": true,
	}
