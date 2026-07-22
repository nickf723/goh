extends Node3D
class_name AirflowVectorVisualizer

@export var sample_extents: Vector3 = Vector3(16.0, 8.0, 14.0)
@export var sample_spacing: Vector3 = Vector3(3.0, 3.0, 3.0)
@export var arrow_scale: float = 0.34
@export var maximum_arrow_length: float = 2.2
@export var minimum_visible_speed: float = 0.18
@export var refresh_interval: float = 0.18
@export var visible_by_default: bool = true

var airflow_manager: Node = null
var mesh_instance: MeshInstance3D = null
var refresh_timer: float = 0.0
var arrow_count: int = 0


func _ready() -> void:
	add_to_group("debuggable")
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "AirflowVectors"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	visible = visible_by_default
	refresh_vectors()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = max(refresh_interval, 0.05)
	refresh_vectors()


func resolve_manager() -> Node:
	if airflow_manager != null and is_instance_valid(airflow_manager):
		return airflow_manager
	airflow_manager = get_tree().get_first_node_in_group("airflow_manager")
	return airflow_manager


func refresh_vectors() -> void:
	var manager: Node = resolve_manager()
	if manager == null or not manager.has_method("sample_total_airflow") or mesh_instance == null:
		return

	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.24, 0.88, 1.0, 0.72)
	material.emission_enabled = true
	material.emission = Color(0.12, 0.72, 1.0, 1.0)
	material.emission_energy_multiplier = 1.45
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)

	arrow_count = 0
	var spacing := Vector3(
		max(sample_spacing.x, 0.5),
		max(sample_spacing.y, 0.5),
		max(sample_spacing.z, 0.5)
	)
	var x_steps: int = int(floor(sample_extents.x * 2.0 / spacing.x))
	var y_steps: int = int(floor(sample_extents.y * 2.0 / spacing.y))
	var z_steps: int = int(floor(sample_extents.z * 2.0 / spacing.z))

	for x_index: int in range(x_steps + 1):
		for y_index: int in range(y_steps + 1):
			for z_index: int in range(z_steps + 1):
				var local_sample := Vector3(
					-sample_extents.x + float(x_index) * spacing.x,
					-sample_extents.y + float(y_index) * spacing.y,
					-sample_extents.z + float(z_index) * spacing.z
				)
				var world_sample: Vector3 = to_global(local_sample)
				var sampled_value: Variant = manager.call("sample_total_airflow", world_sample)
				if not (sampled_value is Vector3):
					continue
				var velocity: Vector3 = sampled_value as Vector3
				var speed: float = velocity.length()
				if speed < minimum_visible_speed:
					continue
				var direction: Vector3 = velocity.normalized()
				var length: float = min(speed * arrow_scale, maximum_arrow_length)
				var local_end: Vector3 = local_sample + direction * length
				add_line(immediate, local_sample, local_end)
				var side: Vector3 = direction.cross(Vector3.UP)
				if side.length() <= 0.05:
					side = direction.cross(Vector3.RIGHT)
				side = side.normalized()
				var head_base: Vector3 = local_end - direction * min(length * 0.32, 0.32)
				add_line(immediate, local_end, head_base + side * 0.12)
				add_line(immediate, local_end, head_base - side * 0.12)
				arrow_count += 1

	immediate.surface_end()
	mesh_instance.mesh = immediate


func add_line(immediate: ImmediateMesh, start: Vector3, finish: Vector3) -> void:
	immediate.surface_add_vertex(start)
	immediate.surface_add_vertex(finish)


func get_debug_data() -> Dictionary:
	return {
		"airflow_vector_visualizer": true,
		"arrows": arrow_count,
		"visible": visible,
		"extents": sample_extents,
		"spacing": sample_spacing,
	}
