extends Node3D
class_name PrototypeWeaponArsenalDojo

const WeaponSandboxCatalogScript = preload(
	"res://scripts/weapons/weapon_sandbox_catalog.gd"
)
const WeaponClassMotionCatalogScript = preload(
	"res://scripts/weapons/weapon_class_motion_catalog.gd"
)
const WeaponMasteryCatalogScript = preload(
	"res://scripts/weapons/weapon_mastery_catalog.gd"
)
const CombatArenaLoadoutScript = preload(
	"res://scripts/systems/combat_arena_loadout.gd"
)
const TrainingTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/combat_training_target.tscn"
)
const GoblinScene: PackedScene = preload(
	"res://scenes/actors/enemies/goblin_drone.tscn"
)
const GremlinScene: PackedScene = preload(
	"res://scenes/actors/enemies/gremlin_drone.tscn"
)

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var weapon_controller: WeaponController = (
	get_node_or_null("Player/WeaponController") as WeaponController
)

var entry_snapshot: Dictionary = {}
var initial_player_transform: Transform3D
var weapon_cache: Dictionary = {}
var target_root: Node3D
var enemy_root: Node3D
var status_label: Label3D
var enemies_live: bool = false
var reset_count: int = 0


func _ready() -> void:
	add_to_group("weapon_arsenal_dojo")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	entry_snapshot = CombatArenaLoadoutScript.capture_state()
	CombatArenaLoadoutScript.apply_everything_unlocked()
	if player != null:
		initial_player_transform = player.global_transform
	_build_environment()
	_build_pedestals()
	_build_targets()
	_connect_weapon_controller()
	_equip_initial_weapon()
	GameState.set_objective(
		"Compare all 16 weapon classes. Authored classes are stable; [PROXY] classes are combat-design sketches."
	)
	_show_message(
		"Arsenal Dojo online. Test Light, Heavy, dash, aerial, whiff, guard, and movement feel on the same targets. F8 resets; F9 toggles live enemies."
	)
	_refresh_status()


func _exit_tree() -> void:
	CombatArenaLoadoutScript.restore_state(entry_snapshot)


func _process(_delta: float) -> void:
	CombatArenaLoadoutScript.refill_combat_resources()
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("editor") or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_dojo()
	elif key_event.physical_keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		enemies_live = not enemies_live
		_refresh_enemies()
		_show_message("Live sparring " + ("enabled." if enemies_live else "disabled."))


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.016, 0.026, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.4, 0.58, 1.0)
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_color = Color(0.72, 0.82, 1.0, 1.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	add_child(light)
	_add_fill_light("WarmFill", Vector3(-8.0, 4.2, 2.0), Color(1.0, 0.46, 0.2), 2.2)
	_add_fill_light("CoolFill", Vector3(8.0, 4.2, 2.0), Color(0.24, 0.62, 1.0), 2.0)

	var wall_color := Color(0.07, 0.08, 0.115, 1.0)
	_create_static_box("Floor", Vector3(0.0, -0.5, 0.0), Vector3(32.0, 1.0, 32.0), Color(0.055, 0.065, 0.09, 1.0))
	_create_static_box("BackWall", Vector3(0.0, 2.5, 16.0), Vector3(32.0, 6.0, 1.0), wall_color)
	_create_static_box("FrontWall", Vector3(0.0, 2.5, -16.0), Vector3(32.0, 6.0, 1.0), wall_color)
	_create_static_box("LeftWall", Vector3(-16.0, 2.5, 0.0), Vector3(1.0, 6.0, 32.0), wall_color)
	_create_static_box("RightWall", Vector3(16.0, 2.5, 0.0), Vector3(1.0, 6.0, 32.0), wall_color)

	_add_label(
		"DojoTitle",
		"ARSENAL DOJO • 16 WEAPON CLASSES",
		Vector3(0.0, 4.0, 15.35),
		48,
		Color(0.86, 0.9, 1.0)
	)
	status_label = _add_label(
		"CurrentWeaponStatus",
		"INITIALIZING",
		Vector3(0.0, 3.1, 15.2),
		26,
		Color(1.0, 0.76, 0.3)
	)
	_add_label(
		"Instructions",
		"SIDE PEDESTALS SWITCH CLASSES • F8 RESET • F9 LIVE ENEMIES",
		Vector3(0.0, 2.35, 15.05),
		21,
		Color(0.7, 0.8, 1.0)
	)

	for x: float in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		var line := MeshInstance3D.new()
		line.name = "RangeLine" + str(x)
		line.position = Vector3(x, 0.015, 2.0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.04, 0.02, 20.0)
		line.mesh = mesh
		line.material_override = _make_material(Color(0.12, 0.26, 0.48, 0.5), true)
		add_child(line)


func _build_pedestals() -> void:
	var classes: Array[String] = WeaponSandboxCatalogScript.get_all_weapon_classes()
	for index: int in range(classes.size()):
		var weapon_class: String = classes[index]
		var weapon: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon(weapon_class)
		if weapon == null:
			continue
		weapon_cache[weapon_class] = weapon
		var pedestal := SandboxWeaponPedestal.new()
		pedestal.name = weapon_class.capitalize() + "Pedestal"
		pedestal.configure(
			weapon,
			WeaponSandboxCatalogScript.get_status_label(weapon_class)
		)
		var left_bank: bool = index < 8
		var row_index: int = index if left_bank else index - 8
		pedestal.position = Vector3(
			-13.8 if left_bank else 13.8,
			0.0,
			-11.5 + float(row_index) * 3.25
		)
		pedestal.rotation_degrees.y = -90.0 if left_bank else 90.0
		add_child(pedestal)


func _build_targets() -> void:
	target_root = Node3D.new()
	target_root.name = "TrainingTargets"
	add_child(target_root)
	_spawn_training_target("CenterTarget", "NEUTRAL TARGET", Vector3(0.0, 0.0, 3.6))
	_spawn_training_target("LeftTarget", "CLEAVE LEFT", Vector3(-3.0, 0.0, 5.2))
	_spawn_training_target("RightTarget", "CLEAVE RIGHT", Vector3(3.0, 0.0, 5.2))
	_spawn_training_target("RangeTarget", "RANGE / PRECISION", Vector3(0.0, 0.0, 10.5))
	enemy_root = Node3D.new()
	enemy_root.name = "LiveEnemies"
	add_child(enemy_root)


func _spawn_training_target(
	node_name: String,
	label_text: String,
	position_value: Vector3
) -> void:
	var target: Node = TrainingTargetScene.instantiate()
	if not target is Node3D:
		target.queue_free()
		return
	target.name = node_name
	(target as Node3D).position = position_value
	if "target_label" in target:
		target.set("target_label", label_text)
	target_root.add_child(target)


func _connect_weapon_controller() -> void:
	if weapon_controller == null:
		return
	weapon_controller.input_buffer_seconds = 0.4
	weapon_controller.facing_assist_range = 4.4
	weapon_controller.facing_assist_strength = 0.72
	weapon_controller.whiff_recovery_penalty = 0.1
	weapon_controller.show_debug_prints = false
	weapon_controller.print_attack_debug = false
	if not weapon_controller.weapon_changed.is_connected(_on_weapon_changed):
		weapon_controller.weapon_changed.connect(_on_weapon_changed)


func _equip_initial_weapon() -> void:
	if weapon_controller == null:
		return
	var sword: WeaponDefinition = weapon_cache.get("sword") as WeaponDefinition
	if sword != null:
		weapon_controller.equip_weapon(sword)


func _on_weapon_changed(_weapon: WeaponDefinition) -> void:
	_refresh_status()


func _refresh_status() -> void:
	if status_label == null or weapon_controller == null:
		return
	var weapon: WeaponDefinition = weapon_controller.equipped_weapon
	if weapon == null:
		status_label.text = "NO WEAPON"
		return
	var status: String = WeaponSandboxCatalogScript.get_status_label(weapon.weapon_class)
	var mastery_name: String = WeaponMasteryCatalogScript.get_display_name(weapon.weapon_class)
	var motion_id: String = "AUTHORED ATTACK MOTION"
	if weapon_controller.current_attack != null and WeaponClassMotionCatalogScript.has_profile(
		weapon_controller.current_attack.character_pose_id
	):
		motion_id = "CLASS-MOTION FALLBACK"
	status_label.text = (
		weapon.display_name.to_upper()
		+ " • " + status
		+ " • " + mastery_name.to_upper()
		+ " • " + motion_id
		+ (" • LIVE ENEMIES" if enemies_live else "")
	)
	status_label.modulate = weapon.visual_accent_color


func _refresh_enemies() -> void:
	if enemy_root == null:
		return
	for child: Node in enemy_root.get_children():
		enemy_root.remove_child(child)
		child.queue_free()
	if not enemies_live:
		return
	_spawn_enemy(GoblinScene, "DojoGoblin", Vector3(-6.0, 0.2, 8.0))
	_spawn_enemy(GremlinScene, "DojoGremlin", Vector3(6.0, 0.2, 8.0))


func _spawn_enemy(
	scene: PackedScene,
	node_name: String,
	position_value: Vector3
) -> void:
	var enemy: Node = scene.instantiate()
	if not enemy is Node3D:
		enemy.queue_free()
		return
	enemy.name = node_name
	(enemy as Node3D).position = position_value
	enemy_root.add_child(enemy)
	enemy.add_to_group("arsenal_dojo_enemy")


func reset_dojo() -> void:
	reset_count += 1
	if player != null:
		player.global_transform = initial_player_transform
		player.velocity = Vector3.ZERO
		if player.has_method("cancel_combat_motion"):
			player.call("cancel_combat_motion", "arsenal_dojo_reset")
		if player.has_method("clear_lock_on"):
			player.call("clear_lock_on")
	if weapon_controller != null:
		weapon_controller.reset_combo_chain()
	for target: Node in get_tree().get_nodes_in_group("combat_arena_resettable"):
		if target != null and is_instance_valid(target) and target.has_method("reset_target"):
			target.call("reset_target")
	_refresh_enemies()
	CombatArenaLoadoutScript.refill_combat_resources()
	_show_message("Arsenal Dojo reset #" + str(reset_count) + ". Weapon class preserved.")


func _add_fill_light(
	node_name: String,
	position_value: Vector3,
	color: Color,
	energy: float
) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 15.0
	add_child(light)


func _add_label(
	node_name: String,
	text_value: String,
	position_value: Vector3,
	font_size: int,
	color: Color
) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.position = position_value
	label.text = text_value
	label.font_size = font_size
	label.pixel_size = 0.0065
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = color
	add_child(label)
	return label


func _create_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = _make_material(color, false)
	body.add_child(visual)
	add_child(body)
	return body


func _make_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.32
	material.roughness = 0.58
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.55
	return material


func _show_message(text_value: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)
	else:
		print(text_value)


func get_debug_data() -> Dictionary:
	var weapon: WeaponDefinition = weapon_controller.equipped_weapon if weapon_controller != null else null
	return {
		"weapon_arsenal_dojo": true,
		"class_count": weapon_cache.size(),
		"current_class": weapon.weapon_class if weapon != null else "none",
		"current_status": WeaponSandboxCatalogScript.get_status_label(weapon.weapon_class) if weapon != null else "none",
		"live_enemies": enemies_live,
		"enemy_count": enemy_root.get_child_count() if enemy_root != null else 0,
		"reset_count": reset_count,
	}
