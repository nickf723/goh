extends "res://scripts/ui/player_hud_unified.gd"
class_name PlayerHUDUnifiedBudgeted

@export_group("Idle Budget")
@export_range(0.03, 0.5, 0.01) var unified_shell_refresh_interval: float = 0.1
@export_range(0.05, 0.5, 0.01) var base_hud_refresh_interval: float = 0.14

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


func _ready() -> void:
	refresh_interval = maxf(base_hud_refresh_interval, 0.05)
	super._ready()
	_connect_legacy_surface_listener()
	shell_refresh_remaining = 0.0
	shell_elapsed_since_refresh = 0.0
	add_to_group("budgeted_player_hud")


func _exit_tree() -> void:
	_disconnect_legacy_surface_listener()


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
	var signature: String = ";".join(parts) if not parts.is_empty() else "ready"
	if signature == last_support_signature:
		return
	last_support_signature = signature
	super._refresh_support_status()


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
	data["per_frame_style_allocation"] = false
	data["per_refresh_recursive_legacy_scan"] = false
	data["suppressed_legacy_processing"] = true
	data["hidden_quick_panel_refresh"] = false
	return data
