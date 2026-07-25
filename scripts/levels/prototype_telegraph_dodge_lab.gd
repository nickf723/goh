extends Node3D
class_name PrototypeTelegraphDodgeLab

var player: CharacterBody3D
var duelist: TelegraphDuelist
var perfect_dodge: PlayerPerfectDodgeController
var status_label: Label


func _ready() -> void:
	_build_environment()
	_build_arena()
	player = get_node_or_null("Player") as CharacterBody3D
	duelist = get_node_or_null("TelegraphDuelist") as TelegraphDuelist
	_configure_player()
	_build_hud()
	GameState.set_objective("Read the telegraph, dodge at impact, then punish the blue counter window.")


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		_reset_lab()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo or duelist == null:
			return
		match key_event.physical_keycode:
			KEY_1:
				duelist.force_attack(0)
			KEY_2:
				duelist.force_attack(1)
			KEY_3:
				duelist.force_attack(2)
			KEY_4:
				duelist.force_attack(3)
			_:
				return
		get_viewport().set_input_as_handled()


func _configure_player() -> void:
	if player == null:
		return
	perfect_dodge = PlayerPerfectDodgeController.new()
	perfect_dodge.name = "PlayerPerfectDodgeController"
	player.add_child(perfect_dodge)
	perfect_dodge.perfect_window_seconds = 0.12
	perfect_dodge.stamina_reward = 8
	perfect_dodge.counter_window_seconds = 0.85
	var dodge := player.get_node_or_null("DodgeController") as PlayerDodgeController
	if dodge != null:
		dodge.dodge_speed = 9.5
		dodge.dodge_duration = 0.25
		dodge.invulnerability_duration = 0.19
		dodge.stamina_cost = 2
		dodge.show_debug_prints = false
	var weapon := player.get_node_or_null("WeaponController") as WeaponController
	if weapon != null:
		weapon.show_debug_prints = false
		var base_weapon: WeaponDefinition = weapon.equipped_weapon
		if base_weapon != null:
			var lab_weapon := base_weapon.duplicate(true) as WeaponDefinition
			lab_weapon.display_name = "Counter-Test Sword"
			lab_weapon.damage = 4
			lab_weapon.stance_damage = 5
			lab_weapon.attack_speed = 1.08
			weapon.equip_weapon(lab_weapon)
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_stamina", 70)
	GameState.set_stat("stamina", 70)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _reset_lab() -> void:
	if duelist != null:
		duelist.reset_target()
	if perfect_dodge != null:
		perfect_dodge.reset_perfect_dodge()
	var defense := player.get_node_or_null("PlayerDefenseController") as PlayerDefenseController if player != null else null
	if defense != null:
		defense.reset_defense()
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.016, 0.028)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.42, 0.6)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.68
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -30, 0)
	key.light_color = Color(0.7, 0.82, 1.0)
	key.light_energy = 1.45
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 5.0, -2.5)
	rim.light_color = Color(1.0, 0.3, 0.12)
	rim.light_energy = 5.2
	rim.omni_range = 12.0
	add_child(rim)


func _build_arena() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 10.0
	shape.height = 0.8
	collision.shape = shape
	collision.position.y = -0.4
	floor.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 10.0
	mesh.bottom_radius = 10.0
	mesh.height = 0.8
	mesh.radial_segments = 64
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.065, 0.08, 0.13)
	material.metallic = 0.4
	material.roughness = 0.58
	mesh_instance.material_override = material
	floor.add_child(mesh_instance)
	add_child(floor)
	for radius: float in [3.0, 6.0, 9.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.025
		torus.outer_radius = radius + 0.025
		torus.rings = 64
		torus.ring_segments = 8
		ring.mesh = torus
		ring.position.y = 0.025
		var ring_material := StandardMaterial3D.new()
		ring_material.albedo_color = Color(0.18, 0.44, 0.78)
		ring_material.emission_enabled = true
		ring_material.emission = Color(0.08, 0.26, 0.62)
		ring_material.emission_energy_multiplier = 0.7
		ring.material_override = ring_material
		add_child(ring)
	var title := Label3D.new()
	title.text = "TELEGRAPH & PERFECT DODGE LAB"
	title.position = Vector3(0, 5.8, -7.5)
	title.font_size = 36
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 8
	title.modulate = Color(0.72, 0.88, 1.0)
	add_child(title)
	var instructions := Label3D.new()
	instructions.text = "DODGE: C / BOTTOM FACE   •   1–4 FORCE ATTACK   •   ORANGE INTERRUPTS   •   RED COMMITS   •   F8 RESET"
	instructions.position = Vector3(0, 4.95, -7.35)
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
	panel.custom_minimum_size = Vector2(535, 112)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.022, 0.043, 0.9)
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
	if status_label == null or duelist == null or perfect_dodge == null:
		return
	var enemy := duelist.get_debug_data()
	var dodge := perfect_dodge.get_debug_data()
	var armor_text: String = "COMMITTED" if bool(enemy.get("committed", false)) else "INTERRUPTIBLE"
	status_label.text = (
		"ENEMY  •  " + str(enemy.get("attack", "None")).to_upper()
		+ "  •  " + str(enemy.get("phase", "IDLE"))
		+ "  " + str(enemy.get("timer", 0.0)) + "s"
		+ "  •  " + armor_text
		+ "\nRESULT  •  " + str(enemy.get("result", "WAITING"))
		+ "     COUNTER " + str(enemy.get("counter", 0.0)) + "s"
		+ "     INTERRUPTS " + str(enemy.get("interrupts", 0))
		+ "\nDODGE  •  " + str(dodge.get("outcome", "READY"))
		+ "     PERFECT WINDOW " + str(dodge.get("window", 0.0)) + "s"
		+ "     PERFECTS " + str(dodge.get("count", 0))
		+ "     STAMINA " + str(GameState.get_stat("stamina")) + "/" + str(GameState.get_stat("max_stamina"))
	)
