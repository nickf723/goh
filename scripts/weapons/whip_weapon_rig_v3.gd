extends Node3D
class_name WhipWeaponRigV3

@export_range(2.5, 7.0, 0.05) var whip_length: float = 4.55
@export_range(0.08, 0.6, 0.01) var contact_radius: float = 0.3
@export_range(6, 24, 1) var segment_count: int = 14
@export_range(4.0, 80.0, 1.0) var tip_max_speed: float = 38.0
@export_range(2.0, 40.0, 1.0) var tip_response: float = 20.0
@export_range(0.0, 1.5, 0.05) var idle_sag: float = 0.55
@export_range(0.0, 10.0, 0.25) var pull_strength: float = 4.5

var weapon: WeaponDefinition
var controller: WeaponController
var handle_anchor: Node3D
var line: ControlledFlexibleLine3D
var tip_marker: MeshInstance3D

var is_attacking: bool = false
var active_attack_id: String = ""
var current_tip_speed: float = 0.0
var peak_tip_speed: float = 0.0

var _desired_tip: Vector3 = Vector3.ZERO
var _visual_tip: Vector3 = Vector3.ZERO
var _previous_tip: Vector3 = Vector3.ZERO
var _curve_side: float = 0.0
var _curve_lift: float = 0.0
var _contact_strengths: Dictionary = {}
var _tip_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("weapon_runtime_rigs")
	add_to_group("whip_weapon_rigs")
	_build_rig()
	set_physics_process(true)


func configure_weapon(new_weapon: WeaponDefinition, new_controller: WeaponController) -> void:
	weapon = new_weapon
	controller = new_controller
	_apply_weapon_identity()
	_snap_idle()


func _physics_process(delta: float) -> void:
	if controller == null or handle_anchor == null or line == null:
		return
	_update_handle()
	if not is_attacking:
		_desired_tip = _idle_tip()
		_curve_side = lerpf(_curve_side, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		_curve_lift = lerpf(_curve_lift, -idle_sag, clampf(delta * 8.0, 0.0, 1.0))
	_drive_tip(delta)
	_update_line_points()
	_update_tip_speed(delta)
	_update_tip_visual()


func begin_attack(attack: WeaponAttackDefinition, _attack_speed: float) -> void:
	if attack == null:
		return
	is_attacking = true
	active_attack_id = attack.attack_id
	peak_tip_speed = 0.0
	_contact_strengths.clear()
	_previous_tip = _visual_tip


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or controller == null:
		return
	_update_handle()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active_end: float = startup + attack.get_active_duration(attack_speed)
	var total: float = attack.get_total_duration(attack_speed)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var reverse: bool = attack.extra_tags.has("reverse")
	var side_sign: float = -1.0 if reverse else 1.0

	if elapsed < startup:
		var p: float = smoothstep(0.0, 1.0, clampf(elapsed / maxf(startup, 0.01), 0.0, 1.0))
		if attack.extra_tags.has("precision"):
			_desired_tip = handle + forward * lerpf(0.9, minf(attack.attack_range, whip_length), p)
			_curve_side = side_sign * (1.0 - p) * 0.18
			_curve_lift = sin(p * PI) * 0.12
		elif attack.extra_tags.has("overhead"):
			_desired_tip = handle + forward * lerpf(0.8, minf(attack.attack_range, whip_length), p)
			_desired_tip.y += lerpf(1.45, -0.35, p)
			_curve_side = side_sign * sin(p * PI) * 0.1
			_curve_lift = lerpf(0.75, -0.08, p)
		else:
			var start_angle: float = deg_to_rad(-82.0 * side_sign)
			var angle: float = lerpf(start_angle, 0.0, p)
			var radius: float = lerpf(0.9, minf(attack.attack_range, whip_length), p)
			_desired_tip = handle + forward * cos(angle) * radius + right * sin(angle) * radius
			_desired_tip.y += sin(p * PI) * 0.2
			_curve_side = side_sign * sin(p * PI) * lerpf(0.62, 0.08, p)
			_curve_lift = sin(p * PI) * 0.16
	elif elapsed <= active_end:
		# Combat authority wins at the actual hit frame. The rendered line is placed
		# directly in the contact lane used by hit detection instead of asking a rope
		# simulation whether it happened to arrive in time.
		_desired_tip = handle + forward * minf(attack.attack_range, whip_length)
		if attack.extra_tags.has("overhead"):
			_desired_tip.y -= 0.28
		_visual_tip = _desired_tip
		_curve_side = 0.0
		_curve_lift = 0.0
		_update_line_points()
		_update_tip_visual()
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		_desired_tip = _desired_tip.lerp(_idle_tip(), recovery)
		_curve_side = lerpf(_curve_side, 0.0, recovery)
		_curve_lift = lerpf(_curve_lift, -idle_sag, recovery)


func end_attack() -> void:
	is_attacking = false
	active_attack_id = ""
	_contact_strengths.clear()
	_desired_tip = _idle_tip()


func find_weapon_targets(
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int
) -> Array[Node]:
	var targets: Array[Node] = []
	_contact_strengths.clear()
	if weapon_controller == null or attack == null or line == null:
		return targets
	var actor: Node3D = weapon_controller.get_actor()
	var sphere := SphereShape3D.new()
	sphere.radius = contact_radius
	var seen: Dictionary = {}
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for sample: Dictionary in line.get_contact_samples(true):
		var fraction: float = clampf(float(sample.get("fraction", 0.0)), 0.0, 1.0)
		if fraction < 0.16:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), sample.get("position", Vector3.ZERO) as Vector3)
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		if actor is CollisionObject3D:
			query.exclude = [(actor as CollisionObject3D).get_rid()]
		for result: Dictionary in space_state.intersect_shape(query, 20):
			var collider: Node = result.get("collider") as Node
			if collider == null:
				continue
			var target: Node = weapon_controller.find_payload_target(collider)
			if target == null or target == actor:
				continue
			var strength: float = 0.36 + 0.64 * pow(fraction, 1.35)
			var id: int = target.get_instance_id()
			_contact_strengths[id] = maxf(float(_contact_strengths.get(id, 0.0)), strength)
			if not seen.has(id):
				seen[id] = true
				targets.append(target)
				if targets.size() >= maxi(attack.max_targets, 1):
					return targets
	return targets


func modify_attack_payload(payload: DamagePayload, attack: WeaponAttackDefinition) -> void:
	if payload == null or attack == null:
		return
	var speed_factor: float = clampf(peak_tip_speed / 24.0, 0.72, 1.2)
	payload.amount = maxi(1, roundi(float(payload.amount) * speed_factor))
	payload.knockback_strength *= lerpf(0.62, 0.9, speed_factor / 1.2)
	_append_tag(payload, "flexible_weapon")
	_append_tag(payload, "whip")
	_append_tag(payload, "controlled_line")
	if peak_tip_speed >= 20.0 and (attack.extra_tags.has("crack") or attack.extra_tags.has("snap")):
		_append_tag(payload, "whip_crack")


func modify_payload_for_target(
	payload: DamagePayload,
	target: Node,
	_attack: WeaponAttackDefinition
) -> void:
	if payload == null or target == null:
		return
	var strength: float = clampf(float(_contact_strengths.get(target.get_instance_id(), 0.6)), 0.36, 1.0)
	payload.amount = maxi(1, roundi(float(payload.amount) * lerpf(0.68, 1.05, strength)))
	payload.stance_damage = maxi(0, roundi(float(payload.stance_damage) * lerpf(0.62, 1.0, strength)))
	payload.knockback_strength *= lerpf(0.55, 1.0, strength)
	_append_tag(payload, "whip_tip_contact" if strength >= 0.9 else "whip_body_contact")


func on_weapon_targets_hit(targets: Array[Node], attack: WeaponAttackDefinition) -> void:
	if attack == null or not attack.extra_tags.has("wrap") or targets.is_empty() or controller == null:
		return
	var target: Node = targets[0]
	var actor: Node3D = controller.get_actor()
	var force_receiver: Node = target.get_node_or_null("ForceReceiver")
	if actor == null or force_receiver == null or not force_receiver.has_method("apply_impulse"):
		return
	var direction: Vector3 = actor.global_position - controller.get_target_position(target)
	force_receiver.call(
		"apply_impulse",
		direction,
		pull_strength,
		0.25,
		weapon.display_name + " • " + attack.display_name if weapon != null else attack.display_name
	)


func get_debug_data() -> Dictionary:
	return {
		"type": "controlled_whip_v3",
		"attack": active_attack_id if active_attack_id != "" else "idle",
		"controlled_line": true,
		"full_line_contact": true,
		"segment_count": segment_count,
		"tip_speed": snappedf(current_tip_speed, 0.1),
		"peak_tip_speed": snappedf(peak_tip_speed, 0.1),
		"contact_targets": _contact_strengths.size(),
	}


func _build_rig() -> void:
	handle_anchor = Node3D.new()
	handle_anchor.name = "HandleAnchor"
	add_child(handle_anchor)
	var grip := MeshInstance3D.new()
	grip.name = "Grip"
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.055
	grip_mesh.bottom_radius = 0.07
	grip_mesh.height = 0.5
	grip_mesh.radial_segments = 10
	grip.mesh = grip_mesh
	grip.rotation_degrees.x = 90.0
	handle_anchor.add_child(grip)

	line = ControlledFlexibleLine3D.new()
	line.name = "ControlledWhipLine"
	add_child(line)
	line.configure(segment_count, 0.035, Color(0.34, 0.13, 0.08, 1.0), 0.05, 0.78)

	tip_marker = MeshInstance3D.new()
	tip_marker.name = "WhipTip"
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.075
	tip_mesh.height = 0.15
	tip_mesh.radial_segments = 10
	tip_mesh.rings = 6
	tip_marker.mesh = tip_mesh
	_tip_material = StandardMaterial3D.new()
	tip_marker.material_override = _tip_material
	add_child(tip_marker)


func _apply_weapon_identity() -> void:
	if weapon == null:
		return
	for child: Node in handle_anchor.get_children():
		if child is MeshInstance3D:
			var material := StandardMaterial3D.new()
			material.albedo_color = weapon.visual_secondary_color
			material.roughness = 0.55
			(child as MeshInstance3D).material_override = material
	line.set_color(weapon.visual_primary_color, 0.0)
	_tip_material.albedo_color = weapon.visual_accent_color
	_tip_material.emission_enabled = true
	_tip_material.emission = weapon.visual_accent_color
	_tip_material.emission_energy_multiplier = 0.55


func _snap_idle() -> void:
	_update_handle()
	_visual_tip = _idle_tip()
	_desired_tip = _visual_tip
	_previous_tip = _visual_tip
	_update_line_points()
	_update_tip_visual()


func _update_handle() -> void:
	if controller == null or handle_anchor == null:
		return
	handle_anchor.global_position = controller.get_attack_origin() + Vector3.DOWN * 0.22


func _forward() -> Vector3:
	if controller == null:
		return Vector3.FORWARD
	var forward: Vector3 = controller.get_attack_forward()
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func _idle_tip() -> Vector3:
	if handle_anchor == null:
		return global_position
	return handle_anchor.global_position + _forward() * 0.75 + Vector3.DOWN * 0.9


func _drive_tip(delta: float) -> void:
	var offset: Vector3 = _desired_tip - _visual_tip
	if offset.length_squared() <= 0.000001:
		_visual_tip = _desired_tip
		return
	var step: Vector3 = offset * (1.0 - exp(-tip_response * delta))
	var max_step: float = tip_max_speed * delta
	if step.length() > max_step:
		step = step.normalized() * max_step
	_visual_tip += step


func _update_tip_speed(delta: float) -> void:
	if delta <= 0.0:
		return
	current_tip_speed = _visual_tip.distance_to(_previous_tip) / delta
	peak_tip_speed = maxf(peak_tip_speed, current_tip_speed)
	_previous_tip = _visual_tip


func _update_line_points() -> void:
	if line == null or handle_anchor == null:
		return
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var points: Array[Vector3] = []
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var point: Vector3 = handle.lerp(_visual_tip, t)
		var envelope: float = sin(t * PI)
		point += right * _curve_side * envelope
		point += Vector3.UP * _curve_lift * envelope
		points.append(point)
	line.set_points(points)


func _update_tip_visual() -> void:
	if tip_marker != null:
		tip_marker.global_position = _visual_tip


func _append_tag(payload: DamagePayload, tag: String) -> void:
	if tag != "" and not payload.tags.has(tag):
		payload.tags.append(tag)
