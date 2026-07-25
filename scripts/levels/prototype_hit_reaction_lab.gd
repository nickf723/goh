extends Node3D
class_name PrototypeHitReactionLab

var player: CharacterBody3D
var weapon_controller: WeaponController
var targets: Array[HitReactionTestTarget] = []
var status_label: Label


func _ready() -> void:
	_build_environment()
	_build_arena()
	player = get_node_or_null("Player") as CharacterBody3D
	for child: Node in get_children():
		if child is HitReactionTestTarget:
			targets.append(child as HitReactionTestTarget)
	_configure_player()
	_build_hud()
	GameState.set_objective("Compare flinch, stagger, launch, armor, super armor, and anti-stunlock adaptation.")


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		for target: HitReactionTestTarget in targets:
			target.reset_target()
		GameState.set_stat("health", GameState.get_stat("max_health"))
		GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
		get_viewport().set_input_as_handled()


func _configure_player() -> void:
	if player == null:
		return
	weapon_controller = player.get_node_or_null("WeaponController") as WeaponController
	if weapon_controller != null:
		weapon_controller.input_buffer_seconds = 0.38
		weapon_controller.facing_assist_range = 4.5
		weapon_controller.show_debug_prints = false
		var base_weapon: WeaponDefinition = weapon_controller.equipped_weapon
		if base_weapon != null:
			var lab_weapon := base_weapon.duplicate(true) as WeaponDefinition
			lab_weapon.display_name = "Reaction-Test Sword"
			lab_weapon.damage = 4
			lab_weapon.stance_damage = 5
			lab_weapon.attack_speed = 1.08
			weapon_controller.equip_weapon(lab_weapon)
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_stamina", 70)
	GameState.set_stat("stamina", 70)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.014, 0.018, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.44, 0.62)
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -24, 0)
	key.light_color = Color(0.75, 0.86, 1.0)
	key.light_energy = 1.45
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 5, -4)
	rim.light_color = Color(1.0, 0.48, 0.16)
	rim.light_energy = 5.0
	rim.omni_range = 13.0
	add_child(rim)


func _build_arena() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(26, 1, 22)
	collision.shape = shape
	collision.position.y = -0.5
	floor.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.075, 0.09, 0.135)
	material.metallic = 0.38
	material.roughness = 0.62
	mesh_instance.material_override = material
	floor.add_child(mesh_instance)
	add_child(floor)
	for x: float in [-4.0, 0.0, 4.0]:
		var pad := MeshInstance3D.new()
		var pad_mesh := CylinderMesh.new()
		pad_mesh.top_radius = 2.0
		pad_mesh.bottom_radius = 2.15
		pad_mesh.height = 0.12
		pad.mesh = pad_mesh
		pad.position = Vector3(x, 0.06, 0)
		var pad_material := StandardMaterial3D.new()
		pad_material.albedo_color = Color(0.12, 0.2, 0.32)
		pad_material.emission_enabled = true
		pad_material.emission = Color(0.08, 0.28, 0.6)
		pad_material.emission_energy_multiplier = 0.6
		pad.material_override = pad_material
		add_child(pad)
	var title := Label3D.new()
	title.text = "HIT REACTION LAB"
	title.position = Vector3(0, 5.8, -6.8)
	title.font_size = 38
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 8
	title.modulate = Color(0.72, 0.88, 1.0)
	add_child(title)
	var instructions := Label3D.new()
	instructions.text = "LIGHT J / LMB / L   •   HEAVY K / MOUSE4 / R   •   REPEAT HITS TO BUILD ADAPTATION   •   F8 RESET"
	instructions.position = Vector3(0, 4.95, -6.7)
	instructions.font_size = 18
	instructions.pixel_size = 0.008
	instructions.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instructions.outline_size = 6
	instructions.modulate = Color(0.86, 0.92, 1.0)
	add_child(instructions)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(520, 118)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.024, 0.046, 0.9)
	style.border_color = Color(0.3, 0.66, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	panel.add_child(status_label)


func _update_hud() -> void:
	if status_label == null:
		return
	var lines: PackedStringArray = ["HIT REACTIONS  •  Poise recovers; adaptation fades after a short pause"]
	for target: HitReactionTestTarget in targets:
		var data := target.get_debug_data()
		var armor_text: String = "SUPER" if bool(data.get("super_armor", false)) else str(data.get("armor", 0.0))
		lines.append(
			str(data.get("name", "Target")).to_upper()
			+ "  •  " + str(data.get("reaction", "READY"))
			+ "  •  POISE " + str(data.get("poise", 0.0)) + "/" + str(data.get("max_poise", 0.0))
			+ "  •  ADAPT " + str(data.get("resistance", 0.0))
			+ "  •  ARMOR " + armor_text
		)
	status_label.text = "\n".join(lines)
