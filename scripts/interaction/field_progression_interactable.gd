extends Area3D
class_name FieldProgressionInteractable

@export var action_id: String = "field_action"
@export var display_name: String = "Field Discovery"
@export var prompt_text: String = "Inspect"
@export_multiline var description: String = "Something here rewards a closer look."
@export var story_flag: String = ""
@export var one_time: bool = true
@export var hide_when_complete: bool = false
@export var visual_icon: String = "◆"
@export var visual_color: Color = Color(0.46, 0.82, 1.0, 1.0)
@export var resettable_in_lab: bool = false

var completed: bool = false
var initial_transform: Transform3D
var label: Label3D
var visual_root: Node3D


func _ready() -> void:
	initial_transform = transform
	add_to_group("interactable_target")
	add_to_group("field_progression_interactable")
	add_to_group("debuggable")
	if resettable_in_lab:
		add_to_group("lab_resettable")
	_ensure_collision()
	_build_visual()
	_sync_from_game_state()


func interact() -> Dictionary:
	if one_time and completed:
		return {
			"message": description,
			"objective": "",
		}

	var host: Node = _find_host()
	if host == null or not host.has_method("handle_field_progression_action"):
		return {
			"message": "The field record has no progression host.",
			"objective": "",
		}

	var result_value: Variant = host.call(
		"handle_field_progression_action",
		action_id,
		self
	)
	var result: Dictionary = (
		result_value as Dictionary if result_value is Dictionary else {}
	)
	var should_complete: bool = bool(result.get("completed", one_time))
	if should_complete:
		set_completed(true)
	return result


func set_completed(value: bool) -> void:
	completed = value
	if story_flag != "":
		GameState.set_flag(story_flag, value)
	monitoring = not value or not one_time
	monitorable = not value or not one_time
	visible = not (value and hide_when_complete)
	if label != null and value and not hide_when_complete:
		label.text = visual_icon + "  " + display_name.to_upper() + "\nRECORDED"
		label.modulate = visual_color.darkened(0.18)


func reset_target() -> void:
	transform = initial_transform
	completed = false
	if story_flag != "":
		GameState.set_flag(story_flag, false)
	monitoring = true
	monitorable = true
	visible = true
	if label != null:
		label.text = visual_icon + "  " + display_name.to_upper()
		label.modulate = visual_color


func unlock() -> void:
	visible = true
	monitoring = true
	monitorable = true


func _sync_from_game_state() -> void:
	if story_flag != "" and GameState.get_flag(story_flag):
		set_completed(true)


func _find_host() -> Node:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor.has_method("handle_field_progression_action"):
			return cursor
		cursor = cursor.get_parent()
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("handle_field_progression_action"):
		return current_scene
	return null


func _ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.72
	collision.shape = shape
	collision.position.y = 0.58
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "FieldVisual"
	add_child(visual_root)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.32
	pedestal_mesh.bottom_radius = 0.46
	pedestal_mesh.height = 0.72
	pedestal_mesh.radial_segments = 12
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.36
	pedestal.material_override = _make_material(visual_color.darkened(0.58), 0.25)
	visual_root.add_child(pedestal)

	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.19
	marker_mesh.height = 0.38
	marker.mesh = marker_mesh
	marker.position.y = 0.92
	marker.material_override = _make_material(visual_color, 1.7)
	visual_root.add_child(marker)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.38
	ring_mesh.outer_radius = 0.43
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.position.y = 0.11
	ring.material_override = _make_material(visual_color, 1.15)
	visual_root.add_child(ring)

	label = Label3D.new()
	label.name = "FieldLabel"
	label.position = Vector3(0.0, 1.55, 0.0)
	label.text = visual_icon + "  " + display_name.to_upper()
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = visual_color
	add_child(label)


func _make_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.44
	material.metallic = 0.16
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color.darkened(0.22)
		material.emission_energy_multiplier = emission_energy
	return material


func _process(delta: float) -> void:
	if visual_root != null and not completed:
		visual_root.rotate_y(delta * 0.42)


func get_debug_data() -> Dictionary:
	return {
		"action_id": action_id,
		"display_name": display_name,
		"completed": completed,
		"story_flag": story_flag,
	}
