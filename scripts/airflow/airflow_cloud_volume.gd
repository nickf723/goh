extends Node3D
class_name AirflowCloudVolume

@export var cloud_label: String = "ADVECTED CLOUD"
@export var particle_count: int = 34
@export var initial_extents: Vector3 = Vector3(2.4, 1.5, 2.4)
@export var advection_scale: float = 0.58
@export var diffusion_speed: float = 0.08
@export var maximum_distance_from_origin: float = 16.0

var airflow_manager: Node = null
var random := RandomNumberGenerator.new()
var particles: Array[MeshInstance3D] = []
var initial_global_position: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var state_label: Label3D = null


func _ready() -> void:
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	random.seed = 17012026
	initial_global_position = global_position
	build_cloud()


func _process(delta: float) -> void:
	elapsed += max(delta, 0.0)
	var manager: Node = resolve_manager()
	if manager == null or not manager.has_method("sample_total_airflow"):
		return
	var center: Vector3 = get_cloud_center()
	for index: int in range(particles.size()):
		var particle: MeshInstance3D = particles[index]
		if particle == null or not is_instance_valid(particle):
			continue
		var sampled_value: Variant = manager.call("sample_total_airflow", particle.global_position)
		var velocity: Vector3 = sampled_value as Vector3 if sampled_value is Vector3 else Vector3.ZERO
		var phase: float = elapsed * 0.7 + float(index) * 1.37
		var diffusion := Vector3(sin(phase), sin(phase * 1.31 + 0.8), cos(phase * 0.83)) * diffusion_speed
		particle.global_position += (velocity * advection_scale + diffusion) * delta
		if particle.global_position.distance_to(initial_global_position) > maximum_distance_from_origin:
			reset_particle(particle)
	update_label(center)


func resolve_manager() -> Node:
	if airflow_manager != null and is_instance_valid(airflow_manager):
		return airflow_manager
	airflow_manager = get_tree().get_first_node_in_group("airflow_manager")
	return airflow_manager


func build_cloud() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.34
	mesh.height = 0.68
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.52, 0.72, 0.78, 0.23)
	material.emission_enabled = true
	material.emission = Color(0.28, 0.48, 0.58, 1.0)
	material.emission_energy_multiplier = 0.48
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for index: int in range(max(particle_count, 1)):
		var particle := MeshInstance3D.new()
		particle.name = "CloudParticle" + str(index)
		particle.mesh = mesh
		particle.material_override = material
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(particle)
		particles.append(particle)
		reset_particle(particle)

	state_label = Label3D.new()
	state_label.name = "CloudReadout"
	state_label.text = cloud_label + "\nGUST OR VORTEX MOVES THE SAME VOLUME"
	state_label.position = Vector3(0.0, 2.6, 0.0)
	state_label.font_size = 24
	state_label.pixel_size = 0.006
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.outline_size = 5
	state_label.modulate = Color(0.64, 0.84, 0.9, 1.0)
	add_child(state_label)


func reset_particle(particle: MeshInstance3D) -> void:
	particle.global_position = initial_global_position + Vector3(
		random.randf_range(-initial_extents.x, initial_extents.x),
		random.randf_range(-initial_extents.y, initial_extents.y),
		random.randf_range(-initial_extents.z, initial_extents.z)
	)
	var scale_value: float = random.randf_range(0.7, 1.65)
	particle.scale = Vector3(scale_value, random.randf_range(0.65, 1.25), scale_value)


func get_cloud_center() -> Vector3:
	if particles.is_empty():
		return global_position
	var total: Vector3 = Vector3.ZERO
	var count: int = 0
	for particle: MeshInstance3D in particles:
		if particle == null or not is_instance_valid(particle):
			continue
		total += particle.global_position
		count += 1
	return total / float(max(count, 1))


func update_label(center: Vector3) -> void:
	if state_label == null:
		return
	state_label.global_position = center + Vector3.UP * 2.4
	state_label.text = cloud_label + "\nDisplacement " + str(snapped(center.distance_to(initial_global_position), 0.1)) + " m"


func reset_target() -> void:
	global_position = initial_global_position
	for particle: MeshInstance3D in particles:
		reset_particle(particle)


func get_debug_data() -> Dictionary:
	return {
		"airflow_cloud": cloud_label,
		"particles": particles.size(),
		"center": get_cloud_center(),
		"displacement": snapped(get_cloud_center().distance_to(initial_global_position), 0.01),
	}
