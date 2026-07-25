extends Node3D
class_name PrototypeEquipmentOutfitterLab

const OutfitterScript = preload("res://scripts/equipment/equipment_outfitter.gd")
const EquipmentChestScript = preload("res://scripts/equipment/equipment_reward_chest.gd")


func _ready() -> void:
	Engine.time_scale = 1.0
	build_environment()
	build_room()
	configure_equipment_trial()
	build_outfitter()
	build_reward_chest()
	GameState.set_objective("Buy equipment, compare its effects, equip a loadout, and test the weapon.")
	show_message("Outfitter ready. The chest contains a Charm; the shop carries weapons, outfits, and relics.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene") and OS.has_feature("editor"):
		reset_equipment_lab()
		get_viewport().set_input_as_handled()


func configure_equipment_trial() -> void:
	GameState.reset_stats_to_defaults(false)
	GameState.reset_equipment_to_defaults(true)
	GameState.set_currency(180)
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))
	GameState.set_flag("equipment_chest_outfitter_charm", false)


func reset_equipment_lab() -> void:
	configure_equipment_trial()
	get_tree().reload_current_scene()


func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.055, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.54, 0.65, 0.72)
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	sun.light_color = Color(1.0, 0.84, 0.62)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func build_room() -> void:
	create_static_box("OutfitterFloor", Vector3(0.0, -0.55, 0.0), Vector3(30.0, 1.0, 30.0), Color(0.16, 0.19, 0.2))
	create_static_box("BackWall", Vector3(0.0, 3.0, -15.0), Vector3(30.0, 6.0, 0.6), Color(0.08, 0.12, 0.15))
	create_static_box("LeftWall", Vector3(-15.0, 3.0, 0.0), Vector3(0.6, 6.0, 30.0), Color(0.08, 0.12, 0.15))
	create_static_box("RightWall", Vector3(15.0, 3.0, 0.0), Vector3(0.6, 6.0, 30.0), Color(0.08, 0.12, 0.15))
	var runway := MeshInstance3D.new()
	var runway_mesh := BoxMesh.new()
	runway_mesh.size = Vector3(5.0, 0.04, 16.0)
	runway.mesh = runway_mesh
	runway.position = Vector3(0.0, 0.03, 2.0)
	runway.material_override = make_material(Color(0.08, 0.35, 0.42), 0.0)
	add_child(runway)
	var title := make_label("ADVENTURER'S OUTFITTER", Vector3(0.0, 5.7, -14.6), Color(0.64, 0.94, 1.0), 47)
	add_child(title)
	var hint := make_label("OWN IT • COMPARE IT • EQUIP IT • TEST IT", Vector3(0.0, 4.55, -14.55), Color(1.0, 0.82, 0.36), 26)
	add_child(hint)
	var combat_hint := make_label("WEAPON TEST FLOOR", Vector3(0.0, 2.0, 10.0), Color(0.5, 0.82, 0.9), 24)
	add_child(combat_hint)


func build_outfitter() -> void:
	var outfitter := Area3D.new()
	outfitter.name = "WayfarersWardrobe"
	outfitter.position = Vector3(0.0, 0.0, -9.5)
	outfitter.set_script(OutfitterScript)
	add_child(outfitter)


func build_reward_chest() -> void:
	var chest := Area3D.new()
	chest.name = "ResonanceCharmChest"
	chest.position = Vector3(-7.0, 0.0, -3.0)
	chest.rotation_degrees.y = 18.0
	chest.set_script(EquipmentChestScript)
	chest.set("chest_id", "outfitter_charm")
	chest.set("equipment_id", "resonance_charm")
	add_child(chest)


func create_static_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color, 0.0)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func make_material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.67
	return material


func make_label(text: String, position: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
