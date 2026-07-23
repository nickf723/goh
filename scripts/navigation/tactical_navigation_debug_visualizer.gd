extends Node3D
class_name TacticalNavigationDebugVisualizer

@export var navigation_component_path: NodePath = NodePath("../TacticalNavigationAgent")
@export_range(0.05, 1.0, 0.01) var refresh_interval: float = 0.16
@export var show_path: bool = true
@export var show_destination: bool = true
@export var show_route_label: bool = true
@export_range(0.01, 0.4, 0.01) var marker_size: float = 0.18

var navigation_component: TacticalNavigationAgent = null
var mesh_instance: MeshInstance3D = null
var route_label: Label3D = null
var refresh_timer: float = 0.0
var last_point_count: int = 0


func _ready() -> void:
	add_to_group("tactical_navigation_debug_visualizers")
	add_to_group("debuggable")
	top_level = true
	resolve_navigation_component()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "RouteLines"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	route_label = Label3D.new()
	route_label.name = "RouteLabel"
	route_label.position = Vector3(0.0, 2.35, 0.0)
	route_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	route_label.font_size = 24
	route_label.pixel_size = 0.005
	route_label.outline_size = 5
	add_child(route_label)
	refresh_visuals()


func _process(delta: float) -> void:
	if not visible:
		return
	refresh_timer -= max(delta, 0.0)
	if refresh_timer > 0.0:
		return
	refresh_timer = max(refresh_interval, 0.05)
	refresh_visuals()


func resolve_navigation_component() -> void:
	navigation_component = get_node_or_null(navigation_component_path) as TacticalNavigationAgent


func refresh_visuals() -> void:
	if navigation_component == null:
		resolve_navigation_component()
	if navigation_component == null or mesh_instance == null:
		return
	if navigation_component.actor != null:
		global_position = navigation_component.actor.global_position

	var route_color: Color = get_route_color(navigation_component.chosen_route_id)
	if route_label != null:
		route_label.visible = show_route_label
		route_label.modulate = route_color
		route_label.text = (
			navigation_component.chosen_route_id.to_upper()
			+ "  score " + str(snapped(navigation_component.chosen_route_score, 0.1))
			+ "\nhazard " + str(snapped(navigation_component.chosen_hazard_cost, 0.1))
		)

	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = route_color
	material.emission_enabled = true
	material.emission = Color(route_color.r, route_color.g, route_color.b, 1.0)
	material.emission_energy_multiplier = 1.35
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)

	last_point_count = 0
	if show_path:
		var path: PackedVector3Array = navigation_component.get_current_navigation_path()
		last_point_count = path.size()
		for index: int in range(1, path.size()):
			add_world_line(immediate, path[index - 1] + Vector3.UP * 0.16, path[index] + Vector3.UP * 0.16)
	if show_destination and navigation_component.has_destination:
		add_world_cross(immediate, navigation_component.current_destination + Vector3.UP * 0.18, marker_size * 2.0)
	for waypoint: Vector3 in navigation_component.route_waypoints:
		add_world_cross(immediate, waypoint + Vector3.UP * 0.22, marker_size)

	immediate.surface_end()
	mesh_instance.mesh = immediate


func add_world_line(immediate: ImmediateMesh, start: Vector3, finish: Vector3) -> void:
	immediate.surface_add_vertex(to_local(start))
	immediate.surface_add_vertex(to_local(finish))


func add_world_cross(immediate: ImmediateMesh, center: Vector3, size_value: float) -> void:
	add_world_line(immediate, center - Vector3.RIGHT * size_value, center + Vector3.RIGHT * size_value)
	add_world_line(immediate, center - Vector3.FORWARD * size_value, center + Vector3.FORWARD * size_value)
	add_world_line(immediate, center - Vector3.UP * size_value, center + Vector3.UP * size_value)


func get_route_color(route_id: String) -> Color:
	var normalized: String = route_id.to_lower().strip_edges()
	if normalized.contains("safe") or normalized.contains("left"):
		return Color(0.2, 0.78, 1.0, 0.9)
	if normalized.contains("shortcut") or normalized.contains("right"):
		return Color(1.0, 0.5, 0.12, 0.9)
	if normalized == "none":
		return Color(0.5, 0.55, 0.62, 0.65)
	return Color(0.72, 0.92, 1.0, 0.85)


func get_debug_data() -> Dictionary:
	return {
		"tactical_navigation_debug": true,
		"route": navigation_component.chosen_route_id if navigation_component != null else "none",
		"points": last_point_count,
		"visible": visible,
	}
