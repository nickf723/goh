extends Area3D
class_name RewardChoiceChest

signal reward_chosen(item_id: String, quantity: int)

@export var option_a: QuickItemDefinition
@export var option_b: QuickItemDefinition
@export var option_c: QuickItemDefinition
@export_range(1, 9, 1) var option_a_quantity: int = 2
@export_range(1, 9, 1) var option_b_quantity: int = 2
@export_range(1, 9, 1) var option_c_quantity: int = 1
@export var starts_locked: bool = true
@export var resettable_in_lab: bool = true

var locked: bool = true
var opened: bool = false
var claimed: bool = false
var choice_pickups: Array[WorldItemPickup] = []
var lid_pivot: Node3D
var state_label: Label3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("reward_choice_chest")
	add_to_group("debuggable")
	if resettable_in_lab:
		add_to_group("lab_resettable")
	ensure_collision()
	create_visual()
	reset_chest()


func interact() -> Dictionary:
	if locked:
		return {
			"message": "The reward chest is sealed. Finish the encounter first.",
			"objective": "Defeat the remaining enemies.",
		}
	if claimed:
		return {"message": "The reward chest is empty.", "objective": ""}
	if opened:
		return {
			"message": "Choose one of the three revealed supplies.",
			"objective": "Collect one reward.",
		}

	opened = true
	if lid_pivot != null:
		lid_pivot.rotation_degrees.x = -62.0
	spawn_choices()
	refresh_visual()
	return {
		"message": "REWARD REVEALED — choose one supply cache.",
		"objective": "Choose Oil, Noise Makers, or a Healing Flask.",
	}


func unlock_chest() -> void:
	if claimed:
		return
	locked = false
	refresh_visual()


func spawn_choices() -> void:
	clear_choices()
	var options: Array[Dictionary] = get_options()
	var offsets: Array[Vector3] = [
		Vector3(-2.2, 0.55, -1.35),
		Vector3(0.0, 0.55, -1.7),
		Vector3(2.2, 0.55, -1.35),
	]
	var world_parent: Node = get_parent()
	if world_parent == null:
		world_parent = get_tree().current_scene

	for index: int in range(options.size()):
		var option: Dictionary = options[index]
		var item: QuickItemDefinition = option.get("item") as QuickItemDefinition
		if item == null:
			continue
		var pickup: WorldItemPickup = preload("res://scenes/items/world_item_pickup.tscn").instantiate() as WorldItemPickup
		pickup.name = "RewardChoice" + str(index + 1)
		pickup.item_definition = item
		pickup.quantity = int(option.get("quantity", 1))
		pickup.prompt_text = "Choose " + item.display_name
		pickup.runtime_drop = true
		pickup.free_after_collect = true
		pickup.attract_to_player = false
		pickup.auto_collect_when_near = false
		pickup.item_collected.connect(_on_choice_collected)
		pickup.add_to_group("reward_choice_pickup")
		world_parent.add_child(pickup)
		pickup.global_position = global_transform * offsets[index]
		choice_pickups.append(pickup)


func get_options() -> Array[Dictionary]:
	return [
		{"item": option_a, "quantity": option_a_quantity},
		{"item": option_b, "quantity": option_b_quantity},
		{"item": option_c, "quantity": option_c_quantity},
	]


func _on_choice_collected(item_id: String, quantity: int, chosen_pickup: WorldItemPickup) -> void:
	if claimed:
		return
	claimed = true
	for pickup: WorldItemPickup in choice_pickups:
		if is_instance_valid(pickup) and pickup != chosen_pickup:
			pickup.queue_free()
	choice_pickups.clear()
	refresh_visual()
	reward_chosen.emit(item_id, quantity)
	show_message("REWARD CLAIMED — " + item_id.replace("_", " ").capitalize() + " ×" + str(quantity) + ".")


func clear_choices() -> void:
	for pickup: WorldItemPickup in choice_pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	choice_pickups.clear()


func reset_chest() -> void:
	clear_choices()
	locked = starts_locked
	opened = false
	claimed = false
	if lid_pivot != null:
		lid_pivot.rotation_degrees.x = 0.0
	refresh_visual()


func ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.8, 1.25, 1.2)
	collision.shape = shape
	collision.position.y = 0.62
	add_child(collision)


func create_visual() -> void:
	var gold: StandardMaterial3D = make_material(Color(0.82, 0.48, 0.08), true)
	var dark: StandardMaterial3D = make_material(Color(0.12, 0.065, 0.035), false)

	var base_mesh: MeshInstance3D = MeshInstance3D.new()
	base_mesh.name = "ChestBase"
	var base_box: BoxMesh = BoxMesh.new()
	base_box.size = Vector3(1.8, 0.75, 1.2)
	base_mesh.mesh = base_box
	base_mesh.position.y = 0.38
	base_mesh.material_override = dark
	add_child(base_mesh)

	var band_mesh: MeshInstance3D = MeshInstance3D.new()
	var band_box: BoxMesh = BoxMesh.new()
	band_box.size = Vector3(0.28, 0.82, 1.24)
	band_mesh.mesh = band_box
	band_mesh.position.y = 0.42
	band_mesh.material_override = gold
	add_child(band_mesh)

	lid_pivot = Node3D.new()
	lid_pivot.name = "LidPivot"
	lid_pivot.position = Vector3(0.0, 0.78, 0.48)
	add_child(lid_pivot)
	var lid_mesh: MeshInstance3D = MeshInstance3D.new()
	var lid_box: BoxMesh = BoxMesh.new()
	lid_box.size = Vector3(1.86, 0.34, 1.24)
	lid_mesh.mesh = lid_box
	lid_mesh.position = Vector3(0.0, 0.12, -0.48)
	lid_mesh.material_override = gold
	lid_pivot.add_child(lid_mesh)

	state_label = Label3D.new()
	state_label.position = Vector3(0.0, 1.75, 0.0)
	state_label.font_size = 34
	state_label.pixel_size = 0.008
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.outline_size = 7
	state_label.modulate = Color(1.0, 0.72, 0.2)
	add_child(state_label)


func make_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.75
	material.roughness = 0.26
	if emissive:
		material.emission_enabled = true
		material.emission = color.darkened(0.35)
		material.emission_energy_multiplier = 1.3
	return material


func refresh_visual() -> void:
	if state_label == null:
		return
	if claimed:
		state_label.text = "REWARD CLAIMED"
	elif locked:
		state_label.text = "REWARD LOCKED"
	elif opened:
		state_label.text = "CHOOSE ONE"
	else:
		state_label.text = "OPEN REWARD"


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


func get_debug_data() -> Dictionary:
	return {
		"locked": locked,
		"opened": opened,
		"claimed": claimed,
		"choices": choice_pickups.size(),
	}
