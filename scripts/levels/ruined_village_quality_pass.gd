extends RefCounted

## Authored presentation for this route only. Gameplay owners retain their state.
const MeadowSurface = preload("res://scripts/environment/meadow_field_surface.gd")
const GroundMaterial = preload("res://art/materials/environment/natural/stylized_pbr_meadow_ground_v1.tres")
const GrassMaterial = preload("res://art/materials/environment/natural/meadow_grass_v1.tres")
const StoneMaterial = preload("res://art/materials/environment/modular/stylized_pbr_stone_study.tres")
const Builder = preload("res://scripts/environment/authored_environment_builder.gd")

var level: Node3D
var root: Node3D
var rng := RandomNumberGenerator.new()

func install(target: Node3D) -> void:
	level = target
	if level.has_node("VillageQuality"):
		return
	rng.seed = 18800915
	root = Node3D.new()
	root.name = "VillageQuality"
	level.add_child(root)
	_apply_ground()
	_build_horizon()
	_build_verges()
	_open_sightlines()
	_build_arrival_frame()
	root.set_meta("quality_pass", "mediterranean_v1")

func _apply_ground() -> void:
	# The former upper slab intersected the ramp with a three-metre vertical lip.
	# Leave its side banks intact while opening a continuous central approach.
	var geometry := level.get_node("GeneratedGeometry")
	var grade := level.get_node("TraversalGrade")
	grade.call("resize_box_body", geometry.get_node("OuterVillageGround"), Vector3(0, 2.5, 13.5), Vector3(46, 1, 21))
	grade.call("resize_box_body", geometry.get_node("OuterVillageEarth"), Vector3(0, 0, 12), Vector3(50, 5, 24))
	for side: float in [-1.0, 1.0]:
		level.call("create_static_box", "ArrivalSideBank" + str(int(side)), Vector3(side * 13.875, 2.5, 32.5), Vector3(18.25, 1, 17), GroundMaterial)
		level.call("create_static_box", "ArrivalBankEarth" + str(int(side)), Vector3(side * 14.875, 0, 33.5), Vector3(20.25, 5, 19), StoneMaterial)
	var ramp := geometry.get_node("ArrivalTraversalRamp") as StaticBody3D
	grade.call("resize_box_body", ramp, Vector3(0, 1.225, 35), Vector3(9.5, 0.55, 22.8))
	ramp.rotation_degrees.x = rad_to_deg(atan(3.0 / 22.0))
	var ground := GroundMaterial.duplicate() as ShaderMaterial
	ground.set_shader_parameter("turf_color", Color(0.24, 0.32, 0.12))
	ground.set_shader_parameter("turf_shadow_color", Color(0.095, 0.14, 0.05))
	ground.set_shader_parameter("dry_turf_color", Color(0.44, 0.37, 0.19))
	ground.set_shader_parameter("soil_light_color", Color(0.52, 0.39, 0.25))
	ground.set_shader_parameter("soil_dark_color", Color(0.20, 0.14, 0.08))
	ground.set_shader_parameter("soil_amount", 0.65)
	ground.set_shader_parameter("soil_threshold", 0.57)
	ground.set_shader_parameter("path_enabled", true)
	# Path coordinates include the material's noise offset.
	ground.set_shader_parameter("path_origin", Vector2(18.7, -9.4))
	ground.set_shader_parameter("path_soil_amount", 0.98)
	ground.set_shader_parameter("path_half_width", 2.4)
	ground.set_shader_parameter("path_wobble_strength", 0.55)
	ground.set_shader_parameter("path_edge_softness", 1.25)
	for node_name: String in ["ArrivalGround", "OuterVillageGround", "ArrivalTraversalRamp", "ArrivalSideBank-1", "ArrivalSideBank1"]:
		var body: Node = level.get_node("GeneratedGeometry/" + node_name)
		for mesh: Node in body.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = ground
	# The road meshes are decorative; the continuous ramp and ground own contact.
	# Retire repeated paving tiles in favor of the continuous earthen walking line.
	var remaster: Node = level.get_node("OutdoorRemasterV1")
	for piece: Node in remaster.get_children():
		var name_text := str(piece.name)
		if name_text.begins_with("ArrivalRoad") or name_text.begins_with("ArrivalRampRoad") or name_text.begins_with("VillageRoad"):
			var road := piece as Node3D
			road.hide()
	# Replace redundant arrival step collision with the already authored smooth ramp.
	for body: Node in level.get_node("GeneratedGeometry").get_children():
		if str(body.name).begins_with("Stair38_"):
			for collision: Node in body.find_children("*", "CollisionShape3D", true, false):
				(collision as CollisionShape3D).set_deferred("disabled", true)
			(body as Node3D).hide()
		if str(body.name).begins_with("Arrival") and str(body.name).ends_with("Cliff"):
			for mesh: Node in body.find_children("*", "MeshInstance3D", true, false):
				(mesh as MeshInstance3D).material_override = StoneMaterial

func _build_horizon() -> void:
	# All background masses sit beyond the playable shell. Keep the church skyline open.
	for i: int in range(22):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z: float = 64.0 - float(i / 2) * 15.0
		var x: float = side * rng.randf_range(42.0, 60.0)
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 18
		mesh.rings = 10
		var hill := MeshInstance3D.new()
		hill.name = "DistantRidge%02d" % i
		hill.mesh = mesh
		hill.position = Vector3(x, -5.0, z)
		hill.scale = Vector3(rng.randf_range(21.0, 34.0), rng.randf_range(13.0, 24.0), rng.randf_range(21.0, 32.0))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.20, 0.28, 0.22).lerp(Color(0.36, 0.43, 0.40), float(i) / 26.0)
		mat.roughness = 1.0
		hill.material_override = mat
		root.add_child(hill)
	# Cypress silhouettes establish Mediterranean scale and rhythm outside routes.
	for p: Vector3 in [Vector3(-16, 0, 58), Vector3(16, 0, 49), Vector3(-19, 3, 31), Vector3(20, 3, 36), Vector3(-21, 3, 9), Vector3(21, 3, -6)]:
		level.call("create_cypress", p, rng.randf_range(0.9, 1.4))

func _ground_height(z: float) -> float:
	if z >= 46.0:
		return 0.02
	if z <= 24.0:
		return 3.02
	return 0.02 + (46.0 - z) * 3.0 / 22.0

func _build_verges() -> void:
	# Reuse the existing meadow meshes and wind shader, with authored exclusion zones.
	var source := MeadowSurface.new()
	source.build_on_ready = false
	var blade: ArrayMesh = source.call("_create_blade_clump_mesh")
	var flower: ArrayMesh = source.call("_create_wildflower_mesh")
	source.free()
	var grass := GrassMaterial.duplicate() as ShaderMaterial
	grass.set_shader_parameter("base_color", Color(0.11, 0.21, 0.065))
	grass.set_shader_parameter("tip_color", Color(0.52, 0.52, 0.24))
	grass.set_shader_parameter("wind_strength", 0.12)
	_scatter("OliveGrass", blade, grass, 5800, false)
	var flowers := grass.duplicate() as ShaderMaterial
	flowers.set_shader_parameter("tip_color", Color(0.65, 0.48, 0.74))
	_scatter("Wildflowers", flower, flowers, 600, true)

func _scatter(node_name: String, mesh: Mesh, material: Material, count: int, flowers: bool) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = count
	var placed: int = 0
	for attempt: int in range(count * 12):
		if placed == count:
			break
		var z: float = rng.randf_range(8.0, 69.0)
		var max_x: float = 15.8 if z > 40.0 else 21.0
		var x: float = rng.randf_range(-max_x, max_x)
		# The ramp is narrow; side banks cannot pretend to be traversable ground.
		if z < 46.0 and z > 24.0 and absf(x) > 4.4:
			continue
		if absf(x) < 3.6:
			continue
		var point := Vector2(x, z)
		if point.distance_to(Vector2(0, 59)) < 7.4 or point.distance_to(Vector2(8, 47)) < 6.0:
			continue
		if point.distance_to(Vector2(-6, 17)) < 5.8 or point.distance_to(Vector2(8, 14)) < 4.0:
			continue
		if z < 10.0 and absf(x) < 14.0:
			continue
		var size_value: float = rng.randf_range(0.26, 0.60) if not flowers else rng.randf_range(0.4, 0.65)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(size_value * 1.6, size_value, size_value * 1.6))
		multi.set_instance_transform(placed, Transform3D(basis, Vector3(x, _ground_height(z), z)))
		multi.set_instance_custom_data(placed, Color(rng.randf(), rng.randf(), rng.randf(), 1.0))
		placed += 1
	multi.visible_instance_count = placed
	var layer := MultiMeshInstance3D.new()
	layer.name = node_name
	layer.multimesh = multi
	layer.material_override = material
	layer.extra_cull_margin = 1.0
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(layer)

func _open_sightlines() -> void:
	# The square's center must read as fighting space, not a prop obstacle course.
	for child: Node in level.get_node("GeneratedDetails").get_children():
		if str(child.name).begins_with("DryWell"):
			var well := child as Node3D
			if well.position.z < 10.0:
				well.position.x = -12.5
				well.position.z = 0.0
			else:
				well.position.x = -4.8
	# Relocate the existing optional weapon display to the arrival's eastern edge.
	var rack_index: int = 0
	for rack: Node in level.get_node("VillageInteractions").get_children():
		if str(rack.name).ends_with("Rack") and rack is Node3D:
			var actor := rack as Node3D
			actor.position = Vector3(12.5, 0.8, 59.0 - float(rack_index) * 3.5)
			actor.rotation.y = PI * 0.5
			rack_index += 1

func _build_arrival_frame() -> void:
	var builder := Builder.new(root)
	# Low, irregular masonry frames the trail without obscuring clues or cameras.
	for i: int in range(7):
		var z: float = 66.0 - float(i) * 2.3
		var height: float = rng.randf_range(0.45, 0.85)
		builder.add_static_box(root, "ArrivalWall%02d" % i, Vector3(0.85, height, 1.9), Vector3(-9.5 + sin(float(i)) * 0.25, height * 0.5, z), Color(0.48, 0.43, 0.33))
	# Authored spacing leaves the central path, crater and optional cache accessible.
	root.set_meta("clear_path_half_width", 3.6)
