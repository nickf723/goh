extends Area3D
class_name StealthObjective

@export var prompt_text: String = "Steal patrol plans"
@export var objective_flag: String = "stealth_lab_plans_stolen"
@export var require_crouch_or_concealment: bool = true
var completed: bool = false


func _ready() -> void:
	add_to_group("interactable_target")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	collision.shape = shape
	collision.position.y = 0.55
	add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.18, 0.5)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.45
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.72, 0.2)
	material.emission_enabled = true
	material.emission = Color(0.65, 0.35, 0.05)
	material.emission_energy_multiplier = 1.1
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var label := Label3D.new()
	label.text = "PATROL PLANS"
	label.position = Vector3(0.0, 1.25, 0.0)
	label.font_size = 25
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = Color(1.0, 0.82, 0.34)
	add_child(label)


func interact() -> Dictionary:
	if completed:
		return {"message": "Grace already has the patrol plans.", "objective": ""}
	var player: Node = get_tree().get_first_node_in_group("player")
	var stealth: Node = player.get_node_or_null("StealthController") if player != null else null
	if require_crouch_or_concealment and stealth != null:
		if not bool(stealth.call("is_crouched")) and not bool(stealth.call("is_concealed")):
			return {
				"message": "Grace is too exposed to steal the plans cleanly. Crouch or use concealment.",
				"objective": "Reach the patrol plans while crouched or concealed.",
			}
	completed = true
	GameState.set_flag(objective_flag, true)
	visible = false
	monitoring = false
	monitorable = false
	return {
		"message": "Patrol plans stolen without raising the camp alarm.",
		"objective": "Escape back through the moonlit gate.",
	}
