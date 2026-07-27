extends RefCounted
class_name AuthoredEnvironmentBuilder

const SURFACE_GROUP := "authored_environment_surface"
const DECOR_GROUP := "authored_environment_decor"
const LIGHT_GROUP := "authored_environment_light"

var root: Node3D
var palette: Resource
var material_cache: Dictionary = {}
var build_counts: Dictionary = {
	"static_boxes": 0,
	"static_cylinders": 0,
	"visuals": 0,
	"stair_runs": 0,
	"pillars": 0,
	"archways": 0,
	"lights": 0,
}


func _init(target_root: Node3D, palette_resource: Resource = null) -> void:
	root = target_root
	palette = palette_resource


func add_root(
	parent: Node3D,
	node_name: String,
	position_value: Vector3 = Vector3.ZERO,
	rotation_value: Vector3 = Vector3.ZERO
) -> Node3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var node := Node3D.new()
	node.name = node_name
	node.position = position_value
	node.rotation = rotation_value
	node.set_meta("authored_environment", true)
	resolved_parent.add_child(node)
	return node


func add_static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	color_or_key: Variant = "stone",
	rotation_value: Vector3 = Vector3.ZERO,
	climbable: bool = false,
	visible_mesh: bool = true,
	role: String = "surface"
) -> StaticBody3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation = rotation_value
	body.add_to_group(SURFACE_GROUP)
	body.set_meta("authored_environment", true)
	body.set_meta("authored_role", role)
	body.set_meta("collision_required", true)
	if climbable:
		body.add_to_group("climbable")
		body.set_meta("climb_surface", "wet")
	resolved_parent.add_child(body)

	if visible_mesh:
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = material(color_or_key)
		body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	build_counts["static_boxes"] = int(build_counts["static_boxes"]) + 1
	return body


func add_static_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	color_or_key: Variant = "stone",
	rotation_value: Vector3 = Vector3.ZERO,
	climbable: bool = false,
	role: String = "surface"
) -> StaticBody3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation = rotation_value
	body.add_to_group(SURFACE_GROUP)
	body.set_meta("authored_environment", true)
	body.set_meta("authored_role", role)
	body.set_meta("collision_required", true)
	if climbable:
		body.add_to_group("climbable")
		body.set_meta("climb_surface", "wet")
	resolved_parent.add_child(body)

	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	visual.mesh = mesh
	visual.material_override = material(color_or_key)
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	build_counts["static_cylinders"] = int(build_counts["static_cylinders"]) + 1
	return body


func add_visual_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	color_or_key: Variant = "stone",
	rotation_value: Vector3 = Vector3.ZERO,
	alpha: float = 1.0,
	emission_energy: float = 0.0,
	role: String = "decor"
) -> MeshInstance3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	visual.add_to_group(DECOR_GROUP)
	visual.set_meta("authored_environment", true)
	visual.set_meta("authored_role", role)
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material(color_or_key, alpha, emission_energy)
	resolved_parent.add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func add_visual_cylinder(
	parent: Node3D,
	node_name: String,
	top_radius: float,
	bottom_radius: float,
	height: float,
	position_value: Vector3,
	color_or_key: Variant = "stone",
	rotation_value: Vector3 = Vector3.ZERO,
	alpha: float = 1.0,
	emission_energy: float = 0.0,
	role: String = "decor"
) -> MeshInstance3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	visual.add_to_group(DECOR_GROUP)
	visual.set_meta("authored_environment", true)
	visual.set_meta("authored_role", role)
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	visual.mesh = mesh
	visual.material_override = material(color_or_key, alpha, emission_energy)
	resolved_parent.add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func add_visual_sphere(
	parent: Node3D,
	node_name: String,
	radius: float,
	position_value: Vector3,
	color_or_key: Variant = "accent",
	scale_value: Vector3 = Vector3.ONE,
	alpha: float = 1.0,
	emission_energy: float = 0.0,
	role: String = "decor"
) -> MeshInstance3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.scale = scale_value
	visual.add_to_group(DECOR_GROUP)
	visual.set_meta("authored_environment", true)
	visual.set_meta("authored_role", role)
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	visual.mesh = mesh
	visual.material_override = material(color_or_key, alpha, emission_energy)
	resolved_parent.add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func add_visual_torus(
	parent: Node3D,
	node_name: String,
	inner_radius: float,
	outer_radius: float,
	position_value: Vector3,
	color_or_key: Variant = "accent",
	rotation_value: Vector3 = Vector3.ZERO,
	alpha: float = 1.0,
	emission_energy: float = 0.0,
	role: String = "decor"
) -> MeshInstance3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	visual.add_to_group(DECOR_GROUP)
	visual.set_meta("authored_environment", true)
	visual.set_meta("authored_role", role)
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 20
	mesh.ring_segments = 10
	visual.mesh = mesh
	visual.material_override = material(color_or_key, alpha, emission_energy)
	resolved_parent.add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func add_stair_run(
	parent: Node3D,
	node_name: String,
	low_origin: Vector3,
	direction: Vector3,
	step_count: int,
	step_width: float,
	step_run: float,
	total_rise: float,
	color_or_key: Variant = "stone_wet",
	climbable: bool = true
) -> Node3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var run_root := add_root(resolved_parent, node_name, low_origin)
	run_root.add_to_group("authored_environment_stair_run")
	run_root.set_meta("step_count", maxi(step_count, 1))
	run_root.set_meta("total_rise", total_rise)
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.001:
		flat_direction = Vector3.FORWARD
	flat_direction = flat_direction.normalized()
	run_root.rotation.y = atan2(flat_direction.x, flat_direction.z)
	var count: int = maxi(step_count, 1)
	for index: int in range(count):
		var progress: float = float(index + 1) / float(count)
		var height: float = maxf(total_rise * progress, 0.08)
		var local_position := Vector3(0.0, height * 0.5, step_run * (float(index) + 0.5))
		add_static_box(
			run_root,
			"Step%02d" % index,
			Vector3(step_width, height, step_run + 0.035),
			local_position,
			color_or_key,
			Vector3.ZERO,
			climbable,
			true,
			"stair"
		)
	build_counts["stair_runs"] = int(build_counts["stair_runs"]) + 1
	return run_root


func add_pillar(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	height: float,
	radius: float,
	color_or_key: Variant = "stone",
	collision: bool = true
) -> Node3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var pillar_root := add_root(resolved_parent, node_name, position_value)
	var base_height: float = 0.34
	var capital_height: float = 0.34
	add_static_box(
		pillar_root,
		"Base",
		Vector3(radius * 2.6, base_height, radius * 2.6),
		Vector3(0.0, base_height * 0.5, 0.0),
		"stone_secondary",
		Vector3.ZERO,
		false,
		collision,
		"pillar_base"
	)
	if collision:
		add_static_cylinder(
			pillar_root,
			"Shaft",
			radius,
			maxf(height - base_height - capital_height, 0.2),
			Vector3(0.0, base_height + (height - base_height - capital_height) * 0.5, 0.0),
			color_or_key,
			Vector3.ZERO,
			false,
			"pillar_shaft"
		)
	else:
		add_visual_cylinder(
			pillar_root,
			"Shaft",
			radius,
			radius,
			maxf(height - base_height - capital_height, 0.2),
			Vector3(0.0, base_height + (height - base_height - capital_height) * 0.5, 0.0),
			color_or_key
		)
	add_visual_box(
		pillar_root,
		"Capital",
		Vector3(radius * 2.8, capital_height, radius * 2.8),
		Vector3(0.0, height - capital_height * 0.5, 0.0),
		"stone_secondary"
	)
	build_counts["pillars"] = int(build_counts["pillars"]) + 1
	return pillar_root


func add_archway(
	parent: Node3D,
	node_name: String,
	ground_center: Vector3,
	opening_width: float,
	opening_height: float,
	depth: float,
	column_width: float,
	color_or_key: Variant = "stone"
) -> Node3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var arch_root := add_root(resolved_parent, node_name, ground_center)
	var post_height: float = maxf(opening_height, 1.0)
	var post_offset: float = opening_width * 0.5 + column_width * 0.5
	add_static_box(
		arch_root,
		"LeftPost",
		Vector3(column_width, post_height, depth),
		Vector3(-post_offset, post_height * 0.5, 0.0),
		color_or_key,
		Vector3.ZERO,
		false,
		true,
		"arch_post"
	)
	add_static_box(
		arch_root,
		"RightPost",
		Vector3(column_width, post_height, depth),
		Vector3(post_offset, post_height * 0.5, 0.0),
		color_or_key,
		Vector3.ZERO,
		false,
		true,
		"arch_post"
	)
	var lintel_height: float = maxf(column_width * 0.8, 0.38)
	add_static_box(
		arch_root,
		"Lintel",
		Vector3(opening_width + column_width * 2.0, lintel_height, depth),
		Vector3(0.0, post_height + lintel_height * 0.5, 0.0),
		"stone_secondary",
		Vector3.ZERO,
		false,
		true,
		"arch_lintel"
	)
	for side: float in [-1.0, 1.0]:
		add_visual_box(
			arch_root,
			"Corbel%s" % ("Left" if side < 0.0 else "Right"),
			Vector3(column_width * 1.35, lintel_height * 0.75, depth * 1.08),
			Vector3(side * (opening_width * 0.5 + column_width * 0.18), post_height - lintel_height * 0.12, 0.0),
			"stone_secondary",
			Vector3(0.0, 0.0, side * 0.18)
		)
	build_counts["archways"] = int(build_counts["archways"]) + 1
	return arch_root


func add_bench(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	length: float,
	rotation_y: float = 0.0,
	broken_amount: float = 0.0,
	color_or_key: Variant = "wood"
) -> Node3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var bench_root := add_root(resolved_parent, node_name, position_value, Vector3(0.0, rotation_y, 0.0))
	bench_root.add_to_group(DECOR_GROUP)
	var tilt: float = clampf(broken_amount, -1.0, 1.0) * 0.12
	add_visual_box(bench_root, "Seat", Vector3(length, 0.16, 0.62), Vector3(0.0, 0.54, 0.0), color_or_key, Vector3(0.0, 0.0, tilt))
	add_visual_box(bench_root, "Back", Vector3(length, 0.72, 0.14), Vector3(0.0, 0.92, 0.27), color_or_key, Vector3(tilt * 0.4, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		add_visual_box(bench_root, "Leg%s" % ("L" if side < 0.0 else "R"), Vector3(0.16, 0.55, 0.48), Vector3(side * length * 0.36, 0.27, 0.0), "wood_dark", Vector3(0.0, 0.0, -side * tilt))
	return bench_root


func add_point_light(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	color_or_key: Variant,
	energy: float,
	range_value: float,
	shadows: bool = false
) -> OmniLight3D:
	var resolved_parent: Node3D = _resolve_parent(parent)
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = _resolve_color(color_or_key)
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = shadows
	light.add_to_group(LIGHT_GROUP)
	light.set_meta("authored_environment", true)
	resolved_parent.add_child(light)
	build_counts["lights"] = int(build_counts["lights"]) + 1
	return light


func material(
	color_or_key: Variant,
	alpha: float = 1.0,
	emission_energy: float = 0.0,
	roughness: float = 0.86,
	metallic: float = 0.0
) -> StandardMaterial3D:
	var base_color: Color = _resolve_color(color_or_key)
	var resolved_alpha: float = clampf(base_color.a * alpha, 0.0, 1.0)
	var key := "%s|%.3f|%.3f|%.3f|%.3f" % [str(base_color), resolved_alpha, emission_energy, roughness, metallic]
	if material_cache.has(key):
		return material_cache[key] as StandardMaterial3D
	var value := StandardMaterial3D.new()
	value.albedo_color = Color(base_color.r, base_color.g, base_color.b, resolved_alpha)
	value.roughness = roughness
	value.metallic = metallic
	if resolved_alpha < 0.999:
		value.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		value.emission_enabled = true
		value.emission = Color(base_color.r, base_color.g, base_color.b, 1.0)
		value.emission_energy_multiplier = emission_energy
	material_cache[key] = value
	return value


func get_build_stats() -> Dictionary:
	return build_counts.duplicate(true)


func _resolve_parent(parent: Node3D) -> Node3D:
	return parent if parent != null else root


func _resolve_color(color_or_key: Variant) -> Color:
	if color_or_key is Color:
		return color_or_key as Color
	if palette != null and palette.has_method("color"):
		return palette.call("color", str(color_or_key), Color.WHITE) as Color
	return Color.WHITE
