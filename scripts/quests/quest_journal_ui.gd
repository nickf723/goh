extends CanvasLayer
class_name QuestJournalUI

var panel: PanelContainer
var title_label: Label
var content_label: RichTextLabel
var hint_label: Label
var journal_open: bool = false


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("quest_journal")
	ensure_input()
	build_ui()
	GameState.quest_changed.connect(_on_quest_changed)


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("quest_journal"):
		if conversation_is_open():
			return
		if journal_open:
			close_journal()
		else:
			open_journal()
		get_viewport().set_input_as_handled()
		return
	if journal_open and event.is_action_pressed("ui_cancel"):
		close_journal()
		get_viewport().set_input_as_handled()


func open_journal() -> void:
	journal_open = true
	refresh()
	panel.visible = true
	get_tree().paused = true


func close_journal() -> void:
	journal_open = false
	panel.visible = false
	get_tree().paused = false


func conversation_is_open() -> bool:
	for npc: Node in get_tree().get_nodes_in_group("conversation_npc"):
		if bool(npc.get("conversation_open")):
			return true
	return false


func refresh() -> void:
	var active: Array[Dictionary] = GameState.get_quest_rows("active")
	var completed: Array[Dictionary] = GameState.get_quest_rows("completed")
	var text: String = ""
	if active.is_empty():
		text += "[color=#8b98a8]No active quests.[/color]\n"
	else:
		text += "[color=#f2c55c][font_size=22]ACTIVE[/font_size][/color]\n\n"
		for quest: Dictionary in active:
			text += quest_card(quest, false) + "\n\n"
	if not completed.is_empty():
		text += "[color=#65d69a][font_size=22]COMPLETED[/font_size][/color]\n\n"
		for quest: Dictionary in completed:
			text += quest_card(quest, true) + "\n\n"
	content_label.text = text


func quest_card(quest: Dictionary, completed: bool) -> String:
	var title: String = str(quest.get("title", "Untitled Quest"))
	var description: String = str(quest.get("description", ""))
	var objective: String = str(quest.get("objective", ""))
	var stage: int = int(quest.get("stage", 0))
	var stages_variant: Variant = quest.get("stages", [])
	var stage_line: String = ""
	if stages_variant is Array and stage >= 0 and stage < (stages_variant as Array).size():
		stage_line = str((stages_variant as Array)[stage])
	var marker: String = "✓" if completed else "◆"
	var result: String = "[color=#f7e7b0]" + marker + "  [b]" + title + "[/b][/color]\n"
	if description != "":
		result += "[color=#aeb9c6]" + description + "[/color]\n"
	if completed:
		result += "[color=#65d69a]Resolved[/color]"
	else:
		if stage_line != "":
			result += "[color=#d8e4f0]" + stage_line + "[/color]\n"
		if objective != "":
			result += "[color=#7fc9f4]Objective: " + objective + "[/color]"
	return result


func _on_quest_changed(_quest_id: String, _quest_data: Dictionary) -> void:
	if journal_open:
		refresh()


func ensure_input() -> void:
	if not InputMap.has_action("quest_journal"):
		InputMap.add_action("quest_journal", 0.2)
	var has_key: bool = false
	var has_button: bool = false
	for event: InputEvent in InputMap.action_get_events("quest_journal"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_J:
			has_key = true
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
			has_button = true
	if not has_key:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_J
		InputMap.action_add_event("quest_journal", key_event)
	if not has_button:
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("quest_journal", joy_event)


func build_ui() -> void:
	panel = PanelContainer.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-470.0, -330.0)
	panel.custom_minimum_size = Vector2(940.0, 660.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.985)
	style.border_color = Color(0.86, 0.66, 0.25, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	title_label = Label.new()
	title_label.text = "JOURNEY"
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var subtitle := Label.new()
	subtitle.text = "Grace's active paths"
	subtitle.add_theme_color_override("font_color", Color(0.52, 0.64, 0.76))
	header.add_child(subtitle)
	var line := HSeparator.new()
	box.add_child(line)
	content_label = RichTextLabel.new()
	content_label.bbcode_enabled = true
	content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_label.add_theme_font_size_override("normal_font_size", 19)
	content_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95))
	box.add_child(content_label)
	hint_label = Label.new()
	hint_label.text = "Minus / J / Cancel  Close"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_color_override("font_color", Color(0.52, 0.62, 0.72))
	box.add_child(hint_label)


func get_debug_data() -> Dictionary:
	return {
		"journal_open": journal_open,
		"active_quests": GameState.get_quest_rows("active").size(),
		"completed_quests": GameState.get_quest_rows("completed").size(),
	}
