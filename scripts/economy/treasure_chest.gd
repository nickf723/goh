extends Area3D
class_name TreasureChest

signal chest_opened(chest_id: String, rewards: Dictionary)

@export var chest_id: String = "treasure_chest"
@export var prompt_text: String = "Open treasure chest"
@export var crown_reward: int = 20
@export var item_rewards: Dictionary = {"starlit_gem": 1, "springwater": 2}

var opened: bool = false
var lid: Node3D
var glow: OmniLight3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("lab_resettable")
	build_visual()
	if GameState.has_collected_pickup(chest_id):
		opened = true
		apply_open_visual(false)


func interact() -> Dictionary:
	if opened:
		show_message("The chest is empty.")
		return {}
	open_chest()
	return {}


func open_chest() -> void:
	if opened:
		return
	opened = true
	var rewards: Dictionary = {}
	var crowns: int = GameState.add_currency(crown_reward)
	if crowns > 0:
		rewards["crowns"] = crowns
	for item_id_variant: Variant in item_rewards.keys():
		var item_id: String = str(item_id_variant)
		var granted: int = GameState.add_inventory_item(item_id, int(item_rewards[item_id_variant]))
		if granted > 0:
			rewards[item_id] = granted
	GameState.mark_collected_pickup(chest_id)
	apply_open_visual(true)
	chest_opened.emit(chest_id, rewards.duplicate(true))
	show_message(format_rewards(rewards))


func format_rewards(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	if rewards.has("crowns"):
		parts.append(str(rewards["crowns"]) + " crowns")
	for key_variant: Variant in rewards.keys():
		var item_id: String = str(key_variant)
		if item_id == "crowns":
			continue
		parts.append(str(rewards[key_variant]) + " " + item_id.replace("_", " ").capitalize())
	if parts.is_empty():
		return "The chest was empty."
	return "Treasure: " + ", ".join(parts) + "."


func apply_open_visual(animated: bool) -> void:
	if lid != null:
		if animated:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_BACK)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(lid, "rotation_degrees:x", -105.0, 0.55)
		else:
			lid.rotation_degrees.x = -105.0
	if glow != null:
		glow.light_energy = 2.5 if animated else 0.25
		if animated:
			var glow_tween := create_tween()
			glow_tween.tween_property(glow, "light_energy", 0.25, 1.2)


func reset_target() -> void:
	opened = false
	GameState.clear_collected_pickup(chest_id)
	if lid != null:
		lid.rotation_degrees.x = 0.0
	if glow != null:
		glow.light_energy = 0.0


func build_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.5, 1.5)
	collision.shape = shape
	collision.position.y = 0.75
	add_child(collision)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(2.0, 0.9, 1.3)
	base.mesh = base_mesh
	base.position.y = 0.45
	base.material_override = make_material(Color(0.32, 0.14, 0.045), 0.0)
	add_child(base)
	lid = Node3D.new()
	lid.position = Vector3(0.0, 0.9, -0.56)
	add_child(lid)
	var lid_mesh_instance := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(2.05, 0.38, 1.35)
	lid_mesh_instance.mesh = lid_mesh
	lid_mesh_instance.position = Vector3(0.0, 0.0, 0.56)
	lid_mesh_instance.material_override = make_material(Color(0.38, 0.17, 0.055), 0.0)
	lid.add_child(lid_mesh_instance)
	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.28, 0.42, 1.4)
	band.mesh = band_mesh
	band.position = Vector3(0.0, 0.0, 0.56)
	band.material_override = make_material(Color(0.82, 0.58, 0.12), 0.8)
	lid.add_child(band)
	glow = OmniLight3D.new()
	glow.position = Vector3(0.0, 1.15, 0.0)
	glow.light_color = Color(0.35, 0.8, 1.0)
	glow.omni_range = 5.0
	glow.light_energy = 0.0
	add_child(glow)
	var label := Label3D.new()
	label.text = "TREASURE"
	label.position = Vector3(0.0, 1.85, 0.0)
	label.font_size = 28
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = Color(1.0, 0.82, 0.36)
	add_child(label)


func make_material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.42
	return material


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)
