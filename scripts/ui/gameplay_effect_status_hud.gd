extends CanvasLayer
class_name GameplayEffectStatusHUD

const GameplayEffectAccessScript = preload("res://scripts/effects/gameplay_effect_access.gd")

@export_range(0.02, 0.5, 0.01) var refresh_interval: float = 0.08

var panel: PanelContainer
var rows_box: VBoxContainer
var refresh_timer: float = 0.0
var last_signature: String = ""


func _ready() -> void:
	layer = 23
	build_hud()
	refresh_display(true)


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = maxf(refresh_interval, 0.02)
	refresh_display()


func build_hud() -> void:
	panel = PanelContainer.new()
	panel.name = "TimedEffectsPanel"
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -350.0
	panel.offset_top = 72.0
	panel.offset_right = -24.0
	panel.offset_bottom = 220.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.add_theme_stylebox_override("panel", make_panel_style())
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 7)
	margin.add_child(rows_box)


func refresh_display(force_rebuild: bool = false) -> void:
	var rows: Array[Dictionary] = GameplayEffectAccessScript.get_active_source_rows(false)
	panel.visible = not rows.is_empty()
	if rows.is_empty():
		last_signature = ""
		clear_rows()
		return

	var signature_parts: Array[String] = []
	for row: Dictionary in rows:
		signature_parts.append(str(row.get("source_id", "")) + ":" + str(row.get("id", "")))
	var signature: String = "|".join(signature_parts)
	if force_rebuild or signature != last_signature or rows_box.get_child_count() != rows.size():
		last_signature = signature
		rebuild_rows(rows)
	else:
		update_row_values(rows)


func rebuild_rows(rows: Array[Dictionary]) -> void:
	clear_rows()
	for row: Dictionary in rows:
		var row_box: HBoxContainer = HBoxContainer.new()
		row_box.custom_minimum_size = Vector2(0.0, 39.0)
		row_box.add_theme_constant_override("separation", 9)
		rows_box.add_child(row_box)

		var icon_label: Label = Label.new()
		icon_label.text = get_effect_icon(str(row.get("id", "")))
		icon_label.custom_minimum_size = Vector2(28.0, 0.0)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 20)
		icon_label.add_theme_color_override("font_color", get_effect_color(str(row.get("id", ""))))
		row_box.add_child(icon_label)

		var copy_box: VBoxContainer = VBoxContainer.new()
		copy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy_box.add_theme_constant_override("separation", 2)
		row_box.add_child(copy_box)

		var title_row: HBoxContainer = HBoxContainer.new()
		title_row.name = "TitleRow"
		copy_box.add_child(title_row)
		var name_label: Label = Label.new()
		name_label.name = "Name"
		name_label.text = str(row.get("name", "Effect"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
		title_row.add_child(name_label)
		var timer_label: Label = Label.new()
		timer_label.name = "Timer"
		timer_label.custom_minimum_size = Vector2(45.0, 0.0)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		timer_label.add_theme_font_size_override("font_size", 11)
		timer_label.add_theme_color_override("font_color", get_effect_color(str(row.get("id", ""))))
		title_row.add_child(timer_label)

		var progress: ProgressBar = ProgressBar.new()
		progress.name = "Progress"
		progress.custom_minimum_size = Vector2(0.0, 5.0)
		progress.show_percentage = false
		progress.max_value = maxf(float(row.get("duration", 1.0)), 0.1)
		progress.add_theme_stylebox_override("background", make_bar_style(Color(0.08, 0.1, 0.14, 0.86)))
		progress.add_theme_stylebox_override("fill", make_bar_style(get_effect_color(str(row.get("id", "")))))
		copy_box.add_child(progress)

	update_row_values(rows)


func update_row_values(rows: Array[Dictionary]) -> void:
	for index: int in range(mini(rows.size(), rows_box.get_child_count())):
		var row: Dictionary = rows[index]
		var row_box: HBoxContainer = rows_box.get_child(index) as HBoxContainer
		if row_box == null or row_box.get_child_count() < 2:
			continue
		var copy_box: VBoxContainer = row_box.get_child(1) as VBoxContainer
		if copy_box == null:
			continue
		var timer_label: Label = copy_box.get_node_or_null("TitleRow/Timer") as Label
		var progress: ProgressBar = copy_box.get_node_or_null("Progress") as ProgressBar
		var remaining: float = maxf(float(row.get("remaining", 0.0)), 0.0)
		if timer_label != null:
			timer_label.text = str(ceili(remaining)) + "s"
		if progress != null:
			progress.max_value = maxf(float(row.get("duration", 1.0)), 0.1)
			progress.value = remaining


func clear_rows() -> void:
	if rows_box == null:
		return
	for child: Node in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()


func get_effect_icon(effect_id: String) -> String:
	match effect_id:
		"wayfarer_stride":
			return "➤"
		"apprentice_flow":
			return "✦"
		"ironweave_guard":
			return "▧"
		"vital_restoration":
			return "♥"
		"resonant_focus":
			return "◉"
		"merchant_rapport":
			return "◇"
		"fortunes_favor":
			return "✧"
		_:
			return "◆"


func get_effect_color(effect_id: String) -> Color:
	match effect_id:
		"wayfarer_stride":
			return Color(0.25, 0.94, 0.72, 1.0)
		"apprentice_flow":
			return Color(0.62, 0.42, 1.0, 1.0)
		"ironweave_guard":
			return Color(0.72, 0.62, 0.39, 1.0)
		"vital_restoration":
			return Color(1.0, 0.38, 0.5, 1.0)
		"resonant_focus":
			return Color(0.25, 0.78, 1.0, 1.0)
		_:
			return Color(0.9, 0.76, 0.28, 1.0)


func make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.025, 0.04, 0.82)
	style.border_color = Color(0.38, 0.62, 0.86, 0.44)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


func make_bar_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style
