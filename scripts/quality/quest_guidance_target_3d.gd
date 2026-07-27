extends Node3D
class_name QuestGuidanceTarget3D

@export var enabled: bool = true
@export var marker_text: String = "OBJECTIVE"
@export var required_flag: String = ""
@export var blocked_flag: String = ""
@export var optional_target: bool = false
@export var show_distance: bool = true
@export var marker_height: float = 2.4
@export var maximum_visible_distance: float = 90.0

var marker_root: Node3D
var marker_material: StandardMaterial3D
var marker_label: Label3D
var elapsed: float = 0.0
var player: Node3D


func _ready() -> void:
	add_to_group("quest_guidance_target")
	if not GameState.flag_changed.is_connected(_on_flag_changed):
		GameState.flag_changed.connect(_on_flag_changed)
	_build_marker()
	refresh_state()


func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	if marker_root == null or not visible:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var distance: float = global_position.distance_to(player.global_position)
		marker_root.visible = distance <= maximum_visible_distance
		if marker_label != null:
			marker_label.text = (
				marker_text + "  %dm" % roundi(distance)
				if show_distance
				else marker_text
			)
	else:
		marker_root.visible = true
	var pulse: float = 1.0 + sin(elapsed * 3.1) * 0.09
	marker_root.scale = Vector3.ONE * pulse
	marker_root.rotation.y += delta * (0.55 if optional_target else 0.8)


func refresh_state() -> void:
	var available: bool = enabled
	if required_flag != "" and not GameState.get_flag(required_flag):
		available = false
	if blocked_flag != "" and GameState.get_flag(blocked_flag):
		available = false
	visible = available
	if marker_root != null:
		marker_root.visible = available


func set_rules(required: String, blocked: String) -> void:
	required_flag = required
	blocked_flag = blocked
	refresh_state()


func _on_flag_changed(flag_name: String, _value: bool) -> void:
	if flag_name == required_flag or flag_name == blocked_flag:
		refresh_state()


func _build_marker() -> void:
	marker_root = Node3D.new()
	marker_root.name = "GuidanceMarker"
	marker_root.position.y = marker_height
	add_child(marker_root)

	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.025
	beacon_mesh.bottom_radius = 0.025
	beacon_mesh.height = 1.5
	beacon.mesh = beacon_mesh
	beacon.position.y = -0.78
	marker_material = StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var color: Color = Color(0.72, 0.46, 1.0, 0.64) if optional_target else Color(0.2, 0.78, 1.0, 0.72)
	marker_material.albedo_color = color
	marker_material.emission_enabled = true
	marker_material.emission = Color(color.r, color.g, color.b)
	marker_material.emission_energy_multiplier = 1.35
	beacon.material_override = marker_material
	marker_root.add_child(beacon)

	var diamond := MeshInstance3D.new()
	diamond.name = "Diamond"
	var diamond_mesh := SphereMesh.new()
	diamond_mesh.radius = 0.18
	diamond_mesh.height = 0.36
	diamond.mesh = diamond_mesh
	diamond.material_override = marker_material
	marker_root.add_child(diamond)

	marker_label = Label3D.new()
	marker_label.name = "Label"
	marker_label.text = marker_text
	marker_label.position.y = 0.48
	marker_label.font_size = 22 if optional_target else 24
	marker_label.modulate = Color(0.82, 0.7, 1.0) if optional_target else Color(0.68, 0.94, 1.0)
	marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker_root.add_child(marker_label)


func get_debug_data() -> Dictionary:
	return {
		"active": visible,
		"text": marker_text,
		"required": required_flag,
		"blocked": blocked_flag,
		"optional": optional_target,
	}
