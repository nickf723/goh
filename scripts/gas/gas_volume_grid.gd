extends Node3D
class_name GasVolumeGrid

@export var gas_definition: GasDefinition
@export var gas_id: String = "gas"

@export_group("Grid")
@export var grid_size: Vector3i = Vector3i(14, 8, 14)
@export_range(0.2, 4.0, 0.05) var cell_size: float = 0.9
@export_range(0.02, 1.0, 0.01) var simulation_interval: float = 0.12
@export_range(1, 8, 1) var maximum_steps_per_frame: int = 2
@export_range(0.0, 1.0, 0.01) var simulation_phase_offset: float = 0.0
@export_range(0.0, 4.0, 0.01) var diffusion_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.01) var decay_multiplier: float = 1.0
@export var resettable: bool = true

@export_group("Active Region")
@export var use_active_bounds: bool = true
@export_range(0.0001, 0.25, 0.0001) var active_density_threshold: float = 0.001
@export_range(1, 8, 1) var active_padding_cells: int = 3

@export_group("Visualization")
@export var show_density_visuals: bool = true
@export_range(1, 6, 1) var visual_stride: int = 1
@export_range(0.02, 1.0, 0.01) var visual_update_interval: float = 0.12
@export_range(0.05, 1.5, 0.01) var visual_radius_scale: float = 0.44
@export_range(0.0, 1.0, 0.01) var visual_alpha_multiplier: float = 1.0

var airflow_manager: Node = null
var density: PackedFloat32Array = PackedFloat32Array()
var next_density: PackedFloat32Array = PackedFloat32Array()
var cell_local_positions: PackedVector3Array = PackedVector3Array()
var cell_world_positions: PackedVector3Array = PackedVector3Array()
var cached_global_transform: Transform3D
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
var last_simulated_cell_count: int = 0
var has_active_density: bool = false
var active_min_cell: Vector3i = Vector3i.ZERO
var active_max_cell: Vector3i = Vector3i.ZERO


func _ready() -> void:
	add_to_group("gas_volumes")
	add_to_group("debuggable")
	if resettable:
		add_to_group("lab_resettable")
	initial_transform = transform
	resolve_definition()
	initialize_grid()
	simulation_timer = -max(simulation_phase_offset, 0.0)
	build_density_visualizer()
	update_density_visuals()


func _process(delta: float) -> void:
	var safe_delta: float = max(delta, 0.0)
	simulation_timer += safe_delta
	visual_timer += safe_delta
	var safe_interval: float = max(simulation_interval, 0.02)
	var step_count: int = 0
	while simulation_timer >= safe_interval and step_count < maximum_steps_per_frame:
		simulation_timer -= safe_interval
		simulate_step(safe_interval)
		step_count += 1
	if visual_timer >= visual_update_interval:
		visual_timer = 0.0
		if show_density_visuals:
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
	cell_local_positions.resize(total_cells)
	cell_world_positions.resize(total_cells)
	density.fill(0.0)
	next_density.fill(0.0)
	cache_cell_positions()


func cache_cell_positions() -> void:
	cached_global_transform = global_transform
	var local_origin: Vector3 = get_grid_local_origin()
	for z: int in range(grid_size.z):
		for y: int in range(grid_size.y):
			for x: int in range(grid_size.x):
				var index: int = get_cell_index_xyz(x, y, z)
				var local_position: Vector3 = local_origin + Vector3(x, y, z) * cell_size
				cell_local_positions[index] = local_position
				cell_world_positions[index] = global_transform * local_position


func refresh_world_position_cache_if_needed() -> void:
	if global_transform != cached_global_transform:
		cache_cell_positions()


func simulate_step(delta: float) -> void:
	if density.is_empty() or gas_definition == null:
		return
	resolve_airflow_manager()
	refresh_world_position_cache_if_needed()
	simulation_time += max(delta, 0.0)

	var emissions: Array[Dictionary] = collect_emissions(delta)
	var bounds: Dictionary = get_simulation_bounds(emissions)
	next_density.fill(0.0)
	last_simulated_cell_count = 0

	if bool(bounds.get("valid", false)):
		var minimum: Vector3i = bounds.get("min", Vector3i.ZERO) as Vector3i
		var maximum: Vector3i = bounds.get("max", Vector3i.ZERO) as Vector3i
		var advection_scale: float = max(gas_definition.advection_scale, 0.0)
		var buoyancy_velocity: Vector3 = gas_definition.buoyancy_velocity
		var diffusion_blend: float = clampf(
			gas_definition.diffusion_rate * diffusion_multiplier * delta,
			0.0,
			1.0
		)
		var decay_factor: float = exp(
			-max(gas_definition.decay_rate_per_second * decay_multiplier, 0.0) * delta
		)
		var maximum_density: float = max(gas_definition.maximum_density, 0.001)

		for z: int in range(minimum.z, maximum.z + 1):
			for y: int in range(minimum.y, maximum.y + 1):
				for x: int in range(minimum.x, maximum.x + 1):
					var index: int = get_cell_index_xyz(x, y, z)
					var world_position: Vector3 = cell_world_positions[index]
					var air_velocity: Vector3 = sample_airflow(world_position)
					var transport_velocity: Vector3 = air_velocity * advection_scale + buoyancy_velocity
					var backtraced_position: Vector3 = world_position - transport_velocity * delta
					var advected_density: float = sample_density_from_buffer(backtraced_position, density)
					var neighbor_average: float = get_neighbor_average_xyz(x, y, z, index, density)
					var resolved_density: float = lerpf(advected_density, neighbor_average, diffusion_blend) * decay_factor
					next_density[index] = clampf(resolved_density, 0.0, maximum_density)
					last_simulated_cell_count += 1

	apply_emissions_to_buffer(next_density, emissions)

	var previous_density: PackedFloat32Array = density
	density = next_density
	next_density = previous_density
	refresh_density_statistics_and_bounds()


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


func collect_emissions(delta: float) -> Array[Dictionary]:
	var emissions: Array[Dictionary] = []
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
		emissions.append({
			"position": emitter.global_position,
			"amount": amount,
			"radius": radius_value,
			"center_bias": center_bias,
		})
	return emissions


func apply_emitters(delta: float) -> void:
	apply_emissions_to_buffer(next_density, collect_emissions(delta))


func apply_emissions_to_buffer(buffer: PackedFloat32Array, emissions: Array[Dictionary]) -> void:
	for emission: Dictionary in emissions:
		inject_into_buffer(
			buffer,
			emission.get("position", global_position) as Vector3,
			float(emission.get("amount", 0.0)),
			float(emission.get("radius", cell_size)),
			float(emission.get("center_bias", 0.45))
		)


func get_simulation_bounds(emissions: Array[Dictionary]) -> Dictionary:
	if not use_active_bounds:
		return {
			"valid": true,
			"min": Vector3i.ZERO,
			"max": grid_size - Vector3i.ONE,
		}

	var bounds: Dictionary = {
		"valid": false,
		"min": Vector3i(grid_size.x, grid_size.y, grid_size.z),
		"max": Vector3i(-1, -1, -1),
	}
	var padding: int = max(active_padding_cells, 1)

	if has_active_density:
		include_cell_in_bounds(bounds, active_min_cell, padding)
		include_cell_in_bounds(bounds, active_max_cell, padding)

	for emission: Dictionary in emissions:
		var position_value: Vector3 = emission.get("position", global_position) as Vector3
		var coordinate: Vector3 = world_to_grid_coordinate(position_value)
		var center := Vector3i(roundi(coordinate.x), roundi(coordinate.y), roundi(coordinate.z))
		var radius_cells: int = max(1, ceili(float(emission.get("radius", cell_size)) / cell_size))
		include_cell_in_bounds(bounds, center, radius_cells + padding)

	clamp_bounds_to_grid(bounds)
	return bounds


func include_cell_in_bounds(bounds: Dictionary, cell: Vector3i, padding: int = 0) -> void:
	var padded_min: Vector3i = cell - Vector3i.ONE * max(padding, 0)
	var padded_max: Vector3i = cell + Vector3i.ONE * max(padding, 0)
	if not bool(bounds.get("valid", false)):
		bounds["valid"] = true
		bounds["min"] = padded_min
		bounds["max"] = padded_max
		return
	var current_min: Vector3i = bounds.get("min", padded_min) as Vector3i
	var current_max: Vector3i = bounds.get("max", padded_max) as Vector3i
	bounds["min"] = Vector3i(
		min(current_min.x, padded_min.x),
		min(current_min.y, padded_min.y),
		min(current_min.z, padded_min.z)
	)
	bounds["max"] = Vector3i(
		max(current_max.x, padded_max.x),
		max(current_max.y, padded_max.y),
		max(current_max.z, padded_max.z)
	)


func clamp_bounds_to_grid(bounds: Dictionary) -> void:
	if not bool(bounds.get("valid", false)):
		return
	var minimum: Vector3i = bounds.get("min", Vector3i.ZERO) as Vector3i
	var maximum: Vector3i = bounds.get("max", Vector3i.ZERO) as Vector3i
	minimum = Vector3i(
		clampi(minimum.x, 0, grid_size.x - 1),
		clampi(minimum.y, 0, grid_size.y - 1),
		clampi(minimum.z, 0, grid_size.z - 1)
	)
	maximum = Vector3i(
		clampi(maximum.x, 0, grid_size.x - 1),
		clampi(maximum.y, 0, grid_size.y - 1),
		clampi(maximum.z, 0, grid_size.z - 1)
	)
	bounds["min"] = minimum
	bounds["max"] = maximum
	if minimum.x > maximum.x or minimum.y > maximum.y or minimum.z > maximum.z:
		bounds["valid"] = false


func inject_density(world_position: Vector3, amount: float, radius_value: float = 0.75, center_bias: float = 0.45) -> void:
	if amount <= 0.0:
		return
	inject_into_buffer(density, world_position, amount, radius_value, center_bias)
	refresh_density_statistics_and_bounds()


func inject_into_next_buffer(world_position: Vector3, amount: float, radius_value: float, center_bias: float) -> void:
	inject_into_buffer(next_density, world_position, amount, radius_value, center_bias)


func inject_into_buffer(buffer: PackedFloat32Array, world_position: Vector3, amount: float, radius_value: float, center_bias: float) -> void:
	if amount <= 0.0 or gas_definition == null:
		return
	var center_grid: Vector3 = world_to_grid_coordinate(world_position)
	var radius_cells: int = max(1, ceili(max(radius_value, cell_size * 0.5) / cell_size))
	var center_cell := Vector3i(roundi(center_grid.x), roundi(center_grid.y), roundi(center_grid.z))
	var minimum_x: int = max(center_cell.x - radius_cells, 0)
	var maximum_x: int = min(center_cell.x + radius_cells, grid_size.x - 1)
	var minimum_y: int = max(center_cell.y - radius_cells, 0)
	var maximum_y: int = min(center_cell.y + radius_cells, grid_size.y - 1)
	var minimum_z: int = max(center_cell.z - radius_cells, 0)
	var maximum_z: int = min(center_cell.z + radius_cells, grid_size.z - 1)
	var exponent_value: float = lerpf(1.0, 3.0, clampf(center_bias, 0.0, 1.0))
	var safe_radius: float = max(radius_value, 0.001)
	var maximum_density: float = max(gas_definition.maximum_density, 0.001)

	for z: int in range(minimum_z, maximum_z + 1):
		for y: int in range(minimum_y, maximum_y + 1):
			for x: int in range(minimum_x, maximum_x + 1):
				var index: int = get_cell_index_xyz(x, y, z)
				var distance: float = cell_world_positions[index].distance_to(world_position)
				if distance > radius_value:
					continue
				var normalized_weight: float = clampf(1.0 - distance / safe_radius, 0.0, 1.0)
				var weight: float = pow(normalized_weight, exponent_value)
				buffer[index] = clampf(buffer[index] + amount * weight, 0.0, maximum_density)


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

	var c000: float = get_buffer_value_xyz(buffer, x0, y0, z0)
	var c100: float = get_buffer_value_xyz(buffer, x0 + 1, y0, z0)
	var c010: float = get_buffer_value_xyz(buffer, x0, y0 + 1, z0)
	var c110: float = get_buffer_value_xyz(buffer, x0 + 1, y0 + 1, z0)
	var c001: float = get_buffer_value_xyz(buffer, x0, y0, z0 + 1)
	var c101: float = get_buffer_value_xyz(buffer, x0 + 1, y0, z0 + 1)
	var c011: float = get_buffer_value_xyz(buffer, x0, y0 + 1, z0 + 1)
	var c111: float = get_buffer_value_xyz(buffer, x0 + 1, y0 + 1, z0 + 1)

	var c00: float = lerpf(c000, c100, tx)
	var c10: float = lerpf(c010, c110, tx)
	var c01: float = lerpf(c001, c101, tx)
	var c11: float = lerpf(c011, c111, tx)
	var c0: float = lerpf(c00, c10, ty)
	var c1: float = lerpf(c01, c11, ty)
	return lerpf(c0, c1, tz)


func get_neighbor_average(cell: Vector3i, buffer: PackedFloat32Array) -> float:
	return get_neighbor_average_xyz(cell.x, cell.y, cell.z, get_cell_index(cell), buffer)


func get_neighbor_average_xyz(x: int, y: int, z: int, index: int, buffer: PackedFloat32Array) -> float:
	var total: float = buffer[index]
	var count: int = 1
	if x > 0:
		total += buffer[index - 1]
		count += 1
	if x + 1 < grid_size.x:
		total += buffer[index + 1]
		count += 1
	if y > 0:
		total += buffer[index - grid_size.x]
		count += 1
	if y + 1 < grid_size.y:
		total += buffer[index + grid_size.x]
		count += 1
	var plane_size: int = grid_size.x * grid_size.y
	if z > 0:
		total += buffer[index - plane_size]
		count += 1
	if z + 1 < grid_size.z:
		total += buffer[index + plane_size]
		count += 1
	return total / float(count)


func get_buffer_cell(buffer: PackedFloat32Array, x: int, y: int, z: int) -> float:
	return get_buffer_value_xyz(buffer, x, y, z)


func get_buffer_value_xyz(buffer: PackedFloat32Array, x: int, y: int, z: int) -> float:
	if x < 0 or x >= grid_size.x or y < 0 or y >= grid_size.y or z < 0 or z >= grid_size.z:
		return 0.0
	return buffer[get_cell_index_xyz(x, y, z)]


func get_cell_index(cell: Vector3i) -> int:
	return get_cell_index_xyz(cell.x, cell.y, cell.z)


func get_cell_index_xyz(x: int, y: int, z: int) -> int:
	return x + grid_size.x * (y + grid_size.y * z)


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
	var index: int = get_cell_index(cell)
	if index >= 0 and index < cell_local_positions.size():
		return cell_local_positions[index]
	return get_grid_local_origin() + Vector3(cell.x, cell.y, cell.z) * cell_size


func get_cell_world_position(cell: Vector3i) -> Vector3:
	var index: int = get_cell_index(cell)
	if index >= 0 and index < cell_world_positions.size():
		return cell_world_positions[index]
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
				visual_cell_indices.append(get_cell_index_xyz(x, y, z))

	var mesh := SphereMesh.new()
	mesh.radius = cell_size * visual_radius_scale
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3

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
	var maximum_density: float = max(gas_definition.maximum_density, 0.001)
	for visual_index: int in range(visual_cell_indices.size()):
		var cell_index: int = visual_cell_indices[visual_index]
		var value: float = density[cell_index] if cell_index >= 0 and cell_index < density.size() else 0.0
		var scale_value: float = 0.0
		if value >= threshold:
			var density_ratio: float = clampf(value, 0.0, maximum_density) / maximum_density
			scale_value = 0.28 + density_ratio * 0.95
		var basis := Basis().scaled(Vector3.ONE * scale_value)
		density_multimesh.set_instance_transform(
			visual_index,
			Transform3D(basis, cell_local_positions[cell_index])
		)


func cell_from_index(index: int) -> Vector3i:
	var plane_size: int = grid_size.x * grid_size.y
	var z: int = int(index / plane_size)
	var remainder: int = index - z * plane_size
	var y: int = int(remainder / grid_size.x)
	var x: int = remainder - y * grid_size.x
	return Vector3i(x, y, z)


func set_density_visuals_visible(value: bool) -> void:
	show_density_visuals = value
	if density_multimesh_instance != null:
		density_multimesh_instance.visible = value
	if value:
		update_density_visuals()


func refresh_density_statistics_and_bounds() -> void:
	last_total_density = 0.0
	last_maximum_density = 0.0
	last_active_cell_count = 0
	has_active_density = false
	var minimum := Vector3i(grid_size.x, grid_size.y, grid_size.z)
	var maximum := Vector3i(-1, -1, -1)
	var visual_threshold: float = max(gas_definition.visual_density_threshold, 0.0001)
	var simulation_threshold: float = max(active_density_threshold, 0.000001)

	for index: int in range(density.size()):
		var value: float = density[index]
		last_total_density += value
		last_maximum_density = max(last_maximum_density, value)
		if value >= visual_threshold:
			last_active_cell_count += 1
		if value < simulation_threshold:
			continue
		var cell: Vector3i = cell_from_index(index)
		if not has_active_density:
			minimum = cell
			maximum = cell
			has_active_density = true
		else:
			minimum = Vector3i(min(minimum.x, cell.x), min(minimum.y, cell.y), min(minimum.z, cell.z))
			maximum = Vector3i(max(maximum.x, cell.x), max(maximum.y, cell.y), max(maximum.z, cell.z))

	active_min_cell = minimum if has_active_density else Vector3i.ZERO
	active_max_cell = maximum if has_active_density else Vector3i.ZERO


func clear_density() -> void:
	density.fill(0.0)
	next_density.fill(0.0)
	last_total_density = 0.0
	last_maximum_density = 0.0
	last_active_cell_count = 0
	last_simulated_cell_count = 0
	has_active_density = false
	active_min_cell = Vector3i.ZERO
	active_max_cell = Vector3i.ZERO
	update_density_visuals()


func get_total_density_mass() -> float:
	return last_total_density * pow(cell_size, 3.0)


func reset_target() -> void:
	transform = initial_transform
	cache_cell_positions()
	simulation_timer = -max(simulation_phase_offset, 0.0)
	visual_timer = 0.0
	simulation_time = 0.0
	clear_density()


func get_debug_data() -> Dictionary:
	return {
		"gas_volume": gas_id,
		"grid_size": grid_size,
		"cell_size": snapped(cell_size, 0.01),
		"total_cells": get_total_cell_count(),
		"simulated_cells": last_simulated_cell_count,
		"active_cells": last_active_cell_count,
		"active_bounds": [active_min_cell, active_max_cell] if has_active_density else [],
		"density_sum": snapped(last_total_density, 0.01),
		"density_mass": snapped(get_total_density_mass(), 0.01),
		"maximum_density": snapped(last_maximum_density, 0.01),
		"simulation_time": snapped(simulation_time, 0.01),
		"definition": gas_definition.get_debug_data() if gas_definition != null else {},
	}
