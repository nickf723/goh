extends "res://scripts/ui/player_hud_unified.gd"
class_name PlayerHUDUnifiedBudgeted

@export_group("Idle Budget")
@export_range(0.03, 0.5, 0.01) var unified_shell_refresh_interval: float = 0.1
@export_range(0.05, 0.5, 0.01) var base_hud_refresh_interval: float = 0.14

const CompactPortraitMedallionScript = preload("res://scripts/ui/portrait_medallion.gd")

const LEGACY_ACTOR_SURFACE_NAMES: Array[String] = [
	"DivineSpecialHUD",
	"QuickItemBeltUI",
	"GameplayEffectStatusHUD",
	"WeaponMasteryHUD",
	"QuickLoadoutHUD",
]
const LEGACY_GAME_UI_SURFACE_NAMES: Array[String] = [
	"ResourceHUD",
	"SpellMenuLabel",
	"DebugStatsLabel",
]

var shell_refresh_remaining: float = 0.0
var shell_elapsed_since_refresh: float = 0.0
var shell_update_count: int = 0
var shell_skipped_frame_count: int = 0
var visible_refresh_count: int = 0
var legacy_quick_refresh_skip_count: int = 0
var legacy_suppression_pass_count: int = 0
var legacy_node_check_count: int = 0
var legacy_processing_disabled_count: int = 0
var legacy_listener_connected: bool = false

var panel_style_cache: Dictionary = {}
var bar_style_cache: Dictionary = {}
var shell_style_cache: Dictionary = {}
var last_mode_signature: String = ""
var last_context_signature: String = ""
var last_support_signature: String = ""
var last_zone_signature: String = ""
var support_detail_stack: VBoxContainer = null


func _ready() -> void:
	refresh_interval = maxf(base_hud_refresh_interval, 0.05)
	super._ready()
	_connect_legacy_surface_listener()
	shell_refresh_remaining = 0.0
	shell_elapsed_since_refresh = 0.0
	add_to_group("budgeted_player_hud")


func _exit_tree() -> void:
	_disconnect_legacy_surface_listener()


# The production shell deliberately keeps only the two resources that matter
# continuously during traversal. The hidden mana and stance rows still exist in
# stat_rows so inherited refresh code remains authoritative and compatibility
# tests do not need a second data path.
func _create_stat_row(
	parent: VBoxContainer,
	stat_id: String,
	icon: String,
	_title: String,
	color: Color
) -> void:
	var row := HBoxContainer.new()
	row.name = "CompactStat_" + stat_id.capitalize()
	row.custom_minimum_size = Vector2(0.0, 24.0)
	row.add_theme_constant_override("separation", 7)
	row.visible = stat_id in ["health", "stamina"]
	parent.add_child(row)

	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.custom_minimum_size = Vector2(20.0, 0.0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 14)
	icon_label.add_theme_color_override("font_color", color)
	row.add_child(icon_label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	bar.add_theme_stylebox_override(
		"background",
		_make_bar_style(Color(0.035, 0.043, 0.058, 0.94), 5)
	)
	bar.add_theme_stylebox_override("fill", _make_bar_style(color, 5))
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = "0 / 0"
	value_label.custom_minimum_size = Vector2(60.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.95, 1.0, 0.96)
	)
	row.add_child(value_label)

	stat_rows[stat_id] = {"bar": bar, "value": value_label}


func _restyle_core_hud() -> void:
	super._restyle_core_hud()
	if stats_panel != null:
		stats_panel.offset_left = 18.0
		stats_panel.offset_top = 18.0
		stats_panel.offset_right = 334.0
		stats_panel.offset_bottom = 126.0
		stats_panel.add_theme_stylebox_override(
			"panel",
			_make_shell_style(
				Color(0.006, 0.012, 0.021, 0.88),
				Color(0.94, 0.62, 0.2, 0.64),
				14,
				2
			)
		)
		for separator: Node in stats_panel.find_children("*", "HSeparator", true, false):
			if separator is CanvasItem:
				(separator as CanvasItem).visible = false
	if avatar_title_label != null:
		avatar_title_label.visible = false
	if loadout_label != null:
		loadout_label.visible = false
	if base_stats_label != null:
		base_stats_label.visible = false


# The support corner is a portrait medallion while nothing needs attention. Its
# detail stack is revealed only for real statuses or persistent abilities.
func _build_support_cluster() -> void:
	support_panel = PanelContainer.new()
	support_panel.name = "UnifiedSupportCluster"
	support_panel.anchor_left = 1.0
	support_panel.anchor_top = 1.0
	support_panel.anchor_right = 1.0
	support_panel.anchor_bottom = 1.0
	support_panel.offset_left = -156.0
	support_panel.offset_top = -156.0
	support_panel.offset_right = -18.0
	support_panel.offset_bottom = -18.0
	support_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_panel.add_to_group("menu_suppressed_hud")
	support_panel.add_theme_stylebox_override(
		"panel",
		_make_shell_style(
			Color(0.006, 0.012, 0.021, 0.86),
			Color(0.9, 0.62, 0.24, 0.68),
			22,
			2
		)
	)
	support_zone.add_child(support_panel)

	var margin := _make_margin(10, 10, 10, 10)
	support_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)

	portrait = CompactPortraitMedallionScript.new()
	portrait.name = "UnifiedGracePortrait"
	portrait.custom_minimum_size = Vector2(100.0, 100.0)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)

	support_detail_stack = VBoxContainer.new()
	support_detail_stack.name = "ContextualSupportDetails"
	support_detail_stack.visible = false
	support_detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	support_detail_stack.add_theme_constant_override("separation", 3)
	row.add_child(support_detail_stack)

	var identity_row := HBoxContainer.new()
	support_detail_stack.add_child(identity_row)
	portrait_name_label = _make_label(10, Color(1.0, 0.76, 0.3))
	portrait_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_child(portrait_name_label)
	portrait_state_label = _make_label(
		8,
		Color(0.64, 0.76, 0.92),
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	identity_row.add_child(portrait_state_label)

	active_ability_stack = VBoxContainer.new()
	active_ability_stack.add_theme_constant_override("separation", 3)
	support_detail_stack.add_child(active_ability_stack)

	support_status_label = _make_label(8, Color(0.66, 0.76, 0.88))
	support_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	support_detail_stack.add_child(support_status_label)
	_rebuild_active_ability_rows()


func _rebuild_active_ability_rows() -> void:
	if active_ability_stack == null:
		return
	_clear_children(active_ability_stack)
	active_ability_stack.visible = not active_ability_entries.is_empty()
	for index: int in range(mini(active_ability_entries.size(), MAX_ACTIVE_ABILITIES)):
		active_ability_stack.add_child(_make_active_ability_row(active_ability_entries[index]))
	last_support_signature = ""


# PlayerHUDUnified previously refreshed its complete shell every rendered frame,
# while PlayerHUDV2 separately rebuilt the legacy-facing snapshot about twelve
# times per second. This override keeps the responsive resource snapshot and
# advances the unified shell on a bounded cadence instead of duplicating both
# presentation passes at frame rate.
func _process(delta: float) -> void:
	var step: float = maxf(delta, 0.0)

	refresh_remaining = maxf(refresh_remaining - step, 0.0)
	if refresh_remaining <= 0.0:
		refresh_remaining = maxf(refresh_interval, 0.05)
		_resolve_bindings()
		_suppress_legacy_hud()
		refresh_data()

	shell_refresh_remaining = maxf(shell_refresh_remaining - step, 0.0)
	shell_elapsed_since_refresh += step
	if shell_refresh_remaining > 0.0:
		shell_skipped_frame_count += 1
		return

	shell_refresh_remaining = maxf(unified_shell_refresh_interval, 0.03)
	var elapsed: float = shell_elapsed_since_refresh
	shell_elapsed_since_refresh = 0.0
	shell_update_count += 1
	_update_unified_shell(elapsed)


# The permanent command dock is now authoritative for spells, items, and Divine
# Specials. Do not keep rebuilding PlayerHUDV2's fully hidden quick panel and its
# styles on every data refresh. The visible stats, dialogue, portrait, and status
# surfaces retain the same bounded update cadence.
func refresh_data(_force: bool = false) -> void:
	visible_refresh_count += 1
	legacy_quick_refresh_skip_count += 1
	_refresh_stats()
	_refresh_dialogue()
	_refresh_statuses_and_portrait()
	_refresh_support_status()


# The old base implementation repeatedly searched both the actor and GameUI tree
# every refresh. One initial pass is sufficient; late legacy surfaces are hidden
# through SceneTree.node_added without another recursive search. Because these
# surfaces are fully replaced by the unified HUD, their processing is disabled
# as well as their rendering.
func _suppress_legacy_hud() -> void:
	if legacy_suppression_pass_count > 0:
		return
	legacy_suppression_pass_count += 1
	super._suppress_legacy_hud()
	_disable_legacy_actor_surface_processing()


func _disable_legacy_actor_surface_processing() -> void:
	if actor == null:
		return
	for node_name: String in LEGACY_ACTOR_SURFACE_NAMES:
		var legacy: Node = actor.get_node_or_null(node_name)
		if legacy != null:
			_disable_legacy_surface(legacy)


func _disable_legacy_surface(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	elif node is CanvasItem:
		(node as CanvasItem).visible = false
	if node.process_mode != Node.PROCESS_MODE_DISABLED:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		legacy_processing_disabled_count += 1


func _connect_legacy_surface_listener() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(callback):
		tree.node_added.connect(callback)
	legacy_listener_connected = true


func _disconnect_legacy_surface_listener() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if tree.node_added.is_connected(callback):
		tree.node_added.disconnect(callback)
	legacy_listener_connected = false


func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	var node_name: String = str(node.name)
	if (
		not LEGACY_ACTOR_SURFACE_NAMES.has(node_name)
		and not LEGACY_GAME_UI_SURFACE_NAMES.has(node_name)
	):
		return
	legacy_node_check_count += 1
	call_deferred("_hide_late_legacy_surface", node)


func _hide_late_legacy_surface(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var node_name: String = str(node.name)
	if LEGACY_ACTOR_SURFACE_NAMES.has(node_name):
		if actor == null or not (node == actor or actor.is_ancestor_of(node)):
			return
		_disable_legacy_surface(node)
		return
	if LEGACY_GAME_UI_SURFACE_NAMES.has(node_name):
		var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
		if game_ui == null or not (node == game_ui or game_ui.is_ancestor_of(node)):
			return
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
		elif node is CanvasItem:
			(node as CanvasItem).visible = false


func _update_zone_visibility() -> void:
	var signature: String = current_mode_id
	if signature == last_zone_signature:
		return
	last_zone_signature = signature
	super._update_zone_visibility()


func _refresh_mode_banner() -> void:
	var signature: String = _get_mode_signature()
	if signature == last_mode_signature:
		return
	last_mode_signature = signature
	super._refresh_mode_banner()


func _refresh_context_strip() -> void:
	var signature: String = _get_context_signature()
	if signature == last_context_signature:
		return
	last_context_signature = signature
	super._refresh_context_strip()


func _refresh_support_status() -> void:
	if support_panel == null or support_status_label == null:
		return
	var rows: Array[Dictionary] = _collect_status_rows()
	var parts: Array[String] = []
	for index: int in range(mini(rows.size(), 2)):
		var row: Dictionary = rows[index]
		parts.append(
			str(row.get("id", "effect"))
			+ "|"
			+ str(row.get("name", "Effect"))
			+ "|"
			+ str(ceili(maxf(float(row.get("remaining", 0.0)), 0.0)))
		)
	for entry: Dictionary in active_ability_entries:
		parts.append(
			"ability|"
			+ str(entry.get("id", entry.get("label", "active")))
			+ "|"
			+ str(entry.get("state", "active"))
		)
	var signature: String = ";".join(parts) if not parts.is_empty() else "idle"
	if signature == last_support_signature:
		return
	last_support_signature = signature

	var expanded: bool = not rows.is_empty() or not active_ability_entries.is_empty()
	if support_detail_stack != null:
		support_detail_stack.visible = expanded
	if expanded:
		support_panel.offset_left = -318.0
		support_panel.offset_top = -198.0
	else:
		support_panel.offset_left = -156.0
		support_panel.offset_top = -156.0

	if rows.is_empty():
		support_status_label.text = ""
	else:
		var copy: Array[String] = []
		for index: int in range(mini(rows.size(), 2)):
			var row: Dictionary = rows[index]
			copy.append(
				_status_icon(str(row.get("id", "effect")))
				+ " "
				+ str(row.get("name", "Effect"))
			)
		support_status_label.text = "  •  ".join(copy)


func _get_mode_signature() -> String:
	var request: Dictionary = _highest_priority_request(mode_requests)
	if request.is_empty() and objective_text != "":
		request = {
			"eyebrow": "CURRENT OBJECTIVE",
			"title": objective_text,
			"detail": objective_detail,
			"accent": Color(0.42, 0.72, 1.0),
		}
	if request.is_empty():
		return "hidden"
	return (
		str(request.get("eyebrow", "MODE"))
		+ "|" + str(request.get("title", ""))
		+ "|" + str(request.get("detail", request.get("state", "")))
		+ "|" + str(request.get("accent", "default"))
	)


func _get_context_signature() -> String:
	var request: Dictionary = _highest_priority_request(context_requests)
	if request.is_empty():
		return "hidden"
	return (
		str(request.get("eyebrow", "CONTEXT"))
		+ "|" + str(request.get("title", ""))
		+ "|" + str(request.get("detail", request.get("state", "")))
		+ "|" + str(request.get("controls", request.get("hint", "")))
		+ "|" + str(request.get("valid", true))
		+ "|" + str(request.get("accent", "default"))
	)


func _make_panel_style(
	fill: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var key: String = _style_key(fill, border, radius, border_width)
	if panel_style_cache.has(key):
		return panel_style_cache[key] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	panel_style_cache[key] = style
	return style


func _make_bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var key: String = color.to_html(true) + "|" + str(radius)
	if bar_style_cache.has(key):
		return bar_style_cache[key] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	bar_style_cache[key] = style
	return style


func _make_shell_style(
	fill: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var key: String = _style_key(fill, border, radius, border_width)
	if shell_style_cache.has(key):
		return shell_style_cache[key] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	shell_style_cache[key] = style
	return style


func _style_key(
	fill: Color,
	border: Color,
	radius: int,
	border_width: int
) -> String:
	return (
		fill.to_html(true)
		+ "|" + border.to_html(true)
		+ "|" + str(radius)
		+ "|" + str(border_width)
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["budgeted_unified_hud"] = true
	data["base_refresh_interval"] = refresh_interval
	data["unified_refresh_interval"] = unified_shell_refresh_interval
	data["unified_updates"] = shell_update_count
	data["unified_skipped_frames"] = shell_skipped_frame_count
	data["visible_refreshes"] = visible_refresh_count
	data["legacy_quick_refresh_skips"] = legacy_quick_refresh_skip_count
	data["legacy_suppression_passes"] = legacy_suppression_pass_count
	data["legacy_node_checks"] = legacy_node_check_count
	data["legacy_processing_disabled"] = legacy_processing_disabled_count
	data["legacy_listener"] = legacy_listener_connected
	data["panel_style_cache"] = panel_style_cache.size()
	data["bar_style_cache"] = bar_style_cache.size()
	data["shell_style_cache"] = shell_style_cache.size()
	data["compact_survival_stats"] = true
	data["contextual_support_cluster"] = true
	data["support_expanded"] = support_detail_stack != null and support_detail_stack.visible
	data["per_frame_style_allocation"] = false
	data["per_refresh_recursive_legacy_scan"] = false
	data["suppressed_legacy_processing"] = true
	data["hidden_quick_panel_refresh"] = false
	return data
