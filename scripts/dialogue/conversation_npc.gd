extends Area3D
class_name ConversationNPC

signal conversation_started(npc: ConversationNPC)
signal conversation_finished(npc: ConversationNPC)
signal choice_selected(choice_id: String, npc: ConversationNPC)

@export var display_name: String = "Traveler"
@export var title: String = "Roadside Traveler"
@export var prompt_text: String = "Talk"
@export var portrait_color: Color = Color(0.94, 0.62, 0.28)
@export_range(-5, 5, 1) var starting_relationship: int = 0

var conversation_data: Dictionary = {}
var current_node_id: String = ""
var selected_choice: int = 0
var relationship: int = 0
var conversation_open: bool = false
var history_open: bool = false
var history: Array[String] = []
var visible_choices: Array[Dictionary] = []
var previous_camera_fov: float = 70.0
var active_camera: Camera3D

var layer: CanvasLayer
var backdrop: ColorRect
var dialogue_panel: PanelContainer
var speaker_label: Label
var title_label: Label
var body_label: RichTextLabel
var relationship_label: Label
var choices_box: VBoxContainer
var hint_label: Label
var history_panel: PanelContainer
var history_label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("interactable_target")
	add_to_group("conversation_npc")
	add_to_group("debuggable")
	relationship = starting_relationship
	ensure_collision()
	build_visual()
	build_dialogue_ui()
	ensure_dialogue_inputs()


func configure(data: Dictionary) -> void:
	conversation_data = data.duplicate(true)
	if conversation_data.has("display_name"):
		display_name = str(conversation_data["display_name"])
	if conversation_data.has("title"):
		title = str(conversation_data["title"])
	if conversation_data.has("portrait_color"):
		portrait_color = conversation_data["portrait_color"]
	if is_node_ready():
		update_visual_colors()


func interact() -> Dictionary:
	if conversation_open:
		return {}
	call_deferred("begin_conversation")
	return {}


func begin_conversation() -> void:
	if conversation_open or conversation_data.is_empty():
		return
	conversation_open = true
	history_open = false
	selected_choice = 0
	current_node_id = resolve_entry_node()
	active_camera = get_viewport().get_camera_3d()
	if active_camera != null:
		previous_camera_fov = active_camera.fov
		active_camera.fov = 58.0
	face_player()
	get_tree().paused = true
	layer.visible = true
	history_panel.visible = false
	show_node(current_node_id)
	conversation_started.emit(self)


func end_conversation() -> void:
	if not conversation_open:
		return
	conversation_open = false
	layer.visible = false
	history_panel.visible = false
	if active_camera != null and is_instance_valid(active_camera):
		active_camera.fov = previous_camera_fov
	active_camera = null
	get_tree().paused = false
	conversation_finished.emit(self)


func _input(event: InputEvent) -> void:
	if not conversation_open or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("dialogue_history"):
		history_open = not history_open
		history_panel.visible = history_open
		update_history()
		get_viewport().set_input_as_handled()
		return
	if history_open:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			history_open = false
			history_panel.visible = false
			get_viewport().set_input_as_handled()
		return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		end_conversation()
		get_viewport().set_input_as_handled()
		return
	if not visible_choices.is_empty():
		if event.is_action_pressed("ui_up"):
			selected_choice = wrapi(selected_choice - 1, 0, visible_choices.size())
			update_choice_highlight()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down"):
			selected_choice = wrapi(selected_choice + 1, 0, visible_choices.size())
			update_choice_highlight()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			select_current_choice()
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		advance_from_current_node()
		get_viewport().set_input_as_handled()


func resolve_entry_node() -> String:
	var resolved_flag: String = str(conversation_data.get("resolved_flag", ""))
	if resolved_flag != "" and GameState.get_flag(resolved_flag):
		return str(conversation_data.get("repeat_entry", "start"))
	return str(conversation_data.get("entry", "start"))


func show_node(node_id: String) -> void:
	var nodes: Dictionary = conversation_data.get("nodes", {})
	if not nodes.has(node_id):
		end_conversation()
		return
	current_node_id = node_id
	var node: Dictionary = nodes[node_id] as Dictionary
	var speaker: String = str(node.get("speaker", display_name))
	var text: String = str(node.get("text", "..."))
	speaker_label.text = speaker.to_upper()
	title_label.text = title
	body_label.text = text
	append_history(speaker, text)
	visible_choices.clear()
	for child: Node in choices_box.get_children():
		child.free()
	var choices_variant: Variant = node.get("choices", [])
	if choices_variant is Array:
		for choice_variant: Variant in choices_variant:
			if choice_variant is Dictionary:
				visible_choices.append((choice_variant as Dictionary).duplicate(true))
	selected_choice = clampi(selected_choice, 0, maxi(visible_choices.size() - 1, 0))
	if visible_choices.is_empty():
		hint_label.text = "A / Enter  Continue     B / Esc  Leave     LB / H  History"
	else:
		hint_label.text = "Up / Down  Choose     A / Enter  Confirm     B / Esc  Leave     LB / H  History"
		build_choice_rows()


func build_choice_rows() -> void:
	for index: int in range(visible_choices.size()):
		var choice: Dictionary = visible_choices[index]
		var row := Label.new()
		row.name = "Choice" + str(index)
		row.custom_minimum_size = Vector2(0.0, 38.0)
		row.add_theme_font_size_override("font_size", 20)
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.text = choice_display_text(choice)
		choices_box.add_child(row)
	update_choice_highlight()


func update_choice_highlight() -> void:
	for index: int in range(choices_box.get_child_count()):
		var row: Label = choices_box.get_child(index) as Label
		if row == null:
			continue
		if index == selected_choice:
			row.text = "◆  " + choice_display_text(visible_choices[index])
			row.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
		else:
			row.text = "   " + choice_display_text(visible_choices[index])
			row.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9))


func choice_display_text(choice: Dictionary) -> String:
	var text: String = str(choice.get("text", "Continue"))
	if choice_is_available(choice):
		return text
	var requirement: String = str(choice.get("requirement_text", "Unavailable"))
	return text + "  [" + requirement + "]"


func choice_is_available(choice: Dictionary) -> bool:
	var required_flag: String = str(choice.get("requires_flag", ""))
	if required_flag != "" and not GameState.get_flag(required_flag):
		return false
	var blocked_flag: String = str(choice.get("blocked_by_flag", ""))
	if blocked_flag != "" and GameState.get_flag(blocked_flag):
		return false
	var item_id: String = str(choice.get("requires_item", ""))
	var item_count: int = int(choice.get("item_count", 1))
	if item_id != "" and GameState.get_inventory_count(item_id) < item_count:
		return false
	var stat_id: String = str(choice.get("requires_stat", ""))
	var stat_minimum: int = int(choice.get("stat_minimum", 0))
	if stat_id != "" and GameState.get_stat(stat_id) < stat_minimum:
		return false
	return true


func select_current_choice() -> void:
	if selected_choice < 0 or selected_choice >= visible_choices.size():
		return
	var choice: Dictionary = visible_choices[selected_choice]
	if not choice_is_available(choice):
		var requirement: String = str(choice.get("requirement_text", "That option is unavailable."))
		body_label.text = requirement
		return
	var choice_text: String = str(choice.get("text", "Continue"))
	append_history("Grace", choice_text)
	apply_choice_effects(choice)
	choice_selected.emit(str(choice.get("id", "")), self)
	var next_id: String = str(choice.get("next", ""))
	if next_id == "":
		end_conversation()
	else:
		show_node(next_id)


func apply_choice_effects(choice: Dictionary) -> void:
	var consume_item: String = str(choice.get("consume_item", ""))
	if consume_item != "":
		GameState.consume_inventory_item(consume_item, int(choice.get("consume_count", 1)))
	var grant_item: String = str(choice.get("grant_item", ""))
	if grant_item != "":
		GameState.add_inventory_item(grant_item, int(choice.get("grant_count", 1)))
	var set_flag: String = str(choice.get("set_flag", ""))
	if set_flag != "":
		GameState.set_flag(set_flag, true)
	var objective: String = str(choice.get("objective", ""))
	if objective != "":
		GameState.set_objective(objective)
	var relationship_delta: int = int(choice.get("relationship_delta", 0))
	if relationship_delta != 0:
		relationship += relationship_delta
		update_relationship_label()


func advance_from_current_node() -> void:
	var nodes: Dictionary = conversation_data.get("nodes", {})
	if not nodes.has(current_node_id):
		end_conversation()
		return
	var node: Dictionary = nodes[current_node_id] as Dictionary
	var next_id: String = str(node.get("next", ""))
	if next_id == "":
		end_conversation()
	else:
		show_node(next_id)


func append_history(speaker: String, text: String) -> void:
	var entry: String = "[color=#f3c35d]" + speaker + "[/color]\n" + text
	if history.is_empty() or history.back() != entry:
		history.append(entry)
	while history.size() > 24:
		history.pop_front()


func update_history() -> void:
	var transcript: String = ""
	for entry: String in history:
		if transcript != "":
			transcript += "\n\n"
		transcript += entry
	history_label.text = transcript


func face_player() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var target: Vector3 = player.global_position
	target.y = global_position.y
	if global_position.distance_squared_to(target) > 0.01:
		look_at(target, Vector3.UP)


func ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.75
	shape.height = 2.4
	collision.shape = shape
	collision.position.y = 1.0
	add_child(collision)


func build_visual() -> void:
	if get_node_or_null("Visual") != null:
		return
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.48
	body_mesh.height = 1.45
	body.mesh = body_mesh
	body.position.y = 0.95
	visual.add_child(body)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.34
	head_mesh.height = 0.68
	head.mesh = head_mesh
	head.position.y = 1.95
	visual.add_child(head)
	var pack := MeshInstance3D.new()
	pack.name = "TravelPack"
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.7, 0.85, 0.36)
	pack.mesh = pack_mesh
	pack.position = Vector3(0.0, 1.05, 0.43)
	visual.add_child(pack)
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = display_name
	label.position = Vector3(0.0, 2.72, 0.0)
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = Color(1.0, 0.9, 0.65)
	visual.add_child(label)
	update_visual_colors()


func update_visual_colors() -> void:
	var visual: Node = get_node_or_null("Visual")
	if visual == null:
		return
	var body: MeshInstance3D = visual.get_node_or_null("Body") as MeshInstance3D
	var head: MeshInstance3D = visual.get_node_or_null("Head") as MeshInstance3D
	var pack: MeshInstance3D = visual.get_node_or_null("TravelPack") as MeshInstance3D
	var label: Label3D = visual.get_node_or_null("NameLabel") as Label3D
	if body != null:
		body.material_override = make_material(portrait_color.darkened(0.28))
	if head != null:
		head.material_override = make_material(Color(0.62, 0.39, 0.26))
	if pack != null:
		pack.material_override = make_material(Color(0.19, 0.13, 0.09))
	if label != null:
		label.text = display_name


func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material


func build_dialogue_ui() -> void:
	layer = CanvasLayer.new()
	layer.name = "ConversationUI"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.visible = false
	add_child(layer)
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.015, 0.025, 0.28)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	dialogue_panel = PanelContainer.new()
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_panel.position = Vector2(-540.0, -365.0)
	dialogue_panel.custom_minimum_size = Vector2(1080.0, 320.0)
	dialogue_panel.add_theme_stylebox_override("panel", panel_style(Color(0.035, 0.045, 0.07, 0.97), portrait_color))
	layer.add_child(dialogue_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	dialogue_panel.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 9)
	margin.add_child(root_box)
	var header := HBoxContainer.new()
	root_box.add_child(header)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 25)
	speaker_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.32))
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(speaker_label)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.69, 0.78))
	header.add_child(title_label)
	relationship_label = Label.new()
	relationship_label.add_theme_font_size_override("font_size", 16)
	relationship_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.72))
	header.add_child(relationship_label)
	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = true
	body_label.custom_minimum_size = Vector2(0.0, 72.0)
	body_label.add_theme_font_size_override("normal_font_size", 22)
	body_label.add_theme_color_override("default_color", Color(0.93, 0.94, 0.96))
	root_box.add_child(body_label)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 2)
	root_box.add_child(choices_box)
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.52, 0.62, 0.72))
	root_box.add_child(hint_label)
	build_history_panel()
	update_relationship_label()


func build_history_panel() -> void:
	history_panel = PanelContainer.new()
	history_panel.visible = false
	history_panel.set_anchors_preset(Control.PRESET_CENTER)
	history_panel.position = Vector2(-430.0, -300.0)
	history_panel.custom_minimum_size = Vector2(860.0, 600.0)
	history_panel.add_theme_stylebox_override("panel", panel_style(Color(0.025, 0.032, 0.052, 0.99), Color(0.38, 0.65, 0.86)))
	layer.add_child(history_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	history_panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "CONVERSATION HISTORY"
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", Color(0.65, 0.86, 1.0))
	box.add_child(heading)
	history_label = RichTextLabel.new()
	history_label.bbcode_enabled = true
	history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_label.add_theme_font_size_override("normal_font_size", 18)
	box.add_child(history_label)
	var close_hint := Label.new()
	close_hint.text = "B / Esc / Interact  Close"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.add_theme_color_override("font_color", Color(0.55, 0.64, 0.74))
	box.add_child(close_hint)


func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style


func update_relationship_label() -> void:
	if relationship_label == null:
		return
	if relationship > 0:
		relationship_label.text = "   TRUST +" + str(relationship)
	elif relationship < 0:
		relationship_label.text = "   TRUST " + str(relationship)
	else:
		relationship_label.text = ""


func ensure_dialogue_inputs() -> void:
	if not InputMap.has_action("dialogue_history"):
		InputMap.add_action("dialogue_history", 0.2)
	var has_h: bool = false
	var has_shoulder: bool = false
	for event: InputEvent in InputMap.action_get_events("dialogue_history"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_H:
			has_h = true
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER:
			has_shoulder = true
	if not has_h:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_H
		InputMap.action_add_event("dialogue_history", key_event)
	if not has_shoulder:
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("dialogue_history", joy_event)


func get_debug_data() -> Dictionary:
	return {
		"conversation_open": conversation_open,
		"node": current_node_id,
		"relationship": relationship,
		"history_entries": history.size(),
	}
