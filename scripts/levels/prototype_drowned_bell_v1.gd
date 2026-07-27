extends Node3D
class_name PrototypeDrownedBellV1

const ConversationNPCScript = preload("res://scripts/dialogue/conversation_npc.gd")
const StoryInteractableScript = preload("res://scripts/interaction/story_interactable.gd")
const AuthoredQuestRuntimeScript = preload("res://scripts/quests/authored_quest_runtime.gd")
const WorldStateVariantScript = preload("res://scripts/quests/world_state_variant.gd")

const QUEST_ID := "the_drowned_bell"
const FLAG_ACCEPTED := "drowned_bell_accepted"
const FLAG_HEARD_PATTERN := "drowned_bell_heard_pattern"
const FLAG_CHAPEL_ENTERED := "drowned_bell_chapel_entered"
const FLAG_COMPLETE := "drowned_bell_complete"

var quest: RefCounted
var chapel_state: RefCounted
var ferryman: Area3D
var bell_marker: Area3D
var objective_label: Label
var status_label: Label
var flooded_state: Node3D
var quiet_state: Node3D


func _ready() -> void:
	quest = AuthoredQuestRuntimeScript.new(QUEST_ID, {
		"title": "The Drowned Bell",
		"description": "Investigate a chapel bell that rings beneath floodwater and discover what is calling through it.",
		"objective": "Speak with Ferryman Orin beside the flooded chapel.",
		"stage": 0,
		"stages": [
			"Speak with Ferryman Orin.",
			"Listen to the bell from the flooded causeway.",
			"Enter the drowned chapel.",
			"Resolve the bell's call and return to Orin.",
		],
	})
	chapel_state = WorldStateVariantScript.new()
	build_environment()
	build_ferryman()
	build_bell_marker()
	build_hud()
	apply_saved_state()


func build_environment() -> void:
	var world := $World
	add_static_box(world, "Shore", Vector3(30, 0.8, 24), Vector3(0, -0.4, -4), Color(0.18, 0.22, 0.16))
	add_static_box(world, "Causeway", Vector3(5, 0.5, 24), Vector3(0, -0.05, 13), Color(0.32, 0.32, 0.28))
	add_static_box(world, "ChapelFloor", Vector3(15, 0.8, 14), Vector3(0, -0.4, 29), Color(0.28, 0.29, 0.28))
	for side: float in [-1.0, 1.0]:
		add_static_box(world, "ChapelWall", Vector3(0.8, 6.0, 14), Vector3(side * 7.1, 3.0, 29), Color(0.2, 0.2, 0.19))
	add_static_box(world, "ChapelBack", Vector3(15, 6.0, 0.8), Vector3(0, 3.0, 35.6), Color(0.2, 0.2, 0.19))
	add_static_box(world, "ChapelArch", Vector3(15, 1.0, 1.2), Vector3(0, 5.8, 22.4), Color(0.23, 0.23, 0.21))
	add_visual_cylinder(world, "BellTower", 1.7, 8.0, Vector3(0, 4.0, 31.0), Color(0.19, 0.2, 0.2))
	add_visual_cylinder(world, "DrownedBell", 0.8, 1.4, Vector3(0, 3.0, 31.0), Color(0.39, 0.31, 0.13), Vector3(PI / 2.0, 0, 0))

	flooded_state = Node3D.new()
	flooded_state.name = "FloodedState"
	world.add_child(flooded_state)
	add_visual_box(flooded_state, "Floodwater", Vector3(22, 0.28, 34), Vector3(0, 0.55, 20), Color(0.08, 0.25, 0.34, 0.72))
	for index: int in range(8):
		add_visual_box(flooded_state, "WaterBand%02d" % index, Vector3(18, 0.03, 0.22), Vector3(0, 0.72, 7.0 + index * 3.4), Color(0.18, 0.56, 0.7, 0.75))

	quiet_state = Node3D.new()
	quiet_state.name = "QuietState"
	quiet_state.visible = false
	world.add_child(quiet_state)
	add_visual_box(quiet_state, "LowWater", Vector3(18, 0.16, 18), Vector3(0, 0.18, 23), Color(0.08, 0.2, 0.26, 0.55))
	add_visual_box(quiet_state, "ExposedSteps", Vector3(4.2, 0.4, 6), Vector3(0, 0.2, 25), Color(0.33, 0.33, 0.29))

	var flooded_nodes: Array[Node] = [flooded_state]
	var quiet_nodes: Array[Node] = [quiet_state]
	chapel_state.call("register_variant", "flooded", flooded_nodes)
	chapel_state.call("register_variant", "quiet", quiet_nodes)
	add_world_label("THE DROWNED CHAPEL", Vector3(0, 8.4, 30), Color(0.63, 0.82, 0.92), 30)


func build_ferryman() -> void:
	ferryman = Area3D.new()
	ferryman.name = "FerrymanOrin"
	ferryman.position = Vector3(-4.8, 0.1, -3.0)
	ferryman.set_script(ConversationNPCScript)
	ferryman.set("display_name", "Orin")
	ferryman.set("title", "Marsh Ferryman")
	ferryman.set("prompt_text", "Talk to Orin")
	ferryman.set("portrait_color", Color(0.24, 0.48, 0.58))
	add_child(ferryman)
	ferryman.call("configure", {
		"display_name": "Orin",
		"title": "Marsh Ferryman",
		"portrait_color": Color(0.24, 0.48, 0.58),
		"entry": "start",
		"entry_rules": [
			{"requires_flag": FLAG_COMPLETE, "node": "after"},
			{"requires_flag": FLAG_CHAPEL_ENTERED, "node": "inside"},
			{"requires_flag": FLAG_HEARD_PATTERN, "node": "heard"},
			{"requires_flag": FLAG_ACCEPTED, "node": "accepted"},
		],
		"nodes": {
			"start": {
				"speaker": "Orin",
				"text": "The chapel bell has been underwater for twelve years. It began ringing three nights ago. No wind, no rope, and no living hand inside.",
				"choices": [
					{"id": "ask_flood", "text": "Why was the chapel abandoned?", "next": "history"},
					{"id": "accept", "text": "I will listen to the bell and investigate.", "set_flag": FLAG_ACCEPTED, "relationship_delta": 2},
					{"id": "leave", "text": "Not yet."},
				],
			},
			"history": {
				"speaker": "Orin",
				"text": "The river changed course after a landslide. The village moved uphill, but the chapel stayed where its dead were buried. We stopped crossing when the water reached the altar.",
				"choices": [
					{"id": "accept_after_history", "text": "Then I will find what woke it.", "set_flag": FLAG_ACCEPTED, "relationship_delta": 2},
					{"id": "back", "text": "Tell me again about the bell.", "next": "start"},
				],
			},
			"accepted": {"speaker": "Orin", "text": "Stand on the old causeway and listen before you enter. A bell speaks differently through water. The pattern matters."},
			"heard": {"speaker": "Orin", "text": "Two low notes and one high. That was the burial signal, but the last note is wrong. Something beneath the chapel is answering it."},
			"inside": {"speaker": "Orin", "text": "You reached the nave. Whatever is ringing knows the old burial call now. Do not let it teach itself another."},
			"after": {"speaker": "Orin", "text": "The marsh is quiet again. I had forgotten how silence carries across open water."},
		},
	})
	ferryman.connect("choice_selected", _on_ferryman_choice)


func build_bell_marker() -> void:
	bell_marker = Area3D.new()
	bell_marker.name = "BellListeningPoint"
	bell_marker.position = Vector3(0, 0.2, 10.0)
	bell_marker.set_script(StoryInteractableScript)
	bell_marker.set("prompt_text", "Listen to the drowned bell")
	bell_marker.set("required_flag", FLAG_ACCEPTED)
	bell_marker.set("blocked_flag", FLAG_HEARD_PATTERN)
	add_child(bell_marker)
	bell_marker.connect("activated", _on_bell_listened)
	add_visual_cylinder(bell_marker, "ListeningRing", 1.6, 0.08, Vector3(0, 0.08, 0), Color(0.28, 0.66, 0.82), Vector3(PI / 2.0, 0, 0))


func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DrownedBellHUD"
	layer.layer = 25
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(720, 122)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "THE DROWNED BELL"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 17)
	box.add_child(objective_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	box.add_child(status_label)


func _on_ferryman_choice(choice_id: String, _npc: Node) -> void:
	if choice_id in ["accept", "accept_after_history"]:
		GameState.set_flag(FLAG_ACCEPTED, true)
		quest.call("ensure_started")
		quest.call("set_stage", 1, "Listen to the drowned bell from the old causeway.")
		refresh_hud("QUEST STARTED  •  The bell is ringing beneath the floodwater.")


func _on_bell_listened(_interactable: Node) -> void:
	GameState.set_flag(FLAG_HEARD_PATTERN, true)
	quest.call("set_stage", 2, "Enter the drowned chapel and trace the false burial signal.")
	refresh_hud("BELL PATTERN HEARD  •  Two low notes, then one impossibly high reply.")


func apply_saved_state() -> void:
	if GameState.get_flag(FLAG_COMPLETE):
		chapel_state.call("apply", "quiet")
		quest.call("complete", "The Drowned Bell is silent. Return to the road when ready.")
	elif GameState.get_flag(FLAG_ACCEPTED):
		chapel_state.call("apply", "flooded")
		quest.call("ensure_started")
	else:
		chapel_state.call("apply", "flooded")
	refresh_hud()


func refresh_hud(status: String = "") -> void:
	if objective_label == null:
		return
	objective_label.text = "OBJECTIVE  •  " + GameState.current_objective
	if status != "":
		status_label.text = status
	elif GameState.get_flag(FLAG_HEARD_PATTERN):
		status_label.text = "The burial signal is being answered from inside the chapel."
	elif GameState.get_flag(FLAG_ACCEPTED):
		status_label.text = "The listening point is active on the old causeway."
	else:
		status_label.text = "Speak with Orin beside the marsh road."


func add_static_box(parent: Node, node_name: String, size: Vector3, position_value: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material(color)
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func add_visual_box(parent: Node, node_name: String, size: Vector3, position_value: Vector3, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material(color)
	parent.add_child(mesh_instance)
	return mesh_instance


func add_visual_cylinder(parent: Node, node_name: String, radius: float, height: float, position_value: Vector3, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.rotation = rotation_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material(color)
	parent.add_child(mesh_instance)
	return mesh_instance


func add_world_label(text_value: String, position_value: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = font_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	$World.add_child(label)
	return label


func material(color: Color) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.86
	if color.a < 1.0:
		value.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return value
