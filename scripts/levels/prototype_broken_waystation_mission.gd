extends Node3D

const GoblinScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")
const MasteryCatalog = preload("res://scripts/weapons/weapon_mastery_catalog.gd")

const STATE_BRIEFING := "briefing"
const STATE_ROADBLOCK := "roadblock"
const STATE_ENCOUNTER := "encounter"
const STATE_RETURN := "return"
const STATE_COMPLETE := "complete"

@onready var player: CharacterBody3D = $Player
@onready var mission_label: Label = $MissionHUD/Panel/Margin/VBox/Mission
@onready var objective_label: Label = $MissionHUD/Panel/Margin/VBox/Objective
@onready var prompt_label: Label = $MissionHUD/Panel/Margin/VBox/Prompt
@onready var status_label: Label = $MissionHUD/Panel/Margin/VBox/Status

var mission_state := STATE_BRIEFING
var roadblock_method := ""
var optional_discovery := false
var checkpoint_position := Vector3(0, 1, -16)
var checkpoint_snapshot: Dictionary = {}
var enemies: Array[Node3D] = []
var encounter_started := false
var reward_granted := false
var elapsed := 0.0

var briefing_position := Vector3(0, 0, -13)
var roadblock_position := Vector3(0, 0, -3)
var discovery_position := Vector3(-8, 0, 5)
var checkpoint_marker_position := Vector3(0, 0, 7)
var encounter_position := Vector3(0, 0, 14)
var return_position := Vector3(0, 0, -13)


func _ready() -> void:
	build_world()
	set_objective("Speak with the waystation keeper.")
	checkpoint_snapshot = capture_mission_state()
	refresh_hud()


func _process(delta: float) -> void:
	elapsed += delta
	update_context_prompt()
	if mission_state == STATE_ENCOUNTER and encounter_started:
		prune_enemies()
		if enemies.is_empty():
			finish_encounter()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_E:
			interact_nearby()
		KEY_1:
			resolve_roadblock("burn")
		KEY_2:
			resolve_roadblock("break")
		KEY_3:
			resolve_roadblock("blink")
		KEY_F8:
			restore_checkpoint()
		KEY_F9:
			reset_mission()


func interact_nearby() -> void:
	if player.global_position.distance_to(briefing_position) < 3.5:
		if mission_state == STATE_BRIEFING:
			mission_state = STATE_ROADBLOCK
			set_objective("Clear the collapsed road. Choose fire, force, or Blink.")
			show_message("The keeper asks Grace to reopen the route and check the abandoned signal post.")
			return
		if mission_state == STATE_RETURN:
			complete_mission()
			return
	if mission_state == STATE_ROADBLOCK and player.global_position.distance_to(discovery_position) < 3.0:
		optional_discovery = true
		$World/SignalCache.visible = false
		show_message("Optional discovery: an intact route ledger names a hidden supply cache.")
		refresh_hud()
		return
	if player.global_position.distance_to(checkpoint_marker_position) < 3.0 and mission_state in [STATE_ROADBLOCK, STATE_ENCOUNTER]:
		activate_checkpoint()


func resolve_roadblock(method: String) -> void:
	if mission_state != STATE_ROADBLOCK:
		return
	if player.global_position.distance_to(roadblock_position) > 5.0:
		show_message("Move closer to the collapsed road before choosing a solution.")
		return
	roadblock_method = method
	$World/Roadblock.visible = false
	$World/RoadblockCollision.process_mode = Node.PROCESS_MODE_DISABLED
	match method:
		"burn":
			show_message("Fire clears the tangled growth. The timber remains as a narrow crossing.")
		"break":
			show_message("A forceful strike shatters the weak supports and opens the road.")
		"blink":
			show_message("Grace Blinks beyond the collapse, leaving the blocked supply pocket behind.")
	mission_state = STATE_ENCOUNTER
	set_objective("Reach the broken waystation and defeat the route raiders.")
	activate_checkpoint()
	spawn_encounter()
	refresh_hud()


func spawn_encounter() -> void:
	if encounter_started:
		return
	encounter_started = true
	spawn_enemy(GoblinScene, encounter_position + Vector3(-2.8, 0.7, 2.0), "WaystationGoblin")
	spawn_enemy(GremlinScene, encounter_position + Vector3(2.8, 0.6, 2.3), "WaystationGremlin")
	spawn_enemy(GoblinScene, encounter_position + Vector3(0, 0.7, 5.5), "WaystationCaptain")


func spawn_enemy(scene: PackedScene, position_value: Vector3, enemy_name: String) -> void:
	var enemy := scene.instantiate()
	if not enemy is Node3D:
		enemy.queue_free()
		return
	$EnemyContainer.add_child(enemy)
	(enemy as Node3D).global_position = position_value
	enemy.name = enemy_name
	enemy.add_to_group("broken_waystation_enemy")
	enemies.append(enemy as Node3D)


func prune_enemies() -> void:
	var remaining: Array[Node3D] = []
	for enemy: Node3D in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			remaining.append(enemy)
	enemies = remaining


func finish_encounter() -> void:
	encounter_started = false
	mission_state = STATE_RETURN
	$World/RepairedBeacon.visible = true
	set_objective("Return to the keeper at the reopened waystation.")
	show_message("The raiders are gone. The waystation beacon sputters back to life.")
	refresh_hud()


func complete_mission() -> void:
	if reward_granted:
		return
	reward_granted = true
	mission_state = STATE_COMPLETE
	var weapon_class := "sword"
	var before := GameState.get_weapon_mastery_points(weapon_class)
	var reward := 12 if optional_discovery else 8
	GameState.set_weapon_mastery_points(weapon_class, before + reward)
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("health", GameState.get_stat("max_health"))
	set_objective("Mission complete: The Broken Waystation")
	show_message("Reward: %d sword mastery%s." % [reward, " and the hidden cache record" if optional_discovery else ""])
	refresh_hud()


func activate_checkpoint() -> void:
	checkpoint_position = checkpoint_marker_position + Vector3(0, 1, -1.5)
	checkpoint_snapshot = capture_mission_state()
	show_message("Checkpoint activated. Mission progress and player resources recorded.")


func restore_checkpoint() -> void:
	player.global_position = checkpoint_position
	player.velocity = Vector3.ZERO
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	if mission_state == STATE_ENCOUNTER:
		clear_enemies()
		encounter_started = false
		spawn_encounter()
	show_message("Returned to the active checkpoint.")


func reset_mission() -> void:
	clear_enemies()
	mission_state = STATE_BRIEFING
	roadblock_method = ""
	optional_discovery = false
	encounter_started = false
	reward_granted = false
	checkpoint_position = Vector3(0, 1, -16)
	$World/Roadblock.visible = true
	$World/RoadblockCollision.process_mode = Node.PROCESS_MODE_INHERIT
	$World/SignalCache.visible = true
	$World/RepairedBeacon.visible = false
	player.global_position = checkpoint_position
	player.velocity = Vector3.ZERO
	set_objective("Speak with the waystation keeper.")
	show_message("Mission reset.")
	refresh_hud()


func clear_enemies() -> void:
	for child: Node in $EnemyContainer.get_children():
		child.queue_free()
	enemies.clear()


func capture_mission_state() -> Dictionary:
	return {
		"state": mission_state,
		"roadblock_method": roadblock_method,
		"optional_discovery": optional_discovery,
		"position": checkpoint_position,
	}


func set_objective(text_value: String) -> void:
	GameState.set_objective(text_value)
	objective_label.text = "OBJECTIVE  •  " + text_value
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text_value)


func show_message(text_value: String) -> void:
	status_label.text = text_value


func update_context_prompt() -> void:
	var prompt := ""
	if player == null:
		return
	if player.global_position.distance_to(briefing_position) < 3.5:
		if mission_state == STATE_BRIEFING:
			prompt = "E  Speak with the keeper"
		elif mission_state == STATE_RETURN:
			prompt = "E  Report success"
	elif mission_state == STATE_ROADBLOCK and player.global_position.distance_to(roadblock_position) < 5.0:
		prompt = "1 Burn growth   2 Break supports   3 Blink beyond"
	elif mission_state == STATE_ROADBLOCK and not optional_discovery and player.global_position.distance_to(discovery_position) < 3.0:
		prompt = "E  Inspect abandoned signal cache"
	elif mission_state in [STATE_ROADBLOCK, STATE_ENCOUNTER] and player.global_position.distance_to(checkpoint_marker_position) < 3.0:
		prompt = "E  Activate checkpoint"
	prompt_label.text = prompt


func refresh_hud() -> void:
	mission_label.text = "THE BROKEN WAYSTATION  •  " + mission_state.to_upper()
	var method_text := roadblock_method.capitalize() if not roadblock_method.is_empty() else "Unresolved"
	status_label.text = "Roadblock: %s   •   Discovery: %s   •   Raiders: %d\nF8 checkpoint  •  F9 reset mission" % [method_text, "FOUND" if optional_discovery else "missing", enemies.size()]


func build_world() -> void:
	add_floor(Vector3(0, -0.5, 7), Vector3(24, 1, 50), Color(0.2, 0.24, 0.17))
	add_floor(Vector3(0, 0.03, 7), Vector3(6, 0.08, 48), Color(0.34, 0.28, 0.17), false)
	add_box($World, "KeeperShelter", Vector3(5, 2.7, 3.5), Vector3(5, 1.35, -13), Color(0.28, 0.18, 0.1), true)
	add_label("WAYSTATION KEEPER", briefing_position + Vector3(0, 2.4, 0), Color(1, 0.8, 0.42))
	add_label("COLLAPSED ROAD", roadblock_position + Vector3(0, 2.8, 0), Color(1, 0.45, 0.2))
	add_label("OPTIONAL SIGNAL CACHE", discovery_position + Vector3(0, 2.2, 0), Color(0.45, 0.88, 1))
	add_label("CHECKPOINT", checkpoint_marker_position + Vector3(0, 2.2, 0), Color(0.6, 1, 0.7))
	add_label("BROKEN WAYSTATION", encounter_position + Vector3(0, 3.0, 4), Color(1, 0.66, 0.3))


func add_floor(position_value: Vector3, size: Vector3, color: Color, collision := true) -> void:
	if collision:
		add_box($World, "Ground", size, position_value, color, true)
	else:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.position = position_value
		mesh.material_override = make_material(color)
		$World.add_child(mesh)


func add_box(parent: Node3D, node_name: String, size: Vector3, position_value: Vector3, color: Color, collision := true) -> Node3D:
	var root: Node3D
	if collision:
		var body := StaticBody3D.new()
		var collision_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision_shape.shape = shape
		body.add_child(collision_shape)
		root = body
	else:
		root = Node3D.new()
	root.name = node_name
	root.position = position_value
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = make_material(color)
	root.add_child(visual)
	parent.add_child(root)
	return root


func add_label(text_value: String, position_value: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = 32
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 5
	$World.add_child(label)


func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material
