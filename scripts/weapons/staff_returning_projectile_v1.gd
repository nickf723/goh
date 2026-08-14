extends Node3D
class_name StaffReturningProjectileV1

@export_range(0.1, 1.0, 0.02) var contact_radius: float = 0.38

var controller: WeaponController
var attack: WeaponAttackDefinition
var source_actor: Node3D
var travel_direction: Vector3 = Vector3.FORWARD
var charge_ratio: float = 0.0
var travel_distance: float = 7.0
var outbound_duration: float = 0.38
var return_duration: float = 0.32
var elapsed: float = 0.0
var configured: bool = false
var returning: bool = false
var start_position: Vector3 = Vector3.ZERO
var outbound_end: Vector3 = Vector3.ZERO
var return_start: Vector3 = Vector3.ZERO
var previous_position: Vector3 = Vector3.ZERO
var outbound_hits: Dictionary = {}
var return_hits: Dictionary = {}
var visual_root: Node3D
var primary_material: StandardMaterial3D
var accent_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("projectile")
	add_to_group("staff_returning_projectiles")
	_build_visual()


func configure(
	new_controller: WeaponController,
	new_attack: WeaponAttackDefinition,
	direction: Vector3,
	charge: float
) -> void:
	controller = new_controller
	attack = new_attack
	source_actor = controller.get_actor() if controller != null else null
	travel_direction = direction
	travel_direction.y = 0.0
	if travel_direction.length_squared() <= 0.0001:
		travel_direction = Vector3.FORWARD
	else:
		travel_direction = travel_direction.normalized()
	charge_ratio = clampf(charge, 0.0, 1.0)
	travel_distance = lerpf(6.5, 10.0, charge_ratio)
	outbound_duration = lerpf(0.42, 0.55, charge_ratio)
	return_duration = lerpf(0.32, 0.4, charge_ratio)
	start_position = _get_catch_position() + travel_direction * 0.28
	outbound_end = start_position + travel_direction * travel_distance
	global_position = start_position
	previous_position = global_position
	configured = true
	_update_materials()


func _physics_process(delta: float) -> void:
	if not configured:
		return
	if controller == null or not is_instance_valid(controller):
		queue_free()
		return
	elapsed += maxf(delta, 0.0)
	if visual_root != null:
		visual_root.rotation.z += delta * lerpf(12.0, 18.0, charge_ratio)
	previous_position = global_position

	if not returning:
		var outward_p: float = clampf(elapsed / maxf(outbound_duration, 0.01), 0.0, 1.0)
		var eased: float = smoothstep(0.0, 1.0, outward_p)
		global_position = start_position.lerp(outbound_end, eased)
		global_position += Vector3.UP * sin(outward_p * PI) * lerpf(0.24, 0.52, charge_ratio)
		if outward_p >= 1.0:
			returning = true
			return_start = global_position
	else:
		var return_elapsed: float = elapsed - outbound_duration
		var return_p: float = clampf(return_elapsed / maxf(return_duration, 0.01), 0.0, 1.0)
		var eased_return: float = smoothstep(0.0, 1.0, return_p)
		var catch_position: Vector3 = _get_catch_position()
		global_position = return_start.lerp(catch_position, eased_return)
		global_position += Vector3.UP * sin(return_p * PI) * 0.18
		if return_p >= 1.0:
			_finish_return()
			return

	_check_swept_contacts(previous_position, global_position, returning)


func _check_swept_contacts(
	from_position: Vector3,
	to_position: Vector3,
	return_pass: bool
) -> void:
	if controller == null or not is_inside_tree():
		return
	var actor: Node3D = source_actor
	var offset: Vector3 = to_position - from_position
	var distance: float = offset.length()
	var sample_count: int = maxi(1, ceili(distance / maxf(contact_radius * 0.7, 0.08)))
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = contact_radius
	var hits: Dictionary = return_hits if return_pass else outbound_hits
	for sample_index: int in range(sample_count + 1):
		var t: float = float(sample_index) / float(sample_count)
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), from_position.lerp(to_position, t))
		query.collision_mask = controller.hit_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		if actor is CollisionObject3D:
			query.exclude = [(actor as CollisionObject3D).get_rid()]
		for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 24):
			var raw_target: Node = result.get("collider") as Node
			var target: Node = controller.find_payload_target(raw_target)
			if target == null or target == actor:
				continue
			var target_id: int = target.get_instance_id()
			if hits.has(target_id):
				continue
			hits[target_id] = true
			if controller.has_method("apply_staff_projectile_contact"):
				controller.call(
					"apply_staff_projectile_contact",
					target,
					attack,
					return_pass
				)


func _get_catch_position() -> Vector3:
	if controller != null:
		var hand_anchor: Node3D = controller.get_node_or_null("HandAnchor") as Node3D
		if hand_anchor != null:
			return hand_anchor.global_position
	if source_actor != null and is_instance_valid(source_actor):
		return source_actor.global_position + Vector3.UP * 0.85
	return global_position


func _finish_return() -> void:
	if controller != null and is_instance_valid(controller):
		if controller.has_method("on_staff_projectile_returned"):
			controller.call("on_staff_projectile_returned", self)
	queue_free()


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "SpinningStaffVisual"
	add_child(visual_root)
	primary_material = StandardMaterial3D.new()
	primary_material.albedo_color = Color(0.08, 0.72, 0.78, 1.0)
	primary_material.metallic = 0.38
	primary_material.roughness = 0.4
	accent_material = StandardMaterial3D.new()
	accent_material.albedo_color = Color(0.32, 1.0, 0.94, 1.0)
	accent_material.metallic = 0.5
	accent_material.roughness = 0.26
	accent_material.emission_enabled = true
	accent_material.emission = Color(0.32, 1.0, 0.94, 1.0)
	accent_material.emission_energy_multiplier = 0.75

	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.name = "StaffShaft"
	var shaft_mesh: CylinderMesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.055
	shaft_mesh.bottom_radius = 0.055
	shaft_mesh.height = 2.45
	shaft_mesh.radial_segments = 10
	shaft.mesh = shaft_mesh
	shaft.rotation_degrees.z = 90.0
	shaft.material_override = primary_material
	visual_root.add_child(shaft)

	for side: float in [-1.0, 1.0]:
		var focus: MeshInstance3D = MeshInstance3D.new()
		focus.name = "StaffFocus"
		var focus_mesh: SphereMesh = SphereMesh.new()
		focus_mesh.radius = 0.14
		focus_mesh.height = 0.28
		focus_mesh.radial_segments = 12
		focus_mesh.rings = 7
		focus.mesh = focus_mesh
		focus.position.x = side * 1.225
		focus.material_override = accent_material
		visual_root.add_child(focus)


func _update_materials() -> void:
	if controller == null or controller.equipped_weapon == null:
		return
	if primary_material != null:
		primary_material.albedo_color = controller.equipped_weapon.visual_primary_color
	if accent_material != null:
		var accent: Color = controller.equipped_weapon.visual_accent_color
		accent_material.albedo_color = accent
		accent_material.emission = Color(accent.r, accent.g, accent.b, 1.0)


func get_debug_data() -> Dictionary:
	return {
		"staff_returning_projectile": true,
		"returning": returning,
		"charge_ratio": snappedf(charge_ratio, 0.01),
		"outbound_hits": outbound_hits.size(),
		"return_hits": return_hits.size(),
	}
