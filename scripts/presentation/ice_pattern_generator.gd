extends RefCounted
class_name IcePatternGenerator


static func generate_radial_paths(event: IceVfxEvent, profile: IcePresentationProfile) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = event.seed
	var branch_total: int = max(event.branch_count, get_branch_count(event.kind, profile))
	var segment_total: int = max(event.segment_count, get_segment_count(event.kind, profile))
	var jitter: float = get_jitter(event.kind, profile)
	var paths: Array[PackedVector3Array] = []
	var basis: Basis = event.get_plane_basis()
	var tangent: Vector3 = basis.x.normalized()
	var bitangent: Vector3 = basis.z.normalized()
	var progress_scale: float = clampf(event.progress, 0.0, 1.0)
	var effective_radius: float = event.radius * max(progress_scale, 0.04)
	for branch_index: int in range(branch_total):
		var path := PackedVector3Array()
		var base_angle: float = TAU * float(branch_index) / max(float(branch_total), 1.0)
		base_angle += rng.randf_range(-0.18, 0.18)
		var angle: float = base_angle
		path.append(event.world_position + event.normal.normalized() * 0.012)
		for segment_index: int in range(1, segment_total + 1):
			var ratio: float = float(segment_index) / float(segment_total)
			angle += rng.randf_range(-jitter, jitter)
			var radius_value: float = effective_radius * ratio
			var sideways: float = rng.randf_range(-jitter, jitter) * effective_radius * 0.22 * ratio
			var point: Vector3 = event.world_position
			point += tangent * (cos(angle) * radius_value + sideways)
			point += bitangent * (sin(angle) * radius_value)
			point += event.normal.normalized() * 0.014
			path.append(point)
		paths.append(path)
	return {
		"paths": paths,
		"branch_count": paths.size(),
		"finite": are_paths_finite(paths),
	}


static func generate_crystals(event: IceVfxEvent, profile: IcePresentationProfile) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = event.seed
	var count: int = clampi(max(event.shard_count, profile.crystal_count), 1, 96)
	var crystals: Array[Dictionary] = []
	var basis: Basis = event.get_plane_basis()
	var tangent: Vector3 = basis.x.normalized()
	var bitangent: Vector3 = basis.z.normalized()
	var normal: Vector3 = event.normal.normalized()
	for index: int in range(count):
		var ratio: float = float(index) / max(float(count - 1), 1.0)
		var angle: float = TAU * ratio + rng.randf_range(-0.55, 0.55)
		var spread: float = rng.randf_range(0.08, max(profile.crystal_spread, 0.1)) * event.radius
		var base_position: Vector3 = event.world_position
		base_position += tangent * cos(angle) * spread
		base_position += bitangent * sin(angle) * spread
		var tilt_a: float = rng.randf_range(-0.42, 0.42)
		var tilt_b: float = rng.randf_range(-0.42, 0.42)
		var direction: Vector3 = (normal + tangent * tilt_a + bitangent * tilt_b).normalized()
		var height: float = profile.crystal_height * event.intensity * rng.randf_range(0.48, 1.24)
		var radius_value: float = profile.crystal_radius * rng.randf_range(0.7, 1.35)
		crystals.append({
			"position": base_position,
			"direction": direction,
			"height": max(height, 0.05),
			"radius": max(radius_value, 0.008),
			"rotation": rng.randf_range(0.0, TAU),
		})
	return {
		"crystals": crystals,
		"count": crystals.size(),
		"finite": are_crystals_finite(crystals),
	}


static func generate_shard_vectors(event: IceVfxEvent, profile: IcePresentationProfile) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = event.seed
	var count: int = clampi(max(event.shard_count, profile.shard_count), 1, 128)
	var vectors: Array[Vector3] = []
	var normal: Vector3 = event.normal.normalized() if event.normal.length() > 0.001 else Vector3.UP
	for index: int in range(count):
		var random_vector := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(0.05, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		vectors.append((random_vector + normal * rng.randf_range(0.15, 0.7)).normalized())
	return vectors


static func get_branch_count(kind: String, profile: IcePresentationProfile) -> int:
	match kind:
		IceVfxEvent.KIND_FROST:
			return profile.frost_branch_count
		IceVfxEvent.KIND_CRACK, IceVfxEvent.KIND_IMPACT:
			return profile.crack_branch_count
		_:
			return profile.front_branch_count


static func get_segment_count(kind: String, profile: IcePresentationProfile) -> int:
	if kind in [IceVfxEvent.KIND_CRACK, IceVfxEvent.KIND_IMPACT]:
		return profile.crack_segment_count
	return profile.front_segment_count


static func get_jitter(kind: String, profile: IcePresentationProfile) -> float:
	if kind in [IceVfxEvent.KIND_CRACK, IceVfxEvent.KIND_IMPACT]:
		return profile.crack_jitter
	return profile.front_jitter


static func are_paths_finite(paths: Array[PackedVector3Array]) -> bool:
	for path: PackedVector3Array in paths:
		for point: Vector3 in path:
			if not point.is_finite():
				return false
	return true


static func are_crystals_finite(crystals: Array[Dictionary]) -> bool:
	for crystal: Dictionary in crystals:
		var position: Vector3 = crystal.get("position", Vector3.ZERO)
		var direction: Vector3 = crystal.get("direction", Vector3.ZERO)
		var height: float = float(crystal.get("height", 0.0))
		var radius_value: float = float(crystal.get("radius", 0.0))
		if not position.is_finite() or not direction.is_finite() or not is_finite(height) or not is_finite(radius_value):
			return false
	return true
