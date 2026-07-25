extends Area3D
class_name EquipmentRewardChest

signal equipment_claimed(item_id: String)

const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")

@export var chest_id: String = "equipment_reward_chest"
@export var equipment_id: String = "resonance_charm"
@export var prompt_text: String = "Open equipment chest"

var opened: bool = false
var lid: Node3D
var glow: OmniLight3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("lab_resettable")
	build_visual()
	if GameState.get_flag("equipment_chest_" + chest_id) or GameState.owns_equipment(equipment_id):
		opened = true
		apply_open_visual(false)


func interact() -> Dictionary:
	if opened:
		show_message("The equipment chest is empty.")
		return {}
	if not EquipmentCatalogScript.has_item(equipment_id):
		show_message("The chest's equipment definition is missing.")
		return {}
	if not GameState.grant_equipment(equipment_id):
		show_message("Grace already owns " + EquipmentCatalogScript.get_display_name(equipment_id) + ".")
		opened = true
		apply_open_visual(false)
		return {}
	opened = true
	GameState.set_flag("equipment_chest_" + chest_id, true)
	apply_open_visual(true)
	equipment_claimed.emit(equipment_id)
	show_message("Found " + EquipmentCatalogScript.get_display_name(equipment_id) + "! Visit the Outfitter to equip it.")
	return {}


func reset_target() -> void:
	if GameState.owns_equipment(equipment_id):
		return
	opened = false
	GameState.set_flag("equipment_chest_" + chest_id, false)
	if lid != null:
		lid.rotation_degrees.x = 0.0
	if glow != null:
		glow.light_energy = 0.0


func apply_open_visual(animated: bool) -> void:
	if lid != null:
		if animated:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_BACK)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(lid, "rotation_degrees:x", -105.0, 0.5)
		else:
			lid.rotation_degrees.x = -105.0
	if glow != null:
		glow.light_energy = 2.4 if animated else 0.2
		if animated:
			var glow_tween := create_tween()
			glow_tween.tween_property(glow, "light_energy", 0.2, 1.0)


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
	base.material_override = make_material(Color(0.12, 0.25, 0.3), 0.25)
	add_child(base)
	lid = Node3D.new()
	lid.position = Vector3(0.0, 0.9, -0.56)
	add_child(lid)
	var lid_part := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(2.05, 0.38, 1.35)
	lid_part.mesh = lid_mesh
	lid_part.position = Vector3(0.0, 0.0, 0.56)
	lid_part.material_override = make_material(Color(0.14, 0.32, 0.38), 0.35)
	lid.add_child(lid_part)
	glow = OmniLight3D.new()
	glow.position = Vector3(0.0, 1.15, 0.0)
	glow.light_color = Color(0.42, 0.85, 1.0)
	glow.omni_range = 5.0
	glow.light_energy = 0.0
	add_child(glow)
	var label := Label3D.new()
	label.text = EquipmentCatalogScript.get_display_name(equipment_id).to_upper()
	label.position = Vector3(0.0, 1.85, 0.0)
	label.font_size = 27
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = Color(0.58, 0.94, 1.0)
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
