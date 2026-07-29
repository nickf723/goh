extends CanvasLayer
class_name PlayerQuickLoadoutHUD

@export_range(0.02, 0.5, 0.01) var refresh_interval: float = 0.08

var router: Node
var panel: PanelContainer
var spell_labels: Array[Label] = []
var hint_label: Label
var refresh_remaining: float = 0.0


func _ready() -> void:
	layer = 19
	_build_hud()
	_resolve_router()
	_refresh_hud()


func _process(delta: float) -> void:
	refresh_remaining = maxf(refresh_remaining - maxf(delta, 0.0), 0.0)
	if refresh_remaining > 0.0:
		return
	refresh_remaining = maxf(refresh_interval, 0.02)
	if router == null or not is_instance_valid(router):
		_resolve_router()
	_refresh_hud()


func _resolve_router() -> void:
	var player: Node = get_parent()
	if player != null:
		router = player.get_node_or_null("PlayerControlRouter")


func _build_hud() -> void:
	panel = PanelContainer.new()
	panel.name = "QuickSpellRibbon"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -260.0
	panel.offset_top = -92.0
	panel.offset_right = 260.0
	panel.offset_bottom = -24.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	var title: Label = Label.new()
	title.text = "QUICK SPELLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.66, 0.76, 1.0, 0.82))
	stack.add_child(title)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var left_arrow: Label = Label.new()
	left_arrow.text = "◀"
	left_arrow.add_theme_color_override("font_color", Color(0.66, 0.76, 1.0, 0.92))
	row.add_child(left_arrow)

	for index: int in range(3):
		var spell_label: Label = Label.new()
		spell_label.name = "QuickSpell" + str(index + 1)
		spell_label.custom_minimum_size = Vector2(126.0, 22.0)
		spell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spell_label.add_theme_font_size_override("font_size", 11)
		row.add_child(spell_label)
		spell_labels.append(spell_label)

	var right_arrow: Label = Label.new()
	right_arrow.text = "▶"
	right_arrow.add_theme_color_override("font_color", Color(0.66, 0.76, 1.0, 0.92))
	row.add_child(right_arrow)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 9)
	hint_label.add_theme_color_override("font_color", Color(0.68, 0.74, 0.86, 0.78))
	stack.add_child(hint_label)


func _refresh_hud() -> void:
	if panel == null:
		return
	if router == null or not is_instance_valid(router):
		panel.visible = false
		return
	panel.visible = true
	var names: Array[String] = []
	if router.has_method("get_quick_spell_names"):
		var names_result: Variant = router.call("get_quick_spell_names")
		if names_result is Array:
			for name_value: Variant in names_result:
				names.append(str(name_value))
	var selected: int = 0
	if router.has_method("get_selected_quick_spell_cursor"):
		selected = int(router.call("get_selected_quick_spell_cursor"))

	for index: int in range(spell_labels.size()):
		var spell_label: Label = spell_labels[index]
		var spell_name: String = names[index] if index < names.size() else "Empty"
		spell_label.text = ("◆ " if index == selected else "") + spell_name
		spell_label.add_theme_color_override(
			"font_color",
			Color(0.96, 0.86, 0.36, 1.0)
			if index == selected
			else Color(0.82, 0.88, 1.0, 0.78)
		)

	var focus_prompt: String = "L"
	var cast_prompt: String = "ZL"
	if router.has_method("get_hand_role_summary"):
		var summary_result: Variant = router.call("get_hand_role_summary")
		if summary_result is Dictionary:
			var summary: Dictionary = summary_result as Dictionary
			focus_prompt = str(summary.get("focus", focus_prompt))
			cast_prompt = str(summary.get("cast", cast_prompt))
	hint_label.text = (
		"D-PAD ◀/▶ SELECT  •  "
		+ cast_prompt
		+ " CAST  •  HOLD "
		+ focus_prompt
		+ " FOR LIBRARY"
	)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.055, 0.84)
	style.border_color = Color(0.38, 0.52, 0.92, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style
