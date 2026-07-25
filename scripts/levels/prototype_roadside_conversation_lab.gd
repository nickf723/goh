extends Node3D
class_name PrototypeRoadsideConversationLab

const ConversationNPCScript = preload("res://scripts/dialogue/conversation_npc.gd")
const QuestFieldObjectiveScript = preload("res://scripts/quests/quest_field_objective.gd")
const QuestJournalScript = preload("res://scripts/quests/quest_journal_ui.gd")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")

const MARA_QUEST_ID: String = "mara_missing_map"

var traveler: Area3D
var result_label: Label3D
var quest_guard: CharacterBody3D
var map_case: Area3D
var distraction: Area3D
var metal_recovery: Area3D


func _ready() -> void:
	Engine.time_scale = 1.0
	build_environment()
	build_roadside_scene()
	build_traveler()
	build_quest_field()
	build_quest_journal()
	if GameState.get_quest(MARA_QUEST_ID).is_empty():
		GameState.set_objective("Speak with Mara and decide how Grace will help.")
	await get_tree().process_frame
	show_message("Help Mara, then accept her field quest. Minus / J opens the Journey journal.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene") and OS.has_feature("editor"):
		GameState.set_flag("helped_mara_supplies", false)
		GameState.set_flag("helped_mara_metal", false)
		GameState.set_flag("helped_mara_persuasion", false)
		GameState.set_flag("mara_helped", false)
		GameState.set_flag("mara_map_quest_active", false)
		GameState.set_flag("mara_map_recovered", false)
		GameState.set_flag("mara_map_quest_completed", false)
		GameState.set_flag("mara_map_distraction", false)
		GameState.reset_quest(MARA_QUEST_ID)
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


func build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.22, 0.37, 0.52)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.82)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.61)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)


func build_roadside_scene() -> void:
	create_static_box("Ground", Vector3(0.0, -0.55, 0.0), Vector3(34.0, 1.0, 42.0), Color(0.18, 0.3, 0.13))
	create_static_box("Road", Vector3(0.0, 0.01, 0.0), Vector3(7.0, 0.14, 42.0), Color(0.35, 0.28, 0.2))
	create_static_box("RoadEdgeLeft", Vector3(-4.0, 0.16, 0.0), Vector3(1.0, 0.32, 42.0), Color(0.28, 0.34, 0.16))
	create_static_box("RoadEdgeRight", Vector3(4.0, 0.16, 0.0), Vector3(1.0, 0.32, 42.0), Color(0.28, 0.34, 0.16))
	build_broken_cart(Vector3(3.2, 0.65, -4.5))
	build_camp(Vector3(-4.8, 0.0, -5.0))
	for position: Vector3 in [
		Vector3(-10.0, 0.0, -10.0), Vector3(11.0, 0.0, -12.0),
		Vector3(-12.0, 0.0, 5.0), Vector3(12.0, 0.0, 8.0),
		Vector3(-9.0, 0.0, 15.0), Vector3(10.0, 0.0, 16.0),
	]:
		build_tree(position)
	var heading := Label3D.new()
	heading.text = "A STRANDED TRAVELER"
	heading.position = Vector3(0.0, 5.8, -10.0)
	heading.font_size = 54
	heading.pixel_size = 0.008
	heading.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heading.outline_size = 9
	heading.modulate = Color(1.0, 0.82, 0.46)
	add_child(heading)
	result_label = Label3D.new()
	result_label.text = "Mara's cart has lost its iron wheel pin."
	result_label.position = Vector3(3.0, 2.8, -4.5)
	result_label.font_size = 27
	result_label.pixel_size = 0.007
	result_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result_label.outline_size = 7
	result_label.modulate = Color(0.78, 0.88, 1.0)
	add_child(result_label)


func build_traveler() -> void:
	traveler = Area3D.new()
	traveler.name = "MaraRoadsideTraveler"
	traveler.position = Vector3(-0.8, 0.1, -3.8)
	traveler.set_script(ConversationNPCScript)
	traveler.set("display_name", "Mara")
	traveler.set("title", "Traveling Cartographer")
	traveler.set("prompt_text", "Talk to Mara")
	traveler.set("portrait_color", Color(0.88, 0.42, 0.22))
	add_child(traveler)
	var data: Dictionary = {
		"display_name": "Mara",
		"title": "Traveling Cartographer",
		"portrait_color": Color(0.88, 0.42, 0.22),
		"entry": "start",
		"repeat_entry": "after_help",
		"resolved_flag": "mara_helped",
		"entry_rules": [
			{"requires_flag": "mara_map_quest_completed", "node": "after_quest"},
			{"requires_flag": "mara_map_recovered", "node": "quest_return"},
			{"requires_flag": "mara_map_quest_active", "blocked_by_flag": "mara_map_recovered", "node": "quest_active"},
			{"requires_flag": "mara_helped", "node": "after_help"},
		],
		"nodes": {
			"start": {
				"speaker": "Mara",
				"text": "Careful around the wheel. The iron pin sheared clean through, and this cart contains every map I own.",
				"choices": [
					{"id": "ask", "text": "What happened here?", "next": "explain"},
					{
						"id": "supplies",
						"text": "Use a healing flask to treat her injured hand.",
						"next": "supplies_result",
						"requires_item": "healing_flask",
						"item_count": 1,
						"requirement_text": "Healing Flask required",
						"consume_item": "healing_flask",
						"consume_count": 1,
						"set_flag": "helped_mara_supplies",
						"relationship_delta": 2,
						"objective": "Check the repaired cart before continuing down the road.",
					},
					{
						"id": "metal",
						"text": "Shape a new wheel pin with Metal magic.",
						"next": "metal_result",
						"requires_stat": "metal",
						"stat_minimum": 1,
						"requirement_text": "Metal affinity 1 required",
						"set_flag": "helped_mara_metal",
						"relationship_delta": 3,
						"objective": "Check the repaired cart before continuing down the road.",
					},
					{"id": "leave", "text": "I cannot stop right now.", "next": "leave"},
				],
			},
			"explain": {
				"speaker": "Mara",
				"text": "A sound like thunder rolled through the hills. The mule bolted, the cart struck a stone, and the pin snapped. I can repair wood, but I cannot forge iron from grass.",
				"choices": [
					{
						"id": "metal_after_ask",
						"text": "Then I will shape the iron.",
						"next": "metal_result",
						"requires_stat": "metal",
						"stat_minimum": 1,
						"requirement_text": "Metal affinity 1 required",
						"set_flag": "helped_mara_metal",
						"relationship_delta": 3,
						"objective": "Check the repaired cart before continuing down the road.",
					},
					{
						"id": "persuade",
						"text": "Convince her the remaining axle can safely reach town.",
						"next": "persuade_success",
						"requires_stat": "charisma",
						"stat_minimum": 2,
						"requirement_text": "Charisma 2 required",
						"set_flag": "helped_mara_persuasion",
						"relationship_delta": 1,
						"objective": "Continue down the road after advising Mara.",
					},
					{"id": "back", "text": "Let me consider the options.", "next": "start"},
				],
			},
			"supplies_result": {
				"speaker": "Mara",
				"text": "That is far too valuable for a scraped hand... but thank you. With steady fingers I can bind the old pin long enough to reach the smithy.",
				"next": "resolved",
			},
			"metal_result": {
				"speaker": "Mara",
				"text": "You made the iron flow like ribbon. The new pin fits perfectly—and you did it without even heating a forge.",
				"next": "resolved",
			},
			"persuade_success": {
				"speaker": "Mara",
				"text": "You may be right. If I unload the map chest and keep to walking speed, the axle should survive the eastern road.",
				"next": "resolved",
			},
			"resolved": {
				"speaker": "Mara",
				"text": "Take this advice in return: something unnatural is stirring beyond the ridge. If your road leads east, keep your eyes above the clouds.",
				"choices": [
					{
						"id": "finish",
						"text": "Thank you. Travel safely.",
						"set_flag": "mara_helped",
						"relationship_delta": 1,
						"objective": "Continue east and investigate the thunder beyond the ridge.",
					},
				],
			},
			"leave": {
				"speaker": "Mara",
				"text": "I understand. Roads rarely wait for anyone. If you return, I will still be here arguing with this wheel.",
			},
			"after_help": {
				"speaker": "Mara",
				"text": "The repair is holding—but I discovered my eastern map case is missing. A Gremlin dragged it into the camp down the road.",
				"choices": [
					{"id": "accept_map_quest", "text": "I will recover your map case.", "next": "quest_accept"},
					{"id": "ask_road", "text": "What lies beyond the eastern ridge?", "next": "road_warning"},
					{"id": "goodbye", "text": "I cannot help with that yet."},
				],
			},
			"quest_accept": {
				"speaker": "Mara",
				"text": "The sentry is small but vicious. Fight it, lure it from the case, or use that remarkable Metal magic of yours.",
			},
			"quest_active": {
				"speaker": "Mara",
				"text": "The map case is in the Gremlin camp south of the cart. There must be more than one way past that sentry.",
			},
			"quest_return": {
				"speaker": "Mara",
				"text": "You found it! Those maps contain roads that vanished before either of us was born.",
				"choices": [
					{"id": "return_map", "text": "Return Mara's map case.", "next": "return_thanks"},
				],
			},
			"return_thanks": {
				"speaker": "Mara",
				"text": "Keep my annotated eastern chart. It will not reveal every danger, but it may keep you from walking directly into one.",
			},
			"after_quest": {
				"speaker": "Mara",
				"text": "The map case is secure, the cart is sound, and your road east is marked. I would call that a very good meeting.",
			},
			"road_warning": {
				"speaker": "Mara",
				"text": "Old ruins, a narrow pass, and storm clouds that have not moved in three days. None of that belongs together.",
			},
		},
	}
	traveler.call("configure", data)
	traveler.connect("choice_selected", _on_choice_selected)
	traveler.connect("conversation_finished", _on_conversation_finished)


func _on_choice_selected(choice_id: String, _npc: Node) -> void:
	if choice_id == "finish":
		result_label.text = "The cart is roadworthy. Mara has another problem."
		result_label.modulate = Color(0.45, 1.0, 0.68)
	elif choice_id == "accept_map_quest":
		start_map_quest()
	elif choice_id == "return_map":
		complete_map_quest()


func _on_conversation_finished(_npc: Node) -> void:
	if GameState.get_flag("mara_map_quest_completed"):
		show_message("Quest complete: The Cartographer's Missing Map.")
	elif GameState.get_flag("mara_helped"):
		show_message("Speak with Mara again to continue her story.")


func start_map_quest() -> void:
	GameState.set_flag("mara_map_quest_active", true)
	GameState.start_quest(MARA_QUEST_ID, {
		"title": "The Cartographer's Missing Map",
		"description": "Recover Mara's eastern map case from the Gremlin camp.",
		"objective": "Follow the road south to the Gremlin camp.",
		"stage": 0,
		"stages": [
			"Find the Gremlin camp.",
			"Recover the stolen map case.",
			"Return the map case to Mara.",
		],
	})
	GameState.set_objective("Follow the road south to the Gremlin camp.")
	set_guard_active(true)
	show_message("Quest started. Choose combat, distraction, or Metal magic.")


func complete_map_quest() -> void:
	if GameState.get_flag("mara_map_quest_completed"):
		return
	GameState.set_flag("mara_map_quest_completed", true)
	GameState.complete_quest(MARA_QUEST_ID, "Continue east using Mara's annotated chart.")
	GameState.add_key_item("mara_eastern_chart", {
		"name": "Mara's Eastern Chart",
		"kind": "Quest Reward",
		"description": "An annotated road map warning of ruins, storms, and vanished paths beyond the ridge.",
		"source": "The Cartographer's Missing Map",
	})
	result_label.text = "QUEST COMPLETE — MARA'S EASTERN CHART ACQUIRED"
	result_label.modulate = Color(1.0, 0.78, 0.28)
	show_message("Quest complete. Mara's Eastern Chart was added to Key Items.")


func build_quest_journal() -> void:
	var journal := QuestJournalScript.new()
	journal.name = "QuestJournalUI"
	add_child(journal)


func build_quest_field() -> void:
	var discover := create_quest_objective(
		"DiscoverGremlinCamp", Vector3(0.0, 0.0, -13.5), "discover",
		"", "Gremlin camp discovered. The sentry guards Mara's map case.",
		0, 1, "Recover the stolen map case.", "", "found_camp"
	)
	discover.set("one_shot", true)
	distraction = create_quest_objective(
		"NoiseLure", Vector3(-5.0, 0.2, -14.0), "interact",
		"Ring abandoned camp bell", "The bell crashes through the trees. The Gremlin abandons its post.",
		1, -1, "Recover Mara's map case while the sentry is distracted.",
		"mara_map_distraction", "distraction"
	)
	distraction.set("visual_color", Color(0.95, 0.66, 0.18))
	distraction.connect("objective_resolved", _on_distraction_resolved)
	map_case = create_quest_objective(
		"MaraMapCase", Vector3(0.0, 0.25, -17.0), "interact",
		"Recover Mara's map case", "Grace recovers Mara's stolen map case.",
		1, 2, "Return the map case to Mara.", "mara_map_recovered", ""
	)
	map_case.set("blocked_by_guard_group", "mara_quest_guard")
	map_case.set("distraction_flag", "mara_map_distraction")
	map_case.set("visual_color", Color(0.2, 0.72, 1.0))
	metal_recovery = create_quest_objective(
		"MetalRecoveryPoint", Vector3(5.0, 0.25, -11.0), "interact",
		"Pull map case with Metal", "Metal answers Grace's call. The case tears free and sails into her hands.",
		1, 2, "Return the map case to Mara.", "mara_map_recovered", "metal_solution"
	)
	metal_recovery.set("required_stat", "metal")
	metal_recovery.set("required_stat_minimum", 1)
	metal_recovery.set("visual_color", Color(0.72, 0.82, 0.94))
	quest_guard = GremlinScene.instantiate() as CharacterBody3D
	quest_guard.name = "MapCaseGremlin"
	quest_guard.position = Vector3(1.7, 0.8, -15.2)
	quest_guard.add_to_group("mara_quest_guard")
	add_child(quest_guard)
	var receiver: Node = quest_guard.get_node_or_null("HitReceiver")
	if receiver != null:
		receiver.connect("health_depleted", _on_guard_defeated)
	if GameState.get_flag("mara_map_recovered") or GameState.get_flag("mara_map_quest_completed"):
		map_case.visible = false
		metal_recovery.visible = false
		distraction.visible = false
		quest_guard.queue_free()
	elif GameState.get_flag("mara_map_quest_active"):
		set_guard_active(true)
	else:
		set_guard_active(false)


func set_guard_active(active: bool) -> void:
	if quest_guard == null or not is_instance_valid(quest_guard):
		return
	var brain: Node = quest_guard.get_node_or_null("EnemyBrain")
	if brain != null:
		brain.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func create_quest_objective(
	node_name: String,
	position: Vector3,
	mode: String,
	prompt: String,
	message: String,
	required_stage: int,
	next_stage: int,
	next_objective: String,
	flag: String,
	optional_id: String
) -> Area3D:
	var objective := Area3D.new()
	objective.name = node_name
	objective.position = position
	objective.set_script(QuestFieldObjectiveScript)
	objective.set("quest_id", MARA_QUEST_ID)
	objective.set("objective_id", node_name.to_snake_case())
	objective.set("mode", mode)
	objective.set("prompt_text", prompt)
	objective.set("message_text", message)
	objective.set("required_stage", required_stage)
	objective.set("next_stage", next_stage)
	objective.set("next_objective", next_objective)
	objective.set("set_flag", flag)
	objective.set("optional_id", optional_id)
	add_child(objective)
	return objective


func _on_guard_defeated() -> void:
	GameState.complete_quest_optional(MARA_QUEST_ID, "combat")
	show_message("The sentry is defeated. Mara's map case is exposed.")


func _on_distraction_resolved(_objective: Node) -> void:
	if quest_guard != null and is_instance_valid(quest_guard):
		quest_guard.position = Vector3(-9.0, 0.8, -18.0)
		var brain: Node = quest_guard.get_node_or_null("EnemyBrain")
		if brain != null:
			brain.process_mode = Node.PROCESS_MODE_DISABLED


func build_broken_cart(position: Vector3) -> void:
	create_static_box("CartBed", position + Vector3(0.0, 0.75, 0.0), Vector3(3.2, 0.35, 2.0), Color(0.34, 0.17, 0.07))
	for x: float in [-1.25, 1.25]:
		for z: float in [-0.72, 0.72]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.55
			mesh.bottom_radius = 0.55
			mesh.height = 0.22
			wheel.mesh = mesh
			wheel.rotation_degrees.z = 90.0
			wheel.position = position + Vector3(x, 0.5, z)
			wheel.material_override = make_material(Color(0.11, 0.08, 0.05))
			add_child(wheel)
	create_static_box("CartChest", position + Vector3(0.0, 1.25, 0.0), Vector3(1.5, 0.75, 1.2), Color(0.25, 0.12, 0.05))


func build_camp(position: Vector3) -> void:
	for angle_index: int in range(8):
		var angle: float = TAU * float(angle_index) / 8.0
		create_static_box(
			"CampStone" + str(angle_index),
			position + Vector3(cos(angle) * 0.72, 0.18, sin(angle) * 0.72),
			Vector3(0.35, 0.35, 0.35),
			Color(0.32, 0.34, 0.36)
		)
	var fire := OmniLight3D.new()
	fire.position = position + Vector3(0.0, 0.65, 0.0)
	fire.light_color = Color(1.0, 0.42, 0.12)
	fire.light_energy = 2.2
	fire.omni_range = 5.5
	add_child(fire)


func build_tree(position: Vector3) -> void:
	create_static_box("TreeTrunk", position + Vector3(0.0, 1.6, 0.0), Vector3(0.65, 3.2, 0.65), Color(0.24, 0.13, 0.06))
	var crown := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.8
	mesh.height = 3.2
	crown.mesh = mesh
	crown.position = position + Vector3(0.0, 3.9, 0.0)
	crown.material_override = make_material(Color(0.12, 0.3, 0.12))
	add_child(crown)


func create_static_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color)
	body.add_child(mesh_instance)
	return body


func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
