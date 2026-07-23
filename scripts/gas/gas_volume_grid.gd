extends Node3D
class_name GasVolumeGrid

@export var gas_definition: GasDefinition
@export var gas_id: String = "gas"

@export_group("Grid")
@export var grid_size: Vector3i = Vector3i(14, 8, 14)
@export_range(0.2, 4.0, 0.05) var cell_size: float = 0.9
@export_range(0.02, 1.0, 0.01) var simulation_interval: float = 0.12
@export_range(1, 8, 1) var maximum_steps_per_frame: int = 2
@export_range(0.0, 4.0, 0.01) var diffusion_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.01) var decay_multiplier: float = 1.0
@export var resettable: bool = true

@export_group("Visualization")
@export var show_density_visuals: bool = true
@export_range(1, 4, 1) var visual_stride: int = 1
@export_range(0.02, 1.0, 0.01) var visual_update_interval: float = 0.12
@export_range(0.05, 1.5, 0.01) var visual_radius_scale: float = 0.44
@export_range(0.0, 1.0, 0.01) var visual_alpha_multiplier: float = 1.0

var airflow_manager: Node = null
var density: PackedFloat32Array = PackedFloat32Array()
var next_density: PackedFloat32Array = PackedFloat32Array()
var simulation_timer: float = 0.0
var visual_timer: float = 0.0
var simulation_time: float = 0.0
var initial_transform: Transform3D

var density_multimesh_instance: MultiMeshInstance3D = null
var density_multimesh: MultiMesh = null
var visual_cell_indices: PackedInt32Array = PackedInt32Array()
var last_total_density: float = 0.0
var last_maximum_density: float = 0.0
var last_active_cell_count: int = 0


func _ready() -> void:
	add_to_group("gas_volumes")
	add_to_group("debuggable")
	if resettable:
		add_to_group("lab_resettable")
	initial_transform = transform
	resolve_definition()
	initialize_grid()
	build_density_visualizer()
	update_density_visuals()


func _process(delta: float) -> void:
	var safe_delta: float = max(delta, 0.0)
	simulation_timer += safe_delta
	visual_timer += safe_delta
	var step_count: int = 0
	while simulation_timer >= simulation_interval and step_count < maximum_steps_per_frame:
		simulation_timer -= simulation_interval
		simulate_step(simulation_interval)
		step_count += 1
	if visual_timer >= visual_update_interval:
		visual_timer = 0.0
		update_density_visuals()


func resolve_definition() -> void:
	if gas_definition != null:
		if gas_definition.gas_id.strip_edges() != "":
			gas_id = gas_definition.gas_id
		return
	gas_definition = GasDefinition.new()
	gas_definition.gas_id = gas_id
	gas_definition.display_name = gas_id.capitalize()


func initialize_grid() -> void:
	grid_size.x = max(grid_size.x, 1)
	grid_size.y = max(grid_size.y, 1)
	grid_size.z = max(grid_size.z, 1)
	var total_cells: int = get_total_cell_count()
	density.resize(total_cells)
	next_density.resize(total_cells)
	density.fill(0.0)
	next_density.fill(0.0)


func simulate_step(delta: float) -> void:
	if density.is_empty():
		return
	resolve_airflow_manager()
	simulation_time += max(delta, 0.0)
	last_total_density = 0.0
	last_maximum_density = 0.0
	last_active_cell_count = 0

	for z: int in range(grid_size.z):
		for y: int in range(grid_size.y):
			for x: int in range(grid_size.x):
				var cell := Vector3i(x, y, z)
				var index: int = get_cell_index(cell)
				var world_position: Vector3 = get_cell_world_position(cell)
				var air_velocity: Vector3 = sample_airflow(world_position)
				var transport_velocity: Vector3 = (
					air_velocity * max(gas_definition.advection_scale, 0.0)
					+ gas_definition.buoyancy_velocity
				)
				var backtraced_position: Vector3 = world_position - transport_velocity * delta
				var advected_density: float = sample_density_from_buffer(backtraced_position, density)
				var neighbor_average: float = get_neighbor_average(cell, density)
				var diffusion_blend: float = clampf(
					gas_definition.diffusion_rate * diffusion_multiplier * delta,
					0.0,
					1.0
				)
				var resolved_density: float = lerpf(advected_density, neighbor_average, diffusion_blend)
				resolved_density *= exp(
					-max(gas_definition.decay_rate_per_second * decay_multiplier, 0.0) * delta
				)
				next_density[index] = gas_definition.clamp_density(resolved_density)

	apply_emitters(delta)

	var previous_density: PackedFloat32Array = density
	density = next_density
	next_density = previous_density

	for value: float in density:
		last_total_density += value
		last_maximum_density = max(last_maximum_density, value)
		if value >= gas_definition.visual_density_threshold:
			last_active_cell_count += 1


func sample_airflow(world_position: Vector3) -> Vector3:
	var manager: Node = resolve_airflow_manager()
	if manager == null or not manager.has_method("sample_total_airflow"):
		return Vector3.ZERO
	var sampled_value: Variant = manager.call("sample_total_airflow", world_position, simulation_time)
	return sampled_value as Vector3 if sampled_value is Vector3 else Vector3.ZERO


func resolve_airflow_manager() -> Node:
	if airflow_manager != null and is_instance_valid(airflow_manager):
		return airflow_manager
	airflow_manager = get_tree().get_first_node_in_group("airflow_manager")
	return airflow_manager


func apply_emitters(delta: float) -> void:
	for emitter: Node in get_tree().get_nodes_in_group("gas_emitters"):
		if emitter == null or not is_instance_valid(emitter):
			continue
		if emitter.has_method("matches_gas") and not bool(emitter.call("matches_gas", gas_id)):
			continue
		if not emitter.has_method("get_emission_amount"):
			continue
		var amount: float = float(emitter.call("get_emission_amount", delta))
		if amount <= 0.0:
			continue
		var radius_value: float = float(emitter.get("emission_radius")) if emitter.get("emission_radius") != null else cell_size
		var center_bias: float = float(emitter.get("center_bias")) if emitter.get("center_bias") != null else 0.45
		inject_into_next_buffer(emitter.global_position, amount, radius_value, center_bias)


func inject_density(world_position: Vector3, amount: float, radius_value: float = 0.75, center_bias: float = 0.45) -> void:
	if amount <= 0.0:
		return
	inject_into_buffer(density, world_position, amount, radius_value, center_bias)


func inject_into_next_buffer(world_position: Vector3, amount: float, radius_value: float, center_bias: float) -> void:
	var center_grid: Vector3 = world_to_grid_coordinate(world_position)
	var radius_cells: int = max(1, ceili(max(radius_value, cell_size * 0.5) / cell_size))
	var center_cell := Vector3i(roundi(center_grid.x), roundi(center_grid.y), roundi(center_grid.z))
	for z: int in range(max(center_cell.z - radius_cells, 0), min(center_cell.z + radius_cells + 1, grid_size.z)):
		for y: int in range(max(center_cell.y - radius_cells, 0), min(center_cell.y + radius_cells + 1, grid_size.y)):
			for x: int in range(max(center_cell.x - radius_cells, 0), min(center_cell.x + radius_cells + 1, grid_size.x)):
				var cell := Vector3i(x, y, z)
				var distance: float = get_cell_world_position(cell).distance_to(world_position)
				if distance > radius_value:
					continue
				var normalized_weight: float = clampf(1.0 - distance / max(radius_value, 0.001), 0.0, 1.0)
				var exponent_value: float = lerpf(1.0, 3.0, clampf(center_bias, 0.0, 1.0))
				var weight: float = pow(normalized_weight, exponent_value)
				var index: int = get_cell_index(cell)
				next_density[index] = gas_definition.clamp_density(next_density[index] + amount * weight)


func inject_into_buffer(buffer: PackedFloat32Array, world_position: Vector3, amount: float, radius_value: float, center_bias: float) -> void:
	var center_grid: Vector3 = world_to_grid_coordinate(world_position)
	var radius_cells: int = max(1, ceili(max(radius_value, cell_size * 0.5) / cell_size))
	var center_cell := Vector3i(roundi(center_grid.x), roundi(center_grid.y), roundi(center_grid.z))
	for z: int in range(max(center_cell.z - radius_cells, 0), min(center_cell.z + radius_cells + 1, grid_size.z)):
		for y: int in range(max(center_cell.y - radius_cells, 0), min(center_cell.y + radius_cells + 1, grid_size.y)):
			for x: int in range(max(center_cell.x - radius_cells, 0), min(center_cell.x + radius_cells + 1, grid_size.x)):
				var cell := Vector3i(x, y, z)
				var distance: float = get_cell_world_position(cell).distance_to(world_position)
				if distance > radius_value:
					continue
				var normalized_weight: float = clampf(1.0 - distance / max(radius_value, 0.001), 0.0, 1.0)
				var exponent_value: float = lerpf(1.0, 3.0, clampf(center_bias, 0.0, 1.0))
				var weight: float = pow(normalized_weight, exponent_value)
				var index: int = get_cell_index(cell)
				buffer[index] = gas_definition.clamp_density(buffer[index] + amount * weight)


func sample_density(world_position: Vector3) -> float:
	return sample_density_from_buffer(world_position, density)


func sample_density_from_buffer(world_position: Vector3, buffer: PackedFloat32Array) -> float:
	if buffer.is_empty():
		return 0.0
	var coordinate: Vector3 = world_to_grid_coordinate(world_position)
	if (
		coordinate.x < -0.5 or coordinate.x > float(grid_size.x) - 0.5
		or coordinate.y < -0.5 or coordinate.y > float(grid_size.y) - 0.5
		or coordinate.z < -0.5 or coordinate.z > float(grid_size.z) - 0.5
	):
		return 0.0

	var x0: int = floori(coordinate.x)
	var y0: int = floori(coordinate.y)
	var z0: int = floori(coordinate.z)
	var tx: float = coordinate.x - float(x0)
	var ty: float = coordinate.y - float(y0)
	var tz: float = coordinate.z - float(z0)

	var c000: float = get_buffer_cell(buffer, x0, y0, z0)
	var c100: float = get_buffer_cell(buffer, x0 + 1, y0, z0)
	var c010: float = get_buffer_cell(buffer, x0, y0 + 1, z0)
	var c110: float = get_buffer_cell(buffer, x0 + 1, y0 + 1, z0)
	var c001: float = get_buffer_cell(buffer, x0, y0, z0 + 1)
	var c101: float = get_buffer_cell(buffer, x0 + 1, y0, z0 + 1)
	var c011: float = get_buffer_cell(buffer, x0, y0 + 1, z0 + 1)
	var c111: float = get_buffer_cell(buffer, x0 + 1, y0 + 1, z0 + 1)

	var c00: float = lerpf(c000, c100, tx)
	var c10: float = lerpf(c010, c110, tx)
	var c01: float = lerpf(c001, c101, tx)
	var c11: float = lerpf(c011, c111, tx)
	var c0: float = lerpf(c00, c10, ty)
	var c1: float = lerpf(c01, c11, ty)
	return lerpf(c0, c1, tz)


func get_neighbor_average(cell: Vector3i, buffer: PackedFloat32Array) -> float:
	var total: float = get_buffer_cell(buffer, cell.x, cell.y, cell.z)
	var count: int = 1
	var offsets: Array[Vector3i] = [
		Vector3i.LEFT,
		Vector3i.RIGHT,
		Vector3i.DOWN,
		Vector3i.UP,
		Vector3i(0, 0, -1),
		Vector3i(0, 0, 1),
	]
	for offset: Vector3i in offsets:
		var neighbor: Vector3i = cell + offset
		if not is_cell_valid(neighbor):
			continue
		total += buffer[get_cell_index(neighbor)]
		count += 1
	return total / float(max(count, 1))


func get_buffer_cell(buffer: PackedFloat32Array, x: int, y: int, z: int) -> float:
	var cell := Vector3i(x, y, z)
	if not is_cell_valid(cell):
		return 0.0
	return buffer[get_cell_index(cell)]


func get_cell_index(cell: Vector3i) -> int:
	return cell.x + grid_size.x * (cell.y + grid_size.y * cell.z)


func get_total_cell_count() -> int:
	return grid_size.x * grid_size.y * grid_size.z


func is_cell_valid(cell: Vector3i) -> bool:
	return (
		cell.x >= 0 and cell.x < grid_size.x
		and cell.y >= 0 and cell.y < grid_size.y
		and cell.z >= 0 and cell.z < grid_size.z
	)


func get_grid_local_origin() -> Vector3:
	var full_size := Vector3(grid_size.x, grid_size.y, grid_size.z) * cell_size
	return -full_size * 0.5 + Vector3.ONE * cell_size * 0.5


func get_cell_local_position(cell: Vector3i) -> Vector3:
	return get_grid_local_origin() + Vector3(cell.x, cell.y, cell.z) * cell_size


func get_cell_world_position(cell: Vector3i) -> Vector3:
	return to_global(get_cell_local_position(cell))


func world_to_grid_coordinate(world_position: Vector3) -> Vector3:
	var local_position: Vector3 = to_local(world_position)
	return (local_position - get_grid_local_origin()) / cell_size


func build_density_visualizer() -> void:
	if density_multimesh_instance != null:
		density_multimesh_instance.queue_free()
	visual_cell_indices = PackedInt32Array()
	var safe_stride: int = max(visual_stride, 1)
	for z: int in range(0, grid_size.z, safe_stride):
		for y: int in range(0, grid_size.y, safe_stride):
			for x: int in range(0, grid_size.x, safe_stride):
				visual_cell_indices.append(get_cell_index(Vector3i(x, y, z)))

	var mesh := SphereMesh.new()
	mesh.radius = cell_size * visual_radius_scale
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 7
	mesh.rings = 4

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var color: Color = gas_definition.visual_color
	color.a *= visual_alpha_multiplier
	material.albedo_color = color
	material.emission_enabled = gas_definition.emission_energy > 0.0
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = gas_definition.emission_energy
	mesh.material = material

	density_multimesh = MultiMesh.new()
	density_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	density_multimesh.instance_count = visual_cell_indices.size()
	density_multimesh.mesh = mesh

	density_multimesh_instance = MultiMeshInstance3D.new()
	density_multimesh_instance.name = "DensityMultiMesh"
	density_multimesh_instance.multimesh = density_multimesh
	density_multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	density_multimesh_instance.visible = show_density_visuals
	add_child(density_multimesh_instance)


func update_density_visuals() -> void:
	if density_multimesh == null or gas_definition == null:
		return
	var threshold: float = max(gas_definition.visual_density_threshold, 0.0001)
	for visual_index: int in range(visual_cell_indices.size()):
		var cell_index: int = visual_cell_indices[visual_index]
		var value: float = density[cell_index] if cell_index >= 0 and cell_index < density.size() else 0.0
		var cell: Vector3i = cell_from_index(cell_index)
		var scale_value: float = 0.0
		if value >= threshold:
			var density_ratio: float = gas_definition.get_density_ratio(value)
			scale_value = 0.28 + density_ratio * 0.95
		var basis := Basis().scaled(Vector3.ONE * scale_value)
		density_multimesh.set_instance_transform(
			visual_index,
			Transform3D(basis, get_cell_local_position(cell))
		)


func cell_from_index(index: int) -> Vector3i:
	var plane_size: int = grid_size.x * grid_size.y
	var z: int = index / plane_size
	var remainder: int = index - z * plane_size
	var y: int = remainder / grid_size.x
	var x: int = remainder - y * grid_size.x
	return Vector3i(x, y, z)


func set_density_visuals_visible(value: bool) -> void:
	show_density_visuals = value
	if density_multimesh_instance != null:
		density_multimesh_instance.visible = value


func clear_density() -> void:
	density.fill(0.0)
	next_density.fill(0.0)
	last_total_density = 0.0
	last_maximum_density = 0.0
	last_active_cell_count = 0
	update_density_visuals()


func get_total_density_mass() -> float:
	var total: float = 0.0
	for value: float in density:
		total += value
	return total * pow(cell_size, 3.0)


func reset_target() -> void:
	transform = initial_transform
	simulation_timer = 0.0
	visual_timer = 0.0
	simulation_time = 0.0
	clear_density()


func get_debug_data() -> Dictionary:
	return {
		"gas_volume": gas_id,
		"grid_size": grid_size,
		"cell_size": snapped(cell_size, 0.01),
		"total_cells": get_total_cell_count(),
		"active_cells": last_active_cell_count,
		"density_sum": snapped(last_total_density, 0.01),
		"density_mass": snapped(get_total_density_mass(), 0.01),
		"maximum_density": snapped(last_maximum_density, 0.01),
		"simulation_time": snapped(simulation_time, 0.01),
		"definition": gas_definition.get_debug_data() if gas_definition != null else {},
	}
