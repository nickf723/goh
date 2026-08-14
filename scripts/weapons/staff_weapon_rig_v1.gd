extends Node3D
class_name StaffWeaponRigV1

@export_range(6, 16, 1) var segment_count: int = 10
@export_range(1.8, 3.4, 0.05) var staff_length: float = 2.5
@export_range(0.025, 0.12, 0.005) var staff_radius: float = 0.055
@export_range(120.0, 1400.0, 10.0) var guard_spin_degrees_per_second: float = 820.0

var weapon: WeaponDefinition
var controller: WeaponController
var segments: Array[MeshInstance3D] = []
var line_points: Array[Vector3] = []
var rear_focus: MeshInstance3D
var front_focus: MeshInstance3D
var support_grip: Marker3D
var primary_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var active_attack: WeaponAttackDefinition
var active_elapsed: float = 0.0
var last_elapsed: float = 0.0
var guard_spin_degrees: float = 0.0
var projectile_out: bool = false


func _ready() -> void:
	add_to_group("weapon_runtime_rigs")
	add_to_group("staff_weapon_rigs")
	_build_rig()
	_apply_idle_pose()


func configure_weapon(
	new_weapon: WeaponDefinition,
	new_controller: WeaponController
) -> void:
	weapon = new_weapon
	controller = new_controller
	_update_materials()
	_apply_idle_pose()


func begin_attack(
	attack: WeaponAttackDefinition,
	_attack_speed: float
) -> void:
	active_attack = attack
	active_elapsed = 0.0
	last_elapsed = 0.0
	if not projectile_out:
		_set_staff_visible(true)
	_update_attack_pose(0.0, 0.0)


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	_attack_speed: float
) -> void:
	if attack == null:
		return
	if active_attack != attack:
		active_attack = attack
		last_elapsed = 0.0
	active_elapsed = maxf(elapsed, 0.0)
	var delta: float = maxf(active_elapsed - last_elapsed, 0.0)
	last_elapsed = active_elapsed
	_update_attack_pose(active_elapsed, delta)


func end_attack() -> void:
	active_attack = null
	active_elapsed = 0.0
	last_elapsed = 0.0
	guard_spin_degrees = 0.0
	if not projectile_out:
		_set_staff_visible(true)
		_apply_idle_pose()


func set_projectile_out(active: bool) -> void:
	projectile_out = active
	_set_staff_visible(not projectile_out)
	if not projectile_out and active_attack == null:
		_apply_idle_pose()


func get_support_grip_influence() -> float:
	return 0.0 if projectile_out else 1.0


func get_support_grip_target() -> Node3D:
	return support_grip


func _update_attack_pose(elapsed: float, delta: float) -> void:
	if active_attack == null:
		_apply_idle_pose()
		return
	if projectile_out:
		_set_staff_visible(false)
		return
	_set_staff_visible(true)

	if active_attack.extra_tags.has("staff_angel_ring"):
		guard_spin_degrees = fmod(
			guard_spin_degrees + guard_spin_degrees_per_second * delta,
			360.0
		)
		position = Vector3(0.0, -0.08, -0.5)
		rotation_degrees = Vector3(-88.0, 0.0, guard_spin_degrees)
		_update_geometry(0.0)
		return
	if active_attack.extra_tags.has("staff_throw_charge"):
		position = Vector3(0.0, -0.04, -0.12)
		rotation_degrees = Vector3(-8.0, -26.0, 68.0)
		_update_geometry(0.0)
		return
	if active_attack.extra_tags.has("staff_returning_throw"):
		var release_p: float = _get_total_progress(active_attack, elapsed)
		position = Vector3(0.0, -0.03, lerpf(-0.1, -0.48, release_p))
		rotation_degrees = Vector3(
			-7.0,
			lerpf(-34.0, 22.0, release_p),
			lerpf(72.0, -22.0, release_p)
		)
		_update_geometry(0.0)
		return
	if active_attack.extra_tags.has("staff_vault_descent"):
		position = Vector3(0.0, -0.24, -0.36)
		rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_update_geometry(0.0)
		return
	if active_attack.extra_tags.has("staff_vault_bend"):
		var bend_ratio: float = 0.0
		if controller != null and controller.has_method("get_staff_vault_bend_ratio"):
			bend_ratio = clampf(
				float(controller.call("get_staff_vault_bend_ratio")),
				0.0,
				1.0
			)
		position = Vector3(0.0, -0.22, -0.38)
		rotation_degrees = Vector3(-90.0, 0.0, lerpf(0.0, -7.0, bend_ratio))
		_update_geometry(bend_ratio)
		return
	if active_attack.extra_tags.has("staff_vault_launch"):
		var launch_p: float = _get_total_progress(active_attack, elapsed)
		position = Vector3(0.0, lerpf(-0.18, 0.05, launch_p), lerpf(-0.42, -0.72, launch_p))
		rotation_degrees = Vector3(
			lerpf(-88.0, -22.0, launch_p),
			0.0,
			lerpf(-7.0, 16.0, launch_p)
		)
		_update_geometry(lerpf(0.8, 0.0, launch_p))
		return
	if active_attack.extra_tags.has("staff_vault_overheld_drop"):
		var drop_p: float = _get_total_progress(active_attack, elapsed)
		position = Vector3(0.0, lerpf(-0.12, -0.34, drop_p), -0.34)
		rotation_degrees = Vector3(-90.0, 0.0, lerpf(-8.0, 0.0, drop_p))
		_update_geometry(lerpf(0.72, 0.0, drop_p))
		return

	_update_normal_attack_pose(active_attack, elapsed)


func _update_normal_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float
) -> void:
	var total_p: float = _get_total_progress(attack, elapsed)
	var startup: float = maxf(attack.get_startup_duration(controller.get_attack_speed() if controller != null else 1.0), 0.001)
	var active: float = maxf(attack.get_active_duration(controller.get_attack_speed() if controller != null else 1.0), 0.001)
	var contact_p: float = 0.0
	if elapsed < startup:
		contact_p = smoothstep(0.0, 1.0, clampf(elapsed / startup, 0.0, 1.0))
	else:
		contact_p = 1.0
	var recovery_p: float = 0.0
	if elapsed > startup + active:
		var remaining: float = maxf(attack.get_total_duration(controller.get_attack_speed() if controller != null else 1.0) - startup - active, 0.001)
		recovery_p = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - startup - active) / remaining, 0.0, 1.0)
		)

	var start_rotation: Vector3 = Vector3(-10.0, -58.0, 0.0)
	var contact_rotation: Vector3 = Vector3(-8.0, 64.0, 0.0)
	var start_position: Vector3 = Vector3(0.0, -0.02, 0.04)
	var contact_position: Vector3 = Vector3(0.0, -0.03, -0.2)
	match attack.attack_id:
		"staff_l1":
			start_rotation = Vector3(-11.0, -74.0, -6.0)
			contact_rotation = Vector3(-8.0, 68.0, 5.0)
		"staff_l2":
			start_rotation = Vector3(-9.0, 76.0, 5.0)
			contact_rotation = Vector3(-10.0, -72.0, -6.0)
		"staff_l3":
			start_rotation = Vector3(-7.0, -12.0, 2.0)
			contact_rotation = Vector3(-4.0, 3.0, 0.0)
			start_position = Vector3(0.0, -0.02, 0.12)
			contact_position = Vector3(0.0, -0.01, -0.66)
		"staff_h0":
			start_rotation = Vector3(-9.0, -24.0, 8.0)
			contact_rotation = Vector3(-5.0, 8.0, -5.0)
			start_position = Vector3(0.0, -0.08, 0.1)
			contact_position = Vector3(0.0, -0.1, -0.58)
		"staff_h1":
			start_rotation = Vector3(-12.0, -96.0, -8.0)
			contact_rotation = Vector3(-8.0, 92.0, 8.0)
		"staff_h2":
			start_rotation = Vector3(-8.0, 104.0, 7.0)
			contact_rotation = Vector3(-12.0, -118.0, -9.0)
		"staff_h3":
			start_rotation = Vector3(-8.0, -128.0, 0.0)
			contact_rotation = Vector3(-7.0, 238.0, 0.0)
			contact_p = smoothstep(0.0, 1.0, total_p)

	var resolved_rotation: Vector3 = start_rotation.lerp(contact_rotation, contact_p)
	var resolved_position: Vector3 = start_position.lerp(contact_position, contact_p)
	if recovery_p > 0.0:
		resolved_rotation = resolved_rotation.lerp(Vector3(-12.0, 0.0, 0.0), recovery_p)
		resolved_position = resolved_position.lerp(Vector3.ZERO, recovery_p)
	rotation_degrees = resolved_rotation
	position = resolved_position
	_update_geometry(0.0)


func _get_total_progress(
	attack: WeaponAttackDefinition,
	elapsed: float
) -> float:
	if attack == null:
		return 0.0
	var speed: float = controller.get_attack_speed() if controller != null else 1.0
	var total: float = maxf(attack.get_total_duration(speed), 0.001)
	return clampf(elapsed / total, 0.0, 1.0)


func _apply_idle_pose() -> void:
	position = Vector3.ZERO
	rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	_update_geometry(0.0)


func _build_rig() -> void:
	if not segments.is_empty():
		return
	primary_material = StandardMaterial3D.new()
	primary_material.albedo_color = Color(0.12, 0.78, 0.82, 1.0)
	primary_material.metallic = 0.38
	primary_material.roughness = 0.42
	accent_material = StandardMaterial3D.new()
	accent_material.albedo_color = Color(0.32, 1.0, 0.94, 1.0)
	accent_material.metallic = 0.52
	accent_material.roughness = 0.28
	accent_material.emission_enabled = true
	accent_material.emission = Color(0.32, 1.0, 0.94, 1.0)
	accent_material.emission_energy_multiplier = 0.65

	for index: int in range(segment_count):
		var segment: MeshInstance3D = MeshInstance3D.new()
		segment.name = "StaffSegment%02d" % index
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = staff_radius
		mesh.bottom_radius = staff_radius
		mesh.height = 1.0
		mesh.radial_segments = 10
		segment.mesh = mesh
		segment.material_override = primary_material
		add_child(segment)
		segments.append(segment)

	rear_focus = _build_focus("RearFocus", staff_radius * 2.25)
	front_focus = _build_focus("FrontFocus", staff_radius * 2.8)
	support_grip = Marker3D.new()
	support_grip.name = "SupportGrip"
	add_child(support_grip)
	_update_geometry(0.0)


func _build_focus(node_name: String, radius: float) -> MeshInstance3D:
	var focus: MeshInstance3D = MeshInstance3D.new()
	focus.name = node_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 7
	focus.mesh = mesh
	focus.material_override = accent_material
	add_child(focus)
	return focus


func _update_materials() -> void:
	if weapon == null or primary_material == null or accent_material == null:
		return
	primary_material.albedo_color = weapon.visual_primary_color
	accent_material.albedo_color = weapon.visual_accent_color
	accent_material.emission = Color(
		weapon.visual_accent_color.r,
		weapon.visual_accent_color.g,
		weapon.visual_accent_color.b,
		1.0
	)


func _update_geometry(bend_ratio: float) -> void:
	if segments.is_empty():
		return
	line_points.clear()
	var rear_z: float = staff_length * 0.29
	var front_z: float = rear_z - staff_length
	var bend: float = clampf(bend_ratio, 0.0, 1.0)
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var curve: float = sin(t * PI)
		line_points.append(Vector3(
			curve * bend * 0.5,
			-curve * bend * 0.2,
			lerpf(rear_z, front_z, t)
		))
	for index: int in range(segments.size()):
		_set_segment_between(segments[index], line_points[index], line_points[index + 1])
	if rear_focus != null:
		rear_focus.position = line_points[0]
	if front_focus != null:
		front_focus.position = line_points[line_points.size() - 1]
	if support_grip != null:
		var grip_index: int = mini(maxi(roundi(float(segment_count) * 0.34), 0), segment_count)
		support_grip.position = line_points[grip_index]


func _set_segment_between(
	segment: MeshInstance3D,
	point_a: Vector3,
	point_b: Vector3
) -> void:
	var offset: Vector3 = point_b - point_a
	var length: float = offset.length()
	if length <= 0.0001:
		segment.visible = false
		return
	segment.visible = not projectile_out
	segment.position = point_a.lerp(point_b, 0.5)
	segment.quaternion = Quaternion(Vector3.UP, offset / length)
	segment.scale = Vector3(1.0, length, 1.0)


func _set_staff_visible(visible_value: bool) -> void:
	for segment: MeshInstance3D in segments:
		segment.visible = visible_value
	if rear_focus != null:
		rear_focus.visible = visible_value
	if front_focus != null:
		front_focus.visible = visible_value


func get_debug_data() -> Dictionary:
	return {
		"type": "articulated_staff_v1",
		"staff_focused": true,
		"segment_count": segment_count,
		"projectile_out": projectile_out,
		"attack": active_attack.attack_id if active_attack != null else "idle",
		"support_grip_influence": get_support_grip_influence(),
	}
