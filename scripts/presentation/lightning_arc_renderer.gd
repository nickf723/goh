extends Node3D
class_name LightningArcRenderer

var active_arcs: Array[LightningArcVisual] = []
var rendered_count: int = 0
var rejected_count: int = 0
var total_generated_points: int = 0
var total_generated_branches: int = 0
var kind_counts: Dictionary = {}
var last_generation: Dictionary = {}


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	add_to_group("vfx_gallery_clearable")


func render_arc(event: LightningArcEvent, profile: LightningProfile = null) -> LightningArcVisual:
	prune_arcs()
	if event == null or not event.is_finite_event():
		rejected_count += 1
		return null
	var resolved_profile: LightningProfile = profile if profile != null else LightningProfile.new()
	var working: LightningArcEvent = event.duplicate_event()
	resolved_profile.apply_to_event(working, event.intensity)
	var generation: Dictionary = LightningPathGenerator.generate(working)
	var main_path: PackedVector3Array = generation.get("main_path", PackedVector3Array()) as PackedVector3Array
	var branches: Array = generation.get("branches", []) as Array
	if main_path.size() < 2 or not bool(generation.get("finite", false)):
		rejected_count += 1
		return null

	var visual := LightningArcVisual.new()
	visual.name = "ProceduralLightning_" + working.kind
	add_child(visual)
	visual.global_position = working.start_position
	visual.configure(working.duration_seconds, resolved_profile.flicker_frequency, working.seed)
	visual.expired.connect(_on_visual_expired)

	var local_paths: Array = []
	local_paths.append(to_local_path(main_path, working.start_position))
	for raw_branch: Variant in branches:
		if raw_branch is PackedVector3Array:
			local_paths.append(to_local_path(raw_branch as PackedVector3Array, working.start_position))

	var glow_mesh: ArrayMesh = build_cross_ribbon_mesh(
		local_paths,
		working.thickness * max(resolved_profile.glow_width_multiplier, 1.0),
		resolved_profile.glow_color
	)
	var core_mesh: ArrayMesh = build_cross_ribbon_mesh(
		local_paths,
		working.thickness,
		resolved_profile.core_color
	)
	if glow_mesh != null:
		var glow_node := MeshInstance3D.new()
		glow_node.name = "LightningGlow"
		glow_node.mesh = glow_mesh
		glow_node.material_override = make_lightning_material(resolved_profile.glow_color, 5.5)
		glow_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(glow_node)
		visual.register_mesh(glow_node)
	if core_mesh != null:
		var core_node := MeshInstance3D.new()
		core_node.name = "LightningCore"
		core_node.mesh = core_mesh
		core_node.material_override = make_lightning_material(resolved_profile.core_color, 11.0)
		core_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(core_node)
		visual.register_mesh(core_node)

	add_impact_flash(visual, working, resolved_profile)
	active_arcs.append(visual)
	rendered_count += 1
	total_generated_points += int(generation.get("point_count", 0))
	total_generated_branches += int(generation.get("branch_count", 0))
	kind_counts[working.kind] = int(kind_counts.get(working.kind, 0)) + 1
	last_generation = {
		"event": working.get_debug_data(),
		"point_count": int(generation.get("point_count", 0)),
		"branch_count": int(generation.get("branch_count", 0)),
	}
	return visual


func add_impact_flash(
	visual: LightningArcVisual,
	event: LightningArcEvent,
	profile: LightningProfile
) -> void:
	var local_end: Vector3 = event.end_position - event.start_position
	var flash_mesh := MeshInstance3D.new()
	flash_mesh.name = "LightningImpactFlash"
	var sphere := SphereMesh.new()
	var radius: float = max(profile.impact_flash_scale * event.intensity, 0.06)
	sphere.radius = radius
	sphere.height = radius * 2.0
	flash_mesh.mesh = sphere
	flash_mesh.position = local_end
	flash_mesh.material_override = make_lightning_material(profile.impact_color, 8.0)
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(flash_mesh)
	visual.register_mesh(flash_mesh)

	var flash_light := OmniLight3D.new()
	flash_light.name = "LightningImpactLight"
	flash_light.position = local_end
	flash_light.light_color = profile.impact_color
	flash_light.light_energy = max(profile.light_energy * event.intensity, 0.0)
	flash_light.omni_range = max(profile.light_range * sqrt(event.intensity), 0.5)
	flash_light.shadow_enabled = false
	visual.add_child(flash_light)
	visual.register_light(flash_light)


func build_cross_ribbon_mesh(paths: Array, width: float, color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_count: int = 0
	for raw_path: Variant in paths:
		if not raw_path is PackedVector3Array:
			continue
		var path: PackedVector3Array = raw_path as PackedVector3Array
		for index: int in range(path.size() - 1):
			var first: Vector3 = path[index]
			var second: Vector3 = path[index + 1]
			var delta: Vector3 = second - first
			if delta.length() <= 0.0001:
				continue
			var direction: Vector3 = delta.normalized()
			var side_a: Vector3 = direction.cross(Vector3.UP)
			if side_a.length() <= 0.0001:
				side_a = direction.cross(Vector3.RIGHT)
			side_a = side_a.normalized() * width
			var side_b: Vector3 = direction.cross(side_a.normalized()).normalized() * width
			append_quad(surface, first - side_a, second - side_a, second + side_a, first + side_a, color)
			append_quad(surface, first - side_b, second - side_b, second + side_b, first + side_b, color)
			vertex_count += 12
	if vertex_count == 0:
		return null
	return surface.commit()


func append_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	for vertex: Vector3 in [a, b, c, a, c, d]:
		surface.set_color(color)
		surface.add_vertex(vertex)


func to_local_path(path: PackedVector3Array, origin: Vector3) -> PackedVector3Array:
	var local_path := PackedVector3Array()
	for point: Vector3 in path:
		local_path.append(point - origin)
	return local_path


func make_lightning_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	return material


func _on_visual_expired(visual: LightningArcVisual) -> void:
	active_arcs.erase(visual)


func prune_arcs() -> void:
	var retained: Array[LightningArcVisual] = []
	for visual: LightningArcVisual in active_arcs:
		if visual != null and is_instance_valid(visual) and not visual.is_queued_for_deletion():
			retained.append(visual)
	active_arcs = retained


func reset_target() -> void:
	for visual: LightningArcVisual in active_arcs:
		if visual != null and is_instance_valid(visual):
			visual.queue_free()
	active_arcs.clear()
	rendered_count = 0
	rejected_count = 0
	total_generated_points = 0
	total_generated_branches = 0
	kind_counts.clear()
	last_generation.clear()


func get_debug_data() -> Dictionary:
	prune_arcs()
	return {
		"lightning_arc_renderer": true,
		"active_arcs": active_arcs.size(),
		"rendered": rendered_count,
		"rejected": rejected_count,
		"generated_points": total_generated_points,
		"generated_branches": total_generated_branches,
		"kinds": kind_counts.duplicate(),
		"last_generation": last_generation.duplicate(true),
	}
