extends Node3D
class_name PrototypeLargeEnemyLab

const ShowcaseLoadout: AbilityLoadout = preload("res://data/loadouts/grace_ruined_village_showcase_loadout.tres")
const TraversalControllerScript = preload("res://scripts/player/large_enemy_traversal_controller.gd")

var construct: LargeConstructEnemy = null
var status_label: Label = null
var traversal_controller: LargeEnemyTraversalController = null


func _ready() -> void:
	_build_environment()
	_build_arena()
	_configure_player()
	construct = get_node_or_null("LargeConstructEnemy") as LargeConstructEnemy
	_setup_traversal_controller()
	_build_hud()
	if construct != null:
		construct.health_changed.connect(_on_construct_changed)
		construct.stance_changed.connect(_on_construct_changed)
		construct.part_consequence.connect(_on_part_consequence)
	GameState.set_objective("Use weapons or spells to break stance, climb during the kneel, and attack exposed parts.")


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "LargeEnemyEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.025, 0.04, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.30, 0.42, 0.60, 1.0)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.14, 0.20, 0.30, 1.0)
	environment.fog_density = 0.008
	environment_node.environment = environment
	add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.name = "ColdFoundryKey"
	key.rotation_degrees = Vector3(-52, -28, 0)
	key.light_color = Color(0.62, 0.78, 1.0, 1.0)
	key.light_energy = 1.35
	key.shadow_enabled = true
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.name = "ForgeRim"
	rim.rotation_degrees = Vector3(-28, 142, 0)
	rim.light_color = Color(1.0, 0.28, 0.08, 1.0)
	rim.light_energy = 0.48
	rim.shadow_enabled = false
	add_child(rim)


func _build_arena() -> void:
	var floor := StaticBody3D.new()
	floor.name = "FoundryArenaFloor"
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(42, 1, 42)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.5
	floor.add_child(floor_collision)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(42, 1, 42)
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.5
	floor_mesh.material_override = _make_material(Color(0.11, 0.13, 0.16), 0.62, 0.48)
	floor.add_child(floor_mesh)
	add_child(floor)

	for index: int in range(16):
		var angle: float = TAU * float(index) / 16.0
		var pillar := StaticBody3D.new()
		pillar.name = "ArenaPillar" + str(index)
		pillar.position = Vector3(cos(angle) * 19.0, 2.0, sin(angle) * 19.0)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.3, 4.0, 1.3)
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _make_material(
			Color(0.16, 0.18, 0.22) if index % 2 == 0 else Color(0.26, 0.12, 0.08),
			0.72,
			0.4
		)
		pillar.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		pillar.add_child(collision)
		add_child(pillar)

	var title := Label3D.new()
	title.text = "LARGE ENEMY • PART BREAKING"
	title.position = Vector3(0, 9.2, -15.5)
	title.font_size = 34
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 8
	title.modulate = Color(0.62, 0.84, 1.0)
	add_child(title)

	var instructions := Label3D.new()
	instructions.text = "BREAK STANCE → INTERACT TO CLIMB   •   MOVE UP/DOWN   •   HOLD INTERACT TO BRACE   •   ATTACK/DODGE TO ESCAPE GRABS"
	instructions.position = Vector3(0, 8.25, -15.3)
	instructions.font_size = 21
	instructions.pixel_size = 0.008
	instructions.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instructions.outline_size = 6
	instructions.modulate = Color(0.82, 0.88, 0.96)
	add_child(instructions)


func _configure_player() -> void:
	var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster != null:
		var runtime_loadout: AbilityLoadout = ShowcaseLoadout.duplicate(true) as AbilityLoadout
		caster.set("loadout", runtime_loadout)
		if caster.has_method("align_focus_menu_to_current_ability"):
			caster.call("align_focus_menu_to_current_ability")
		if caster.has_method("emit_current_ability"):
			caster.call_deferred("emit_current_ability")
	var resources: Node = player.get_node_or_null("PlayerResourceController")
	if resources != null and resources.has_method("restore_full_resources"):
		resources.call("restore_full_resources")
	# Encounter profile: sturdy enough to learn the boss and strong enough to reach a kneel.
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_stamina", 50)
	GameState.set_stat("stamina", 50)
	GameState.set_stat("max_mana", 40)
	GameState.set_stat("mana", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	GameState.set_stat("power", 10)
	GameState.set_stat("skill", 8)
	GameState.set_stat("arcana", 10)
	GameState.set_stat("defense", 6)
	GameState.set_stat("resilience", 6)
	GameState.set_stat("focus", 8)


func _setup_traversal_controller() -> void:
	var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if player == null or construct == null:
		return
	traversal_controller = TraversalControllerScript.new() as LargeEnemyTraversalController
	traversal_controller.name = "LargeEnemyTraversalController"
	player.add_child(traversal_controller)
	traversal_controller.setup(player, construct)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LargeEnemyHUD"
	layer.layer = 15
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(390, 112)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.028, 0.045, 0.88)
	style.border_color = Color(0.26, 0.58, 0.92, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.91, 1.0))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(status_label)


func _update_hud() -> void:
	if status_label == null or construct == null:
		return
	var debug: Dictionary = construct.get_debug_data()
	var target_text: String = "BODY"
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		var target_value: Variant = player.get("lock_on_target")
		if target_value is Node:
			target_text = (target_value as Node).name.to_snake_case().to_upper()
	status_label.text = (
		"FOUNDRY COLOSSUS  •  " + str(debug.get("state", "UNKNOWN"))
		+ "\nHEALTH " + str(debug.get("health", 0)) + " / " + str(debug.get("maximum_health", 0))
		+ "     STANCE " + str(debug.get("stance", 0)) + " / " + str(debug.get("maximum_stance", 0))
		+ "\nTARGET " + target_text
		+ "     HAMMER " + ("ACTIVE" if bool(debug.get("weapon_arm", true)) else "DISABLED")
		+ "     CORE " + ("EXPOSED" if bool(debug.get("chest_open", false)) else "ARMORED")
		+ "\nTRAVERSAL " + (traversal_controller.get_state_name() if traversal_controller != null else "OFFLINE")
		+ "     STAMINA " + str(GameState.get_stat("stamina")) + " / " + str(GameState.get_stat("max_stamina"))
		+ "\n" + (traversal_controller.get_status_text() if traversal_controller != null else "")
	)


func _on_construct_changed(_current: int, _maximum: int) -> void:
	_update_hud()


func _on_part_consequence(_part_id: String, consequence: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", consequence.capitalize())


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
