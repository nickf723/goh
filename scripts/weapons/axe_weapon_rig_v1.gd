extends Node3D
class_name AxeWeaponRigV1

# The blade face lives in local X/Z. Overhead techniques roll the whole weapon
# 90 degrees so that plane matches the vertical swing plane and the bright edge,
# not the broad cheek, arrives at the target first.

var weapon: WeaponDefinition
var controller: WeaponController
var active_attack: WeaponAttackDefinition
var active_elapsed: float = 0.0
var support_grip: Marker3D
var primary_material: StandardMaterial3D
var secondary_material: StandardMaterial3D
var accent_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("weapon_runtime_rigs")
	add_to_group("axe_weapon_rigs")
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
	_update_attack_pose()


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	_attack_speed: float
) -> void:
	active_attack = attack
	active_elapsed = maxf(elapsed, 0.0)
	_update_attack_pose()


func end_attack() -> void:
	active_attack = null
	active_elapsed = 0.0
	_apply_idle_pose()


func get_support_grip_target() -> Node3D:
	return support_grip


func get_support_grip_influence() -> float:
	if active_attack == null:
		return 0.0
	if (
		active_attack.input_kind == "heavy"
		or active_attack.extra_tags.has("axe_charge_ready")
		or active_attack.extra_tags.has("axe_lever_vault")
	):
		return 0.94
	return 0.18


func _update_attack_pose() -> void:
	if active_attack == null:
		_apply_idle_pose()
		return
	_update_momentum_glow()
	if active_attack.extra_tags.has("axe_charge_ready"):
		position = Vector3(0.0, 0.04, 0.02)
		rotation_degrees = Vector3(-108.0, -4.0, 90.0)
		return
	if active_attack.extra_tags.has("axe_lever_vault"):
		_update_lever_vault_pose()
		return
	if (
		active_attack.extra_tags.has("axe_overhead")
		or active_attack.extra_tags.has("axe_edge_aligned")
		or active_attack.extra_tags.has("ground_slam")
	):
		_update_overhead_pose()
		return
	if active_attack.extra_tags.has("axe_rising"):
		_update_rising_pose()
		return
	_update_side_hew_pose()


func _update_side_hew_pose() -> void:
	var phase: Dictionary = _get_attack_phase()
	var side: float = -1.0 if active_attack.extra_tags.has("reverse") else 1.0
	var broad: float = 1.18 if active_attack.extra_tags.has("axe_broad_hew") else 1.0
	var start_rotation: Vector3 = Vector3(-10.0, -70.0 * side * broad, 4.0 * side)
	var contact_rotation: Vector3 = Vector3(-8.0, 78.0 * side * broad, -6.0 * side)
	var follow_rotation: Vector3 = Vector3(-12.0, 108.0 * side * broad, -8.0 * side)
	var recover_rotation: Vector3 = Vector3(-16.0, 8.0 * side, 0.0)
	rotation_degrees = _sample_phase_vector(
		start_rotation,
		contact_rotation,
		follow_rotation,
		recover_rotation,
		phase
	)
	var start_position: Vector3 = Vector3(0.0, 0.01, 0.05)
	var contact_position: Vector3 = Vector3(-0.03 * side, -0.04, -0.22)
	var follow_position: Vector3 = Vector3(-0.05 * side, -0.05, -0.3)
	position = _sample_phase_vector(
		start_position,
		contact_position,
		follow_position,
		Vector3.ZERO,
		phase
	)


func _update_overhead_pose() -> void:
	var phase: Dictionary = _get_attack_phase()
	var finisher: bool = (
		active_attack.extra_tags.has("execution")
		or active_attack.extra_tags.has("axe_exploit")
	)
	var start_rotation: Vector3 = Vector3(-112.0, -4.0, 90.0)
	var contact_rotation: Vector3 = Vector3(90.0, 3.0, 90.0)
	var follow_rotation: Vector3 = Vector3(112.0, 4.0, 88.0)
	if finisher:
		start_rotation.x = -122.0
		follow_rotation.x = 126.0
	rotation_degrees = _sample_phase_vector(
		start_rotation,
		contact_rotation,
		follow_rotation,
		Vector3(24.0, 1.0, 86.0),
		phase
	)
	position = _sample_phase_vector(
		Vector3(0.0, 0.08, 0.07),
		Vector3(0.0, -0.12, -0.28),
		Vector3(0.0, -0.15, -0.35),
		Vector3.ZERO,
		phase
	)


func _update_rising_pose() -> void:
	var phase: Dictionary = _get_attack_phase()
	rotation_degrees = _sample_phase_vector(
		Vector3(78.0, -7.0, 90.0),
		Vector3(-44.0, 5.0, 90.0),
		Vector3(-72.0, 7.0, 88.0),
		Vector3(-14.0, 0.0, 84.0),
		phase
	)
	position = _sample_phase_vector(
		Vector3(0.0, -0.13, -0.08),
		Vector3(0.0, 0.14, -0.2),
		Vector3(0.0, 0.2, -0.24),
		Vector3.ZERO,
		phase
	)


func _update_lever_vault_pose() -> void:
	var speed: float = controller.get_attack_speed() if controller != null else 1.0
	var startup: float = maxf(active_attack.get_startup_duration(speed), 0.01)
	var p: float = clampf(active_elapsed / startup, 0.0, 1.0)
	if p < 0.16:
		var plant: float = smoothstep(0.0, 1.0, p / 0.16)
		rotation_degrees = Vector3(
			lerpf(-112.0, 92.0, plant),
			lerpf(-4.0, 1.0, plant),
			90.0
		)
		position = Vector3(
			0.0,
			lerpf(0.08, -0.16, plant),
			lerpf(0.06, -0.32, plant)
		)
		return
	if p < 0.42:
		var lever: float = smoothstep(0.0, 1.0, (p - 0.16) / 0.26)
		rotation_degrees = Vector3(
			lerpf(92.0, 36.0, lever),
			lerpf(1.0, -8.0, lever),
			90.0
		)
		position = Vector3(
			0.0,
			lerpf(-0.16, -0.03, lever),
			lerpf(-0.32, -0.4, lever)
		)
		return
	if p < 0.62:
		var extract: float = smoothstep(0.0, 1.0, (p - 0.42) / 0.2)
		rotation_degrees = Vector3(
			lerpf(36.0, -82.0, extract),
			lerpf(-8.0, 10.0, extract),
			90.0
		)
		position = Vector3(
			0.0,
			lerpf(-0.03, 0.18, extract),
			lerpf(-0.4, -0.24, extract)
		)
		return
	if p < 0.84:
		var carry: float = smoothstep(0.0, 1.0, (p - 0.62) / 0.22)
		rotation_degrees = Vector3(
			lerpf(-82.0, -126.0, carry),
			lerpf(10.0, -12.0, carry),
			lerpf(90.0, 94.0, carry)
		)
		position = Vector3(
			lerpf(0.0, 0.08, carry),
			lerpf(0.18, 0.1, carry),
			lerpf(-0.24, -0.04, carry)
		)
		return
	var slam: float = smoothstep(0.0, 1.0, (p - 0.84) / 0.16)
	rotation_degrees = Vector3(
		lerpf(-126.0, 94.0, slam),
		lerpf(-12.0, 4.0, slam),
		lerpf(94.0, 90.0, slam)
	)
	position = Vector3(
		lerpf(0.08, 0.0, slam),
		lerpf(0.1, -0.16, slam),
		lerpf(-0.04, -0.4, slam)
	)


func _get_attack_phase() -> Dictionary:
	if active_attack == null:
		return {"stage": "recover", "weight": 1.0}
	var speed: float = controller.get_attack_speed() if controller != null else 1.0
	var startup: float = maxf(active_attack.get_startup_duration(speed), 0.001)
	var active: float = maxf(active_attack.get_active_duration(speed), 0.001)
	var recovery: float = maxf(active_attack.get_recovery_duration(speed), 0.001)
	if active_elapsed < startup:
		return {
			"stage": "startup",
			"weight": smoothstep(0.0, 1.0, active_elapsed / startup),
		}
	if active_elapsed < startup + active:
		return {
			"stage": "active",
			"weight": smoothstep(0.0, 1.0, (active_elapsed - startup) / active),
		}
	return {
		"stage": "recovery",
		"weight": clampf((active_elapsed - startup - active) / recovery, 0.0, 1.0),
	}


func _sample_phase_vector(
	start_value: Vector3,
	contact_value: Vector3,
	follow_value: Vector3,
	recover_value: Vector3,
	phase: Dictionary
) -> Vector3:
	var stage: String = str(phase.get("stage", "recovery"))
	var weight: float = float(phase.get("weight", 1.0))
	match stage:
		"startup":
			return start_value.lerp(contact_value, weight)
		"active":
			return contact_value.lerp(follow_value, weight)
		_:
			return follow_value.lerp(recover_value, smoothstep(0.0, 1.0, weight))


func _apply_idle_pose() -> void:
	position = Vector3.ZERO
	rotation_degrees = Vector3(-18.0, -8.0, 8.0)
	_update_momentum_glow()


func _build_rig() -> void:
	if get_child_count() > 0:
		return
	primary_material = _make_material(Color(0.1, 0.32, 0.9, 1.0), false)
	secondary_material = _make_material(Color(0.025, 0.06, 0.16, 1.0), false)
	accent_material = _make_material(Color(0.28, 0.72, 1.0, 1.0), true)

	_add_cylinder(
		"Haft",
		0.055,
		1.86,
		Vector3(0.0, 0.0, -0.56),
		secondary_material
	)
	_add_box(
		"AxeCheek",
		Vector3(0.72, 0.12, 0.5),
		Vector3(-0.23, 0.0, -1.38),
		primary_material,
		Vector3(0.0, 0.0, -16.0)
	)
	_add_box(
		"AxeBeard",
		Vector3(0.38, 0.1, 0.34),
		Vector3(-0.48, 0.0, -1.54),
		primary_material,
		Vector3(0.0, 0.0, -26.0)
	)
	_add_box(
		"AxeEdge",
		Vector3(0.09, 0.15, 0.54),
		Vector3(-0.61, 0.0, -1.5),
		accent_material,
		Vector3(0.0, 0.0, -22.0)
	)
	_add_box(
		"Poll",
		Vector3(0.26, 0.16, 0.22),
		Vector3(0.22, 0.0, -1.34),
		primary_material,
		Vector3.ZERO
	)
	_add_box(
		"GripWrap",
		Vector3(0.13, 0.13, 0.5),
		Vector3(0.0, 0.0, 0.05),
		primary_material,
		Vector3.ZERO
	)

	support_grip = Marker3D.new()
	support_grip.name = "SupportGrip"
	support_grip.position = Vector3(0.0, 0.0, -0.44)
	add_child(support_grip)


func _add_box(
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	material: StandardMaterial3D,
	local_rotation_degrees: Vector3
) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = local_position
	part.rotation_degrees = local_rotation_degrees
	part.material_override = material
	add_child(part)


func _add_cylinder(
	node_name: String,
	radius: float,
	height: float,
	local_position: Vector3,
	material: StandardMaterial3D
) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = node_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	part.mesh = mesh
	part.position = local_position
	part.rotation_degrees.x = 90.0
	part.material_override = material
	add_child(part)


func _make_material(
	color: Color,
	emissive: bool
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.52
	material.roughness = 0.32
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.7
	return material


func _update_materials() -> void:
	if weapon == null:
		return
	if primary_material != null:
		primary_material.albedo_color = weapon.visual_primary_color
	if secondary_material != null:
		secondary_material.albedo_color = weapon.visual_secondary_color
	if accent_material != null:
		accent_material.albedo_color = weapon.visual_accent_color
		accent_material.emission = Color(
			weapon.visual_accent_color.r,
			weapon.visual_accent_color.g,
			weapon.visual_accent_color.b,
			1.0
		)


func _update_momentum_glow() -> void:
	if accent_material == null:
		return
	var ratio: float = 0.0
	if controller != null and controller.has_method("get_axe_momentum_ratio"):
		ratio = clampf(
			float(controller.call("get_axe_momentum_ratio")),
			0.0,
			1.0
		)
	accent_material.emission_energy_multiplier = lerpf(0.7, 1.9, ratio)


func get_debug_data() -> Dictionary:
	return {
		"axe_weapon_rig_v1": true,
		"blue_axe": true,
		"edge_aligned_overheads": true,
		"active_attack": active_attack.attack_id if active_attack != null else "none",
		"support_grip_influence": get_support_grip_influence(),
	}
