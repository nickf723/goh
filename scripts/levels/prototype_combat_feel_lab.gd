extends Node3D
class_name PrototypeCombatFeelLab

var player: CharacterBody3D
var weapon_controller: WeaponController
var dummy: CombatFeelDummy
var status_label: Label
var hitboxes_visible: bool = false


func _ready() -> void:
	_build_environment()
	_build_arena()
	player = get_node_or_null("Player") as CharacterBody3D
	dummy = get_node_or_null("CombatFeelDummy") as CombatFeelDummy
	_configure_player()
	_build_hud()
	GameState.set_objective("Test light chains, Light→Heavy branches, Heavy→Light Reprise, dodges, whiffs, and guard contact.")


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.physical_keycode == KEY_G and dummy != null:
			dummy.toggle_guarded()
			get_viewport().set_input_as_handled()
		elif key_event.physical_keycode == KEY_H and weapon_controller != null:
			hitboxes_visible = not hitboxes_visible
			weapon_controller.show_debug_hitboxes = hitboxes_visible
			get_viewport().set_input_as_handled()


func _configure_player() -> void:
	if player == null:
		return
	weapon_controller = player.get_node_or_null("WeaponController") as WeaponController
	if weapon_controller != null:
		weapon_controller.input_buffer_seconds = 0.38
		weapon_controller.facing_assist_range = 4.0
		weapon_controller.facing_assist_strength = 0.74
		weapon_controller.whiff_recovery_penalty = 0.12
		weapon_controller.show_debug_prints = false
		weapon_controller.print_attack_debug = false
		weapon_controller.show_debug_hitboxes = false
		var base_weapon: WeaponDefinition = weapon_controller.equipped_weapon
		if base_weapon != null:
			var lab_weapon: WeaponDefinition = base_weapon.duplicate(true) as WeaponDefinition
			lab_weapon.display_name = "Flow-Test Sword"
			lab_weapon.damage = 4
			lab_weapon.stance_damage = 5
			lab_weapon.attack_speed = 1.08
			weapon_controller.equip_weapon(lab_weapon)
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_stamina", 60)
	GameState.set_stat("stamina", 60)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.022, 0.034)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.36, 0.44, 0.62)
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.62
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_color = Color(0.72, 0.84, 1.0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 4, -4)
	rim.light_color = Color(1.0, 0.56, 0.18)
	rim.light_energy = 5.0
	rim.omni_range = 11.0
	add_child(rim)


func _build_arena() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(24, 1, 24)
	collision.shape = shape
	collision.position.y = -0.5
	floor.add_child(collision)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(24, 1, 24)
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.09, 0.11, 0.16)
	material.metallic = 0.42
	material.roughness = 0.58
	floor_mesh.material_override = material
	floor.add_child(floor_mesh)
	add_child(floor)
	for index: int in range(5):
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.035, 0.015, 18.0)
		line.mesh = line_mesh
		line.position = Vector3((float(index) - 2.0) * 2.0, 0.015, 0)
		var line_material := StandardMaterial3D.new()
		line_material.albedo_color = Color(0.18, 0.5, 0.82, 0.5)
		line_material.emission_enabled = true
		line_material.emission = Color(0.12, 0.38, 0.72)
		line_material.emission_energy_multiplier = 0.65
		line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material_override = line_material
		add_child(line)
	var title := Label3D.new()
	title.text = "COMBAT FEEL LAB"
	title.position = Vector3(0, 5.2, -7.5)
	title.font_size = 38
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 8
	title.modulate = Color(0.66, 0.86, 1.0)
	add_child(title)
	var instructions := Label3D.new()
	instructions.text = "LIGHT CHAIN   •   LIGHT→HEAVY BRANCH   •   HEAVY→LIGHT REPRISE   •   G GUARD   •   H HITBOXES   •   F8 RESET"
	instructions.position = Vector3(0, 4.35, -7.35)
	instructions.font_size = 20
	instructions.pixel_size = 0.008
	instructions.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instructions.outline_size = 6
	instructions.modulate = Color(0.84, 0.9, 1.0)
	add_child(instructions)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(430, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.028, 0.05, 0.88)
	style.border_color = Color(0.24, 0.62, 1.0, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(status_label)


func _update_hud() -> void:
	if status_label == null or weapon_controller == null or dummy == null:
		return
	var weapon: Dictionary = weapon_controller.get_debug_data()
	var target: Dictionary = dummy.get_debug_data()
	var chain_value: Variant = weapon.get("chain", [])
	var chain_text: String = " → ".join(chain_value as Array) if chain_value is Array and (chain_value as Array).size() > 0 else "none"
	status_label.text = (
		"FLOW-TEST SWORD  •  " + str(weapon.get("attack", "Ready")).to_upper()
		+ "\nPHASE " + str(weapon.get("phase", "idle")).to_upper()
		+ "     BUFFER " + str(weapon.get("queued", "none")).to_upper()
		+ "  " + str(weapon.get("queue_time", 0.0)) + "s"
		+ "\nCHAIN " + chain_text
		+ "\nCONTACT " + str(target.get("contact", "waiting"))
		+ "     DAMAGE " + str(target.get("damage", 0))
		+ "     DUMMY OFFSET " + str(target.get("offset", 0.0)) + "m"
		+ "\nGUARD " + ("ON" if bool(target.get("guarded", false)) else "OFF")
		+ "     HITBOXES " + ("ON" if hitboxes_visible else "OFF")
		+ "     STAMINA " + str(GameState.get_stat("stamina")) + " / " + str(GameState.get_stat("max_stamina"))
	)
