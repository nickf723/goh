extends Node3D
class_name ChainWeaponRig3D

const IronChain: FlexibleMaterialProfile = preload("res://data/flexible_materials/iron_chain.tres")

@export_range(1.5, 6.0, 0.05) var chain_length: float = 3.25
@export_range(0.1, 5.0, 0.05) var tip_mass: float = 1.8
@export_range(0.1, 1.2, 0.05) var contact_radius: float = 0.58
@export_range(8, 32, 1) var maximum_sweep_samples: int = 20

var weapon: WeaponDefinition
var controller: WeaponController
var handle_anchor: Node3D
var weighted_tip: Node3D
var tether: FlexibleTether3D

var current_tip_speed: float = 0.0
var peak_tip_speed: float = 0.0
var current_momentum: float = 0.0
var is_attacking: bool = false
var active_attack_id: String = ""

var _previous_tip_position: Vector3
var _last_attack_elapsed: float = 0.0
var _sweep_points: Array[Vector3] = []
var _tip_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("weapon_runtime_rigs")
	add_to_group("chain_weapon_rigs")
	_build_rig()
	set_process(true)


func configure_weapon(new_weapon: WeaponDefinition, new_controller: WeaponController) -> void:
	weapon = new_weapon
	controller = new_controller
	if not is_node_ready():
		call_deferred("configure_weapon", new_weapon, new_controller)
		return
	_apply_weapon_identity()
	_snap_to_idle()


func _process(delta: float) -> void:
	if controller == null or weighted_tip == null:
		return

	if not is_attacking:
		var idle_target: Vector3 = _get_handle_position() + _get_forward() * 0.45 + Vector3.DOWN * 0.9
		weighted_tip.global_position = weighted_tip.global_position.lerp(idle_target, clampf(delta * 9.0, 0.0, 1.0))
		_update_handle()
		_update_tip_kinematics(delta)


func begin_attack(attack: WeaponAttackDefinition, _attack_speed: float) -> void:
	if attack == null:
		return
	is_attacking = true
	active_attack_id = attack.attack_id
	_last_attack_elapsed = 0.0
	_sweep_points.clear()
	_update_handle()
	_previous_tip_position = weighted_tip.global_position
	_sweep_points.append(_previous_tip_position)
	_update_tip_material(true)


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or weighted_tip == null:
		return

	_update_handle()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active_end: float = startup + attack.get_active_duration(attack_speed)
	var total: float = attack.get_total_duration(attack_speed)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _get_forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var target: Vector3

	if elapsed <= startup:
		var weight: float = smoothstep(0.0, 1.0, clampf(elapsed / maxf(startup, 0.01), 0.0, 1.0))
		if attack.extra_tags.has("slam"):
			target = handle + forward * lerpf(0.8, chain_length * 1.04, weight)
			target.y += lerpf(2.25, -0.55, weight)
		else:
			var reverse: bool = attack.extra_tags.has("reverse")
			var start_angle: float = deg_to_rad(112.0 if reverse else -112.0)
			var end_angle: float = deg_to_rad(-112.0 if reverse else 112.0)
			var angle: float = lerpf(start_angle, end_angle, weight)
			var radius: float = minf(
				chain_length * lerpf(0.82, 1.04, weight),
				maxf(attack.attack_range, 1.0)
			)
			target = (
				handle
				+ forward * (cos(angle) * radius)
				+ right * (sin(angle) * radius)
				+ Vector3.UP * lerpf(0.2, -0.08, absf(weight - 0.5) * 2.0)
			)
		_append_sweep_point(target)
	elif elapsed <= active_end:
		target = weighted_tip.global_position
	else:
		var recovery_weight: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		var idle_target: Vector3 = handle + forward * 0.45 + Vector3.DOWN * 0.9
		target = weighted_tip.global_position.lerp(idle_target, recovery_weight)

	weighted_tip.global_position = target
	_update_tip_kinematics(maxf(elapsed - _last_attack_elapsed, 0.001))
	_last_attack_elapsed = elapsed


func end_attack() -> void:
	is_attacking = false
	active_attack_id = ""
	_sweep_points.clear()
	_update_tip_material(false)


func find_weapon_targets(
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int
) -> Array[Node]:
	var targets: Array[Node] = []
	if weapon_controller == null or attack == null:
		return targets

	var actor: Node3D = weapon_controller.get_actor()
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = contact_radius
	var seen: Dictionary = {}

	for sample_position: Vector3 in _get_contact_samples():
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), sample_position)
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		if actor is CollisionObject3D:
			query.exclude = [actor.get_rid()]

		for result: Dictionary in space_state.intersect_shape(query, 24):
			var collider: Node = result.get("collider") as Node
			if collider == null:
				continue
			var target: Node = weapon_controller.find_payload_target(collider)
			if target == null or target == actor:
				continue
			var target_id: int = target.get_instance_id()
			if seen.has(target_id):
				continue
			seen[target_id] = true
			targets.append(target)
			if targets.size() >= max(attack.max_targets, 1):
				return targets

	return targets


func modify_attack_payload(payload: DamagePayload, attack: WeaponAttackDefinition) -> void:
	if payload == null or attack == null:
		return
	var momentum_ratio: float = clampf(current_momentum / 22.0, 0.72, 1.45)
	payload.knockback_strength *= momentum_ratio
	payload.stance_damage = max(1, roundi(float(payload.stance_damage) * lerpf(0.9, 1.2, momentum_ratio / 1.45)))
	if not payload.tags.has("flexible_weapon"):
		payload.tags.append("flexible_weapon")
	if not payload.tags.has("weighted_tip"):
		payload.tags.append("weighted_tip")


func get_debug_data() -> Dictionary:
	return {
		"type": "weighted_chain",
		"attack": active_attack_id if active_attack_id != "" else "idle",
		"tip_speed": snapped(current_tip_speed, 0.1),
		"peak_tip_speed": snapped(peak_tip_speed, 0.1),
		"momentum": snapped(current_momentum, 0.1),
		"tension": snapped(tether.current_tension, 0.1) if tether != null else 0.0,
		"sweep_samples": _sweep_points.size(),
	}


func _build_rig() -> void:
	handle_anchor = Node3D.new()
	handle_anchor.name = "HandleAnchor"
	add_child(handle_anchor)

	var grip: MeshInstance3D = MeshInstance3D.new()
	grip.name = "Grip"
	var grip_mesh: CylinderMesh = CylinderMesh.new()
	grip_mesh.top_radius = 0.07
	grip_mesh.bottom_radius = 0.08
	grip_mesh.height = 0.48
	grip_mesh.radial_segments = 10
	grip.mesh = grip_mesh
	grip.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	handle_anchor.add_child(grip)

	weighted_tip = Node3D.new()
	weighted_tip.name = "WeightedTip"
	add_child(weighted_tip)

	var weight_mesh: MeshInstance3D = MeshInstance3D.new()
	weight_mesh.name = "MeteorWeight"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.26
	sphere.height = 0.52
	sphere.radial_segments = 14
	sphere.rings = 8
	weight_mesh.mesh = sphere
	_tip_material = StandardMaterial3D.new()
	weight_mesh.material_override = _tip_material
	weighted_tip.add_child(weight_mesh)

	tether = FlexibleTether3D.new()
	tether.name = "FlexibleChain"
	tether.endpoint_a_path = NodePath("../HandleAnchor")
	tether.endpoint_b_path = NodePath("../WeightedTip")
	tether.material_profile = IronChain
	tether.rest_length = chain_length
	tether.segment_count = 13
	tether.constraint_iterations = 8
	tether.gravity_scale = 0.45
	tether.apply_endpoint_forces = false
	tether.debug_tension_color = true
	add_child(tether)


func _apply_weapon_identity() -> void:
	if weapon == null:
		return
	for child: Node in handle_anchor.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _make_material(weapon.visual_secondary_color, false)
	_update_tip_material(false)


func _update_tip_material(active: bool) -> void:
	if _tip_material == null:
		return
	var color: Color = weapon.visual_primary_color if weapon != null else Color(0.2, 0.22, 0.28, 1.0)
	var accent: Color = weapon.visual_accent_color if weapon != null else Color(1.0, 0.4, 0.08, 1.0)
	_tip_material.albedo_color = color.lerp(accent, 0.35 if active else 0.0)
	_tip_material.metallic = 0.75
	_tip_material.roughness = 0.24
	_tip_material.emission_enabled = active
	_tip_material.emission = accent
	_tip_material.emission_energy_multiplier = 1.1 if active else 0.0


func _make_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.55
	material.roughness = 0.32
	material.emission_enabled = emissive
	material.emission = color
	material.emission_energy_multiplier = 0.7 if emissive else 0.0
	return material


func _update_handle() -> void:
	if handle_anchor == null:
		return
	handle_anchor.global_position = _get_handle_position()


func _get_handle_position() -> Vector3:
	if controller == null:
		return global_position
	return controller.get_attack_origin() + Vector3.DOWN * 0.22


func _get_forward() -> Vector3:
	if controller == null:
		return Vector3.FORWARD
	return controller.get_attack_forward()


func _snap_to_idle() -> void:
	if weighted_tip == null:
		return
	_update_handle()
	weighted_tip.global_position = _get_handle_position() + _get_forward() * 0.45 + Vector3.DOWN * 0.9
	_previous_tip_position = weighted_tip.global_position
	if tether != null:
		tether.reset_tether()


func _update_tip_kinematics(delta: float) -> void:
	if weighted_tip == null or delta <= 0.0:
		return
	current_tip_speed = weighted_tip.global_position.distance_to(_previous_tip_position) / delta
	peak_tip_speed = maxf(peak_tip_speed, current_tip_speed)
	current_momentum = current_tip_speed * tip_mass
	_previous_tip_position = weighted_tip.global_position


func _append_sweep_point(point: Vector3) -> void:
	if _sweep_points.is_empty() or _sweep_points[-1].distance_to(point) >= contact_radius * 0.45:
		_sweep_points.append(point)
	while _sweep_points.size() > maximum_sweep_samples:
		_sweep_points.remove_at(1)


func _get_contact_samples() -> Array[Vector3]:
	var samples: Array[Vector3] = []
	samples.assign(_sweep_points)
	if weighted_tip != null and (samples.is_empty() or samples[-1].distance_to(weighted_tip.global_position) > 0.02):
		samples.append(weighted_tip.global_position)
	return samples
