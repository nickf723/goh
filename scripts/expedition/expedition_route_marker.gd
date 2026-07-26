extends Area3D
class_name ExpeditionRouteMarker

@export_enum("landmark", "start", "destination") var marker_type: String = "landmark"
@export var marker_id: String = "marker"
@export var display_name: String = "Route Marker"
@export var accent_color: Color = Color(0.75, 0.9, 1.0, 1.0)

var director: Node
var label: Label3D


func configure(
	kind: String,
	resolved_id: String,
	resolved_name: String,
	color: Color
) -> void:
	marker_type = kind
	marker_id = resolved_id
	display_name = resolved_name
	accent_color = color
	name = "Marker_" + marker_id


func _ready() -> void:
	add_to_group("debuggable")
	director = get_tree().get_first_node_in_group("expedition_route_director")
	build_marker_visual()
	refresh_marker()


func build_marker_visual() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 1.05
	shape.height = 2.5
	collision.shape = shape
	collision.position.y = 1.25
	add_child(collision)

	var pillar: MeshInstance3D = MeshInstance3D.new()
	var pillar_mesh: CylinderMesh = CylinderMesh.new()
	pillar_mesh.top_radius = 0.26
	pillar_mesh.bottom_radius = 0.46
	pillar_mesh.height = 2.1
	pillar_mesh.radial_segments = 10
	pillar.mesh = pillar_mesh
	pillar.position.y = 1.05
	pillar.material_override = create_material(Color(0.3, 0.31, 0.28, 1.0))
	add_child(pillar)

	var beacon: MeshInstance3D = MeshInstance3D.new()
	var beacon_mesh: SphereMesh = SphereMesh.new()
	beacon_mesh.radius = 0.38
	beacon_mesh.height = 0.76
	beacon_mesh.radial_segments = 12
	beacon_mesh.rings = 8
	beacon.mesh = beacon_mesh
	beacon.position.y = 2.25
	beacon.material_override = create_material(accent_color, true)
	add_child(beacon)

	label = Label3D.new()
	label.position = Vector3(0.0, 3.0, 0.0)
	label.font_size = 32
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = accent_color
	label.outline_size = 6
	add_child(label)


func interact() -> Dictionary:
	if director == null:
		director = get_tree().get_first_node_in_group("expedition_route_director")
	if director == null:
		return {
			"message": display_name + " cannot find the expedition route.",
			"objective": "",
		}
	var result: Dictionary = {}
	if director.has_method("activate_route_marker"):
		var raw_result: Variant = director.call("activate_route_marker", marker_type, marker_id)
		if raw_result is Dictionary:
			result = raw_result as Dictionary
	refresh_marker()
	if result.is_empty():
		return {
			"message": "Grace examines " + display_name + ".",
			"objective": "Continue the expedition.",
		}
	return result


func refresh_marker() -> void:
	if label == null:
		return
	var suffix: String = ""
	if director != null and director.has_method("is_marker_recorded"):
		if bool(director.call("is_marker_recorded", marker_type, marker_id)):
			suffix = "  ✓"
	label.text = display_name.to_upper() + suffix


func create_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.25
	material.roughness = 0.48
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 1.25
	return material


func get_debug_data() -> Dictionary:
	return {
		"type": marker_type,
		"id": marker_id,
		"recorded": is_marker_recorded(),
	}


func is_marker_recorded() -> bool:
	if director == null or not director.has_method("is_marker_recorded"):
		return false
	return bool(director.call("is_marker_recorded", marker_type, marker_id))
