extends CanvasLayer
class_name ProgressionHUD

var panel: PanelContainer
var level_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var banner: PanelContainer
var banner_label: Label
var banner_tween: Tween


func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	build_hud()
	if not GameState.experience_changed.is_connected(_on_experience_changed):
		GameState.experience_changed.connect(_on_experience_changed)
	if not GameState.level_gained.is_connected(_on_level_gained):
		GameState.level_gained.connect(_on_level_gained)
	if not GameState.growth_points_changed.is_connected(_on_growth_points_changed):
		GameState.growth_points_changed.connect(_on_growth_points_changed)
	refresh()


func _exit_tree() -> void:
	if GameState.experience_changed.is_connected(_on_experience_changed):
		GameState.experience_changed.disconnect(_on_experience_changed)
	if GameState.level_gained.is_connected(_on_level_gained):
		GameState.level_gained.disconnect(_on_level_gained)
	if GameState.growth_points_changed.is_connected(_on_growth_points_changed):
		GameState.growth_points_changed.disconnect(_on_growth_points_changed)


func refresh() -> void:
	var current: int = GameState.get_experience()
	var required: int = GameState.get_experience_required()
	level_label.text = "LEVEL " + str(GameState.get_stat("level")) + "     GROWTH " + str(GameState.get_growth_points())
	progress_bar.max_value = maxi(required, 1)
	progress_bar.value = current
	progress_label.text = str(current) + " / " + str(required) + " XP"


func _on_experience_changed(_current: int, _required: int) -> void:
	refresh()


func _on_growth_points_changed(_points: int) -> void:
	refresh()


func _on_level_gained(new_level: int, points_awarded: int) -> void:
	refresh()
	show_level_banner(new_level, points_awarded)


func show_level_banner(new_level: int, points_awarded: int) -> void:
	if banner_tween != null and banner_tween.is_valid():
		banner_tween.kill()
	banner.visible = true
	banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	banner.scale = Vector2(0.86, 0.86)
	banner.pivot_offset = banner.size * 0.5
	banner_label.text = "LEVEL " + str(new_level) + "\n+" + str(points_awarded) + " GROWTH POINT"
	banner_tween = create_tween()
	banner_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	banner_tween.set_trans(Tween.TRANS_BACK)
	banner_tween.set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.22)
	banner_tween.parallel().tween_property(banner, "scale", Vector2.ONE, 0.32)
	banner_tween.tween_interval(1.6)
	banner_tween.set_trans(Tween.TRANS_QUAD)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.35)
	banner_tween.tween_callback(banner.hide)


func build_hud() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-230.0, 18.0)
	panel.custom_minimum_size = Vector2(460.0, 74.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.04, 0.88)
	style.border_color = Color(0.28, 0.76, 0.94, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 17)
	level_label.add_theme_color_override("font_color", Color(0.72, 0.91, 1.0))
	root.add_child(level_label)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	root.add_child(bar_row)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(320.0, 18.0)
	progress_bar.show_percentage = false
	bar_row.add_child(progress_bar)
	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.94))
	bar_row.add_child(progress_label)
	banner = PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-230.0, -90.0)
	banner.custom_minimum_size = Vector2(460.0, 180.0)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.025, 0.05, 0.08, 0.97)
	banner_style.border_color = Color(1.0, 0.78, 0.25)
	banner_style.set_border_width_all(3)
	banner_style.set_corner_radius_all(24)
	banner.add_theme_stylebox_override("panel", banner_style)
	add_child(banner)
	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 31)
	banner_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	banner.add_child(banner_label)
	banner.visible = false
