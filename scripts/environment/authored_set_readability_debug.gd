extends RefCounted
class_name AuthoredSetReadabilityDebug

const DEFAULT_PROFILE: Resource = preload("res://data/player/grace_spatial_profile.tres")


static func build(parent: Node3D, plan: Dictionary, spatial_profile: Resource = DEFAULT_PROFILE) -> Node3D:
	if parent == null:
		return null
	var existing: Node3D = parent.get_node_or_null("SpatialReadabilityDebug") as Node3D
	if existing != null:
		existing.queue_free()
	var root := Node3D.new()
	root.name = "SpatialReadabilityDebug"
	root.add_to_group("spatial_readability_debug")
	parent.add_child(root)

	for route: Dictionary in _dictionary_rows(plan.get("routes", [])):
		_build_route(root, route, spatial_profile)
	for zone: Dictionary in _dictionary_rows(plan.get("zones", [])):
		_build_zone(root, zone, spatial_profile)
	return root


static func _build_route(parent: Node3D, route: Dictionary, profile: Resource) -> void:
	var points: Array[Vector3] = _vector3_rows(route.get("points", []))
	if points.size() < 2:
		return
	var route_id: String = str(route.get("id", "Route"))
	var clear_radius: float = float(route.get("clear_radius", _profile_number(profile, "primary_route_radius", 1.35)))
	var camera_radius: float = float(route.get("camera_radius", _profile_number(profile, "camera_route_radius", 2.55)))
	for index: int in range(points.size() - 1):
		_add_segment_box(parent, route_id + "_Camera%02d" % index, points[index], points[index + 1], camera_radius, Color(0.18, 0.48, 0.95, 0.10), 0.025)
		_add_segment_box(parent, route_id + "_Travel%02d" % index, points[index], points[index + 1], clear_radius, Color(0.18, 0.9, 0.48, 0.18), 0.045)


static func _build_zone(parent: Node3D, zone: Dictionary, profile: Resource) -> void:
	var kind: String = str(zone.get("kind", "interaction")).to_lower().strip_edges()
	var radius: float = float(zone.get("radius", _profile_zone_radius(profile, kind)))
	var center: Vector3 = _vector3_from(zone.get("center", Vector3.ZERO), Vector3.ZERO)
	var color := Color(1.0, 0.62, 0.16, 0.18)
	match kind:
		"landmark":
			color = Color(0.72, 0.3, 1.0, 0.16)
		"combat":
			color = Color(0.95, 0.22, 0.22, 0.13)
		"camera", "camera_route":
			color = Color(0.18, 0.48, 0.95, 0.14)
	var ring := MeshInstance3D.new()
	ring.name = str(zone.get("id", "Zone"))
	ring.position = center + Vector3.UP * 0.055
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.035
	mesh.radial_segments = 40
	ring.mesh = mesh
	ring.material_override = _material(color)
	parent.add_child(ring)


static func _add_segment_box(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, color: Color, height: float) -> void:
	var start_flat := Vector3(start.x, 0.0, start.z)
	var finish_flat := Vector3(finish.x, 0.0, finish.z)
	var segment: Vector3 = finish_flat - start_flat
	if segment.length_squared() <= 0.0001:
		return
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = (start + finish) * 0.5 + Vector3.UP * (height * 0.5 + 0.025)
	visual.rotation.y = atan2(segment.x, segment.z)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(radius * 2.0, 0.1), height, segment.length())
	visual.mesh = mesh
	visual.material_override = _material(color)
	parent.add_child(visual)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	return material


static func _profile_zone_radius(profile: Resource, kind: String) -> float:
	match kind:
		"camera", "camera_route":
			return _profile_number(profile, "camera_route_radius", 2.55)
		"landmark":
			return _profile_number(profile, "landmark_radius", 2.4)
		"combat":
			return _profile_number(profile, "combat_radius", 5.5)
		_:
			return _profile_number(profile, "interaction_radius", 1.8)


static func _profile_number(profile: Resource, property_name: String, fallback: float) -> float:
	if profile == null:
		return fallback
	for property_variant: Variant in profile.get_property_list():
		if property_variant is Dictionary and str((property_variant as Dictionary).get("name", "")) == property_name:
			return float(profile.get(property_name))
	return fallback


static func _dictionary_rows(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not value is Array:
		return rows
	for row_variant: Variant in value as Array:
		if row_variant is Dictionary:
			rows.append((row_variant as Dictionary).duplicate(true))
	return rows


static func _vector3_rows(value: Variant) -> Array[Vector3]:
	var rows: Array[Vector3] = []
	if not value is Array:
		return rows
	for row_variant: Variant in value as Array:
		rows.append(_vector3_from(row_variant, Vector3.ZERO))
	return rows


static func _vector3_from(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Array:
		var values: Array = value as Array
		if values.size() >= 3:
			return Vector3(float(values[0]), float(values[1]), float(values[2]))
	return fallback
