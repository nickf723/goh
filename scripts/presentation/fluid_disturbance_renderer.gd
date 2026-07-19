extends Node3D
class_name FluidDisturbanceRenderer

var volume: FluidForceVolume
var profile: FluidPresentationProfile
var active_effects: Array[Node] = []
var rendered_count: int = 0
var ripple_render_count: int = 0
var splash_render_count: int = 0
var wake_render_count: int = 0
var churn_render_count: int = 0
var rejected_count: int = 0


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func configure(next_volume: FluidForceVolume, next_profile: FluidPresentationProfile) -> void:
	volume = next_volume
	profile = next_profile


func render_disturbance(event: FluidDisturbanceEvent) -> void:
	prune_effects()
	if event == null or volume == null or not event.is_finite_event():
		rejected_count += 1
		return
	var maximum_effects: int = profile.maximum_active_effects if profile != null else 96
	if active_effects.size() >= max(maximum_effects, 8):
		rejected_count += 1
		return

	rendered_count += 1
	match event.kind:
		FluidDisturbanceEvent.KIND_ENTRY, FluidDisturbanceEvent.KIND_IMPACT:
			spawn_ripple(event, 1.0)
			spawn_splash(event, 1.0)
		FluidDisturbanceEvent.KIND_WAKE:
			spawn_wake(event)
		FluidDisturbanceEvent.KIND_CHURN:
			spawn_churn(event)
		FluidDisturbanceEvent.KIND_BUBBLE, FluidDisturbanceEvent.KIND_BOIL:
			spawn_bubble_plume(event)
		FluidDisturbanceEvent.KIND_ELECTRICAL:
			spawn_ripple(event, 1.35)
			spawn_surface_flash(event)
		_:
			spawn_ripple(event, 1.0)


func spawn_ripple(event: FluidDisturbanceEvent, expansion_scale: float = 1.0) -> void:
	var ripple := MeshInstance3D.new()
	ripple.name = "ProceduralRipple"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.52
	torus.rings = 32
	torus.ring_segments = 10
	ripple.mesh = torus
	ripple.material_override = make_foam_material(event.tint, 1.25)
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var direction: Vector3 = event.get_horizontal_direction()
	ripple.rotation.y = atan2(direction.x, direction.z)
	var radius: float = max(event.radius, 0.08)
	ripple.scale = Vector3(radius * 1.15, 0.08, radius * (0.82 + event.strength * 0.08))
	place_at_surface(ripple, event.world_position, 0.028)
	add_effect(ripple)
	ripple_render_count += 1

	var duration: float = profile.ripple_duration if profile != null else 0.95
	var expansion: float = profile.ripple_expansion if profile != null else 3.2
	var current: Vector3 = volume.get_flow_velocity_at(event.world_position)
	var drift: Vector3 = Vector3(current.x, 0.0, current.z) * duration * 0.28
	var target_scale := Vector3(
		ripple.scale.x * expansion * expansion_scale,
		ripple.scale.y,
		ripple.scale.z * (expansion + current.length() * 0.16) * expansion_scale
	)
	var tween := ripple.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", target_scale, duration)
	tween.tween_property(ripple, "global_position", ripple.global_position + drift, duration)
	tween.tween_property(ripple, "transparency", 1.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(Callable(self, "release_effect").bind(ripple))


func spawn_splash(event: FluidDisturbanceEvent, intensity_scale: float = 1.0) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ProceduralSplash"
	var lifetime: float = profile.splash_lifetime if profile != null else 0.8
	var droplets_per_strength: float = profile.splash_droplets_per_strength if profile != null else 9.0
	particles.amount = clampi(int(6.0 + event.strength * droplets_per_strength * intensity_scale), 6, 72)
	particles.lifetime = max(lifetime, 0.2)
	particles.one_shot = true
	particles.explosiveness_ratio = 0.92
	particles.randomness = 0.72
	particles.visibility_aabb = AABB(Vector3(-5.0, -2.0, -5.0), Vector3(10.0, 9.0, 10.0))

	var process := ParticleProcessMaterial.new()
	var horizontal: Vector3 = event.get_horizontal_direction()
	process.direction = (Vector3.UP * 1.7 + horizontal * 0.34).normalized()
	process.spread = 58.0
	var velocity_scale: float = profile.splash_velocity_scale if profile != null else 1.0
	var impact_speed: float = max(event.velocity.length(), event.strength * 1.4)
	process.initial_velocity_min = clampf(1.4 + impact_speed * 0.32, 1.4, 5.5) * velocity_scale
	process.initial_velocity_max = clampf(2.5 + impact_speed * 0.62, 2.5, 9.0) * velocity_scale
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.scale_min = 0.035 * clampf(event.radius, 0.45, 2.0)
	process.scale_max = 0.11 * clampf(event.radius + event.strength * 0.12, 0.6, 2.5)
	process.color = get_foam_color(event.tint)
	particles.process_material = process
	particles.draw_pass_1 = make_droplet_mesh(event.tint)
	place_at_surface(particles, event.world_position, 0.02)
	add_effect(particles)
	splash_render_count += 1
	particles.emitting = true
	var tween := particles.create_tween()
	tween.tween_interval(particles.lifetime + 0.25)
	tween.tween_callback(Callable(self, "release_effect").bind(particles))


func spawn_wake(event: FluidDisturbanceEvent) -> void:
	var direction: Vector3 = event.get_horizontal_direction()
	var right: Vector3 = Vector3.UP.cross(direction).normalized()
	var radius: float = max(event.radius, 0.18)
	var wake_length: float = profile.wake_length_scale if profile != null else 2.4
	for side: float in [-1.0, 1.0]:
		var wake_event := FluidDisturbanceEvent.make(
			FluidDisturbanceEvent.KIND_RIPPLE,
			event.world_position - direction * radius * 0.5 + right * side * radius * 0.38,
			direction,
			event.velocity,
			event.strength * 0.72,
			radius,
			event.source_id,
			event.tags
		)
		spawn_ripple(wake_event, wake_length * 0.52)

	var foam := MeshInstance3D.new()
	foam.name = "ProceduralWakeFoam"
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 1.1, radius * wake_length)
	foam.mesh = plane
	foam.material_override = make_foam_material(event.tint, 0.72)
	foam.rotation.y = atan2(direction.x, direction.z)
	place_at_surface(foam, event.world_position - direction * radius * 0.65, 0.034)
	add_effect(foam)
	wake_render_count += 1
	var duration: float = profile.wake_duration if profile != null else 1.15
	var flow: Vector3 = volume.get_flow_velocity_at(event.world_position)
	var tween := foam.create_tween()
	tween.set_parallel(true)
	tween.tween_property(foam, "scale", Vector3(1.55, 1.0, 2.1), duration)
	tween.tween_property(foam, "global_position", foam.global_position + Vector3(flow.x, 0.0, flow.z) * duration * 0.35, duration)
	tween.tween_property(foam, "transparency", 1.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(Callable(self, "release_effect").bind(foam))


func spawn_churn(event: FluidDisturbanceEvent) -> void:
	var churn_event := FluidDisturbanceEvent.make(
		FluidDisturbanceEvent.KIND_WAKE,
		event.world_position,
		event.direction,
		event.velocity,
		max(event.strength, 0.65),
		max(event.radius, 0.25),
		event.source_id,
		event.tags
	)
	spawn_wake(churn_event)
	spawn_splash(event, 0.58)
	spawn_bubble_plume(event)
	churn_render_count += 1


func spawn_bubble_plume(event: FluidDisturbanceEvent) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ProceduralBubblePlume"
	particles.amount = clampi(int(8.0 + event.strength * 8.0), 8, 48)
	particles.lifetime = clampf(0.65 + event.strength * 0.12, 0.65, 1.5)
	particles.one_shot = true
	particles.explosiveness_ratio = 0.72
	particles.randomness = 0.86
	particles.visibility_aabb = AABB(Vector3(-4.0, -3.0, -4.0), Vector3(8.0, 8.0, 8.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 38.0
	process.initial_velocity_min = 0.45
	process.initial_velocity_max = 1.8 + event.strength * 0.28
	process.gravity = Vector3(0.0, 0.9, 0.0)
	process.scale_min = 0.025
	process.scale_max = 0.09 * clampf(event.radius + 0.5, 0.6, 2.0)
	process.color = Color(0.78, 0.96, 1.0, 0.68)
	particles.process_material = process
	particles.draw_pass_1 = make_droplet_mesh(Color(0.72, 0.95, 1.0, 0.62))
	particles.global_position = event.world_position
	add_effect(particles)
	particles.emitting = true
	var tween := particles.create_tween()
	tween.tween_interval(particles.lifetime + 0.2)
	tween.tween_callback(Callable(self, "release_effect").bind(particles))


func spawn_surface_flash(event: FluidDisturbanceEvent) -> void:
	var flash := OmniLight3D.new()
	flash.name = "FluidSurfaceFlash"
	flash.light_color = Color(0.45, 0.68, 1.0, 1.0)
	flash.light_energy = 2.0 + event.strength * 1.6
	flash.omni_range = 2.5 + event.radius * 2.0
	place_at_surface(flash, event.world_position, 0.16)
	add_effect(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.18 + event.strength * 0.025)
	tween.tween_callback(Callable(self, "release_effect").bind(flash))


func make_foam_material(tint: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var color: Color = get_foam_color(tint)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	return material


func make_droplet_mesh(tint: Color) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = get_foam_color(tint)
	material.emission_enabled = true
	material.emission = Color(0.55, 0.88, 1.0, 1.0)
	material.emission_energy_multiplier = 0.55
	mesh.material = material
	return mesh


func get_foam_color(tint: Color) -> Color:
	var base: Color = profile.foam_color if profile != null else volume.foam_color
	if tint == Color.WHITE:
		return base
	return base.lerp(tint, 0.28)


func place_at_surface(node: Node3D, world_position: Vector3, height_offset: float) -> void:
	node.global_position = Vector3(world_position.x, volume.get_surface_y() + height_offset, world_position.z)


func add_effect(node: Node) -> void:
	var parent: Node = volume
	if volume.get_tree() != null and volume.get_tree().current_scene != null:
		parent = volume.get_tree().current_scene
	parent.add_child(node)
	active_effects.append(node)


func release_effect(node: Node) -> void:
	active_effects.erase(node)
	if node != null and is_instance_valid(node):
		node.queue_free()


func prune_effects() -> void:
	var retained: Array[Node] = []
	for node: Node in active_effects:
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			retained.append(node)
	active_effects = retained


func reset_target() -> void:
	for node: Node in active_effects:
		if node != null and is_instance_valid(node):
			node.queue_free()
	active_effects.clear()
	rendered_count = 0
	ripple_render_count = 0
	splash_render_count = 0
	wake_render_count = 0
	churn_render_count = 0
	rejected_count = 0


func get_debug_data() -> Dictionary:
	prune_effects()
	return {
		"fluid_disturbance_renderer": true,
		"active_effects": active_effects.size(),
		"rendered": rendered_count,
		"ripples": ripple_render_count,
		"splashes": splash_render_count,
		"wakes": wake_render_count,
		"churn": churn_render_count,
		"rejected": rejected_count,
	}
