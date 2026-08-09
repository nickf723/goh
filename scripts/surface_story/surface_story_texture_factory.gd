extends RefCounted
class_name SurfaceStoryTextureFactory

var resolution: int = 128
var texture_sets: Dictionary = {}


func _init(texture_resolution: int = 128) -> void:
	resolution = clampi(texture_resolution, 64, 256)


func get_texture_set(kind: String) -> Dictionary:
	var normalized: String = kind.strip_edges().to_lower()
	if texture_sets.has(normalized):
		return texture_sets[normalized] as Dictionary
	var created: Dictionary = _build_texture_set(normalized)
	texture_sets[normalized] = created
	return created


func _build_texture_set(kind: String) -> Dictionary:
	var albedo_image: Image = Image.create_empty(
		resolution,
		resolution,
		false,
		Image.FORMAT_RGBA8
	)
	var orm_image: Image = Image.create_empty(
		resolution,
		resolution,
		false,
		Image.FORMAT_RGBA8
	)
	albedo_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	orm_image.fill(Color(1.0, 1.0, 0.0, 1.0))

	var seed_value: float = float(abs(kind.hash() % 10000)) * 0.0137
	for y: int in range(resolution):
		for x: int in range(resolution):
			var uv := Vector2(
				(float(x) + 0.5) / float(resolution),
				(float(y) + 0.5) / float(resolution)
			)
			var sample: Dictionary = _sample_kind(kind, uv, seed_value)
			var alpha: float = clampf(float(sample.get("alpha", 0.0)), 0.0, 1.0)
			if alpha <= 0.001:
				continue
			var color: Color = sample.get("color", Color.WHITE)
			color.a = alpha
			albedo_image.set_pixel(x, y, color)
			orm_image.set_pixel(
				x,
				y,
				Color(
					clampf(float(sample.get("ao", 1.0)), 0.0, 1.0),
					clampf(float(sample.get("roughness", 0.9)), 0.0, 1.0),
					clampf(float(sample.get("metallic", 0.0)), 0.0, 1.0),
					1.0
				)
			)

	return {
		"albedo": ImageTexture.create_from_image(albedo_image),
		"orm": ImageTexture.create_from_image(orm_image),
		"kind": kind,
	}


func _sample_kind(kind: String, uv: Vector2, seed_value: float) -> Dictionary:
	match kind:
		"crack":
			return _sample_crack(uv, seed_value)
		"moss":
			return _sample_moss(uv, seed_value)
		"wet":
			return _sample_wet(uv, seed_value)
		"grime":
			return _sample_grime(uv, seed_value)
		"wear":
			return _sample_wear(uv, seed_value)
		"carving":
			return _sample_carving(uv, seed_value)
		_:
			return _sample_grime(uv, seed_value)


func _sample_crack(uv: Vector2, seed_value: float) -> Dictionary:
	var main_x: float = (
		0.50
		+ sin(uv.y * 9.0 + seed_value) * 0.085
		+ sin(uv.y * 23.0 + seed_value * 0.37) * 0.027
	)
	var main_distance: float = absf(uv.x - main_x)
	var branch_distance: float = 1.0
	if uv.y > 0.40:
		var branch_origin: float = 0.50 + sin(0.40 * 9.0 + seed_value) * 0.085
		var branch_x: float = branch_origin + (uv.y - 0.40) * 0.46
		branch_x += sin(uv.y * 17.0 + seed_value) * 0.025
		branch_distance = absf(uv.x - branch_x)
	var crack_distance: float = minf(main_distance, branch_distance)
	var width: float = 0.012 + _noise(uv * 5.0, seed_value) * 0.010
	var alpha: float = 1.0 - smoothstep(width, width * 2.4, crack_distance)
	alpha *= _soft_edge(uv, 0.08)
	return {
		"alpha": alpha * 0.82,
		"color": Color(0.035, 0.046, 0.030, 1.0),
		"ao": 0.50,
		"roughness": 0.96,
		"metallic": 0.0,
	}


func _sample_moss(uv: Vector2, seed_value: float) -> Dictionary:
	var p: Vector2 = uv - Vector2(0.5, 0.52)
	var radius: float = Vector2(p.x / 0.50, p.y / 0.42).length()
	var noise: float = _noise(uv * 5.5, seed_value)
	var detail: float = _noise(uv * 13.0, seed_value + 2.4)
	var boundary: float = 0.72 + noise * 0.24
	var alpha: float = 1.0 - smoothstep(boundary - 0.12, boundary + 0.08, radius)
	alpha *= smoothstep(0.26, 0.63, noise * 0.72 + detail * 0.28)
	return {
		"alpha": alpha * 0.72,
		"color": Color(0.055, 0.19, 0.045, 1.0),
		"ao": 0.78,
		"roughness": 1.0,
		"metallic": 0.0,
	}


func _sample_wet(uv: Vector2, seed_value: float) -> Dictionary:
	var p: Vector2 = uv - Vector2(0.5, 0.5)
	var radius: float = Vector2(p.x / 0.52, p.y / 0.46).length()
	var noise: float = _noise(uv * 4.0, seed_value)
	var streak: float = 0.5 + 0.5 * sin((uv.x * 13.0 + uv.y * 2.0) + seed_value)
	var boundary: float = 0.80 + (noise - 0.5) * 0.22
	var alpha: float = 1.0 - smoothstep(boundary - 0.10, boundary + 0.10, radius)
	alpha *= 0.70 + streak * 0.30
	return {
		"alpha": alpha * 0.58,
		"color": Color(0.018, 0.060, 0.052, 1.0),
		"ao": 0.88,
		"roughness": 0.24,
		"metallic": 0.02,
	}


func _sample_grime(uv: Vector2, seed_value: float) -> Dictionary:
	var p: Vector2 = uv - Vector2(0.5, 0.5)
	var radius: float = p.length() * 1.9
	var noise: float = _noise(uv * 6.0, seed_value)
	var fine: float = _noise(uv * 17.0, seed_value + 8.2)
	var alpha: float = 1.0 - smoothstep(0.55 + noise * 0.18, 0.88, radius)
	alpha *= smoothstep(0.34, 0.68, noise * 0.7 + fine * 0.3)
	return {
		"alpha": alpha * 0.52,
		"color": Color(0.105, 0.073, 0.027, 1.0),
		"ao": 0.76,
		"roughness": 0.93,
		"metallic": 0.0,
	}


func _sample_wear(uv: Vector2, seed_value: float) -> Dictionary:
	var p: Vector2 = uv - Vector2(0.5, 0.5)
	var radius: float = Vector2(p.x / 0.50, p.y / 0.36).length()
	var noise: float = _noise(uv * 8.0, seed_value)
	var alpha: float = 1.0 - smoothstep(0.62 + noise * 0.12, 0.90, radius)
	alpha *= smoothstep(0.24, 0.58, noise)
	return {
		"alpha": alpha * 0.34,
		"color": Color(0.31, 0.29, 0.19, 1.0),
		"ao": 0.96,
		"roughness": 0.70,
		"metallic": 0.0,
	}


func _sample_carving(uv: Vector2, seed_value: float) -> Dictionary:
	var p: Vector2 = uv - Vector2(0.5, 0.5)
	var radius: float = p.length()
	var ring: float = absf(radius - 0.29)
	var inner_ring: float = absf(radius - 0.16)
	var diagonal_a: float = absf(p.y - p.x * 0.72)
	var diagonal_b: float = absf(p.y + p.x * 0.72)
	var line_distance: float = minf(minf(ring, inner_ring), minf(diagonal_a, diagonal_b))
	var width: float = 0.018 + _noise(uv * 7.0, seed_value) * 0.006
	var alpha: float = 1.0 - smoothstep(width, width * 2.0, line_distance)
	alpha *= _soft_edge(uv, 0.12)
	return {
		"alpha": alpha * 0.50,
		"color": Color(0.075, 0.082, 0.048, 1.0),
		"ao": 0.66,
		"roughness": 0.90,
		"metallic": 0.0,
	}


func _noise(p: Vector2, seed_value: float) -> float:
	var a: float = sin(p.x * 2.13 + p.y * 1.71 + seed_value)
	var b: float = sin(p.x * 4.47 - p.y * 3.19 + seed_value * 0.43)
	var c: float = sin(p.x * 9.11 + p.y * 7.37 + seed_value * 1.31)
	return clampf(0.5 + (a * 0.26 + b * 0.16 + c * 0.08), 0.0, 1.0)


func _soft_edge(uv: Vector2, edge_width: float) -> float:
	var edge_distance: float = minf(
		minf(uv.x, 1.0 - uv.x),
		minf(uv.y, 1.0 - uv.y)
	)
	return smoothstep(0.0, maxf(edge_width, 0.001), edge_distance)


func get_debug_data() -> Dictionary:
	return {
		"surface_story_texture_factory": true,
		"resolution": resolution,
		"cached_sets": texture_sets.size(),
		"kinds": texture_sets.keys(),
	}
