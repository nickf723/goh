extends Node3D
class_name PrototypeSpectralFamiliarLab

var player: CharacterBody3D
var manager: PlayerSummonManager
var status_label: Label
var plate_label: Label3D
var plate_position := Vector3(7.0, 0.12, -7.0)
var gate: StaticBody3D
var gate_open: bool = false
var target_health: int = 16
var target_body: StaticBody3D
var target_label: Label3D


func _ready() -> void:
	_build_environment()
	_build_lab()
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		manager = player.get_node_or_null("SummonManager") as PlayerSummonManager
	_configure_player()
	_build_hud()
	GameState.set_objective("Cast Call Familiar, command Lumen to hold the plate, then use Assist against the target.")


func _process(_delta: float) -> void:
	_update_plate()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		_reset_lab()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_K and manager != null:
			manager.dismiss_summon(false)
			get_viewport().set_input_as_handled()


func _configure_player() -> void:
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_mana", 50)
	GameState.set_stat("mana", 50)
	GameState.set_stat("max_stamina", 50)
	GameState.set_stat("stamina", 50)
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("select_ability"):
		return
	var loadout_resource: AbilityLoadout = caster.get("loadout") as AbilityLoadout
	if loadout_resource == null:
		return
	for index: int in range(loadout_resource.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout_resource.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == "spectral_familiar":
			caster.call("select_ability", index)
			break


func _reset_lab() -> void:
	if manager != null:
		manager.reset_summons()
	if player != null:
		player.global_position = Vector3(0, 1.1, 10)
		player.velocity = Vector3.ZERO
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	target_health = 16
	gate_open = false
	if gate != null:
		gate.position.y = 1.5
	_update_target_label()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.025, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.28, 0.45, 0.72)
	environment.ambient_light_energy = 0.92
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.82
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -22, 0)
	sun.light_color = Color(0.58, 0.8, 1.0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	add_child(sun)


func _build_lab() -> void:
	_add_box_body("Ground", Vector3(24, 0.6, 42), Vector3(0, -0.3, -7), Color(0.1, 0.13, 0.2))
	_add_box_body("DividerLeft", Vector3(0.6, 3.2, 16), Vector3(-5.5, 1.6, -8), Color(0.16, 0.22, 0.32))
	_add_box_body("DividerRight", Vector3(0.6, 3.2, 16), Vector3(5.5, 1.6, -8), Color(0.16, 0.22, 0.32))
	gate = _add_box_body("SoulGate", Vector3(5.0, 3.0, 0.6), Vector3(0, 1.5, -9), Color(0.35, 0.18, 0.58))
	_build_plate()
	_build_target()
	_add_label("SPECTRAL FAMILIAR LAB", Vector3(0, 5.5, 8), Color(0.55, 0.88, 1.0), 38)
	_add_label("CAST SUMMONS / RECALLS  •  TAP D-PAD DOWN CYCLES  •  HOLD FOR COMMANDS  •  K DISMISSES  •  F8 RESET", Vector3(0, 4.7, 8), Color(0.84, 0.92, 1.0), 17)
	_add_label("STAY ON THE PLATE", Vector3(7, 2.2, -7), Color(0.58, 0.9, 1.0), 23)
	_add_label("ASSIST TARGET", Vector3(-7, 3.2, -16), Color(0.76, 0.48, 1.0), 23)


func _build_plate() -> void:
	var plate := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.25
	mesh.bottom_radius = 1.25
	mesh.height = 0.16
	plate.mesh = mesh
	plate.position = plate_position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.46, 0.72)
	material.emission_enabled = true
	material.emission = Color(0.18, 0.66, 1.0)
	material.emission_energy_multiplier = 1.5
	plate.material_override = material
	add_child(plate)
	plate_label = Label3D.new()
	plate_label.position = plate_position + Vector3.UP * 0.55
	plate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate_label.font_size = 22
	plate_label.pixel_size = 0.007
	plate_label.outline_size = 6
	add_child(plate_label)


func _build_target() -> void:
	target_body = _add_box_body("FamiliarTarget", Vector3(1.5, 2.4, 1.5), Vector3(-7, 1.2, -16), Color(0.42, 0.18, 0.58))
	target_body.add_to_group("enemy")
	target_body.add_to_group("combat_targetable")
	target_body.set_script(load("res://scripts/levels/spectral_familiar_lab_target.gd"))
	target_label = Label3D.new()
	target_label.position = Vector3(-7, 3.2, -16)
	target_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	target_label.font_size = 20
	target_label.pixel_size = 0.007
	target_label.outline_size = 6
	add_child(target_label)
	call_deferred("_bind_target")


func _bind_target() -> void:
	if target_body != null:
		target_body.set("lab", self)
		target_body.set("health", target_health)
	_update_target_label()


func receive_target_hit(damage: int) -> Dictionary:
	target_health = maxi(target_health - damage, 0)
	if target_body != null:
		target_body.set("health", target_health)
	_update_target_label()
	return {"message": "Familiar target hit. Health " + str(target_health) + "/16", "objective": ""}


func _update_target_label() -> void:
	if target_label != null:
		target_label.text = "FAMILIAR TARGET\n" + str(target_health) + "/16"


func _update_plate() -> void:
	var occupied: bool = false
	if manager != null:
		var familiar: SpectralFamiliar = manager.get_active_summon()
		occupied = familiar != null and familiar.global_position.distance_to(plate_position) <= 1.45
	if plate_label != null:
		plate_label.text = "ACTIVE" if occupied else "WAITING"
		plate_label.modulate = Color(0.45, 1.0, 0.72) if occupied else Color(0.55, 0.78, 1.0)
	if occupied != gate_open:
		gate_open = occupied
		if gate != null:
			var tween := gate.create_tween()
			tween.tween_property(gate, "position:y", -1.7 if gate_open else 1.5, 0.45)


func _add_box_body(body_name: String, size: Vector3, position: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.28
	material.roughness = 0.52
	material.emission_enabled = true
	material.emission = color.darkened(0.2)
	material.emission_energy_multiplier = 0.35
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	return body


func _add_label(text: String, position: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.pixel_size = 0.008
	label.outline_size = 7
	label.modulate = color
	add_child(label)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(610, 94)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.022, 0.052, 0.9)
	style.border_color = Color(0.38, 0.76, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	panel.add_child(status_label)


func _update_hud() -> void:
	if status_label == null or manager == null:
		return
	var data: Dictionary = manager.get_debug_data()
	var familiar: SpectralFamiliar = manager.get_active_summon()
	var familiar_data: Dictionary = familiar.get_debug_data() if familiar != null else {}
	status_label.text = (
		"SUMMON  •  " + str(data.get("summon", "none"))
		+ "     COMMAND " + str(data.get("command", "NONE"))
		+ "     COOLDOWN " + str(data.get("cooldown", 0.0)) + "s"
		+ "\nHEALTH " + str(familiar_data.get("health", 0)) + "/" + str(familiar_data.get("maximum_health", 0))
		+ "     TARGET " + str(familiar_data.get("target", "none"))
		+ "     MANA " + str(GameState.get_stat("mana")) + "/" + str(GameState.get_stat("max_mana"))
		+ "     GATE " + ("OPEN" if gate_open else "CLOSED")
	)
