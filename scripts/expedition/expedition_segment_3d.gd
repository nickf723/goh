extends Node3D
class_name ExpeditionSegment3D

const GoblinScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")

var definition: ExpeditionSegmentDefinition
var segment_seed: int = 0
var is_optional_branch: bool = false
var entry_socket: Marker3D
var exit_socket: Marker3D
var branch_socket: Marker3D
var built: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func configure(
	segment_definition: ExpeditionSegmentDefinition,
	seed_value: int,
	optional_branch: bool = false
) -> void:
	definition = segment_definition
	segment_seed = seed_value
	is_optional_branch = optional_branch
	rng.seed = segment_seed
	name = "Segment_" + definition.segment_id
	build_segment()


func build_segment() -> void:
	if built or definition == null:
		return
	built = true
	build_sockets()
	build_ground()
	build_boundaries()
	build_role_content()
	build_segment_label()
	add_to_group("expedition_segment")
	add_to_group("debuggable")


func build_sockets() -> void:
	entry_socket = Marker3D.new()
	entry_socket.name = "EntrySocket"
	add_child(entry_socket)

	exit_socket = Marker3D.new()
	exit_socket.name = "ExitSocket"
	exit_socket.position = definition.get_exit_local_position()
	add_child(exit_socket)

	if definition.allows_optional_branch and not is_optional_branch:
		branch_socket = Marker3D.new()
		branch_socket.name = "BranchSocket"
		branch_socket.position = definition.get_branch_local_position()
		branch_socket.rotation_degrees.y = -90.0 if definition.branch_side == "left" else 90.0
		add_child(branch_socket)


func build_ground() -> void:
	var slope_length: float = sqrt(
		definition.length * definition.length
		+ definition.elevation_delta * definition.elevation_delta
	)
	var slope_angle: float = -atan2(definition.elevation_delta, definition.length)
	var center: Vector3 = Vector3(0.0, definition.elevation_delta * 0.5 - 0.28, definition.length * 0.5)
	add_static_box(
		"Ground",
		Vector3(definition.width, 0.55, slope_length),
		center,
		Vector3(slope_angle, 0.0, 0.0),
		definition.ground_color
	)
	add_visual_box(
		"Path",
		Vector3(definition.path_width, 0.08, slope_length),
		center + Vector3(0.0, 0.34, 0.0),
		Vector3(slope_angle, 0.0, 0.0),
		definition.path_color
	)

	if definition.water_fraction > 0.01:
		build_water(slope_angle, slope_length)


func build_water(slope_angle: float, slope_length: float) -> void:
	var water_width: float = maxf(
		(definition.width - definition.path_width) * definition.water_fraction,
		1.0
	)
	for side_sign: float in [-1.0, 1.0]:
		var x_position: float = side_sign * (definition.path_width * 0.5 + water_width * 0.25)
		var material_color: Color = Color(0.08, 0.28, 0.34, 0.68)
		add_visual_box(
			"Water" + ("Left" if side_sign < 0.0 else "Right"),
			Vector3(water_width * 0.5, 0.12, slope_length),
			Vector3(x_position, definition.elevation_delta * 0.5 + 0.03, definition.length * 0.5),
			Vector3(slope_angle, 0.0, 0.0),
			material_color,
			true
		)


func build_boundaries() -> void:
	build_boundary_side(-1.0)
	build_boundary_side(1.0)


func build_boundary_side(side_sign: float) -> void:
	var branch_side_sign: float = -1.0 if definition.branch_side == "left" else 1.0
	var has_gap: bool = (
		definition.allows_optional_branch
		and not is_optional_branch
		and is_equal_approx(side_sign, branch_side_sign)
	)
	var branch_z: float = definition.length * definition.branch_distance_normalized
	var gap_half: float = 2.4
	if has_gap:
		add_boundary_span(side_sign, 0.0, maxf(branch_z - gap_half, 0.0))
		add_boundary_span(side_sign, minf(branch_z + gap_half, definition.length), definition.length)
	else:
		add_boundary_span(side_sign, 0.0, definition.length)


func add_boundary_span(side_sign: float, start_z: float, end_z: float) -> void:
	var span_length: float = end_z - start_z
	if span_length <= 0.25:
		return
	var center_z: float = (start_z + end_z) * 0.5
	var elevation: float = elevation_at(center_z)
	var wall_height: float = 4.5
	var wall_width: float = 2.4
	if definition.boundary_style == "cliff":
		wall_height = 6.2
		wall_width = 3.2
	elif definition.boundary_style == "marsh":
		wall_height = 3.7
		wall_width = 3.0
	var x_position: float = side_sign * (definition.width * 0.5 + wall_width * 0.35)
	add_static_box(
		"Boundary",
		Vector3(wall_width, wall_height, span_length),
		Vector3(x_position, elevation + wall_height * 0.5 - 0.15, center_z),
		Vector3.ZERO,
		definition.boundary_color
	)
	build_boundary_detail(side_sign, start_z, end_z)


func build_boundary_detail(side_sign: float, start_z: float, end_z: float) -> void:
	var spacing: float = 3.0 if definition.boundary_style != "cliff" else 4.5
	var z_position: float = start_z + spacing * 0.5
	while z_position < end_z:
		var jitter: float = rng.randf_range(-0.65, 0.65)
		var x_position: float = side_sign * (definition.width * 0.5 - 0.15) + jitter
		var elevation: float = elevation_at(z_position)
		if definition.boundary_style == "cliff":
			add_rock(Vector3(x_position, elevation + 0.65, z_position), rng.randf_range(1.4, 2.5))
		else:
			add_tree(Vector3(x_position, elevation, z_position), rng.randf_range(0.85, 1.3))
		z_position += spacing + rng.randf_range(-0.45, 0.65)


func build_role_content() -> void:
	match definition.role:
		"traversal":
			build_traversal_obstacle()
		"combat":
			build_enemy_camp()
		"resource":
			build_resource_grove()
		"discovery":
			build_ruin_fragments()
		"rest":
			build_campsite()
		"transition":
			build_transition_markers()
		_:
			build_scattered_obstacles()


func build_scattered_obstacles() -> void:
	var count: int = clampi(roundi(definition.obstacle_density * 8.0), 1, 7)
	for index: int in range(count):
		var side_sign: float = -1.0 if index % 2 == 0 else 1.0
		var x_position: float = side_sign * rng.randf_range(definition.path_width * 0.28, definition.path_width * 0.43)
		var z_position: float = rng.randf_range(4.0, maxf(definition.length - 4.0, 4.5))
		add_rock(Vector3(x_position, elevation_at(z_position) + 0.35, z_position), rng.randf_range(0.55, 1.0))


func build_traversal_obstacle() -> void:
	build_scattered_obstacles()
	var obstacle_z: float = definition.length * 0.58
	for index: int in range(5):
		var x_position: float = lerpf(-definition.path_width * 0.38, definition.path_width * 0.38, float(index) / 4.0)
		add_rock(
			Vector3(x_position, elevation_at(obstacle_z) + 0.25, obstacle_z + sin(float(index)) * 0.8),
			0.62
		)


func build_enemy_camp() -> void:
	var camp_z: float = definition.length * 0.58
	add_visual_box(
		"CampPlatform",
		Vector3(definition.path_width * 0.92, 0.14, 5.5),
		Vector3(0.0, elevation_at(camp_z) + 0.08, camp_z),
		Vector3.ZERO,
		Color(0.24, 0.17, 0.12, 1.0)
	)
	add_campfire(Vector3(0.0, elevation_at(camp_z) + 0.25, camp_z))
	spawn_enemy(GoblinScene, Vector3(-1.6, elevation_at(camp_z - 1.2) + 0.65, camp_z - 1.2), "WildsGoblin")
	spawn_enemy(GremlinScene, Vector3(1.7, elevation_at(camp_z + 1.1) + 0.55, camp_z + 1.1), "WildsGremlin")


func build_resource_grove() -> void:
	var grove_z: float = definition.length * 0.52
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0
		var position_3d: Vector3 = Vector3(
			cos(angle) * 2.0,
			elevation_at(grove_z) + 0.28,
			grove_z + sin(angle) * 2.0
		)
		add_glowing_orb(position_3d, definition.accent_color, 0.22)


func build_ruin_fragments() -> void:
	var ruin_z: float = definition.length * 0.68
	for index: int in range(3):
		var x_position: float = -2.0 + float(index) * 2.0
		add_static_box(
			"RuinPillar",
			Vector3(0.65, 2.0 + float(index) * 0.4, 0.65),
			Vector3(x_position, elevation_at(ruin_z) + 1.0, ruin_z + absf(x_position) * 0.3),
			Vector3(0.0, rng.randf_range(-0.2, 0.2), rng.randf_range(-0.08, 0.08)),
			Color(0.36, 0.37, 0.32, 1.0)
		)


func build_campsite() -> void:
	var camp_z: float = definition.length * 0.5
	add_campfire(Vector3(0.0, elevation_at(camp_z) + 0.22, camp_z))
	add_visual_box(
		"Shelter",
		Vector3(3.6, 0.18, 2.4),
		Vector3(-2.4, elevation_at(camp_z) + 1.25, camp_z + 0.8),
		Vector3(0.0, 0.2, -0.35),
		Color(0.28, 0.18, 0.1, 1.0)
	)


func build_transition_markers() -> void:
	build_scattered_obstacles()
	var marker_z: float = definition.length * 0.48
	add_tree(Vector3(-2.8, elevation_at(marker_z), marker_z), 0.8)
	add_rock(Vector3(2.7, elevation_at(marker_z) + 0.55, marker_z), 1.3)


func build_segment_label() -> void:
	var label: Label3D = Label3D.new()
	label.name = "SegmentLabel"
	label.position = Vector3(0.0, 3.0, 2.2)
	label.text = definition.display_name.to_upper() + "  •  " + definition.role.to_upper()
	label.font_size = 30
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = definition.accent_color
	label.outline_size = 5
	add_child(label)


func elevation_at(z_position: float) -> float:
	return definition.elevation_delta * clampf(z_position / maxf(definition.length, 0.01), 0.0, 1.0)


func add_static_box(
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	local_rotation: Vector3,
	color: Color
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = local_position
	body.rotation = local_rotation
	add_child(body)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = create_material(color)
	body.add_child(mesh_instance)
	return body


func add_visual_box(
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	local_rotation: Vector3,
	color: Color,
	transparent: bool = false
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = create_material(color, transparent)
	add_child(mesh_instance)
	return mesh_instance


func add_tree(local_position: Vector3, scale_value: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "BoundaryTree"
	root.position = local_position
	root.scale = Vector3.ONE * scale_value
	add_child(root)

	var trunk: MeshInstance3D = MeshInstance3D.new()
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 3.2
	trunk_mesh.radial_segments = 8
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.6
	trunk.material_override = create_material(Color(0.22, 0.13, 0.07, 1.0))
	root.add_child(trunk)

	var canopy: MeshInstance3D = MeshInstance3D.new()
	var canopy_mesh: SphereMesh = SphereMesh.new()
	canopy_mesh.radius = 1.25
	canopy_mesh.height = 2.5
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 6
	canopy.mesh = canopy_mesh
	canopy.position.y = 3.4
	canopy.material_override = create_material(definition.boundary_color.lightened(0.08))
	root.add_child(canopy)


func add_rock(local_position: Vector3, scale_value: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Rock"
	body.position = local_position
	body.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 180.0), rng.randf_range(-8.0, 8.0))
	add_child(body)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = scale_value * 0.62
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = scale_value * 0.65
	mesh.height = scale_value * 1.15
	mesh.radial_segments = 8
	mesh.rings = 5
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(1.2, 0.85, 1.0)
	mesh_instance.material_override = create_material(Color(0.32, 0.33, 0.3, 1.0))
	body.add_child(mesh_instance)


func add_campfire(local_position: Vector3) -> void:
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0
		add_rock(
			local_position + Vector3(cos(angle) * 0.52, 0.0, sin(angle) * 0.52),
			0.28
		)
	add_glowing_orb(local_position + Vector3(0.0, 0.42, 0.0), Color(1.0, 0.36, 0.08, 1.0), 0.42)


func add_glowing_orb(local_position: Vector3, color: Color, radius: float) -> void:
	var orb: MeshInstance3D = MeshInstance3D.new()
	orb.name = "Glow"
	orb.position = local_position
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	orb.mesh = mesh
	orb.material_override = create_emissive_material(color)
	add_child(orb)


func spawn_enemy(scene: PackedScene, local_position: Vector3, enemy_name: String) -> void:
	if scene == null:
		return
	var enemy: Node = scene.instantiate()
	if not enemy is Node3D:
		enemy.queue_free()
		return
	enemy.name = enemy_name
	add_child(enemy)
	(enemy as Node3D).position = local_position
	enemy.add_to_group("expedition_enemy")


func create_material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if transparent or color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material


func create_emissive_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = create_material(color)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 1.4
	return material


func get_exit_global_transform() -> Transform3D:
	return exit_socket.global_transform if exit_socket != null else global_transform


func get_branch_global_transform() -> Transform3D:
	return branch_socket.global_transform if branch_socket != null else Transform3D.IDENTITY


func get_signature() -> Dictionary:
	return {
		"segment_id": definition.segment_id if definition != null else "none",
		"seed": segment_seed,
		"transform": global_transform,
		"branch": is_optional_branch,
	}


func get_debug_data() -> Dictionary:
	return {
		"segment": definition.get_debug_summary() if definition != null else "none",
		"seed": segment_seed,
		"branch": is_optional_branch,
		"exit": exit_socket.global_position if exit_socket != null else global_position,
	}
