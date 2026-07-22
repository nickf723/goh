extends Node3D
class_name AirflowTracerVolume

@export var tracer_count: int = 90
@export var volume_extents: Vector3 = Vector3(16.0, 8.0, 14.0)
@export var advection_scale: float = 0.72
@export var minimum_motion_speed: float = 0.12
@export var tracer_radius: float = 0.035

var airflow_manager: Node = null
var random := RandomNumberGenerator.new()
var tracers: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	random.seed = 7232026
	build_tracers()


func _process(delta: float) -> void:
	var manager: Node = resolve_manager()
	if manager == null or not manager.has_method("sample_total_airflow"):
		return
	for tracer: MeshInstance3D in tracers:
		if tracer == null or not is_instance_valid(tracer):
			continue
		var sampled_value: Variant = manager.call("sample_total_airflow", tracer.global_position)
		var velocity: Vector3 = sampled_value as Vector3 if sampled_value is Vector3 else Vector3.ZERO
		if velocity.length() < minimum_motion_speed:
			velocity += Vector3(0.08, 0.02, -0.04)
		tracer.global_position += velocity * advection_scale * max(delta, 0.0)
		if is_outside_volume(to_local(tracer.global_position)):
			reset_tracer(tracer, true)


func resolve_manager() -> Node:
	if airflow_manager != null and is_instance_valid(airflow_manager):
		return airflow_manager
	airflow_manager = get_tree().get_first_node_in_group("airflow_manager")
	return airflow_manager


func build_tracers() -> void:
	if not tracers.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = tracer_radius
	mesh.height = tracer_radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.72, 0.94, 1.0, 0.64)
	material.emission_enabled = true
	material.emission = Color(0.4, 0.82, 1.0, 1.0)
	material.emission_energy_multiplier = 1.3
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for index: int in range(max(tracer_count, 1)):
		var tracer := MeshInstance3D.new()
		tracer.name = "AirTracer" + str(index)
		tracer.mesh = mesh
		tracer.material_override = material
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tracer)
		tracers.append(tracer)
		reset_tracer(tracer, true)


func reset_tracer(tracer: MeshInstance3D, randomize_all_axes: bool = false) -> void:
	if tracer == null:
		return
	var local_position := Vector3(
		random.randf_range(-volume_extents.x, volume_extents.x),
		random.randf_range(-volume_extents.y, volume_extents.y),
		random.randf_range(-volume_extents.z, volume_extents.z)
	)
	if not randomize_all_axes:
		local_position.x = -volume_extents.x
	tracer.position = local_position
	var scale_value: float = random.randf_range(0.65, 1.5)
	tracer.scale = Vector3.ONE * scale_value


func is_outside_volume(local_position: Vector3) -> bool:
	return (
		abs(local_position.x) > volume_extents.x
		or abs(local_position.y) > volume_extents.y
		or abs(local_position.z) > volume_extents.z
	)


func reset_target() -> void:
	for tracer: MeshInstance3D in tracers:
		reset_tracer(tracer, true)


func get_debug_data() -> Dictionary:
	return {
		"airflow_tracers": tracers.size(),
		"volume_extents": volume_extents,
		"advection_scale": advection_scale,
	}
