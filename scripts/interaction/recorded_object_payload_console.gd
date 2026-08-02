extends Area3D
class_name RecordedObjectPayloadConsole

@export var element: String = "fire"
@export var console_label: String = "FIRE"
@export var payload_amount: int = 3
@export var payload_strength: float = 1.0
@export var knockback_strength: float = 0.0
@export var search_radius: float = 5.5
@export var color: Color = Color(1.0, 0.32, 0.08, 1.0)
@export var extra_tags: Array[String] = []

var label: Label3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("recorded_object_payload_console")
	add_to_group("debuggable")
	_build_collision()
	_build_visual()


func interact() -> Dictionary:
	var target: RecordedObjectInstance = _find_nearest_recorded_object()
	if target == null:
		return {
			"message": console_label + " console: place a recorded object on the interaction pad first.",
			"objective": "Reproduce an object inside the marked test ring.",
		}
	var payload := DamagePayload.new()
	payload.amount = payload_amount
	payload.stance_damage = payload_amount
	payload.element = element
	payload.source_name = "Recorded Object " + console_label.title_case() + " Console"
	payload.hit_type = "environment"
	payload.status_strength = payload_strength
	payload.knockback_strength = knockback_strength
	payload.tags = ["recorded_object_lab", element]
	for tag: String in extra_tags:
		if not payload.tags.has(tag):
			payload.tags.append(tag)
	target.receive_damage_payload(payload)
	return {
		"message": (
			console_label
			+ " applied to "
			+ str(target.definition.get("display_name", target.blueprint_id.capitalize()))
			+ "."
		),
		"objective": "Combine elemental state with the object's physical role.",
	}


func _find_nearest_recorded_object() -> RecordedObjectInstance:
	var nearest: RecordedObjectInstance
	var nearest_distance: float = search_radius
	for node: Node in get_tree().get_nodes_in_group("recorded_object"):
		var object := node as RecordedObjectInstance
		if object == null or not is_instance_valid(object):
			continue
		var distance: float = global_position.distance_to(object.global_position)
		if distance <= nearest_distance:
			nearest = object
			nearest_distance = distance
	return nearest


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 0.75
	shape.height = 1.4
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	var pedestal := MeshInstance3D.new()
	pedestal.name = "ConsolePedestal"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.58
	cylinder.bottom_radius = 0.72
	cylinder.height = 1.0
	cylinder.radial_segments = 18
	pedestal.mesh = cylinder
	pedestal.position.y = 0.5
	pedestal.material_override = _make_material(color.darkened(0.5))
	add_child(pedestal)

	var core := MeshInstance3D.new()
	core.name = "ConsoleCore"
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	core.mesh = sphere
	core.position.y = 1.3
	core.material_override = _make_material(color)
	add_child(core)

	label = Label3D.new()
	label.name = "ConsoleLabel"
	label.text = console_label + "\nAPPLY TO NEAREST OBJECT"
	label.position = Vector3(0.0, 2.25, 0.0)
	label.font_size = 31
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	add_child(label)


func _make_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.35
	material.roughness = 0.42
	material.emission_enabled = true
	material.emission = tint.darkened(0.3)
	material.emission_energy_multiplier = 0.75
	return material


func get_debug_data() -> Dictionary:
	return {
		"element": element,
		"label": console_label,
		"payload_amount": payload_amount,
		"knockback_strength": knockback_strength,
		"search_radius": search_radius,
		"has_target": _find_nearest_recorded_object() != null,
	}
