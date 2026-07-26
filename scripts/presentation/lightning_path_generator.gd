extends RefCounted
class_name LightningPathGenerator


static func generate(event: LightningArcEvent) -> Dictionary:
	if event == null or not event.is_finite_event():
		return {
			"main_path": PackedVector3Array(),
			"branches": [],
			"point_count": 0,
			"branch_count": 0,
			"finite": false,
		}

	var working: LightningArcEvent = event.duplicate_event()
	working.sanitize()
	var rng := RandomNumberGenerator.new()
	rng.seed = working.event_seed
	var main_path: PackedVector3Array = generate_polyline(
		working.start_position,
		working.end_position,
		working.subdivision_count,
		working.jitter_amplitude,
		working.flatten_to_surface,
		working.surface_y,
		rng
	)
	var branches: Array = []
	var branch_budget: int = working.maximum_branches
	if working.branch_depth > 0 and branch_budget > 0:
		append_branches(main_path, working, working.branch_depth, branches, branch_budget, rng)

	var point_count: int = main_path.size()
	for raw_branch: Variant in branches:
		if raw_branch is PackedVector3Array:
			point_count += (raw_branch as PackedVector3Array).size()
	return {
		"main_path": main_path,
		"branches": branches,
		"point_count": point_count,
		"branch_count": branches.size(),
		"finite": paths_are_finite(main_path, branches),
	}


static func generate_polyline(
	start: Vector3,
	end: Vector3,
	subdivisions: int,
	jitter: float,
	flatten_to_surface: bool,
	surface_y: float,
	rng: RandomNumberGenerator
) -> PackedVector3Array:
	var points := PackedVector3Array([start, end])
	var amplitude: float = max(jitter, 0.0)
	for level: int in range(clampi(subdivisions, 1, 8)):
		var next_points := PackedVector3Array()
		for index: int in range(points.size() - 1):
			var first: Vector3 = points[index]
			var second: Vector3 = points[index + 1]
			var midpoint: Vector3 = (first + second) * 0.5
			var offset_direction: Vector3 = random_perpendicular(second - first, flatten_to_surface, rng)
			midpoint += offset_direction * rng.randf_range(-amplitude, amplitude)
			if flatten_to_surface:
				midpoint.y = surface_y + rng.randf_range(-0.025, 0.025) * max(amplitude, 0.25)
			next_points.append(first)
			next_points.append(midpoint)
		next_points.append(points[points.size() - 1])
		points = next_points
		amplitude *= 0.52
	if flatten_to_surface:
		points[0].y = surface_y
		points[points.size() - 1].y = surface_y
	return points


static func append_branches(
	parent_path: PackedVector3Array,
	event: LightningArcEvent,
	depth: int,
	branches: Array,
	branch_budget: int,
	rng: RandomNumberGenerator
) -> int:
	if depth <= 0 or branch_budget <= 0 or parent_path.size() < 3:
		return branch_budget
	var parent_length: float = path_length(parent_path)
	var step: int = max(1, int(parent_path.size() / 9.0))
	for index: int in range(1, parent_path.size() - 1, step):
		if branch_budget <= 0:
			break
		if rng.randf() > event.branch_chance:
			continue
		var branch_start: Vector3 = parent_path[index]
		var tangent: Vector3 = parent_path[index + 1] - parent_path[index - 1]
		if tangent.length() <= 0.0001:
			tangent = event.get_direction()
		var side: Vector3 = random_perpendicular(tangent, event.flatten_to_surface, rng)
		var forward_bias: Vector3 = tangent.normalized() * rng.randf_range(0.08, 0.32)
		var branch_direction: Vector3 = (side * rng.randf_range(0.75, 1.35) + forward_bias).normalized()
		if not event.flatten_to_surface:
			branch_direction = (branch_direction + Vector3.UP * rng.randf_range(-0.22, 0.42)).normalized()
		var length_scale: float = event.branch_length_ratio * rng.randf_range(0.58, 1.0)
		var branch_length: float = max(parent_length * length_scale, 0.18)
		var branch_end: Vector3 = branch_start + branch_direction * branch_length
		if event.flatten_to_surface:
			branch_start.y = event.surface_y
			branch_end.y = event.surface_y
		var branch_path: PackedVector3Array = generate_polyline(
			branch_start,
			branch_end,
			max(event.subdivision_count - 2, 2),
			event.jitter_amplitude * 0.5,
			event.flatten_to_surface,
			event.surface_y,
			rng
		)
		branches.append(branch_path)
		branch_budget -= 1
		if depth > 1 and branch_budget > 0:
			var nested_event: LightningArcEvent = event.duplicate_event()
			nested_event.branch_chance *= 0.55
			nested_event.branch_length_ratio *= 0.62
			nested_event.jitter_amplitude *= 0.58
			branch_budget = append_branches(
				branch_path,
				nested_event,
				depth - 1,
				branches,
				branch_budget,
				rng
			)
	return branch_budget


static func random_perpendicular(
	delta: Vector3,
	flatten_to_surface: bool,
	rng: RandomNumberGenerator
) -> Vector3:
	var direction: Vector3 = delta.normalized()
	if direction.length() <= 0.0001:
		direction = Vector3.UP
	if flatten_to_surface:
		var horizontal := Vector3(-direction.z, 0.0, direction.x)
		if horizontal.length() <= 0.0001:
			horizontal = Vector3.RIGHT
		return horizontal.normalized() * (-1.0 if rng.randf() < 0.5 else 1.0)
	var first_axis: Vector3 = direction.cross(Vector3.UP)
	if first_axis.length() <= 0.0001:
		first_axis = direction.cross(Vector3.RIGHT)
	first_axis = first_axis.normalized()
	var second_axis: Vector3 = direction.cross(first_axis).normalized()
	var angle: float = rng.randf_range(0.0, TAU)
	return (first_axis * cos(angle) + second_axis * sin(angle)).normalized()


static func path_length(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for index: int in range(path.size() - 1):
		total += path[index].distance_to(path[index + 1])
	return total


static func paths_are_finite(main_path: PackedVector3Array, branches: Array) -> bool:
	if not path_is_finite(main_path):
		return false
	for raw_branch: Variant in branches:
		if not raw_branch is PackedVector3Array:
			return false
		if not path_is_finite(raw_branch as PackedVector3Array):
			return false
	return true


static func path_is_finite(path: PackedVector3Array) -> bool:
	for point: Vector3 in path:
		if not (
			is_finite(point.x)
			and is_finite(point.y)
			and is_finite(point.z)
		):
			return false
	return true
