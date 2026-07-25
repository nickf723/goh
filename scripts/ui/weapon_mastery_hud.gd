extends CanvasLayer
class_name WeaponMasteryHUD

const MasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")

@export_range(0.5, 12.0, 0.1) var visible_duration: float = 4.5

var panel: PanelContainer
var title_label: Label
var detail_label: Label
var progress_bar: ProgressBar
var hide_timer: float = 0.0
var current_weapon_class: String = "sword"


func _ready() -> void:
	layer = 24
	build_hud()
	if not GameState.weapon_mastery_changed.is_connected(_on_mastery_changed):
		GameState.weapon_mastery_changed.connect(_on_mastery_changed)
	if not GameState.weapon_mastery_ranked_up.is_connected(_on_mastery_ranked_up):
		GameState.weapon_mastery_ranked_up.connect(_on_mastery_ranked_up)
	var weapon_controller: Node = get_parent().get_node_or_null("WeaponController")
	if weapon_controller != null:
		if weapon_controller.weapon_changed.connect(_on_weapon_changed) != OK:
			pass
		var weapon: WeaponDefinition = weapon_controller.get("equipped_weapon") as WeaponDefinition
		if weapon != null:
			current_weapon_class = weapon.weapon_class
	refresh_display(false)


func _exit_tree() -> void:
	if GameState.weapon_mastery_changed.is_connected(_on_mastery_changed):
		GameState.weapon_mastery_changed.disconnect(_on_mastery_changed)
	if GameState.weapon_mastery_ranked_up.is_connected(_on_mastery_ranked_up):
		GameState.weapon_mastery_ranked_up.disconnect(_on_mastery_ranked_up)


func _process(delta: float) -> void:
	if panel == null or not panel.visible:
		return
	hide_timer -= maxf(delta, 0.0)
	if hide_timer <= 0.0:
		panel.visible = false


func build_hud() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24.0
	panel.offset_top = -192.0
	panel.offset_right = 316.0
	panel.offset_bottom = -116.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.025, 0.04, 0.9)
	style.border_color = Color(0.92, 0.68, 0.2, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	margin.add_child(rows)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))
	rows.add_child(title_label)
	detail_label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 11)
	detail_label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.92, 1.0))
	rows.add_child(detail_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0.0, 5.0)
	progress_bar.show_percentage = false
	rows.add_child(progress_bar)
	panel.visible = false


func _on_weapon_changed(weapon: WeaponDefinition) -> void:
	if weapon == null:
		return
	current_weapon_class = weapon.weapon_class
	refresh_display(true)


func _on_mastery_changed(weapon_class: String, _points: int, _rank: int, _delta: int) -> void:
	if weapon_class != current_weapon_class:
		return
	refresh_display(true)


func _on_mastery_ranked_up(weapon_class: String, rank: int) -> void:
	if weapon_class != current_weapon_class:
		return
	refresh_display(true)
	detail_label.text = "RANK UP • " + MasteryCatalogScript.get_upgrade_description(weapon_class, rank)
	hide_timer = visible_duration + 2.0


func refresh_display(show_panel: bool) -> void:
	var points: int = GameState.get_weapon_mastery_points(current_weapon_class)
	var rank: int = GameState.get_weapon_mastery_rank(current_weapon_class)
	var threshold: int = MasteryCatalogScript.get_rank_threshold(rank)
	var next_threshold: int = MasteryCatalogScript.get_next_rank_threshold(rank)
	title_label.text = (
		MasteryCatalogScript.get_icon(current_weapon_class)
		+ "  "
		+ MasteryCatalogScript.get_display_name(current_weapon_class)
		+ " Mastery • "
		+ MasteryCatalogScript.get_rank_name(rank)
	)
	if rank >= MasteryCatalogScript.RANK_THRESHOLDS.size() - 1:
		detail_label.text = str(points) + " proficiency • MASTERED"
		progress_bar.min_value = 0
		progress_bar.max_value = 1
		progress_bar.value = 1
	else:
		detail_label.text = str(points) + " / " + str(next_threshold) + " proficiency"
		progress_bar.min_value = threshold
		progress_bar.max_value = next_threshold
		progress_bar.value = points
	if show_panel:
		panel.visible = true
		hide_timer = visible_duration
