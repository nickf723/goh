extends Node3D
class_name GasDensitySensor

@export var sensor_label: String = "GAS SENSOR"
@export var gas_ids: Array[String] = ["smoke", "poison"]
@export_range(0.02, 1.0, 0.01) var sample_interval: float = 0.15
@export var label_offset: Vector3 = Vector3(0.0, 1.35, 0.0)
@export var sample_offset: Vector3 = Vector3(0.0, 1.1, 0.0)
@export var label_color: Color = Color(0.68, 0.94, 1.0, 1.0)

var gas_manager: Node = null
var label: Label3D = null
var sample_timer: float = 0.0
var last_densities: Dictionary = {}


func _ready() -> void:
	add_to_group("gas_sensors")
	add_to_group("debuggable")
	build_visual()
	update_sensor()


func _process(delta: float) -> void:
	sample_timer -= max(delta, 0.0)
	if sample_timer > 0.0:
		return
	sample_timer = max(sample_interval, 0.02)
	update_sensor()


func resolve_manager() -> Node:
	if gas_manager != null and is_instance_valid(gas_manager):
		return gas_manager
	gas_manager = get_tree().get_first_node_in_group("gas_manager")
	return gas_manager


func build_visual() -> void:
	var post := MeshInstance3D.new()
	post.name = "SensorPost"
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.07
	post_mesh.bottom_radius = 0.1
	post_mesh.height = 1.1
	post_mesh.radial_segments = 10
	post.mesh = post_mesh
	post.position = Vector3(0.0, 0.55, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.22, 0.3, 1.0)
	material.metallic = 0.55
	material.roughness = 0.3
	post.material_override = material
	add_child(post)

	var sensor_orb := MeshInstance3D.new()
	sensor_orb.name = "SensorOrb"
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.16
	orb_mesh.height = 0.32
	orb_mesh.radial_segments = 10
	orb_mesh.rings = 5
	sensor_orb.mesh = orb_mesh
	sensor_orb.position = Vector3(0.0, 1.15, 0.0)
	var orb_material := StandardMaterial3D.new()
	orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_material.albedo_color = label_color
	orb_material.emission_enabled = true
	orb_material.emission = label_color
	orb_material.emission_energy_multiplier = 1.8
	sensor_orb.material_override = orb_material
	add_child(sensor_orb)

	label = Label3D.new()
	label.name = "SensorLabel"
	label.position = label_offset
	label.font_size = 24
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = label_color
	add_child(label)


func update_sensor() -> void:
	last_densities.clear()
	var manager: Node = resolve_manager()
	var lines: Array[String] = [sensor_label]
	for gas_id: String in gas_ids:
		var density: float = 0.0
		if manager != null and manager.has_method("sample_density"):
			density = float(manager.call("sample_density", global_position + sample_offset, gas_id))
		last_densities[gas_id] = density
		lines.append(gas_id.to_upper() + "  " + str(snapped(density, 0.01)))
	if label != null:
		label.text = "\n".join(lines)


func get_density(gas_id: String) -> float:
	return float(last_densities.get(gas_id, 0.0))


func get_debug_data() -> Dictionary:
	return {
		"gas_sensor": sensor_label,
		"position": global_position,
		"sample_position": global_position + sample_offset,
		"densities": last_densities.duplicate(true),
	}
