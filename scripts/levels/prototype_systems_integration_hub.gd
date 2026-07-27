extends Node3D
class_name PrototypeSystemsIntegrationHub

const CombatArenaLoadoutScript = preload("res://scripts/systems/combat_arena_loadout.gd")
const CombatTargetScene: PackedScene = preload("res://scenes/actors/testing/combat_training_target.tscn")
const GoblinScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")

const STATIONS: Array[Dictionary] = [
	{"key": KEY_F1, "name": "Central Console", "position": Vector3(0.0, 1.0, -14.0)},
	{"key": KEY_F2, "name": "Combat & Mastery", "position": Vector3(-20.0, 1.0, 0.0)},
	{"key": KEY_F3, "name": "Aerial Reactions", "position": Vector3(20.0, 1.0, 0.0)},
	{"key": KEY_F4, "name": "Movement Course", "position": Vector3(0.0, 1.0, 22.0)},
	{"key": KEY_F5, "name": "Interaction Yard", "position": Vector3(-22.0, 1.0, 24.0)},
	{"key": KEY_F6, "name": "Status & Ability Range", "position": Vector3(22.0, 1.0, 24.0)},
]

var player: CharacterBody3D
var entry_snapshot: Dictionary = {}
var everything_unlocked: bool = false
var status_label: Label
var station_label: Label
var target_container: Node3D
var enemy_container: Node3D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	entry_snapshot = CombatArenaLoadoutScript.capture_state()
	build_campus()
	refresh_hud("Central Console")
	GameState.set_objective("Use F1-F6 to visit integration stations. F8 resets; F9 toggles all unlocks.")


func _exit_tree() -> void:
	if not entry_snapshot.is_empty():
		CombatArenaLoadoutScript.restore_state(entry_snapshot)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	for station: Dictionary in STATIONS:
		if key_event.physical_keycode == int(station.get("key", 0)):
			teleport_player(station.get("position", Vector3.ZERO) as Vector3)
			refresh_hud(str(station.get("name", "Unknown Station")))
			get_viewport().set_input_as_handled()
			return
	match key_event.physical_keycode:
		KEY_F8:
			reset_hub()
			get_viewport().set_input_as_handled()
		KEY_F9:
			toggle_everything_unlocked()
			get_viewport().set_input_as_handled()
		KEY_F10:
			respawn_live_enemies()
			get_viewport().set_input_as_handled()


func build_campus() -> void:
	build_floor_and_boundaries()
	build_central_console()
	build_combat_station()
	build_aerial_station()
	build_movement_station()
	build_interaction_station()
	build_status_station()
	build_hud()


func build_floor_and_boundaries() -> void:
	add_static_box("CampusFloor", Vector3(62.0, 0.6, 62.0), Vector3(0.0, -0.3, 12.0), Color(0.12, 0.13, 0.17, 1.0))
	add_static_box("NorthWall", Vector3(62.0, 4.0, 1.0), Vector3(0.0, 2.0, 43.0), Color(0.07, 0.08, 0.12, 1.0))
	add_static_box("SouthWall", Vector3(62.0, 4.0, 1.0), Vector3(0.0, 2.0, -19.0), Color(0.07, 0.08, 0.12, 1.0))
	add_static_box("WestWall", Vector3(1.0, 4.0, 62.0), Vector3(-31.0, 2.0, 12.0), Color(0.07, 0.08, 0.12, 1.0))
	add_static_box("EastWall", Vector3(1.0, 4.0, 62.0), Vector3(31.0, 2.0, 12.0), Color(0.07, 0.08, 0.12, 1.0))
	for station: Dictionary in STATIONS:
		var p: Vector3 = station.get("position", Vector3.ZERO) as Vector3
		add_visual_disc(p + Vector3(0.0, -0.86, 0.0), Color(0.35, 0.62, 1.0, 1.0), 1.8)


func build_central_console() -> void:
	add_static_box("CentralDais", Vector3(15.0, 0.35, 7.0), Vector3(0.0, 0.18, -13.0), Color(0.22, 0.18, 0.31, 1.0))
	add_world_label("SYSTEMS INTEGRATION HUB", Vector3(0.0, 4.1, -17.0), Color(0.92, 0.78, 1.0, 1.0), 62)
	add_world_label("ONE PLAYER • SHARED STATE • EVERY SYSTEM", Vector3(0.0, 3.25, -16.8), Color(0.62, 0.78, 1.0, 1.0), 32)
	add_world_label("F1-F6 STATIONS   F8 RESET   F9 ALL UNLOCKS   F10 ENEMIES", Vector3(0.0, 1.8, -10.7), Color(1.0, 0.84, 0.46, 1.0), 28)


func build_combat_station() -> void:
	var center := Vector3(-20.0, 0.0, 0.0)
	add_zone_floor("CombatZone", center, Vector3(18.0, 0.18, 18.0), Color(0.25, 0.12, 0.1, 1.0))
	add_world_label("COMBAT & MASTERY", center + Vector3(0.0, 3.2, -7.0), Color(1.0, 0.45, 0.24, 1.0), 42)
	target_container = Node3D.new()
	target_container.name = "CombatTargets"
	add_child(target_container)
	spawn_target(center + Vector3(-4.0, 0.0, 1.5), "COMBO TARGET")
	spawn_target(center + Vector3(0.0, 0.0, 3.0), "STANCE TARGET")
	spawn_target(center + Vector3(4.0, 0.0, 1.5), "DASH / TECHNIQUE TARGET")
	enemy_container = Node3D.new()
	enemy_container.name = "LiveEnemies"
	add_child(enemy_container)
	respawn_live_enemies()


func build_aerial_station() -> void:
	var center := Vector3(20.0, 0.0, 0.0)
	add_zone_floor("AerialZone", center, Vector3(18.0, 0.18, 18.0), Color(0.11, 0.18, 0.3, 1.0))
	add_world_label("AERIAL REACTIONS", center + Vector3(0.0, 3.2, -7.0), Color(0.42, 0.78, 1.0, 1.0), 42)
	add_static_box("LaunchStepLow", Vector3(4.0, 0.8, 4.0), center + Vector3(-5.0, 0.4, 1.0), Color(0.18, 0.3, 0.42, 1.0))
	add_static_box("LaunchStepMid", Vector3(4.0, 1.7, 4.0), center + Vector3(0.0, 0.85, 3.0), Color(0.18, 0.3, 0.42, 1.0))
	add_static_box("LaunchStepHigh", Vector3(4.0, 2.8, 4.0), center + Vector3(5.0, 1.4, 5.0), Color(0.18, 0.3, 0.42, 1.0))
	spawn_target(center + Vector3(-3.2, 0.0, -1.0), "LAUNCH TARGET")
	spawn_target(center + Vector3(3.2, 0.0, -1.0), "JUGGLE TARGET")


func build_movement_station() -> void:
	var center := Vector3(0.0, 0.0, 22.0)
	add_zone_floor("MovementZone", center, Vector3(18.0, 0.18, 18.0), Color(0.13, 0.27, 0.18, 1.0))
	add_world_label("MOVEMENT COURSE", center + Vector3(0.0, 3.2, -7.0), Color(0.46, 1.0, 0.62, 1.0), 42)
	for index: int in range(5):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		add_static_box(
			"MovementBlock" + str(index),
			Vector3(3.2, 0.6 + float(index) * 0.32, 3.0),
			center + Vector3(side * 3.8, 0.3 + float(index) * 0.16, -4.0 + float(index) * 2.4),
			Color(0.17, 0.38, 0.24, 1.0)
		)
	add_static_box("DashGateLeft", Vector3(1.0, 3.6, 1.0), center + Vector3(-2.2, 1.8, 6.0), Color(0.34, 0.65, 0.42, 1.0))
	add_static_box("DashGateRight", Vector3(1.0, 3.6, 1.0), center + Vector3(2.2, 1.8, 6.0), Color(0.34, 0.65, 0.42, 1.0))


func build_interaction_station() -> void:
	var center := Vector3(-22.0, 0.0, 24.0)
	add_zone_floor("InteractionZone", center, Vector3(14.0, 0.18, 14.0), Color(0.29, 0.22, 0.1, 1.0))
	add_world_label("INTERACTION YARD", center + Vector3(0.0, 3.2, -5.0), Color(1.0, 0.78, 0.32, 1.0), 38)
	for index: int in range(6):
		add_static_box(
			"InteractionProp" + str(index),
			Vector3(1.2, 1.2 + float(index % 3) * 0.35, 1.2),
			center + Vector3(-4.0 + float(index % 3) * 4.0, 0.6, -1.0 + float(index / 3) * 4.0),
			Color(0.42, 0.29, 0.12, 1.0)
		)
	add_world_label("RECEIVERS / BREAKABLES / FUTURE PUZZLE FIXTURES", center + Vector3(0.0, 1.7, 5.0), Color(0.95, 0.82, 0.54, 1.0), 22)


func build_status_station() -> void:
	var center := Vector3(22.0, 0.0, 24.0)
	add_zone_floor("StatusZone", center, Vector3(14.0, 0.18, 14.0), Color(0.18, 0.12, 0.28, 1.0))
	add_world_label("STATUS & ABILITY RANGE", center + Vector3(0.0, 3.2, -5.0), Color(0.78, 0.52, 1.0, 1.0), 38)
	var colors: Array[Color] = [
		Color(1.0, 0.25, 0.08, 1.0),
		Color(0.25, 0.78, 1.0, 1.0),
		Color(0.48, 1.0, 0.24, 1.0),
		Color(0.72, 0.38, 1.0, 1.0),
	]
	for index: int in range(4):
		add_visual_disc(center + Vector3(-4.5 + float(index) * 3.0, 0.02, 0.0), colors[index], 1.15)
	spawn_target(center + Vector3(-3.0, 0.0, 4.0), "STATUS TARGET")
	spawn_target(center + Vector3(3.0, 0.0, 4.0), "SPELL RANGE TARGET")


func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "IntegrationHUD"
	layer.layer = 30
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22.0, 22.0)
	panel.size = Vector2(650.0, 166.0)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	station_label = Label.new()
	station_label.add_theme_font_size_override("font_size", 22)
	box.add_child(station_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	box.add_child(status_label)


func refresh_hud(station_name: String) -> void:
	if station_label == null or status_label == null:
		return
	station_label.text = "INTEGRATION HUB  •  " + station_name.to_upper()
	status_label.text = (
		"F1 Central  F2 Combat  F3 Aerial  F4 Movement  F5 Interaction  F6 Status\n"
		+ "F8 Reset  F9 All unlocks: " + ("ON" if everything_unlocked else "OFF") + "  F10 Respawn enemies\n"
		+ "WIRED: player, weapons, mastery, techniques, aerial reactions, abilities, enemies, resources"
	)


func teleport_player(destination: Vector3) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = destination
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")


func reset_hub() -> void:
	teleport_player(STATIONS[0].get("position", Vector3.ZERO) as Vector3)
	CombatArenaLoadoutScript.refill_combat_resources()
	respawn_live_enemies()
	refresh_hud("Central Console")


func toggle_everything_unlocked() -> void:
	everything_unlocked = not everything_unlocked
	if everything_unlocked:
		CombatArenaLoadoutScript.apply_everything_unlocked()
	else:
		CombatArenaLoadoutScript.restore_state(entry_snapshot)
	CombatArenaLoadoutScript.refill_combat_resources()
	refresh_hud(current_station_name())


func current_station_name() -> String:
	if player == null:
		return "Central Console"
	var closest_name := "Central Console"
	var closest_distance := INF
	for station: Dictionary in STATIONS:
		var distance: float = player.global_position.distance_to(station.get("position", Vector3.ZERO) as Vector3)
		if distance < closest_distance:
			closest_distance = distance
			closest_name = str(station.get("name", closest_name))
	return closest_name


func respawn_live_enemies() -> void:
	if enemy_container == null:
		return
	for child: Node in enemy_container.get_children():
		child.queue_free()
	spawn_enemy(GoblinScene, Vector3(-24.0, 0.65, 5.5), "HubGoblin")
	spawn_enemy(GremlinScene, Vector3(-16.0, 0.55, 5.5), "HubGremlin")


func spawn_enemy(scene: PackedScene, position_value: Vector3, enemy_name: String) -> void:
	if scene == null or enemy_container == null:
		return
	var enemy := scene.instantiate()
	if not enemy is Node3D:
		enemy.queue_free()
		return
	enemy.name = enemy_name
	enemy_container.add_child(enemy)
	(enemy as Node3D).global_position = position_value


func spawn_target(position_value: Vector3, label_text: String) -> void:
	if CombatTargetScene == null:
		return
	var target := CombatTargetScene.instantiate()
	if not target is Node3D:
		target.queue_free()
		return
	if target_container == null:
		target_container = Node3D.new()
		target_container.name = "SharedTargets"
		add_child(target_container)
	target_container.add_child(target)
	(target as Node3D).global_position = position_value
	target.set("target_label", label_text)


func add_zone_floor(node_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	add_static_box(node_name, size, center + Vector3(0.0, -0.09, 0.0), color)


func add_static_box(node_name: String, size: Vector3, position_value: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = create_material(color)
	body.add_child(visual)
	return body


func add_visual_disc(position_value: Vector3, color: Color, radius: float) -> void:
	var visual := MeshInstance3D.new()
	visual.position = position_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh.radial_segments = 24
	visual.mesh = mesh
	visual.material_override = create_emissive_material(color)
	add_child(visual)


func add_world_label(text_value: String, position_value: Vector3, color: Color, size_value: int) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = size_value
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 6
	add_child(label)


func create_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	return material


func create_emissive_material(color: Color) -> StandardMaterial3D:
	var material := create_material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.25
	return material


func get_debug_data() -> Dictionary:
	return {
		"stations": STATIONS.size(),
		"unlocked": everything_unlocked,
		"player": player != null,
		"targets": get_tree().get_nodes_in_group("combat_training_target").size(),
		"enemies": enemy_container.get_child_count() if enemy_container != null else 0,
	}
