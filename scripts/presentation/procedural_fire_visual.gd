extends Node3D
class_name ProceduralFireVisual

const FireProfileScript = preload("res://scripts/presentation/fire_presentation_profile.gd")
const FireEventScript = preload("res://scripts/presentation/fire_vfx_event.gd")
const FlameShader: Shader = preload("res://shaders/fire_flame_v1.gdshader")

signal expired(visual: Node3D)

var profile: Resource
var event: RefCounted
var flame_nodes: Array[MeshInstance3D] = []
var smoke_particles: GPUParticles3D
var ember_particles: GPUParticles3D
var fire_light: OmniLight3D
var age: float = 0.0
var current_intensity: float = 1.0
var wind_velocity: Vector3 = Vector3.ZERO
var persistent: bool = false
var seed_phase: float = 0.0
var base_light_energy: float = 0.0


func configure(next_event: RefCounted, next_profile: Resource) -> void:
	event = next_event
	profile = next_profile if next_profile != null else FireProfileScript.new()
	if event == null:
		event = FireEventScript.new()
	current_intensity = clampf(float(event.intensity), 0.0, 5.0)
	wind_velocity = event.wind_velocity
	persistent = bool(profile.persistent)
	seed_phase = float(abs(int(event.seed) % 997)) * 0.031
	build_flames()
	build_smoke()
	build_embers()
	build_light()
	apply_state(current_intensity, wind_velocity, float(event.smoke_strength), float(event.ember_strength))


func build_flames() -> void:
	var count: int = clampi(int(profile.lick_count), 1, 16)
	for index: int in range(count):
		var lick := MeshInstance3D.new()
		lick.name = "FlameLick" + str(index + 1)
		var mesh := CylinderMesh.new()
		var spread: float = float(index) / max(float(count - 1), 1.0)
		var height_scale: float = lerpf(0.54, 1.12, 1.0 - absf(spread * 2.0 - 1.0))
		mesh.top_radius = 0.015
		mesh.bottom_radius = max(float(profile.flame_radius) * lerpf(0.45, 0.82, fmod(float(index) * 0.67, 1.0)), 0.04)
		mesh.height = max(float(profile.flame_height) * height_scale, 0.08)
		mesh.radial_segments = 12
		mesh.rings = 6
		lick.mesh = mesh
		lick.position = Vector3(
			sin(float(index) * 2.13 + seed_phase) * float(profile.flame_radius) * 0.42,
			mesh.height * 0.5,
			cos(float(index) * 1.71 + seed_phase) * float(profile.flame_radius) * 0.42
		)
		lick.rotation.y = float(index) * 1.37 + seed_phase
		lick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = FlameShader
		material.set_shader_parameter("inner_color", profile.inner_color)
		material.set_shader_parameter("body_color", profile.body_color)
		material.set_shader_parameter("fringe_color", profile.fringe_color)
		material.set_shader_parameter("intensity", current_intensity)
		material.set_shader_parameter("seed", seed_phase + float(index) * 0.173)
		material.set_shader_parameter("sway_strength", float(profile.sway_strength))
		material.set_shader_parameter("wind_velocity", wind_velocity)
		material.set_shader_parameter("time_scale", max(float(profile.flicker_speed) / 13.0, 0.1))
		lick.material_override = material
		add_child(lick)
		flame_nodes.append(lick)


func build_smoke() -> void:
	smoke_particles = GPUParticles3D.new()
	smoke_particles.name = "ProceduralSmoke"
	smoke_particles.amount = clampi(int(profile.smoke_amount), 1, 128)
	smoke_particles.lifetime = 2.4
	smoke_particles.randomness = 0.82
	smoke_particles.one_shot = not persistent
	smoke_particles.visibility_aabb = AABB(Vector3(-5.0, -1.0, -5.0), Vector3(10.0, 12.0, 10.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 28.0
	process.initial_velocity_min = 0.45
	process.initial_velocity_max = 1.9
	process.gravity = Vector3(0.0, 0.45, 0.0)
	process.scale_min = 0.18
	process.scale_max = 0.72
	process.color = profile.smoke_color
	smoke_particles.process_material = process
	smoke_particles.draw_pass_1 = make_particle_quad(profile.smoke_color, false, 0.42)
	smoke_particles.position.y = max(float(profile.flame_height) * 0.72, 0.2)
	add_child(smoke_particles)


func build_embers() -> void:
	ember_particles = GPUParticles3D.new()
	ember_particles.name = "ProceduralEmbers"
	ember_particles.amount = clampi(int(profile.ember_amount), 1, 128)
	ember_particles.lifetime = 1.25
	ember_particles.randomness = 0.9
	ember_particles.one_shot = not persistent
	ember_particles.visibility_aabb = AABB(Vector3(-5.0, -1.0, -5.0), Vector3(10.0, 9.0, 10.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 48.0
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 3.2
	process.gravity = Vector3(0.0, -0.45, 0.0)
	process.scale_min = 0.025
	process.scale_max = 0.085
	process.color = profile.ember_color
	ember_particles.process_material = process
	ember_particles.draw_pass_1 = make_particle_quad(profile.ember_color, true, 0.07)
	ember_particles.position.y = max(float(profile.flame_height) * 0.38, 0.1)
	add_child(ember_particles)


func build_light() -> void:
	fire_light = OmniLight3D.new()
	fire_light.name = "ProceduralFireLight"
	fire_light.light_color = profile.body_color.lerp(profile.inner_color, 0.4)
	base_light_energy = max(float(profile.light_energy), 0.0)
	fire_light.light_energy = base_light_energy * current_intensity
	fire_light.omni_range = max(float(profile.light_range), 0.5)
	fire_light.position.y = max(float(profile.flame_height) * 0.48, 0.2)
	fire_light.shadow_enabled = false
	add_child(fire_light)


func make_particle_quad(color: Color, emissive: bool, size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 5.0
	mesh.material = material
	return mesh


func apply_state(
	next_intensity: float,
	next_wind_velocity: Vector3,
	smoke_strength: float,
	ember_strength: float
) -> void:
	current_intensity = clampf(next_intensity, 0.0, 5.0)
	wind_velocity = next_wind_velocity if next_wind_velocity.is_finite() else Vector3.ZERO
	var visible_flame: bool = current_intensity > 0.025
	var base_scale: float = get_base_flame_scale()
	for index: int in range(flame_nodes.size()):
		var lick: MeshInstance3D = flame_nodes[index]
		lick.visible = visible_flame
		lick.scale = Vector3.ONE * base_scale
		var material := lick.material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter("intensity", current_intensity)
			material.set_shader_parameter("wind_velocity", wind_velocity)
	if smoke_particles != null:
		smoke_particles.amount = clampi(int(max(float(profile.smoke_amount) * max(smoke_strength, 0.08), 1.0)), 1, 192)
		smoke_particles.emitting = smoke_strength > 0.025
		var smoke_process := smoke_particles.process_material as ParticleProcessMaterial
		if smoke_process != null:
			smoke_process.direction = (Vector3.UP * 1.6 + wind_velocity * 0.22).normalized()
	if ember_particles != null:
		ember_particles.amount = clampi(int(max(float(profile.ember_amount) * max(ember_strength, 0.06), 1.0)), 1, 192)
		ember_particles.emitting = ember_strength > 0.02 and current_intensity > 0.02
		var ember_process := ember_particles.process_material as ParticleProcessMaterial
		if ember_process != null:
			ember_process.direction = (Vector3.UP * 1.4 + wind_velocity * 0.3).normalized()
	if fire_light != null:
		fire_light.visible = visible_flame
		fire_light.omni_range = max(float(profile.light_range) * sqrt(max(current_intensity, 0.01)), 0.5)


func get_base_flame_scale() -> float:
	return lerpf(0.35, 1.18, clampf(current_intensity, 0.0, 1.5) / 1.5)


func _process(delta: float) -> void:
	age += max(delta, 0.0)
	var flicker: float = 0.72 + 0.28 * absf(sin(age * float(profile.flicker_speed) + seed_phase))
	flicker += sin(age * float(profile.flicker_speed) * 0.43 + seed_phase * 2.0) * 0.08
	if fire_light != null:
		fire_light.light_energy = base_light_energy * current_intensity * max(flicker, 0.1)
	var base_scale: float = get_base_flame_scale()
	for index: int in range(flame_nodes.size()):
		var lick: MeshInstance3D = flame_nodes[index]
		lick.rotation.y += delta * (0.1 + float(index % 3) * 0.035)
		var individual_pulse: float = flicker + sin(age * (4.8 + float(index) * 0.31) + seed_phase) * 0.035
		lick.scale = Vector3(base_scale, base_scale * clampf(0.94 + individual_pulse * 0.1, 0.9, 1.08), base_scale)
	if not persistent and age >= max(float(event.duration_seconds), float(profile.effect_lifetime)):
		expired.emit(self)
		queue_free()


func reset_target() -> void:
	age = 0.0
	apply_state(0.0, Vector3.ZERO, 0.0, 0.0)


func get_debug_data() -> Dictionary:
	return {
		"procedural_fire_visual": true,
		"persistent": persistent,
		"intensity": snapped(current_intensity, 0.01),
		"wind": wind_velocity,
		"flame_licks": flame_nodes.size(),
		"smoke_emitting": smoke_particles.emitting if smoke_particles != null else false,
		"embers_emitting": ember_particles.emitting if ember_particles != null else false,
		"age": snapped(age, 0.01),
	}
