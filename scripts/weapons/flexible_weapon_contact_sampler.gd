extends RefCounted
class_name FlexibleWeaponContactSampler


static func sample_tether(
	tether: FlexibleTether3D,
	delta: float,
	minimum_fraction: float = 0.0,
	include_midpoints: bool = true
) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	if tether == null:
		return samples
	var points: PackedVector3Array = tether._points
	var previous: PackedVector3Array = tether._previous_points
	if points.size() < 2:
		return samples
	var last_index: int = points.size() - 1
	var safe_delta: float = maxf(delta, 0.001)
	var start_index: int = clampi(
		floori(clampf(minimum_fraction, 0.0, 1.0) * float(last_index)),
		0,
		last_index
	)
	for index: int in range(start_index, points.size()):
		var fraction: float = float(index) / float(last_index)
		var speed: float = 0.0
		if previous.size() == points.size():
			speed = points[index].distance_to(previous[index]) / safe_delta
		samples.append({
			"position": points[index],
			"fraction": fraction,
			"speed": speed,
			"index": index,
		})
		if include_midpoints and index < last_index:
			var next_fraction: float = float(index + 1) / float(last_index)
			var next_speed: float = speed
			if previous.size() == points.size():
				next_speed = points[index + 1].distance_to(previous[index + 1]) / safe_delta
			samples.append({
				"position": points[index].lerp(points[index + 1], 0.5),
				"fraction": lerpf(fraction, next_fraction, 0.5),
				"speed": lerpf(speed, next_speed, 0.5),
				"index": index,
			})
	return samples


static func get_peak_speed(
	tether: FlexibleTether3D,
	delta: float,
	minimum_fraction: float = 0.0
) -> float:
	var peak: float = 0.0
	for sample: Dictionary in sample_tether(tether, delta, minimum_fraction, false):
		peak = maxf(peak, float(sample.get("speed", 0.0)))
	return peak


static func get_straightness(tether: FlexibleTether3D) -> float:
	if tether == null:
		return 0.0
	var points: PackedVector3Array = tether._points
	if points.size() < 2:
		return 0.0
	var path_length: float = 0.0
	for index: int in range(points.size() - 1):
		path_length += points[index].distance_to(points[index + 1])
	if path_length <= 0.0001:
		return 0.0
	return clampf(points[0].distance_to(points[-1]) / path_length, 0.0, 1.0)
