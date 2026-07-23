extends Node3D
class_name PerceptionDebugVisualizer

@export var sensor_path: NodePath = NodePath("../EnemyPerceptionSensor")
@export var brain_path: NodePath = NodePath("../EnemyBrain")
@export_range(0.05, 1.0, 0.01) var refresh_interval: float = 0.12
@export_range(4, 48, 1) var cone_segments: int = 18
@export_range(8, 64, 1) var hearing_segments: int = 28
@export var show_vision_cone: bool = true
@export var show_hearing_radius: bool = true
@export var show_last_known_position: bool = true
@export var show_label: bool = true

var sensor: EnemyPerceptionSensor = null
var brain: Node = null
var mesh_instance: MeshInstance3D = null
var label: Label3D = null
var refresh_timer: float = 0.0


func _ready() -> void:
	add_to_group("perception_debug_visualizers")
	add_to_group("debuggable")
	resolve_components()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "PerceptionLines"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	build_label()
	refresh_visuals()


func _process(delta: float) -> void:
	if not visible:
		return
	refresh_timer -= max(delta, 0.0)
	if refresh_timer > 0.0:
		return
	refresh_timer = max(refresh_interval, 0.05)
	refresh_visuals()


func resolve_components() -> void:
	sensor = get_node_or_null(sensor_path) as EnemyPerceptionSensor
	brain = get_node_or_null(brain_path)


func build_label() -> void:
	if not show_label:
		return
	label = Label3D.new()
	label.name = "PerceptionLabel"
	label.position = Vector3(0.0, 2.35, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.005
	label.outline_size = 5
	label.no_depth_test = true
	add_child(label)


func refresh_visuals() -> void:
	if sensor == null or brain == null:
		resolve_components()
	if sensor == null or mesh_instance == null:
		return
	var state_name: String = str(brain.call("get_awareness_state_name")) if brain != null and brain.has_method("get_awareness_state_name") else "UNAWARE"
	var color: Color = get_state_color(state_name)
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.78)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.25
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	if show_vision_cone:
		draw_vision_cone(immediate)
	if show_hearing_radius:
		draw_hearing_circle(immediate)
	if show_last_known_position:
		draw_last_known(immediate)
	immediate.surface_end()
	mesh_instance.mesh = immediate
	update_label(state_name, color)


func draw_vision_cone(immediate: ImmediateMesh) -> void:
	var eye_world: Vector3 = sensor.get_eye_position()
	var eye_local: Vector3 = to_local(eye_world)
	var actor: Node3D = sensor.actor
	if actor == null:
		return
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var half_angle: float = deg_to_rad(sensor.field_of_view_degrees * 0.5)
	var range_value: float = sensor.vision_range * max(sensor.vision_multiplier, 0.05)
	var previous_local: Vector3 = Vector3.ZERO
	for index: int in range(max(cone_segments, 4) + 1):
		var ratio: float = float(index) / float(max(cone_segments, 4))
		var angle: float = lerpf(-half_angle, half_angle, ratio)
		var direction: Vector3 = forward * cos(angle) + right * sin(angle)
		var point_local: Vector3 = to_local(eye_world + direction * range_value)
		if index > 0:
			add_line(immediate, previous_local, point_local)
		if index == 0 or index == max(cone_segments, 4):
			add_line(immediate, eye_local, point_local)
		previous_local = point_local


func draw_hearing_circle(immediate: ImmediateMesh) -> void:
	var center_world: Vector3 = sensor.get_eye_position()
	var radius: float = 8.0 * max(sensor.hearing_sensitivity * sensor.hearing_multiplier, 0.05)
	var segments: int = max(hearing_segments, 8)
	var previous_local: Vector3 = Vector3.ZERO
	for index: int in range(segments + 1):
		var angle: float = TAU * float(index) / float(segments)
		var point_world := center_world + Vector3(cos(angle) * radius, -0.78, sin(angle) * radius)
		var point_local: Vector3 = to_local(point_world)
		if index > 0:
			add_line(immediate, previous_local, point_local)
		previous_local = point_local


func draw_last_known(immediate: ImmediateMesh) -> void:
	if brain == null:
		return
	var destination_value: Variant = brain.get("last_known_position")
	if not (destination_value is Vector3):
		return
	var destination: Vector3 = destination_value as Vector3
	var start: Vector3 = to_local(sensor.get_eye_position())
	var end: Vector3 = to_local(destination + Vector3.UP * 0.12)
	add_line(immediate, start, end)
	var marker_size: float = 0.38
	add_line(immediate, end + Vector3.LEFT * marker_size, end + Vector3.RIGHT * marker_size)
	add_line(immediate, end + Vector3.FORWARD * marker_size, end + Vector3.BACK * marker_size)


func update_label(state_name: String, color: Color) -> void:
	if label == null:
		return
	var suspicion: float = float(brain.get("suspicion")) if brain != null and brain.get("suspicion") != null else 0.0
	var visible_text: String = "SEES GRACE" if sensor.target_visible else "NO VISUAL"
	var heard_text: String = ""
	if brain != null:
		var heard_value: Variant = brain.get("last_heard_summary")
		if heard_value != null and str(heard_value) != "none":
			heard_text = "\nHeard: " + str(heard_value)
	label.text = state_name + "  " + str(snapped(suspicion, 0.01)) + "\n" + visible_text + heard_text
	label.modulate = color


func get_state_color(state_name: String) -> Color:
	match state_name:
		"SUSPICIOUS":
			return Color(1.0, 0.82, 0.2, 1.0)
		"INVESTIGATING":
			return Color(1.0, 0.52, 0.16, 1.0)
		"ALERTED":
			return Color(1.0, 0.18, 0.18, 1.0)
		"SEARCHING":
			return Color(0.82, 0.35, 1.0, 1.0)
		"RETURNING":
			return Color(0.34, 0.72, 1.0, 1.0)
		_:
			return Color(0.35, 1.0, 0.64, 1.0)


func add_line(immediate: ImmediateMesh, start: Vector3, finish: Vector3) -> void:
	immediate.surface_add_vertex(start)
	immediate.surface_add_vertex(finish)


func get_debug_data() -> Dictionary:
	return {
		"perception_debug_visualizer": true,
		"sensor": sensor != null,
		"brain": brain != null,
		"visible": visible,
	}
