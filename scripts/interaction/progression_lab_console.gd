extends Area3D
class_name ProgressionLabConsole

@export_enum(
	"refill_supplies",
	"reset_stations",
	"reset_progress",
	"complete_all"
) var action_id: String = "refill_supplies"
@export var display_name: String = "REFILL SUPPLIES"
@export var prompt_text: String = "Use progression lab console"
@export var console_color: Color = Color(0.35, 0.78, 1.0)


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("debuggable")
	_build_visual()


func interact() -> Dictionary:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return {
			"message": "The progression laboratory is not available.",
			"objective": "",
		}
	var method_name: String = _method_for_action()
	if method_name == "" or not scene_root.has_method(method_name):
		return {
			"message": "This console cannot reach its laboratory function.",
			"objective": "",
		}
	var result_value: Variant = scene_root.call(method_name)
	var message: String = display_name.capitalize() + "."
	var objective: String = "Open the Codex to inspect challenge progress."
	if result_value is Dictionary:
		var result: Dictionary = result_value as Dictionary
		message = str(result.get("message", message))
		objective = str(result.get("objective", objective))
	return {
		"message": message,
		"objective": objective,
	}


func get_debug_data() -> Dictionary:
	return {
		"progression_lab_console": action_id,
		"display_name": display_name,
	}


func _method_for_action() -> String:
	match action_id:
		"refill_supplies":
			return "refill_lab_supplies"
		"reset_stations":
			return "reset_lab"
		"reset_progress":
			return "reset_challenge_progress"
		"complete_all":
			return "complete_all_challenges"
	return ""


func _build_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.35, 1.25, 1.0)
	collision.shape = shape
	collision.position.y = 0.62
	add_child(collision)

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.2, 1.05, 0.88)
	base.mesh = base_mesh
	base.position.y = 0.52
	base.material_override = _make_material(console_color.darkened(0.62), 0.15)
	add_child(base)

	var face := MeshInstance3D.new()
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.86, 0.52, 0.08)
	face.mesh = face_mesh
	face.position = Vector3(0.0, 0.78, -0.48)
	face.rotation_degrees.x = -12.0
	face.material_override = _make_material(console_color, 1.6)
	add_child(face)

	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.16
	orb_mesh.height = 0.32
	orb.mesh = orb_mesh
	orb.position = Vector3(0.0, 1.22, 0.0)
	orb.material_override = _make_material(console_color.lightened(0.12), 2.2)
	add_child(orb)

	var label := Label3D.new()
	label.name = "ConsoleLabel"
	label.text = display_name
	label.position = Vector3(0.0, 1.72, 0.0)
	label.font_size = 26
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = console_color.lightened(0.2)
	add_child(label)


func _make_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material
