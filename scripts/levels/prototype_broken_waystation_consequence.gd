extends "res://scripts/levels/prototype_broken_waystation_relay_response.gd"
class_name PrototypeBrokenWaystationConsequence

const QUEST_ID := "broken_waystation_relay_response"
const FLAG_COMPLETE := "broken_waystation_quest_complete"
const PRISM_ITEM_ID := "cracked_false_signal_prism"
const CHART_ITEM_ID := "tamsin_eastern_route_chart"

var aftermath_root: Node3D
var eastern_gate_closed: Node3D
var eastern_gate_open: Node3D
var packed_camp: Node3D
var supply_cache: Node3D
var completion_layer: CanvasLayer
var completion_panel: PanelContainer
var completion_summary: RichTextLabel
var completion_pending := false


func _ready() -> void:
	super._ready()
	build_aftermath_world_state()
	build_completion_screen()
	configure_consequence_dialogue()
	apply_consequence_saved_state()
	ensure_existing_quest_state()


func _unhandled_input(event: InputEvent) -> void:
	if completion_layer != null and completion_layer.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			completion_layer.visible = false
			get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func configure_consequence_dialogue() -> void:
	if tamsin == null or tamsin.conversation_data.is_empty():
		return
	var data: Dictionary = tamsin.conversation_data.duplicate(true)
	var nodes: Dictionary = data.get("nodes", {})
	var return_text := "That prism is not one of ours. " + get_repair_callback() + " See the dark thread trapped inside the glass? Someone taught the relay to answer a signal it should never recognize."
	if nodes.has("prism_return"):
		var prism_node: Dictionary = nodes["prism_return"]
		prism_node["text"] = return_text
		nodes["prism_return"] = prism_node
	if nodes.has("after_return"):
		var after_node: Dictionary = nodes["after_return"]
		after_node["text"] = get_post_quest_dialogue()
		nodes["after_return"] = after_node
	data["nodes"] = nodes
	tamsin.call("configure", data)


func get_repair_callback() -> String:
	if GameState.get_flag(FLAG_METAL):
		return "The new signal arm you shaped is steady, so this false reply did not come from our mechanism."
	if GameState.get_flag(FLAG_EARTH):
		return "The foundation you raised never shifted, so the false reply came from farther east."
	if GameState.get_flag(FLAG_LIGHTNING):
		return "The current you restored was clean; this corruption entered through the answering post."
	return "Our restored relay carried the signal correctly."


func get_post_quest_dialogue() -> String:
	var method_line := get_repair_callback()
	var conduit_line := (
		"Disabling the eastern conduit probably kept the corruption from spreading."
		if GameState.get_flag(FLAG_CONDUIT_DISABLED)
		else "I have marked the eastern conduit as dangerous until another keeper can dismantle it."
	)
	var overlook_line := (
		"Your survey from the overlook also confirmed the old mountain road is still intact."
		if GameState.get_flag(FLAG_SPACE_OVERLOOK)
		else "The old survey overlook remains unchecked, but the main road is open."
	)
	return method_line + " " + conduit_line + " " + overlook_line + " The chart is yours. The ridge will remember who reopened it."


func _on_tamsin_choice(choice_id: String, npc: Node) -> void:
	super._on_tamsin_choice(choice_id, npc)
	if choice_id in ["accept_investigation", "accept_after_warning"]:
		start_relay_response_quest()
	elif choice_id == "return_prism":
		complete_relay_response_quest()


func _on_tamsin_finished(npc: Node) -> void:
	super._on_tamsin_finished(npc)
	if completion_pending:
		completion_pending = false
		call_deferred("show_completion_screen")


func start_relay_response_quest() -> void:
	if not GameState.get_quest(QUEST_ID).is_empty():
		return
	GameState.start_quest(QUEST_ID, {
		"title": "The Relay Response",
		"description": "Trace the false eastern reply, secure the abandoned relay, and return its cracked signal prism to Tamsin.",
		"objective": "Follow the blue signal stakes to the abandoned eastern relay.",
		"stage": 0,
		"stages": [
			"Follow the signal trail.",
			"Secure the abandoned eastern relay.",
			"Recover the cracked signal prism.",
			"Return the evidence to Tamsin.",
		],
	})


func start_remote_encounter() -> void:
	super.start_remote_encounter()
	if not GameState.get_quest(QUEST_ID).is_empty():
		GameState.set_quest_stage(QUEST_ID, 1, "Secure the abandoned eastern relay.")


func finish_remote_encounter() -> void:
	super.finish_remote_encounter()
	if not GameState.get_quest(QUEST_ID).is_empty():
		GameState.set_quest_stage(QUEST_ID, 2, "Recover the cracked signal prism.")


func _on_prism_activated(interactable: Node) -> void:
	super._on_prism_activated(interactable)
	GameState.add_key_item(PRISM_ITEM_ID, {
		"name": "Cracked False-Signal Prism",
		"kind": "Quest Evidence",
		"description": "A violet signal prism threaded with a dark elemental filament. It forced an abandoned relay to imitate a waykeeper distress response.",
		"source": "The Relay Response",
	})
	if not GameState.get_quest(QUEST_ID).is_empty():
		GameState.set_quest_stage(QUEST_ID, 3, "Return the cracked signal prism to Tamsin.")


func complete_relay_response_quest() -> void:
	if GameState.get_flag(FLAG_COMPLETE):
		return
	GameState.set_flag(FLAG_COMPLETE, true)
	GameState.complete_quest(QUEST_ID, "Continue east using Tamsin's annotated ridge chart.")
	GameState.add_key_item(CHART_ITEM_ID, {
		"name": "Tamsin's Eastern Ridge Chart",
		"kind": "Quest Reward",
		"description": "A waykeeper's chart marking relay posts, shelters, the old survey overlook, and the safest remaining road beyond the ridge.",
		"source": "The Relay Response",
	})
	apply_completed_aftermath()
	completion_pending = true
	set_objective("The Relay Response complete. Continue east when ready.")


func ensure_existing_quest_state() -> void:
	if GameState.get_flag(FLAG_COMPLETE):
		return
	if GameState.get_flag(FLAG_INVESTIGATION) and GameState.get_quest(QUEST_ID).is_empty():
		start_relay_response_quest()
	if GameState.get_flag(FLAG_PRISM_RECOVERED) and not GameState.get_quest(QUEST_ID).is_empty():
		GameState.set_quest_stage(QUEST_ID, 3, "Return the cracked signal prism to Tamsin.")


func build_aftermath_world_state() -> void:
	aftermath_root = Node3D.new()
	aftermath_root.name = "QuestAftermath"
	$World.add_child(aftermath_root)
	var gate_origin := Vector3(0, 0, 16.2)
	eastern_gate_closed = Node3D.new()
	eastern_gate_closed.name = "ClosedEasternGate"
	eastern_gate_closed.position = gate_origin
	aftermath_root.add_child(eastern_gate_closed)
	for side: float in [-1.0, 1.0]:
		add_static_box(eastern_gate_closed, "GatePost", Vector3(0.7, 3.6, 0.7), Vector3(side * 2.8, 1.8, 0), Color(0.31, 0.23, 0.13))
		add_visual_box(eastern_gate_closed, "ClosedDoor", Vector3(2.7, 2.8, 0.3), Vector3(side * 1.35, 1.4, 0), Color(0.38, 0.25, 0.11))
	eastern_gate_open = Node3D.new()
	eastern_gate_open.name = "OpenEasternGate"
	eastern_gate_open.position = gate_origin
	eastern_gate_open.visible = false
	aftermath_root.add_child(eastern_gate_open)
	for side: float in [-1.0, 1.0]:
		add_visual_box(eastern_gate_open, "OpenDoor", Vector3(2.7, 2.8, 0.3), Vector3(side * 3.7, 1.4, 0.5), Color(0.38, 0.25, 0.11), Vector3(0, side * 0.85, 0))
	packed_camp = Node3D.new()
	packed_camp.name = "PackedRepairCamp"
	packed_camp.position = Vector3(-6.2, 0, -4.5)
	packed_camp.visible = false
	aftermath_root.add_child(packed_camp)
	add_visual_box(packed_camp, "RolledCanvas", Vector3(2.8, 0.55, 0.55), Vector3(0, 0.35, 0), Color(0.44, 0.34, 0.2), Vector3(0, 0, PI / 2.0))
	add_visual_box(packed_camp, "ToolCrate", Vector3(1.5, 0.8, 1.0), Vector3(1.6, 0.4, 0), Color(0.16, 0.31, 0.34))
	supply_cache = Node3D.new()
	supply_cache.name = "WaykeeperSupplyCache"
	supply_cache.position = Vector3(5.2, 0, -8.0)
	supply_cache.visible = false
	aftermath_root.add_child(supply_cache)
	add_static_box(supply_cache, "SupplyChest", Vector3(2.2, 1.15, 1.5), Vector3(0, 0.58, 0), Color(0.35, 0.22, 0.09))
	add_world_label("WAYKEEPER SUPPLIES", Vector3(5.2, 2.0, -8.0), Color(0.55, 0.94, 0.72), 23)


func apply_consequence_saved_state() -> void:
	if GameState.get_flag(FLAG_COMPLETE):
		apply_completed_aftermath()


func apply_completed_aftermath() -> void:
	if eastern_gate_closed != null:
		eastern_gate_closed.visible = false
	if eastern_gate_open != null:
		eastern_gate_open.visible = true
	if packed_camp != null:
		packed_camp.visible = true
	if supply_cache != null:
		supply_cache.visible = true
	var repair_camp := get_node_or_null("World/RepairCamp")
	if repair_camp != null:
		repair_camp.visible = false
	if remote_light != null:
		remote_light.light_color = Color(0.35, 0.76, 1.0)
		remote_light.light_energy = 0.45
	if response_label != null:
		response_label.text = "EASTERN ROAD SECURED"
		response_label.modulate = Color(0.45, 0.9, 1.0)
	status_label.text = "QUEST COMPLETE  •  Eastern gate open  •  Route chart recorded"


func build_completion_screen() -> void:
	completion_layer = CanvasLayer.new()
	completion_layer.name = "QuestCompletionScreen"
	completion_layer.layer = 95
	completion_layer.visible = false
	completion_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(completion_layer)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.02, 0.035, 0.62)
	completion_layer.add_child(backdrop)
	completion_panel = PanelContainer.new()
	completion_panel.set_anchors_preset(Control.PRESET_CENTER)
	completion_panel.position = Vector2(-410, -255)
	completion_panel.custom_minimum_size = Vector2(820, 510)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.98)
	style.border_color = Color(0.36, 0.78, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	completion_panel.add_theme_stylebox_override("panel", style)
	completion_layer.add_child(completion_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	completion_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "QUEST COMPLETE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	box.add_child(heading)
	var title := Label.new()
	title.text = "THE RELAY RESPONSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	box.add_child(title)
	completion_summary = RichTextLabel.new()
	completion_summary.bbcode_enabled = true
	completion_summary.fit_content = true
	completion_summary.custom_minimum_size = Vector2(0, 300)
	completion_summary.add_theme_font_size_override("normal_font_size", 20)
	box.add_child(completion_summary)
	var hint := Label.new()
	hint.text = "A / Enter / Interact  Continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.62, 0.72, 0.8))
	box.add_child(hint)


func show_completion_screen() -> void:
	completion_summary.text = build_completion_summary()
	completion_layer.visible = true


func build_completion_summary() -> String:
	var repair := "Metal arm reconstruction" if GameState.get_flag(FLAG_METAL) else ("Earth foundation reinforcement" if GameState.get_flag(FLAG_EARTH) else "Lightning conduit restoration")
	var conduit := "Disabled before the final confrontation" if GameState.get_flag(FLAG_CONDUIT_DISABLED) else "Left active and marked for dismantling"
	var overlook := "Surveyed through Space" if GameState.get_flag(FLAG_SPACE_OVERLOOK) else "Not surveyed"
	return "[color=#9bdcff]Waystation repair[/color]\n" + repair + "\n\n[color=#9bdcff]Eastern conduit[/color]\n" + conduit + "\n\n[color=#9bdcff]Old overlook[/color]\n" + overlook + "\n\n[color=#ffd36b]Rewards[/color]\nTamsin's Eastern Ridge Chart\nCracked False-Signal Prism recorded as evidence\nSword mastery +10\nEastern gate opened"
