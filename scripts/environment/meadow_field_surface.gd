extends Node3D
class_name MeadowFieldSurface

const GROUND_MATERIAL: ShaderMaterial = preload(
	"res://art/materials/environment/natural/stylized_pbr_meadow_ground_v1.tres"
)
const GRASS_MATERIAL: ShaderMaterial = preload(
	"res://art/materials/environment/natural/meadow_grass_v1.tres"
)

@export var field_width: float = 108.0
@export var field_depth: float = 164.0
@export_range(24, 160, 1) var terrain_columns: int = 73
@export_range(24, 192, 1) var terrain_rows: int = 105
@export_range(1000, 30000, 100) var grass_instance_count: int = 23000
@export_range(0, 4000, 50) var seed_head_count: int = 1550
@export_range(0, 2000, 20) var wildflower_count: int = 440
@export var scatter_seed: int = 18890417
@export var build_on_ready: bool = true

var built: bool = false
var terrain_mesh: ArrayMesh
var terrain_body: StaticBody3D
var grass_canopy: MultiMeshInstance3D
var seed_heads: MultiMeshInstance3D
var wildflowers: MultiMeshInstance3D
var horizon_root: Node3D
var minimum_height: float = 0.0
var maximum_height: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	if build_on_ready:
		build_field()


func build_field() -> void:
	if built:
		return
	built = true
	rng.seed = scatter_seed
	name = "GoldenMeadowSurface"
	add_to_group("meadow_field_surface")
	add_to_group("authored_environment_composition")
	set_meta("asset_quality_target", "hero_environment_benchmark")
	set_meta("gameplay_clutter_free", true)

	_build_terrain()
	_build_vegetation()
	_build_horizon()
	set_meta("meadow_metrics", get_debug_data())


func get_height(x_value: float, z_value: float) -> float:
	var raw_height: float = _raw_height(x_value, z_value)
	var spawn_z: float = field_depth * 0.38
	var spawn_height: float = _raw_height(0.0, spawn_z)
	var spawn_distance: float = Vector2(
		x_value,
		z_value - spawn_z
	).length()
	var flatten_weight: float = _smoothstep(3.0, 11.0, spawn_distance)
	return lerpf(spawn_height, raw_height, flatten_weight)


func get_spawn_position() -> Vector3:
	var spawn_z: float = field_depth * 0.38
	return Vector3(0.0, get_height(0.0, spawn_z) + 1.05, spawn_z)


func _raw_height(x_value: float, z_value: float) -> float:
	var broad_roll: float = (
		sin(x_value * 0.038 + 0.45) * 0.72
		+ cos(z_value * 0.031 - 0.85) * 0.58
		+ sin((x_value + z_value) * 0.067) * 0.24
		+ cos((x_value - z_value) * 0.091 + 0.3) * 0.14
	)
	var northward_lift: float = (
		-z_value / maxf(field_depth, 1.0)
	) * 0.72
	var edge_x: float = absf(x_value) / maxf(field_width * 0.5, 0.01)
	var edge_z: float = absf(z_value) / maxf(field_depth * 0.5, 0.01)
	var edge_lift: float = (
		pow(edge_x, 3.2) * 1.15
		+ pow(edge_z, 4.0) * 1.45
	)
	return broad_roll + northward_lift + edge_lift


func _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
	var span: float = maxf(edge_end - edge_start, 0.0001)
	var t: float = clampf((value - edge_start) / span, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _build_terrain() -> void:
	terrain_body = StaticBody3D.new()
	terrain_body.name = "MeadowTerrain"
	terrain_body.add_to_group("meadow_walkable_terrain")
	add_child(terrain_body)

	terrain_mesh = _create_terrain_mesh()
	var visual := MeshInstance3D.new()
	visual.name = "TerrainVisual"
	visual.mesh = terrain_mesh
	visual.material_override = GROUND_MATERIAL
	visual.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	terrain_body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	var terrain_shape: Shape3D = terrain_mesh.create_trimesh_shape()
	collision.shape = terrain_shape
	terrain_body.add_child(collision)


func _create_terrain_mesh() -> ArrayMesh:
	var columns: int = maxi(terrain_columns, 2)
	var rows: int = maxi(terrain_rows, 2)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(columns * rows)
	normals.resize(columns * rows)
	uvs.resize(columns * rows)
	minimum_height = INF
	maximum_height = -INF

	for row: int in range(rows):
		var z_ratio: float = float(row) / float(rows - 1)
		var z_value: float = lerpf(
			-field_depth * 0.5,
			field_depth * 0.5,
			z_ratio
		)
		for column: int in range(columns):
			var x_ratio: float = float(column) / float(columns - 1)
			var x_value: float = lerpf(
				-field_width * 0.5,
				field_width * 0.5,
				x_ratio
			)
			var vertex_index: int = row * columns + column
			var y_value: float = get_height(x_value, z_value)
			vertices[vertex_index] = Vector3(x_value, y_value, z_value)
			normals[vertex_index] = _terrain_normal(x_value, z_value)
			uvs[vertex_index] = Vector2(x_ratio, z_ratio)
			minimum_height = minf(minimum_height, y_value)
			maximum_height = maxf(maximum_height, y_value)

	for row: int in range(rows - 1):
		for column: int in range(columns - 1):
			var a: int = row * columns + column
			var b: int = a + 1
			var c: int = a + columns
			var d: int = c + 1
			indices.append_array(PackedInt32Array([
				a, c, b,
				b, c, d,
			]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _terrain_normal(x_value: float, z_value: float) -> Vector3:
	var sample_distance: float = 0.32
	var left_height: float = get_height(
		x_value - sample_distance,
		z_value
	)
	var right_height: float = get_height(
		x_value + sample_distance,
		z_value
	)
	var near_height: float = get_height(
		x_value,
		z_value - sample_distance
	)
	var far_height: float = get_height(
		x_value,
		z_value + sample_distance
	)
	return Vector3(
		left_height - right_height,
		sample_distance * 2.0,
		near_height - far_height
	).normalized()


func _build_vegetation() -> void:
	var blade_mesh: ArrayMesh = _create_blade_clump_mesh()
	grass_canopy = _build_scatter_layer(
		"GrassCanopy",
		blade_mesh,
		GRASS_MATERIAL,
		grass_instance_count,
		Vector2(0.76, 1.16),
		Vector2(0.42, 0.68),
		"grass"
	)

	var seed_material := GRASS_MATERIAL.duplicate(true) as ShaderMaterial
	seed_material.set_shader_parameter(
		"base_color",
		Color(0.075, 0.19, 0.045, 1.0)
	)
	seed_material.set_shader_parameter(
		"tip_color",
		Color(0.57, 0.49, 0.16, 1.0)
	)
	seed_material.set_shader_parameter("wind_strength", 0.17)
	seed_material.set_shader_parameter("sun_kiss_intensity", 0.09)
	seed_heads = _build_scatter_layer(
		"SeedHeads",
		blade_mesh,
		seed_material,
		seed_head_count,
		Vector2(0.72, 1.1),
		Vector2(0.74, 1.12),
		"seed"
	)

	var flower_material := GRASS_MATERIAL.duplicate(true) as ShaderMaterial
	flower_material.set_shader_parameter(
		"base_color",
		Color(0.09, 0.24, 0.07, 1.0)
	)
	flower_material.set_shader_parameter(
		"tip_color",
		Color(1.0, 0.82, 0.42, 1.0)
	)
	flower_material.set_shader_parameter(
		"sun_kiss_color",
		Color(1.0, 0.45, 0.16, 1.0)
	)
	flower_material.set_shader_parameter("wind_strength", 0.18)
	flower_material.set_shader_parameter("sun_kiss_intensity", 0.12)
	wildflowers = _build_scatter_layer(
		"Wildflowers",
		_create_wildflower_mesh(),
		flower_material,
		wildflower_count,
		Vector2(0.78, 1.12),
		Vector2(0.78, 1.08),
		"flower"
	)


func _build_scatter_layer(
	layer_name: String,
	mesh_value: Mesh,
	material_value: Material,
	count: int,
	width_scale_range: Vector2,
	height_scale_range: Vector2,
	layer_kind: String
) -> MultiMeshInstance3D:
	var layer := MultiMeshInstance3D.new()
	layer.name = layer_name
	layer.material_override = material_value
	layer.extra_cull_margin = 3.0
	layer.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	add_child(layer)

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_custom_data = true
	multi_mesh.mesh = mesh_value
	multi_mesh.instance_count = maxi(count, 0)
	multi_mesh.custom_aabb = AABB(
		Vector3(
			-field_width * 0.5 - 2.0,
			minimum_height - 1.0,
			-field_depth * 0.5 - 2.0
		),
		Vector3(
			field_width + 4.0,
			maximum_height - minimum_height + 7.0,
			field_depth + 4.0
		)
	)
	layer.multimesh = multi_mesh

	for index: int in range(multi_mesh.instance_count):
		var scatter_position: Vector2 = _scatter_position(
			layer_kind,
			index
		)
		var x_value: float = scatter_position.x
		var z_value: float = scatter_position.y
		var y_value: float = get_height(x_value, z_value) + 0.015
		var yaw: float = rng.randf_range(0.0, TAU)
		var width_scale: float = rng.randf_range(
			width_scale_range.x,
			width_scale_range.y
		)
		var height_scale: float = rng.randf_range(
			height_scale_range.x,
			height_scale_range.y
		)
		var basis := Basis(Vector3.UP, yaw)
		basis = basis.scaled(Vector3(
			width_scale,
			height_scale,
			width_scale
		))
		multi_mesh.set_instance_transform(
			index,
			Transform3D(
				basis,
				Vector3(x_value, y_value, z_value)
			)
		)
		multi_mesh.set_instance_custom_data(
			index,
			Color(
				rng.randf_range(0.1, 0.95),
				rng.randf_range(0.08, 0.96),
				rng.randf(),
				1.0
			)
		)
	return layer


func _scatter_position(
	layer_kind: String,
	index: int
) -> Vector2:
	var margin: float = 1.8
	if layer_kind != "flower":
		var candidate := Vector2.ZERO
		var spawn_center := Vector2(0.0, field_depth * 0.38)
		for _attempt: int in range(6):
			candidate = Vector2(
				rng.randf_range(
					-field_width * 0.5 + margin,
					field_width * 0.5 - margin
				),
				rng.randf_range(
					-field_depth * 0.5 + margin,
					field_depth * 0.5 - margin
				)
			)
			if candidate.distance_to(spawn_center) >= 1.8:
				return candidate
		return candidate

	var flower_patches: Array[Vector2] = [
		Vector2(-24.0, -38.0),
		Vector2(17.0, -18.0),
		Vector2(-11.0, 12.0),
		Vector2(28.0, 36.0),
		Vector2(-30.0, 48.0),
		Vector2(9.0, -54.0),
	]
	var center: Vector2 = flower_patches[
		index % flower_patches.size()
	]
	var offset := Vector2(
		rng.randf_range(-5.5, 5.5)
			+ rng.randf_range(-3.0, 3.0),
		rng.randf_range(-6.5, 6.5)
			+ rng.randf_range(-3.5, 3.5)
	)
	return Vector2(
		clampf(
			center.x + offset.x,
			-field_width * 0.5 + margin,
			field_width * 0.5 - margin
		),
		clampf(
			center.y + offset.y,
			-field_depth * 0.5 + margin,
			field_depth * 0.5 - margin
		)
	)


func _create_blade_clump_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for blade_index: int in range(5):
		var angle: float = float(blade_index) * PI / 5.0
		var right := Vector3(cos(angle), 0.0, sin(angle))
		var normal := Vector3(-sin(angle), 0.0, cos(angle))
		var center := Vector3(
			cos(angle * 2.3) * 0.052,
			0.0,
			sin(angle * 2.3) * 0.052
		)
		var bend := Vector3(
			sin(angle * 1.7) * 0.052,
			0.0,
			cos(angle * 1.7) * 0.052
		)
		var half_width: float = 0.036 + float(blade_index % 2) * 0.005
		var mid_center: Vector3 = center + bend * 0.32 + Vector3.UP * 0.48
		var tip_center: Vector3 = center + bend + Vector3.UP * (
			0.88 + float(blade_index % 3) * 0.055
		)
		var base_index: int = vertices.size()
		vertices.append(center - right * half_width)
		vertices.append(center + right * half_width)
		vertices.append(mid_center - right * half_width * 0.48)
		vertices.append(mid_center + right * half_width * 0.48)
		vertices.append(tip_center)
		normals.append_array(PackedVector3Array([
			normal,
			normal,
			normal,
			normal,
			normal,
		]))
		uvs.append_array(PackedVector2Array([
			Vector2(0.0, 1.0),
			Vector2(1.0, 1.0),
			Vector2(0.26, 0.52),
			Vector2(0.74, 0.52),
			Vector2(0.5, 0.0),
		]))
		indices.append_array(PackedInt32Array([
			base_index,
			base_index + 1,
			base_index + 2,
			base_index + 1,
			base_index + 3,
			base_index + 2,
			base_index + 2,
			base_index + 3,
			base_index + 4,
		]))
	return _mesh_from_arrays(vertices, normals, uvs, indices)


func _create_wildflower_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-0.018, 0.0, 0.0),
		Vector3(0.018, 0.0, 0.0),
		Vector3(0.0, 0.56, 0.0),
		Vector3(0.0, 0.0, -0.018),
		Vector3(0.0, 0.0, 0.018),
		Vector3(0.0, 0.56, 0.0),
	])
	var normals := PackedVector3Array([
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(0.5, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(0.5, 0.0),
	])
	var indices := PackedInt32Array([0, 1, 2, 3, 4, 5])
	var flower_center := Vector3(0.0, 0.56, 0.0)
	for petal_index: int in range(6):
		var angle: float = float(petal_index) * TAU / 6.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-direction.z, 0.0, direction.x)
		var base_index: int = vertices.size()
		vertices.append(flower_center + side * 0.038)
		vertices.append(flower_center + direction * 0.145)
		vertices.append(flower_center - side * 0.038)
		normals.append_array(PackedVector3Array([
			Vector3.UP,
			Vector3.UP,
			Vector3.UP,
		]))
		uvs.append_array(PackedVector2Array([
			Vector2(0.35, 0.0),
			Vector2(0.5, 0.0),
			Vector2(0.65, 0.0),
		]))
		indices.append_array(PackedInt32Array([
			base_index,
			base_index + 1,
			base_index + 2,
		]))
	return _mesh_from_arrays(vertices, normals, uvs, indices)


func _mesh_from_arrays(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)
	return result


func _build_horizon() -> void:
	horizon_root = Node3D.new()
	horizon_root.name = "LayeredHorizon"
	horizon_root.add_to_group("meadow_horizon")
	add_child(horizon_root)
	_add_ridge_ring(
		"NearRidge",
		112.0,
		4.8,
		3.2,
		Color(0.10, 0.22, 0.16, 1.0),
		0.7
	)
	_add_ridge_ring(
		"MiddleRidge",
		148.0,
		7.6,
		5.2,
		Color(0.14, 0.24, 0.23, 1.0),
		2.1
	)
	_add_ridge_ring(
		"FarRidge",
		188.0,
		10.8,
		6.6,
		Color(0.23, 0.31, 0.34, 1.0),
		4.4
	)


func _add_ridge_ring(
	node_name: String,
	radius: float,
	base_height: float,
	amplitude: float,
	color: Color,
	phase: float
) -> void:
	var segments: int = 96
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for index: int in range(segments + 1):
		var ratio: float = float(index) / float(segments)
		var angle: float = ratio * TAU
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var ridge_height: float = (
			base_height
			+ sin(angle * 2.0 + phase) * amplitude * 0.42
			+ sin(angle * 5.0 - phase * 0.7) * amplitude * 0.22
			+ cos(angle * 9.0 + phase * 1.3) * amplitude * 0.11
		)
		vertices.append(direction * radius + Vector3.UP * -12.0)
		vertices.append(direction * radius + Vector3.UP * ridge_height)
		normals.append(-direction)
		normals.append(-direction)
	for index: int in range(segments):
		var base_index: int = index * 2
		indices.append_array(PackedInt32Array([
			base_index,
			base_index + 1,
			base_index + 2,
			base_index + 1,
			base_index + 3,
			base_index + 2,
		]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ridge := MeshInstance3D.new()
	ridge.name = node_name
	ridge.mesh = mesh
	ridge.material_override = material
	ridge.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	horizon_root.add_child(ridge)


func get_debug_data() -> Dictionary:
	return {
		"built": built,
		"field_width": field_width,
		"field_depth": field_depth,
		"terrain_vertices": (
			maxi(terrain_columns, 2)
			* maxi(terrain_rows, 2)
		),
		"terrain_triangles": (
			(maxi(terrain_columns, 2) - 1)
			* (maxi(terrain_rows, 2) - 1)
			* 2
		),
		"height_range": maximum_height - minimum_height,
		"grass_instances": (
			grass_canopy.multimesh.instance_count
			if grass_canopy != null
			and grass_canopy.multimesh != null
			else 0
		),
		"seed_heads": (
			seed_heads.multimesh.instance_count
			if seed_heads != null
			and seed_heads.multimesh != null
			else 0
		),
		"wildflowers": (
			wildflowers.multimesh.instance_count
			if wildflowers != null
			and wildflowers.multimesh != null
			else 0
		),
		"horizon_layers": (
			horizon_root.get_child_count()
			if horizon_root != null
			else 0
		),
		"scatter_seed": scatter_seed,
		"grass_blades_per_clump": 5,
		"maximum_canopy_height": 0.68,
		"spawn_readability_radius": 1.8,
		"ground_surface_detail": "multi_scale_procedural_meadow",
		"ground_material": GROUND_MATERIAL.resource_path,
		"grass_material": GRASS_MATERIAL.resource_path,
		"gameplay_clutter_free": true,
	}
