extends "res://scripts/levels/prototype_ruined_village_field_progression_objects.gd"
class_name PrototypeRuinedVillageFamiliarUtility

const FamiliarTaskReceiverScript: Script = preload(
	"res://scripts/summons/familiar_task_receiver.gd"
)

const UTILITY_TASK_PREFIX: String = "ruined_village_familiar_utility:"

var familiar_utility_root: Node3D
var waykeeper_gate: StaticBody3D
var waykeeper_plate: FamiliarTaskReceiver
var ram_barricade: StaticBody3D
var ram_receiver: FamiliarTaskReceiver
var forage_cache: Node3D
var forage_receiver: FamiliarTaskReceiver


func _ready() -> void:
	await super._ready()
	_build_familiar_utility_route()


func _build_familiar_utility_route() -> void:
	if get_node_or_null("FieldProgression/FamiliarUtilityRoute") != null:
		return
	familiar_utility_root = Node3D.new()
	familiar_utility_root.name = "FamiliarUtilityRoute"
	field_root.add_child(familiar_utility_root)

	_build_waykeeper_plate()
	_build_ram_barricade()
	_build_forage_patch()

	var route_label := Label3D.new()
	route_label.name = "FamiliarUtilityRouteLabel"
	route_label.position = Vector3(-3.5, 7.1, 9.0)
	route_label.text = "FAMILIAR UTILITY ROUTE\nAim Go There at marked objects"
	route_label.font_size = 25
	route_label.pixel_size = 0.0062
	route_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	route_label.outline_size = 7
	route_label.modulate = Color(0.52, 1.0, 0.78)
	familiar_utility_root.add_child(route_label)


func _build_waykeeper_plate() -> void:
	waykeeper_gate = _create_utility_box(
		"WaykeeperGate",
		Vector3(-3.5, 4.45, 4.0),
		Vector3(5.8, 2.8, 0.55),
		Color(0.28, 0.22, 0.14)
	)
	_create_utility_box(
		"WaykeeperPlateVisual",
		Vector3(-3.5, 3.18, 9.0),
		Vector3(2.1, 0.16, 2.1),
		Color(0.28, 0.82, 0.62),
		false
	)
	waykeeper_plate = FamiliarTaskReceiverScript.new() as FamiliarTaskReceiver
	waykeeper_plate.name = "WaykeeperPlate"
	waykeeper_plate.position = Vector3(-3.5, 3.25, 9.0)
	waykeeper_plate.task_id = "hold"
	waykeeper_plate.task_key = UTILITY_TASK_PREFIX + "waykeeper_plate"
	waykeeper_plate.display_name = "Waykeeper Plate"
	waykeeper_plate.action_label = "Hold Pressure Plate"
	waykeeper_plate.description = "Keep the familiar on the plate to hold the gate open."
	waykeeper_plate.capability_tag = "hold"
	waykeeper_plate.persist_completion = false
	waykeeper_plate.interaction_radius = 1.35
	waykeeper_plate.accent_color = Color(0.32, 1.0, 0.72)
	waykeeper_plate.task_state_changed.connect(_on_waykeeper_plate_state_changed)
	familiar_utility_root.add_child(waykeeper_plate)


func _build_ram_barricade() -> void:
	ram_barricade = _create_utility_box(
		"RamBarricade",
		Vector3(8.6, 7.35, -39.2),
		Vector3(5.6, 2.5, 0.9),
		Color(0.42, 0.2, 0.08)
	)
	for index: int in range(3):
		var timber := MeshInstance3D.new()
		timber.name = "CrossTimber" + str(index + 1)
		var timber_mesh := BoxMesh.new()
		timber_mesh.size = Vector3(5.8, 0.34, 0.34)
		timber.mesh = timber_mesh
		timber.position = Vector3(0.0, float(index - 1) * 0.62, 0.0)
		timber.rotation_degrees.z = -18.0 + float(index) * 18.0
		var timber_material := StandardMaterial3D.new()
		timber_material.albedo_color = Color(0.5, 0.26, 0.1)
		timber_material.roughness = 0.9
		timber.material_override = timber_material
		ram_barricade.add_child(timber)

	ram_receiver = FamiliarTaskReceiverScript.new() as FamiliarTaskReceiver
	ram_receiver.name = "RamBarricadeTask"
	ram_receiver.position = Vector3(8.6, 6.35, -37.9)
	ram_receiver.task_id = "ram"
	ram_receiver.task_key = UTILITY_TASK_PREFIX + "ram_barricade"
	ram_receiver.display_name = "Collapsed Timber"
	ram_receiver.action_label = "Ram Barricade"
	ram_receiver.description = "A sturdy familiar can smash the weakened timber apart."
	ram_receiver.capability_tag = "ram"
	ram_receiver.one_shot = true
	ram_receiver.persist_completion = true
	ram_receiver.affected_node_path = NodePath("../RamBarricade")
	ram_receiver.accent_color = Color(1.0, 0.48, 0.18)
	familiar_utility_root.add_child(ram_receiver)


func _build_forage_patch() -> void:
	var brush := Node3D.new()
	brush.name = "ForageBrushVisual"
	brush.position = Vector3(-17.2, 3.18, 16.2)
	familiar_utility_root.add_child(brush)
	for index: int in range(7):
		var leaf := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.42 + float(index % 3) * 0.08
		leaf_mesh.height = leaf_mesh.radius * 1.35
		leaf.mesh = leaf_mesh
		leaf.position = Vector3(
			float(index % 3 - 1) * 0.55,
			0.35 + float(index % 2) * 0.2,
			float(index / 3 - 1) * 0.48
		)
		var leaf_material := StandardMaterial3D.new()
		leaf_material.albedo_color = Color(0.18, 0.48 + float(index % 2) * 0.1, 0.2)
		leaf_material.roughness = 0.92
		leaf.material_override = leaf_material
		brush.add_child(leaf)

	forage_cache = Node3D.new()
	forage_cache.name = "ForageCache"
	forage_cache.position = Vector3(-17.2, 3.22, 14.6)
	forage_cache.visible = false
	familiar_utility_root.add_child(forage_cache)
	var cache_mesh := MeshInstance3D.new()
	var cache_shape := CylinderMesh.new()
	cache_shape.top_radius = 0.65
	cache_shape.bottom_radius = 0.8
	cache_shape.height = 0.45
	cache_mesh.mesh = cache_shape
	var cache_material := StandardMaterial3D.new()
	cache_material.albedo_color = Color(0.72, 0.48, 0.16)
	cache_material.emission_enabled = true
	cache_material.emission = Color(0.24, 0.82, 0.32)
	cache_material.emission_energy_multiplier = 1.1
	cache_mesh.material_override = cache_material
	forage_cache.add_child(cache_mesh)

	forage_receiver = FamiliarTaskReceiverScript.new() as FamiliarTaskReceiver
	forage_receiver.name = "ForageHerbBed"
	forage_receiver.position = Vector3(-17.2, 3.25, 16.2)
	forage_receiver.task_id = "forage"
	forage_receiver.task_key = UTILITY_TASK_PREFIX + "forage_herb_bed"
	forage_receiver.display_name = "Overgrown Herb Bed"
	forage_receiver.action_label = "Search Brush"
	forage_receiver.description = "A familiar can scent out useful plants hidden beneath the overgrowth."
	forage_receiver.capability_tag = "forage"
	forage_receiver.one_shot = true
	forage_receiver.persist_completion = true
	forage_receiver.reward_item_id = "life_bloom"
	forage_receiver.reward_amount = 2
	forage_receiver.revealed_node_path = NodePath("../ForageCache")
	forage_receiver.accent_color = Color(0.45, 1.0, 0.38)
	familiar_utility_root.add_child(forage_receiver)


func _on_waykeeper_plate_state_changed(_task_id: String, state: String) -> void:
	_set_utility_node_enabled(waykeeper_gate, state != "active")


func _set_utility_node_enabled(node: Node, enabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is Node3D:
		(node as Node3D).visible = enabled
	if node is CollisionObject3D:
		var collision := node as CollisionObject3D
		if not collision.has_meta("utility_original_layer"):
			collision.set_meta("utility_original_layer", collision.collision_layer)
			collision.set_meta("utility_original_mask", collision.collision_mask)
		collision.collision_layer = int(collision.get_meta("utility_original_layer", 1)) if enabled else 0
		collision.collision_mask = int(collision.get_meta("utility_original_mask", 1)) if enabled else 0


func _create_utility_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color,
	with_collision: bool = true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1 if with_collision else 0
	body.collision_mask = 1 if with_collision else 0
	familiar_utility_root.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	if with_collision:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_value
		collision.shape = shape
		body.add_child(collision)
	return body


func get_familiar_utility_receiver(task_name: String) -> FamiliarTaskReceiver:
	match task_name.to_lower().strip_edges():
		"hold", "plate", "waykeeper":
			return waykeeper_plate
		"ram", "barricade":
			return ram_receiver
		"forage", "brush":
			return forage_receiver
		_:
			return null


func reset_familiar_utility_route() -> void:
	var receivers: Array[FamiliarTaskReceiver] = [
		waykeeper_plate,
		ram_receiver,
		forage_receiver,
	]
	for receiver: FamiliarTaskReceiver in receivers:
		if receiver != null and is_instance_valid(receiver):
			receiver.reset_task(true)
	_set_utility_node_enabled(waykeeper_gate, true)
	_set_utility_node_enabled(ram_barricade, true)
	if forage_cache != null:
		forage_cache.visible = false


func get_field_progression_debug_data() -> Dictionary:
	var data: Dictionary = super.get_field_progression_debug_data()
	data["familiar_utility_route"] = familiar_utility_root != null
	data["familiar_utility_tasks"] = {
		"hold": waykeeper_plate.get_task_debug_data() if waykeeper_plate != null else {},
		"ram": ram_receiver.get_task_debug_data() if ram_receiver != null else {},
		"forage": forage_receiver.get_task_debug_data() if forage_receiver != null else {},
	}
	data["waykeeper_gate_open"] = waykeeper_gate != null and not waykeeper_gate.visible
	data["ram_barricade_cleared"] = ram_barricade != null and not ram_barricade.visible
	data["forage_cache_revealed"] = forage_cache != null and forage_cache.visible
	return data
