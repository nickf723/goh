extends Node3D
class_name ProceduralIceRenderer

const IceEventScript = preload("res://scripts/presentation/ice_vfx_event.gd")
const IceProfileScript = preload("res://scripts/presentation/ice_presentation_profile.gd")
const IcePatternScript = preload("res://scripts/presentation/ice_pattern_generator.gd")

var active_effects: Array[Node] = []
var rendered_count: int = 0
var rejected_count: int = 0
var front_count: int = 0
var crystal_count: int = 0
var crack_count: int = 0
var shatter_count: int = 0
var thaw_count: int = 0
var total_generated_points: int = 0


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func render_event(event: Resource, profile: Resource = null) -> Node3D:
	prune_effects()
	if event == null or not event.has_method("is_valid_event") or not bool(event.call("is_valid_event")):
		rejected_count += 1
		return null
	var active_profile: Resource = profile
	if active_profile == null:
		active_profile = IceProfileScript.new()
	if active_effects.size() >= max(int(active_profile.maximum_active_effects), 8):
		rejected_count += 1
		return null
	var root := Node3D.new()
	root.name = "ProceduralIce_" + str(event.kind)
	add_child(root)
	root.global_position = event.world_position
	active_effects.append(root)
	rendered_count += 1
	match str(event.kind):
		IceEventScript.KIND_FREEZE_FRONT:
			spawn_freeze_surface(root, event, active_profile)
			spawn_path_geometry(root, event, active_profile, active_profile.ice_color)
			front_count += 1
		IceEventScript.KIND_FROST:
			spawn_path_geometry(root, event, active_profile, active_profile.frost_color)
			spawn_frost_particles(root, event, active_profile)
			front_count += 1
		IceEventScript.KIND_CRYSTAL_GROWTH, IceEventScript.KIND_PROJECTILE:
			spawn_crystal_cluster(root, event, active_profile)
			crystal_count += 1
		IceEventScript.KIND_CRACK:
			spawn_path_geometry(root, event, active_profile, active_profile.crack_color)
			crack_count += 1
		IceEventScript.KIND_SHATTER:
			spawn_shatter(root, event, active_profile)
			shatter_count += 1
		IceEventScript.KIND_THAW:
			spawn_thaw(root, event, active_profile)
			thaw_count += 1
		IceEventScript.KIND_IMPACT:
			spawn_path_geometry(root, event, active_profile, active_profile.crack_color)
			spawn_shatter(root, event, active_profile)
			crack_count += 1
			shatter_count += 1
		_:
			spawn_crystal_cluster(root, event, active_profile)
	var lifetime: float = max(float(event.duration_seconds), float(active_profile.effect_lifetime), 0.15)
	if not event.has_method("has_tag") or not bool(event.call("has_tag", "persistent")):
		var tween := root.create_tween()
		tween.tween_interval(lifetime)
		tween.tween_callback(Callable(self, "release_effect").bind(root))
	return root


func spawn_freeze_surface(root: Node3D, event: Resource, profile: Resource) -> void:
	var surface := MeshInstance3D.new()
	surface.name = "GeneratedFreezeSurface"
	var mesh := CylinderMesh.new()
	mesh.top_radius = max(float(event.radius), 0.05)
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.035
	mesh.radial_segments = 64
	surface.mesh = mesh
	surface.material_override = make_ice_material(profile.ice_color, float(profile.surface_opacity), 1.25)
	surface.quaternion = Quaternion(Vector3.UP, event.normal.normalized())
	surface.position = event.normal.normalized() * 0.018
	root.add_child(surface)
	var target_progress: float = clampf(float(event.progress), 0.04, 1.0)
	surface.scale = Vector3(0.035, 1.0, 0.035)
	var tween := surface.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(surface, "scale", Vector3(target_progress, 1.0, target_progress), min(float(event.duration_seconds) * 0.68, 1.5))


func spawn_path_geometry(root: Node3D, event: Resource, profile: Resource, color: Color) -> void:
	var result: Dictionary = IcePatternScript.generate_radial_paths(event, profile)
	var paths: Array = result.get("paths", [])
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for raw_path: Variant in paths:
		if not raw_path is PackedVector3Array:
			continue
		var path: PackedVector3Array = raw_path as PackedVector3Array
		total_generated_points += path.size()
		for index: int in range(path.size() - 1):
			mesh.surface_add_vertex(path[index] - event.world_position)
			mesh.surface_add_vertex(path[index + 1] - event.world_position)
	mesh.surface_end()
	var glow := MeshInstance3D.new()
	glow.name = "GeneratedIceVeinsGlow"
	glow.mesh = mesh
	glow.material_override = make_ice_material(color, 0.34, float(profile.line_emission) * 0.55)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.scale = Vector3.ONE * 1.018
	root.add_child(glow)
	var core := MeshInstance3D.new()
	core.name = "GeneratedIceVeinsCore"
	core.mesh = mesh
	core.material_override = make_ice_material(color.lightened(0.28), 0.92, float(profile.line_emission))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)


func spawn_crystal_cluster(root: Node3D, event: Resource, profile: Resource) -> void:
	var result: Dictionary = IcePatternScript.generate_crystals(event, profile)
	var crystals: Array = result.get("crystals", [])
	var instance := MultiMeshInstance3D.new()
	instance.name = "GeneratedCrystalCluster"
	var crystal_mesh := CylinderMesh.new()
	crystal_mesh.top_radius = 0.0
	crystal_mesh.bottom_radius = 1.0
	crystal_mesh.height = 1.0
	crystal_mesh.radial_segments = 6
	crystal_mesh.rings = 2
	crystal_mesh.material = make_ice_material(event.tint, 0.78, 2.1)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = crystal_mesh
	multimesh.instance_count = crystals.size()
	for index: int in range(crystals.size()):
		var crystal: Dictionary = crystals[index]
		var position: Vector3 = crystal.get("position", event.world_position) - event.world_position
		var direction: Vector3 = crystal.get("direction", Vector3.UP).normalized()
		var height: float = float(crystal.get("height", 0.5))
		var radius_value: float = float(crystal.get("radius", 0.06))
		var basis := Basis(Quaternion(Vector3.UP, direction))
		basis = basis.scaled(Vector3(radius_value, height, radius_value))
		var transform := Transform3D(basis, position + direction * height * 0.5)
		multimesh.set_instance_transform(index, transform)
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	instance.scale = Vector3(0.04, 0.04, 0.04)
	var tween := instance.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(instance, "scale", Vector3.ONE, min(float(event.duration_seconds) * 0.55, 1.2))


func spawn_frost_particles(root: Node3D, event: Resource, profile: Resource) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "GeneratedFrostDust"
	particles.amount = clampi(int(14.0 + float(event.intensity) * 20.0), 12, 72)
	particles.lifetime = 1.35
	particles.one_shot = true
	particles.randomness = 0.88
	particles.visibility_aabb = AABB(Vector3(-5.0, -5.0, -5.0), Vector3(10.0, 10.0, 10.0))
	var process := ParticleProcessMaterial.new()
	process.direction = event.normal.normalized()
	process.spread = 72.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.6 + float(event.intensity) * 0.25
	process.gravity = Vector3(0.0, -0.22, 0.0)
	process.scale_min = 0.018
	process.scale_max = 0.06
	process.color = profile.frost_color
	particles.process_material = process
	particles.draw_pass_1 = make_shard_mesh(profile.frost_color, 0.045)
	root.add_child(particles)
	particles.emitting = true


func spawn_shatter(root: Node3D, event: Resource, profile: Resource) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "GeneratedIceShatter"
	particles.amount = clampi(max(int(event.shard_count), int(profile.shard_count)), 8, 128)
	particles.lifetime = 1.35
	particles.one_shot = true
	particles.randomness = 0.94
	particles.visibility_aabb = AABB(Vector3(-7.0, -3.0, -7.0), Vector3(14.0, 12.0, 14.0))
	var process := ParticleProcessMaterial.new()
	process.direction = event.normal.normalized()
	process.spread = 82.0
	process.initial_velocity_min = 1.0 + float(event.intensity) * 0.8
	process.initial_velocity_max = 3.2 + float(event.intensity) * 2.0
	process.gravity = Vector3(0.0, -7.2, 0.0)
	process.scale_min = 0.045
	process.scale_max = 0.18
	process.color = event.tint
	particles.process_material = process
	particles.draw_pass_1 = make_shard_mesh(event.tint, 0.16)
	root.add_child(particles)
	particles.emitting = true
	var flash := OmniLight3D.new()
	flash.name = "IceShatterFlash"
	flash.light_color = Color(0.52, 0.88, 1.0, 1.0)
	flash.light_energy = 1.6 + float(event.intensity) * 1.1
	flash.omni_range = 2.2 + float(event.radius)
	root.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.24)


func spawn_thaw(root: Node3D, event: Resource, profile: Resource) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "GeneratedMeltDroplets"
	particles.amount = clampi(int(10.0 + float(event.intensity) * 18.0), 8, 64)
	particles.lifetime = 1.6
	particles.one_shot = true
	particles.randomness = 0.8
	particles.visibility_aabb = AABB(Vector3(-4.0, -5.0, -4.0), Vector3(8.0, 10.0, 8.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.DOWN
	process.spread = 24.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0.0, -3.8, 0.0)
	process.scale_min = 0.035
	process.scale_max = 0.1
	process.color = profile.melt_color
	particles.process_material = process
	particles.draw_pass_1 = make_droplet_mesh(profile.melt_color)
	root.add_child(particles)
	particles.emitting = true


func make_ice_material(color: Color, alpha: float, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
	material.metallic = 0.08
	material.roughness = 0.14
	material.emission_enabled = emission_energy > 0.0
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = max(emission_energy, 0.0)
	return material


func make_shard_mesh(color: Color, length: float) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(length * 0.38, length, length * 0.24)
	mesh.material = make_ice_material(color, 0.9, 2.0)
	return mesh


func make_droplet_mesh(color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.11
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = make_ice_material(color, 0.72, 0.5)
	return mesh


func release_effect(node: Node) -> void:
	if node == null:
		return
	active_effects.erase(node)
	if is_instance_valid(node):
		node.queue_free()


func prune_effects() -> void:
	var valid_effects: Array[Node] = []
	for effect: Node in active_effects:
		if effect != null and is_instance_valid(effect) and not effect.is_queued_for_deletion():
			valid_effects.append(effect)
	active_effects = valid_effects


func reset_target() -> void:
	for effect: Node in active_effects:
		if effect != null and is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()
	rendered_count = 0
	rejected_count = 0
	front_count = 0
	crystal_count = 0
	crack_count = 0
	shatter_count = 0
	thaw_count = 0
	total_generated_points = 0


func get_debug_data() -> Dictionary:
	prune_effects()
	return {
		"procedural_ice_renderer": true,
		"active_effects": active_effects.size(),
		"rendered": rendered_count,
		"rejected": rejected_count,
		"freeze_fronts": front_count,
		"crystals": crystal_count,
		"cracks": crack_count,
		"shatters": shatter_count,
		"thaws": thaw_count,
		"generated_points": total_generated_points,
	}
