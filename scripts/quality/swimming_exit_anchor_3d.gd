extends Node3D
class_name SwimmingExitAnchor3D

const SafeDestinationQueryScript = preload("res://scripts/quality/safe_destination_query.gd")

@export var enabled: bool = true
@export var water_volume_path: NodePath
@export var activation_radius: float = 3.2
@export var maximum_vertical_distance: float = 2.4
@export var require_facing: bool = false
@export_range(-1.0, 1.0, 0.05) var minimum_facing_dot: float = 0.0
@export var marker_text: String = "EXIT"
@export var show_marker: bool = true
@export var marker_height: float = 1.6

var water_volume: Area3D
var marker_root: Node3D
var marker_material: StandardMaterial3D
var elapsed: float = 0.0


func _ready() -> void:
	add_to_group("swimming_exit_anchor")
	if water_volume_path != NodePath():
		water_volume = get_node_or_null(water_volume_path) as Area3D
	if show_marker:
		_build_marker()


func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	if marker_root == null:
		return
	marker_root.visible = enabled
	var pulse: float = 1.0 + sin(elapsed * 3.4) * 0.08
	marker_root.scale = Vector3.ONE * pulse
	marker_root.rotation.y += delta * 0.65


func set_water_volume(value: Area3D) -> void:
	water_volume = value


func supports_volume(volume: Node) -> bool:
	return volume != null and (water_volume == null or volume == water_volume)


func supports_any_volume(volumes: Array) -> bool:
	for volume: Variant in volumes:
		if supports_volume(volume as Node):
			return true
	return false


func is_available_for(actor: CharacterBody3D) -> bool:
	if not enabled or actor == null:
		return false
	var offset: Vector3 = global_position - actor.global_position
	var vertical_distance: float = absf(offset.y)
	offset.y = 0.0
	if offset.length() > activation_radius or vertical_distance > maximum_vertical_distance:
		return false
	if require_facing and offset.length_squared() > 0.001:
		var forward: Vector3 = -actor.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			return false
		if forward.normalized().dot(offset.normalized()) < minimum_facing_dot:
			return false
	return true


func try_exit(actor: CharacterBody3D) -> bool:
	if not is_available_for(actor):
		return false
	var safe_result: Dictionary = SafeDestinationQueryScript.find_safe_destination(actor, global_position, {
		"start_position": actor.global_position,
		"require_ground": true,
		"max_rise": 2.0,
		"max_drop": 4.0,
		"search_steps": 4,
	})
	if not bool(safe_result.get("valid", false)):
		_show_message("No safe water exit is available from here.")
		return false

	var swimming: Node = actor.get_node_or_null("SwimmingController")
	if swimming != null and swimming.has_method("reset_swimming"):
		swimming.call("reset_swimming")
	var climbing: Node = actor.get_node_or_null("ClimbingController")
	if climbing != null and climbing.has_method("reset_climbing"):
		climbing.call("reset_climbing")
	var action_state: Node = actor.get_node_or_null("PlayerActionState")
	if action_state != null and action_state.has_method("clear_action_locks"):
		action_state.call("clear_action_locks")

	var target_basis := Basis(Vector3.UP, global_rotation.y)
	actor.global_transform = Transform3D(target_basis, safe_result.get("position", global_position))
	actor.velocity = Vector3.ZERO
	GameState.begin_player_invulnerability(0.3)
	_show_message("Grace climbs out of the water.")
	return true


func _build_marker() -> void:
	marker_root = Node3D.new()
	marker_root.name = "ExitMarker"
	marker_root.position.y = marker_height
	add_child(marker_root)

	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.18
	mesh.height = 0.46
	arrow.mesh = mesh
	arrow.position.y = 0.2
	marker_material = StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(0.42, 0.92, 1.0, 0.86)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.18, 0.72, 1.0)
	marker_material.emission_energy_multiplier = 1.5
	arrow.material_override = marker_material
	marker_root.add_child(arrow)

	var label := Label3D.new()
	label.name = "Label"
	label.text = marker_text
	label.position.y = 0.62
	label.font_size = 22
	label.modulate = Color(0.68, 0.94, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker_root.add_child(label)


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


func get_debug_data() -> Dictionary:
	return {
		"enabled": enabled,
		"volume": water_volume.name if water_volume != null else "any",
		"radius": activation_radius,
		"position": global_position,
	}
