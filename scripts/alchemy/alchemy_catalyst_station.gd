extends Area3D
class_name AlchemyCatalystStation

@export_enum("fire", "air", "ice", "water", "lightning") var element: String = "fire"
@export var prompt_text: String = "Prepare cauldron"
@export var display_name: String = "Fire Treatment"
@export var station_color: Color = Color(1.0, 0.3, 0.08)


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("alchemy_catalyst_station")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	collision.shape = shape
	collision.position.y = 0.55
	add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.46
	mesh.height = 0.7
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.45
	var material := StandardMaterial3D.new()
	material.albedo_color = station_color
	material.emission_enabled = true
	material.emission = station_color.darkened(0.28)
	material.emission_energy_multiplier = 1.1
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var label := Label3D.new()
	label.text = display_name + "\n" + element.to_upper()
	label.position = Vector3(0.0, 1.35, 0.0)
	label.font_size = 22
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = station_color
	add_child(label)


func interact() -> Dictionary:
	var cauldron: Node = get_tree().get_first_node_in_group("alchemy_cauldron")
	if cauldron == null or not cauldron.has_method("apply_element"):
		return {"message": "No cauldron is ready for treatment.", "objective": ""}
	cauldron.call("apply_element", element)
	return {
		"message": display_name + " applied to the cauldron.",
		"objective": "Combine two ingredients and brew the treated mixture.",
	}
