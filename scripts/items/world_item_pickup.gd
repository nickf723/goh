extends Area3D
class_name WorldItemPickup

signal item_collected(item_id: String, quantity: int, pickup: WorldItemPickup)

@export var item_definition: QuickItemDefinition
@export_range(1, 99, 1) var quantity: int = 1
@export var pickup_id: String = ""
@export var prompt_text: String = "Collect item"
@export var objective_after_pickup: String = ""
@export var resettable_in_lab: bool = false

@export_group("Runtime Drop")
@export var runtime_drop: bool = false
@export var free_after_collect: bool = false
@export var attract_to_player: bool = false
@export var auto_collect_when_near: bool = false
@export_range(0.0, 3.0, 0.05) var attraction_delay: float = 0.35
@export_range(0.5, 20.0, 0.25) var attraction_speed: float = 6.5
@export_range(0.2, 2.0, 0.05) var auto_collect_distance: float = 0.8

var collected: bool = false
var initial_transform: Transform3D
var visual_root: Node3D
var label: Label3D
var drop_age: float = 0.0
var player_target: Node3D
var waiting_for_inventory_space: bool = false
var resume_attraction_after_space: bool = false


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
	drop_age += delta
	if attract_to_player or auto_collect_when_near:
		process_runtime_drop(delta)


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
	item_collected.emit(item_definition.item_id, added, self)
	return {
		"message": "Collected " + item_definition.display_name + " ×" + str(added) + ". Open the Field Kit to assign it.",
		"objective": objective_after_pickup,
	}


func set_collected_state(value: bool) -> void:
	collected = value
	monitoring = not value
	monitorable = not value
	visible = not value
	if value and free_after_collect:
		call_deferred("queue_free")


func reset_pickup() -> void:
	if not resettable_in_lab:
		return
	if pickup_id != "":
		GameState.clear_collected_pickup(pickup_id)
	transform = initial_transform
	drop_age = 0.0
	player_target = null
	waiting_for_inventory_space = false
	resume_attraction_after_space = false
	restore_label_text()
	set_collected_state(false)


func process_runtime_drop(delta: float) -> void:
	if drop_age < attraction_delay:
		return
	if player_target == null or not is_instance_valid(player_target):
		player_target = resolve_player_target()
	if player_target == null:
		return

	if waiting_for_inventory_space:
		if not has_inventory_space():
			return
		waiting_for_inventory_space = false
		attract_to_player = resume_attraction_after_space
		restore_label_text()

	var target_position: Vector3 = player_target.global_position + Vector3.UP * 0.55
	var distance: float = global_position.distance_to(target_position)
	if auto_collect_when_near and distance <= auto_collect_distance:
		var result: Dictionary = interact()
		if collected:
			show_auto_collect_message(str(result.get("message", "")))
		else:
			settle_beside_player()
		return
	if attract_to_player:
		global_position = global_position.move_toward(target_position, attraction_speed * delta)


func has_inventory_space() -> bool:
	if item_definition == null:
		return false
	return GameState.get_inventory_count(item_definition.item_id) < maxi(item_definition.max_stack, 1)


func settle_beside_player() -> void:
	if player_target == null:
		return
	waiting_for_inventory_space = true
	resume_attraction_after_space = attract_to_player
	attract_to_player = false
	var away: Vector3 = global_position - player_target.global_position
	away.y = 0.0
	if away.length_squared() <= 0.01:
		var angle: float = float(get_instance_id() % 360) * PI / 180.0
		away = Vector3(cos(angle), 0.0, sin(angle))
	away = away.normalized()
	global_position = player_target.global_position + away * 1.2 + Vector3.UP * 0.35
	if label != null:
		label.text = (item_definition.display_name if item_definition != null else "Item") + " ×" + str(quantity) + "\nINVENTORY FULL"
		label.modulate = Color(1.0, 0.5, 0.22)


func restore_label_text() -> void:
	if label == null:
		return
	var color: Color = item_definition.use_visual_color if item_definition != null else Color(0.5, 0.8, 1.0)
	label.text = (item_definition.display_name if item_definition != null else "Item") + " ×" + str(quantity)
	label.modulate = color


func resolve_player_target() -> Node3D:
	var grouped_player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if grouped_player != null:
		return grouped_player
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		return current_scene.find_child("Player", true, false) as Node3D
	return null


func show_auto_collect_message(message: String) -> void:
	if message == "":
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


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
		"runtime_drop": runtime_drop,
		"attracting": attract_to_player,
		"auto_collect": auto_collect_when_near,
		"waiting_for_inventory_space": waiting_for_inventory_space,
	}
