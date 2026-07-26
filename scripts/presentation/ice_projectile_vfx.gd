extends Node3D
class_name IceProjectileVfx

const IceRendererScript = preload("res://scripts/presentation/procedural_ice_renderer.gd")
const IceEventScript = preload("res://scripts/presentation/ice_vfx_event.gd")
const IceProfileScript = preload("res://scripts/presentation/ice_presentation_profile.gd")

var projectile: Node3D
var renderer: Node3D
var projectile_visual: Node3D
var trail_particles: GPUParticles3D
var initialized: bool = false
var active_for_ice: bool = false
var elapsed: float = 0.0


func _ready() -> void:
	call_deferred("initialize_vfx")


func initialize_vfx() -> void:
	projectile = get_parent() as Node3D
	if projectile == null or not projectile.has_method("get_element"):
		set_process(false)
		return
	active_for_ice = str(projectile.call("get_element")) == "ice"
	if not active_for_ice:
		visible = false
		set_process(false)
		return
	var legacy_root: Node3D = projectile.get_node_or_null("ElementVisualRoot") as Node3D
	if legacy_root != null:
		legacy_root.visible = false
	renderer = IceRendererScript.new()
	renderer.name = "ProceduralIceRenderer"
	add_child(renderer)
	var event: Resource = IceEventScript.make(
		IceEventScript.KIND_PROJECTILE,
		projectile.global_position,
		Vector3.FORWARD,
		1.0,
		0.42,
		projectile.get_instance_id(),
		"ice_lance_projectile",
		["projectile", "persistent"]
	)
	event.direction = Vector3.FORWARD
	event.shard_count = 8
	event.duration_seconds = 30.0
	projectile_visual = renderer.call("render_event", event, IceProfileScript.make_projectile()) as Node3D
	build_trail()
	initialized = true


func build_trail() -> void:
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "ProceduralIceTrail"
	trail_particles.amount = 32
	trail_particles.lifetime = 0.55
	trail_particles.randomness = 0.88
	trail_particles.local_coords = false
	trail_particles.visibility_aabb = AABB(Vector3(-8.0, -8.0, -8.0), Vector3(16.0, 16.0, 16.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.BACK
	process.spread = 32.0
	process.initial_velocity_min = 0.12
	process.initial_velocity_max = 0.75
	process.gravity = Vector3(0.0, -0.3, 0.0)
	process.scale_min = 0.025
	process.scale_max = 0.095
	process.color = Color(0.68, 0.94, 1.0, 0.9)
	trail_particles.process_material = process
	var shard := PrismMesh.new()
	shard.size = Vector3(0.035, 0.13, 0.025)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.58, 0.9, 1.0, 0.86)
	material.emission_enabled = true
	material.emission = Color(0.62, 0.94, 1.0, 1.0)
	material.emission_energy_multiplier = 2.2
	shard.material = material
	trail_particles.draw_pass_1 = shard
	add_child(trail_particles)
	trail_particles.emitting = true


func _process(delta: float) -> void:
	if not initialized or not active_for_ice:
		return
	elapsed += max(delta, 0.0)
	rotation.z = elapsed * 2.35
	var travel_direction: Vector3 = Vector3.FORWARD
	if projectile != null:
		var raw_direction: Variant = projectile.get("direction")
		if raw_direction is Vector3 and (raw_direction as Vector3).length() > 0.001:
			travel_direction = raw_direction as Vector3
	if trail_particles != null:
		var process := trail_particles.process_material as ParticleProcessMaterial
		if process != null:
			process.direction = -travel_direction.normalized()


func reset_target() -> void:
	elapsed = 0.0
	if renderer != null and renderer.has_method("reset_target"):
		renderer.call("reset_target")


func get_debug_data() -> Dictionary:
	var trail_emitting: bool = false
	if trail_particles != null:
		trail_emitting = trail_particles.emitting
	var renderer_debug: Dictionary = {}
	if renderer != null and renderer.has_method("get_debug_data"):
		renderer_debug = renderer.call("get_debug_data") as Dictionary
	return {
		"ice_projectile_vfx": true,
		"active": active_for_ice,
		"initialized": initialized,
		"trail_emitting": trail_emitting,
		"renderer": renderer_debug,
	}
