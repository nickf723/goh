extends "res://scripts/ui/game_ui_unified.gd"
class_name GameUICompactFocus

const SpellIconsCompact = preload("res://scripts/ui/spell_icon_factory.gd")
const VineTargetPreviewScript = preload(
	"res://scripts/player/vine_grapple_target_preview.gd"
)

var focus_spell_scroll: ScrollContainer
var compact_focus_element_panel: PanelContainer
var compact_focus_detail_panel: PanelContainer
var vine_target_preview: Node


func _ready() -> void:
	super._ready()
	_apply_compact_focus_chrome()
	update_focus_help_copy()
	call_deferred("_ensure_vine_target_preview")


# Focus is a combat picker, not the encyclopedia. The full Magic menu owns
# long-form spell detail. This surface keeps all sixteen elements legible while
# capping the spell list so a growing library never expands over the HUD.
func ensure_focus_spell_selector_ui() -> void:
	if focus_spell_panel != null:
		return

	focus_spell_panel = PanelContainer.new()
	focus_spell_panel.name = "FocusSpellSelectorPanel"
	focus_spell_panel.visible = false
	focus_spell_panel.anchor_left = 0.5
	focus_spell_panel.anchor_top = 1.0
	focus_spell_panel.anchor_right = 0.5
	focus_spell_panel.anchor_bottom = 1.0
	focus_spell_panel.offset_left = -360.0
	focus_spell_panel.offset_top = -355.0
	focus_spell_panel.offset_right = 360.0
	focus_spell_panel.offset_bottom = -128.0
	focus_spell_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.008, 0.014, 0.024, 0.965),
			Color(0.34, 0.5, 0.78, 0.76),
			2,
			15
		)
	)
	add_child(focus_spell_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	focus_spell_panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 5)
	margin.add_child(root_box)

	var header_box := HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 10)
	root_box.add_child(header_box)

	focus_spell_title_label = Label.new()
	focus_spell_title_label.text = "SPELL FOCUS"
	focus_spell_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_spell_title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.74, 0.28, 1.0)
	)
	focus_spell_title_label.add_theme_font_size_override("font_size", 14)
	header_box.add_child(focus_spell_title_label)

	focus_spell_current_label = Label.new()
	focus_spell_current_label.text = "ACTIVE • None"
	focus_spell_current_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_spell_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	focus_spell_current_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	focus_spell_current_label.add_theme_color_override(
		"font_color",
		Color(0.62, 0.7, 0.82, 0.82)
	)
	focus_spell_current_label.add_theme_font_size_override("font_size", 10)
	header_box.add_child(focus_spell_current_label)

	var content_box := HBoxContainer.new()
	content_box.add_theme_constant_override("separation", 9)
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(content_box)

	compact_focus_element_panel = PanelContainer.new()
	compact_focus_element_panel.name = "ElementMatrixPanel"
	compact_focus_element_panel.custom_minimum_size = Vector2(238.0, 146.0)
	compact_focus_element_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.025, 0.036, 0.052, 0.78),
			Color(0.2, 0.28, 0.42, 0.58),
			1,
			10
		)
	)
	content_box.add_child(compact_focus_element_panel)

	var element_margin := MarginContainer.new()
	element_margin.add_theme_constant_override("margin_left", 6)
	element_margin.add_theme_constant_override("margin_top", 6)
	element_margin.add_theme_constant_override("margin_right", 6)
	element_margin.add_theme_constant_override("margin_bottom", 6)
	compact_focus_element_panel.add_child(element_margin)

	focus_spell_element_grid = GridContainer.new()
	focus_spell_element_grid.columns = 5
	focus_spell_element_grid.add_theme_constant_override("h_separation", 4)
	focus_spell_element_grid.add_theme_constant_override("v_separation", 4)
	element_margin.add_child(focus_spell_element_grid)

	compact_focus_detail_panel = PanelContainer.new()
	compact_focus_detail_panel.name = "SpellWindowPanel"
	compact_focus_detail_panel.custom_minimum_size = Vector2(430.0, 146.0)
	compact_focus_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_focus_detail_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.02, 0.03, 0.046, 0.82),
			Color(0.2, 0.28, 0.42, 0.58),
			1,
			10
		)
	)
	content_box.add_child(compact_focus_detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 7)
	detail_margin.add_theme_constant_override("margin_top", 6)
	detail_margin.add_theme_constant_override("margin_right", 7)
	detail_margin.add_theme_constant_override("margin_bottom", 6)
	compact_focus_detail_panel.add_child(detail_margin)

	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 4)
	detail_margin.add_child(detail_box)

	focus_spell_header_label = Label.new()
	focus_spell_header_label.text = "FIRE"
	focus_spell_header_label.add_theme_color_override("font_color", TEXT_MAIN)
	focus_spell_header_label.add_theme_font_size_override("font_size", 12)
	detail_box.add_child(focus_spell_header_label)

	# Kept as a compatibility node because older presenters write to it. The
	# compact picker deliberately does not spend a full line repeating selection
	# detail that is already visible in the highlighted spell row.
	focus_spell_selected_label = Label.new()
	focus_spell_selected_label.name = "LegacySelectionDetail"
	focus_spell_selected_label.visible = false
	detail_box.add_child(focus_spell_selected_label)

	focus_spell_scroll = ScrollContainer.new()
	focus_spell_scroll.name = "SpellWindowScroll"
	focus_spell_scroll.custom_minimum_size = Vector2(0.0, 116.0)
	focus_spell_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_spell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(focus_spell_scroll)

	focus_spell_list = VBoxContainer.new()
	focus_spell_list.name = "SpellWindowList"
	focus_spell_list.add_theme_constant_override("separation", 3)
	focus_spell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_spell_scroll.add_child(focus_spell_list)

	focus_spell_help_label = Label.new()
	focus_spell_help_label.text = "Browse • Equip • Assign"
	focus_spell_help_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	focus_spell_help_label.add_theme_color_override(
		"font_color",
		Color(0.58, 0.66, 0.78, 0.68)
	)
	focus_spell_help_label.add_theme_font_size_override("font_size", 8)
	root_box.add_child(focus_spell_help_label)


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	super.show_spell_focus_menu(menu_data)
	_apply_compact_focus_detail(menu_data)
	call_deferred(
		"_sync_compact_spell_scroll",
		int(menu_data.get("selected_spell_index", 0))
	)


func update_focus_help_copy() -> void:
	if focus_spell_help_label == null:
		return
	if last_input_mode == INPUT_MODE_CONTROLLER:
		var hand_roles: Dictionary = get_hand_role_summary()
		focus_spell_help_label.text = (
			"D-pad browse  •  A/"
			+ str(hand_roles.get("cast", "ZL"))
			+ " equip  •  1–0 slot  •  release "
			+ str(hand_roles.get("focus", "L"))
		)
	else:
		focus_spell_help_label.text = (
			"Arrows / wheel browse  •  Enter / Q equip  •  1–0 slot  •  release Tab"
		)


func _apply_compact_focus_chrome() -> void:
	if focus_spell_title_label != null:
		focus_spell_title_label.text = "SPELL FOCUS"
		focus_spell_title_label.add_theme_font_size_override("font_size", 14)
	if focus_spell_panel != null:
		focus_spell_panel.offset_left = -360.0
		focus_spell_panel.offset_top = -355.0
		focus_spell_panel.offset_right = 360.0
		focus_spell_panel.offset_bottom = -128.0
	if focus_spell_element_grid != null:
		focus_spell_element_grid.columns = 5
		focus_spell_element_grid.add_theme_constant_override("h_separation", 4)
		focus_spell_element_grid.add_theme_constant_override("v_separation", 4)


func _apply_compact_focus_detail(menu_data: Dictionary) -> void:
	var element: String = str(menu_data.get("selected_element", ""))
	var element_name: String = str(
		menu_data.get("selected_element_name", element.capitalize())
	)
	var spell_names: Array = menu_data.get("spell_names", []) as Array
	var current_name: String = str(menu_data.get("current_ability_name", "None"))
	if focus_spell_title_label != null:
		focus_spell_title_label.text = "SPELL FOCUS"
	if focus_spell_current_label != null:
		focus_spell_current_label.text = "ACTIVE • " + current_name
	if focus_spell_header_label != null:
		focus_spell_header_label.text = (
			element_name.to_upper()
			+ "  •  "
			+ str(spell_names.size())
		)
		focus_spell_header_label.add_theme_color_override(
			"font_color",
			get_element_color(element)
		)
	if focus_spell_selected_label != null:
		focus_spell_selected_label.visible = false


func _make_focus_group_label(group_name: String) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(36.0, 28.0)
	match group_name.to_lower():
		"natural":
			label.text = "NAT"
		"primal":
			label.text = "PRI"
		"vital":
			label.text = "VIT"
		"mystical":
			label.text = "MYS"
		_:
			label.text = group_name.to_upper().left(3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override(
		"font_color",
		Color(0.46, 0.55, 0.7, 0.76)
	)
	return label


func _make_cached_element_tile(element: String) -> Dictionary:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(44.0, 28.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	tile.add_child(margin)
	var label := Label.new()
	label.text = get_short_element_name(element)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 8)
	margin.add_child(label)
	return {"tile": tile, "label": label}


func _make_icon_spell_row(entry: Dictionary) -> Dictionary:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 32.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	row.add_child(margin)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var badge: PanelContainer = SpellIconsCompact.create_badge(
		entry,
		26.0,
		false,
		false
	)
	content.add_child(badge)

	var label := Label.new()
	label.text = str(entry.get("name", "Spell"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	content.add_child(label)

	var quick_label := Label.new()
	quick_label.text = ""
	quick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quick_label.add_theme_font_size_override("font_size", 7)
	quick_label.visible = false
	content.add_child(quick_label)

	var equipped_label := Label.new()
	equipped_label.text = "★"
	equipped_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipped_label.add_theme_font_size_override("font_size", 9)
	equipped_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.72, 0.22, 1.0)
	)
	equipped_label.visible = false
	content.add_child(equipped_label)
	return {
		"row": row,
		"label": label,
		"badge": badge,
		"quick_label": quick_label,
		"equipped_label": equipped_label,
	}


func _sync_compact_spell_scroll(selected_index: int) -> void:
	if focus_spell_scroll == null or focus_spell_list == null:
		return
	if selected_index < 0 or selected_index >= focus_spell_list.get_child_count():
		return
	var row: Control = focus_spell_list.get_child(selected_index) as Control
	if row == null:
		return
	var viewport_top: float = float(focus_spell_scroll.scroll_vertical)
	var viewport_bottom: float = viewport_top + focus_spell_scroll.size.y
	var row_top: float = row.position.y
	var row_bottom: float = row.position.y + row.size.y
	if row_top < viewport_top:
		focus_spell_scroll.scroll_vertical = maxi(0, int(row_top))
	elif row_bottom > viewport_bottom:
		focus_spell_scroll.scroll_vertical = maxi(
			0,
			int(row_bottom - focus_spell_scroll.size.y)
		)


func _ensure_vine_target_preview() -> void:
	if get_tree() == null:
		return
	var existing: Node = get_tree().get_first_node_in_group(
		"vine_grapple_target_previews"
	)
	if existing != null:
		vine_target_preview = existing
		return
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	vine_target_preview = VineTargetPreviewScript.new()
	vine_target_preview.name = "VineGrappleTargetPreview"
	host.add_child(vine_target_preview)


func get_compact_focus_debug_data() -> Dictionary:
	return {
		"compact": true,
		"title": focus_spell_title_label.text if focus_spell_title_label != null else "",
		"panel_bottom": focus_spell_panel.offset_bottom if focus_spell_panel != null else 0.0,
		"panel_width": focus_spell_panel.size.x if focus_spell_panel != null else 0.0,
		"scroll_backed": focus_spell_scroll != null,
		"spell_window_height": focus_spell_scroll.size.y if focus_spell_scroll != null else 0.0,
		"selection_detail_hidden": focus_spell_selected_label != null and not focus_spell_selected_label.visible,
		"vine_preview_installed": vine_target_preview != null and is_instance_valid(vine_target_preview),
	}
