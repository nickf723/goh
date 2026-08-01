extends "res://scripts/ui/full_menu_shell_codex_v1_legacy.gd"

# Safety wrapper for the Codex detail panel. Godot constructs nested array
# literals as plain Array values, so the previous Array[String] loop rejected
# otherwise valid heading/text pairs at runtime.


func _make_codex_detail_panel(
	row: Dictionary,
	definition: Dictionary
) -> PanelContainer:
	var panel: PanelContainer = _make_magic_subpanel()
	panel.name = "CodexDetailPanel"
	panel.custom_minimum_size = Vector2(410.0, 0.0)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)
	if row.is_empty():
		var empty: Label = Label.new()
		empty.text = str(definition.get("description", "No records."))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", TEXT_SOFT)
		stack.add_child(empty)
		return panel

	var icon: Label = Label.new()
	icon.text = str(row.get("icon", "◇"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 40)
	icon.add_theme_color_override("font_color", CODEX_ACTIVE_BORDER)
	stack.add_child(icon)
	var title: Label = Label.new()
	title.text = str(row.get("name", "Codex Record"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(title)
	var status: Label = Label.new()
	status.text = str(row.get("status", "ACTIVE"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", CODEX_ACTIVE_BORDER)
	stack.add_child(status)

	var progress: ProgressBar = ProgressBar.new()
	progress.name = "CodexProgressBar"
	progress.min_value = 0.0
	progress.max_value = float(maxi(int(row.get("progress_target", 1)), 1))
	progress.value = float(row.get("progress_current", 0))
	progress.show_percentage = true
	progress.custom_minimum_size = Vector2(0.0, 24.0)
	stack.add_child(progress)
	var fraction_label: Label = Label.new()
	fraction_label.text = (
		str(row.get("progress_current", 0))
		+ " / "
		+ str(row.get("progress_target", 1))
	)
	fraction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fraction_label.add_theme_font_size_override("font_size", 10)
	fraction_label.add_theme_color_override("font_color", TEXT_SOFT)
	stack.add_child(fraction_label)

	var copy_rows: Array = [
		["SUMMARY", str(row.get("summary", ""))],
		["REQUIREMENT", str(row.get("requirement", ""))],
		["REWARD", str(row.get("reward", ""))],
	]
	for raw_copy: Variant in copy_rows:
		if not raw_copy is Array:
			continue
		var heading_and_text: Array = raw_copy as Array
		if heading_and_text.size() < 2:
			continue
		var heading: String = str(heading_and_text[0])
		var body: String = str(heading_and_text[1])
		var label: Label = Label.new()
		label.text = heading + "  •  " + body
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override(
			"font_color",
			TEXT_MAIN if heading != "SUMMARY" else TEXT_SOFT
		)
		stack.add_child(label)
	for detail_text: String in _codex_string_array(row.get("details", [])):
		var detail: Label = Label.new()
		detail.text = detail_text
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 9)
		detail.add_theme_color_override("font_color", TEXT_DIM)
		stack.add_child(detail)
	return panel
