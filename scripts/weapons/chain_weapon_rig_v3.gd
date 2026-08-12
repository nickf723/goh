extends Node3D
class_name ChainWeaponRigV3

@export_range(1.5, 5.0, 0.05) var chain_length: float = 3.25
@export_range(0.1, 5.0, 0.05) var tip_mass: float = 1.8
@export_range(0.1, 1.0, 0.02) var contact_radius: float = 0.34
@export_range(5, 20, 1) var segment_count: int = 11
@export_range(4.0, 40.0, 1.0) var head_max_speed: float = 22.0
@export_range(2.0, 30.0, 1.0) var head_response: float = 11.0
@export_range(0.0, 1.5, 0.05) var line_sag: float = 0.38

var weapon: WeaponDefinition
var controller: WeaponController
var handle_anchor: Node3D
var line: ControlledFlexibleLine3D
var weighted_tip: MeshInstance3D

var is_attacking: bool = false
var active_attack_id: String = ""
var current_tip_speed: float = 0.0
var peak_tip_speed: float = 0.0
var current_momentum: float = 0.0

var _desired_tip: Vector3 = Vector3.ZERO
var _visual_tip: Vector3 = Vector3.ZERO
var _tip_velocity: Vector3 = Vector3.ZERO
var _previous_tip: Vector3 = Vector3.ZERO
var _side_bend: float = 0.0
var _lift_bend: float = 0.0
var _contact_strengths: Dictionary = {}
var _tip_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("weapon_runtime_rigs")
	add_to_group("chain_weapon_rigs")
	_build_rig()
	set_physics_process(true)


func configure_weapon(new_weapon: WeaponDefinition, new_controller: WeaponController) -> void:
	weapon = new_weapon
	controller = new_controller
	_apply_weapon_identity()
	_snap_idle()


func _physics_process(delta: float) -> void:
	if controller == null or line == null:
		return
	_update_handle()
	if not is_attacking:
		_desired_tip = _idle_tip()
		_side_bend = lerpf(_side_bend, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		_lift_bend = lerpf(_lift_bend, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	_drive_head(delta)
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
	_tip_velocity *= 0.45


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

	if elapsed <= startup:
		var p: float = smoothstep(0.0, 1.0, clampf(elapsed / maxf(startup, 0.01), 0.0, 1.0))
		if attack.extra_tags.has("slam") or attack.extra_tags.has("ground_slam"):
			_desired_tip = handle + forward * lerpf(0.65, minf(chain_length, attack.attack_range), p)
			_desired_tip.y += lerpf(1.35, -0.45, p)
			_side_bend = side_sign * sin(p * PI) * 0.12
			_lift_bend = lerpf(0.45, -0.12, p)
		else:
			var start_angle: float = deg_to_rad(-108.0 * side_sign)
			var end_angle: float = deg_to_rad(108.0 * side_sign)
			var angle: float = lerpf(start_angle, end_angle, p)
			var radius: float = minf(chain_length, attack.attack_range) * lerpf(0.62, 1.0, p)
			_desired_tip = handle + forward * cos(angle) * radius + right * sin(angle) * radius
			_desired_tip.y += sin(p * PI) * 0.18
			_side_bend = side_sign * sin(p * PI) * 0.22
			_lift_bend = sin(p * PI) * 0.1
	elif elapsed <= active_end:
		_side_bend *= 0.84
		_lift_bend *= 0.84
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		_desired_tip = _desired_tip.lerp(_idle_tip(), recovery)
		_side_bend = lerpf(_side_bend, 0.0, recovery)
		_lift_bend = lerpf(_lift_bend, 0.0, recovery)


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
		if fraction < 0.14:
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
			var strength: float = 0.5 + 0.5 * pow(fraction, 1.25)
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
	var momentum_factor: float = clampf(current_momentum / 24.0, 0.72, 1.3)
	payload.knockback_strength *= lerpf(0.78, 1.28, momentum_factor / 1.3)
	payload.stance_damage = maxi(1, roundi(float(payload.stance_damage) * lerpf(0.84, 1.2, momentum_factor / 1.3)))
	_append_tag(payload, "flexible_weapon")
	_append_tag(payload, "chain")
	_append_tag(payload, "controlled_line")


func modify_payload_for_target(
	payload: DamagePayload,
	target: Node,
	_attack: WeaponAttackDefinition
) -> void:
	if payload == null or target == null:
		return
	var strength: float = clampf(float(_contact_strengths.get(target.get_instance_id(), 0.7)), 0.5, 1.0)
	payload.amount = maxi(1, roundi(float(payload.amount) * lerpf(0.76, 1.05, strength)))
	payload.stance_damage = maxi(1, roundi(float(payload.stance_damage) * lerpf(0.74, 1.08, strength)))
	payload.knockback_strength *= lerpf(0.68, 1.08, strength)
	_append_tag(payload, "weighted_tip" if strength >= 0.92 else "chain_body_contact")


func get_debug_data() -> Dictionary:
	return {
		"type": "controlled_chain_v3",
		"attack": active_attack_id if active_attack_id != "" else "idle",
		"controlled_line": true,
		"full_line_contact": true,
		"segment_count": segment_count,
		"tip_speed": snappedf(current_tip_speed, 0.1),
		"momentum": snappedf(current_momentum, 0.1),
		"contact_targets": _contact_strengths.size(),
	}


func _build_rig() -> void:
	handle_anchor = Node3D.new()
	handle_anchor.name = "HandleAnchor"
	add_child(handle_anchor)
	var grip := MeshInstance3D.new()
	grip.name = "Grip"
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.065
	grip_mesh.bottom_radius = 0.08
	grip_mesh.height = 0.48
	grip_mesh.radial_segments = 10
	grip.mesh = grip_mesh
	grip.rotation_degrees.x = 90.0
	handle_anchor.add_child(grip)

	line = ControlledFlexibleLine3D.new()
	line.name = "ControlledChainLine"
	add_child(line)
	line.configure(segment_count, 0.065, Color(0.28, 0.32, 0.38, 1.0), 0.82, 0.34)

	weighted_tip = MeshInstance3D.new()
	weighted_tip.name = "WeightedTip"
	var sphere := SphereMesh.new()
	sphere.radius = 0.27
	sphere.height = 0.54
	sphere.radial_segments = 14
	sphere.rings = 8
	weighted_tip.mesh = sphere
	_tip_material = StandardMaterial3D.new()
	weighted_tip.material_override = _tip_material
	add_child(weighted_tip)


func _apply_weapon_identity() -> void:
	if weapon == null:
		return
	for child: Node in handle_anchor.get_children():
		if child is MeshInstance3D:
			var material := StandardMaterial3D.new()
			material.albedo_color = weapon.visual_secondary_color
			material.metallic = 0.55
			material.roughness = 0.38
			(child as MeshInstance3D).material_override = material
	line.set_color(weapon.visual_primary_color, 0.0)
	_tip_material.albedo_color = weapon.visual_primary_color
	_tip_material.metallic = 0.78
	_tip_material.roughness = 0.26
	_tip_material.emission_enabled = true
	_tip_material.emission = weapon.visual_accent_color
	_tip_material.emission_energy_multiplier = 0.3


func _snap_idle() -> void:
	_update_handle()
	_visual_tip = _idle_tip()
	_desired_tip = _visual_tip
	_previous_tip = _visual_tip
	_tip_velocity = Vector3.ZERO
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
	return handle_anchor.global_position + _forward() * 0.55 + Vector3.DOWN * 0.95


func _drive_head(delta: float) -> void:
	if delta <= 0.0:
		return
	var offset: Vector3 = _desired_tip - _visual_tip
	var desired_velocity: Vector3 = offset * head_response
	if desired_velocity.length() > head_max_speed:
		desired_velocity = desired_velocity.normalized() * head_max_speed
	var blend: float = 1.0 - exp(-head_response * 0.65 * delta)
	_tip_velocity = _tip_velocity.lerp(desired_velocity, clampf(blend, 0.0, 1.0))
	_visual_tip += _tip_velocity * delta


func _update_tip_speed(delta: float) -> void:
	if delta <= 0.0:
		return
	current_tip_speed = _visual_tip.distance_to(_previous_tip) / delta
	peak_tip_speed = maxf(peak_tip_speed, current_tip_speed)
	current_momentum = current_tip_speed * tip_mass
	_previous_tip = _visual_tip


func _update_line_points() -> void:
	if line == null or handle_anchor == null:
		return
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var sag_amount: float = line_sag * (0.2 if is_attacking else 1.0)
	var points: Array[Vector3] = []
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var point: Vector3 = handle.lerp(_visual_tip, t)
		var envelope: float = sin(t * PI)
		point += right * _side_bend * envelope
		point += Vector3.UP * (_lift_bend - sag_amount) * envelope
		points.append(point)
	line.set_points(points)


func _update_tip_visual() -> void:
	if weighted_tip != null:
		weighted_tip.global_position = _visual_tip


func _append_tag(payload: DamagePayload, tag: String) -> void:
	if tag != "" and not payload.tags.has(tag):
		payload.tags.append(tag)
