extends Area3D
class_name WorldItemPickup

@export var item_definition: QuickItemDefinition
@export_range(1, 99, 1) var quantity: int = 1
@export var pickup_id: String = ""
@export var prompt_text: String = "Collect item"
@export var objective_after_pickup: String = ""
@export var resettable_in_lab: bool = false

var collected: bool = false
var initial_transform: Transform3D
var visual_root: Node3D
var label: Label3D


func _ready() -> void:
	initial_transform = transform
	add_to_group("interactable_target")
	add_to_group("world_item_pickup")
	add_to_group("debuggable")
	if resettable_in_lab:
		add_to_group("lab_resettable")
	ensure_collision()
	create_visual()
	if pickup_id != "" and GameState.has_collected_pickup(pickup_id) and not resettable_in_lab:
		set_collected_state(true)


func _process(delta: float) -> void:
	if collected or visual_root == null:
		return
	visual_root.rotate_y(delta * 1.2)
	visual_root.position.y = 0.18 + sin(Time.get_ticks_msec() * 0.003) * 0.05


func interact() -> Dictionary:
	if collected or item_definition == null:
		return {"message": "The supply spot is empty.", "objective": ""}
	var added: int = GameState.add_inventory_item(item_definition.item_id, quantity)
	if added <= 0:
		return {
			"message": item_definition.display_name + " inventory is full.",
			"objective": "",
		}
	if pickup_id != "":
		GameState.mark_collected_pickup(pickup_id)
	set_collected_state(true)
	return {
		"message": "Collected " + item_definition.display_name + " ×" + str(added) + ". Open the Field Kit to assign it.",
		"objective": objective_after_pickup,
	}


func set_collected_state(value: bool) -> void:
	collected = value
	monitoring = not value
	monitorable = not value
	visible = not value


func reset_pickup() -> void:
	if not resettable_in_lab:
		return
	if pickup_id != "":
		GameState.clear_collected_pickup(pickup_id)
	transform = initial_transform
	set_collected_state(false)


func ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	shape_node.shape = shape
	add_child(shape_node)


func create_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "PickupVisual"
	add_child(visual_root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.16
	mesh.height = 0.34
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	var color := item_definition.use_visual_color if item_definition != null else Color(0.5, 0.8, 1.0)
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = color.darkened(0.35)
	material.emission_energy_multiplier = 1.15
	mesh_instance.material_override = material
	visual_root.add_child(mesh_instance)

	var ring_instance := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.23
	ring.outer_radius = 0.27
	ring.rings = 20
	ring.ring_segments = 8
	ring_instance.mesh = ring
	ring_instance.position.y = -0.18
	ring_instance.material_override = material
	visual_root.add_child(ring_instance)

	label = Label3D.new()
	label.position = Vector3(0.0, 0.72, 0.0)
	label.text = (item_definition.display_name if item_definition != null else "Item") + " ×" + str(quantity)
	label.font_size = 32
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	add_child(label)


func get_debug_data() -> Dictionary:
	return {
		"pickup": pickup_id,
		"item": item_definition.item_id if item_definition != null else "none",
		"quantity": quantity,
		"collected": collected,
	}
