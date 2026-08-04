extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const GameUIScene: PackedScene = preload(
	"res://scenes/ui/game_ui.tscn"
)

class RibbonProvider:
	extends Node
	var active: bool = true

	func get_active_ability_ribbon_entry() -> Dictionary:
		return {
			"active": active,
			"id": "fixture_familiar",
			"label": "Juniper",
			"state": "Follow",
			"spell_ids": ["spectral_familiar"],
			"spell_id": "spectral_familiar",
			"element": "life",
			"icon_text": "J",
			"priority": 1,
		}


class PlacementProvider:
	extends Node
	var active: bool = false
	var valid: bool = true
	var depth: float = 0.0
	var rotation: float = 0.0

	func begin_shared_placement(placement_id: String) -> Dictionary:
		if placement_id != "fixture":
			return {"ok": false, "error": "Unknown fixture."}
		active = true
		return {"ok": true}

	func get_shared_placement_state(placement_id: String) -> Dictionary:
		return {
			"session_active": active and placement_id == "fixture",
			"eyebrow": "FIXTURE PLACEMENT",
			"title": "Test Platform",
			"valid": valid,
			"reason": "Blocked by fixture geometry.",
			"depth": depth,
			"rotation": rotation,
			"mana_cost": 2,
			"active_count": 1,
			"active_limit": 3,
		}

	func adjust_shared_placement_depth(
		placement_id: String,
		direction: int
	) -> Dictionary:
		if not active or placement_id != "fixture":
			return {"ok": false}
		depth += float(direction) * 0.25
		return {"ok": true}

	func rotate_shared_placement(
		placement_id: String,
		direction: int
	) -> Dictionary:
		if not active or placement_id != "fixture":
			return {"ok": false}
		rotation += float(direction) * 22.5
		return {"ok": true}

	func cycle_shared_placement_variant(
		placement_id: String,
		_direction: int
	) -> Dictionary:
		return {"ok": active and placement_id == "fixture"}

	func confirm_shared_placement(placement_id: String) -> Dictionary:
		if not active or placement_id != "fixture":
			return {"ok": false}
		active = false
		return {"ok": true}

	func cancel_shared_placement(placement_id: String) -> void:
		if placement_id == "fixture":
			active = false


var failures: Array[String] = []
var player: CharacterBody3D
var game_ui: Node
var hud: Node
var ability_router: Node
var placement_controller: Node
var context_menu: Node
var active_ribbon: Node
var quick_dock: Node
var caster: Node
var ribbon_provider: RibbonProvider
var placement_provider: PlacementProvider


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	Engine.time_scale = 1.0
	game_ui = GameUIScene.instantiate()
	game_ui.name = "GameUI"
	add_child(game_ui)
	player = PlayerScene.instantiate() as CharacterBody3D
	player.name = "Player"
	player.add_to_group("player")
	add_child(player)
	for _frame: int in range(40):
		await get_tree().process_frame
	await get_tree().physics_frame

	hud = player.get_node_or_null("PlayerHUDV2")
	ability_router = player.get_node_or_null("AbilityContextRouter")
	quick_dock = player.get_node_or_null("QuickSpellBeltPresentation")
	caster = player.get_node_or_null("AbilityCaster")
	if ability_router != null:
		placement_controller = ability_router.call(
			"get_shared_placement_controller"
		) as Node
		context_menu = ability_router.call("get_context_menu") as Node
		active_ribbon = ability_router.call(
			"get_active_ability_ribbon"
		) as Node

	_test_shell_installation()
	_test_layout_geometry()
	await _test_objective_prompt_and_activity()
	await _test_active_ability_support()
	await _test_placement_mode()
	await _test_focus_mode()
	await _cleanup_and_finish()


func _test_shell_installation() -> void:
	_expect(hud != null, "player owns a HUD")
	_expect(
		hud != null and hud.is_in_group("unified_hud_shell"),
		"player HUD is the unified layout authority"
	)
	if hud == null:
		return
	for zone_id: String in [
		"status",
		"mode",
		"activity",
		"action_bar",
		"support",
		"context",
	]:
		_expect(
			hud.call("get_hud_zone", zone_id) is Control,
			"unified HUD exposes the " + zone_id + " zone"
		)
	_expect(ability_router != null, "ability context router remains installed")
	_expect(placement_controller != null, "shared placement remains installed")
	_expect(context_menu != null, "ability context menu remains installed")
	_expect(active_ribbon != null, "active ability provider collector remains installed")
	_expect(quick_dock != null, "command dock remains installed")
	if quick_dock != null:
		var dock_data: Dictionary = quick_dock.call("get_debug_data") as Dictionary
		_expect(bool(dock_data.get("unified_layout", false)), "command dock uses unified layout")
		_expect(
			str(dock_data.get("dock_parent_zone", "")) == "ActionBarZone",
			"command dock is parented to the action bar zone"
		)
	var hud_root: Control = hud.get("root") as Control
	_expect(
		_count_visible_named_controls(
			hud_root,
			"PermanentDPadCommandDock"
		) == 1,
		"exactly one rendered command dock survives runtime replacement"
	)
	if context_menu != null:
		var compact_panel: Control = context_menu.get("compact_panel") as Control
		_expect(
			compact_panel != null and not compact_panel.visible,
			"duplicate compact ability card is retired"
		)
	var legacy_quick_item: CanvasLayer = player.get_node_or_null(
		"QuickItemBeltUI"
	) as CanvasLayer
	_expect(legacy_quick_item != null, "legacy quick-item node remains available for compatibility")
	if legacy_quick_item != null:
		_expect(
			not legacy_quick_item.visible,
			"legacy quick-item card is hidden under the unified HUD"
		)
		if legacy_quick_item.has_method("get_debug_data"):
			var legacy_data: Dictionary = legacy_quick_item.call(
				"get_debug_data"
			) as Dictionary
			_expect(
				bool(legacy_data.get("unified_hud_suppressed", false)),
				"legacy quick-item card reports unified suppression"
			)
	var source_bridge: Node = game_ui.get_node_or_null("UnifiedHUDSourceBridge")
	_expect(source_bridge != null, "global HUD source bridge is installed")
	for special_hud: Node in get_tree().get_nodes_in_group("divine_special_hud"):
		var panel_value: Variant = special_hud.get("panel")
		if panel_value is Control:
			_expect(
				is_zero_approx((panel_value as Control).modulate.a),
				"duplicate divine special panel is visually retired"
			)


func _test_layout_geometry() -> void:
	if hud == null or quick_dock == null:
		return
	var stats_panel: Control = hud.get("stats_panel") as Control
	var mode_panel: Control = hud.get("mode_panel") as Control
	var activity_rail: Control = hud.get("activity_rail") as Control
	var support_panel: Control = hud.get("support_panel") as Control
	var context_panel: Control = hud.get("context_panel") as Control
	var dock_panel: Control = quick_dock.get("dock_panel") as Control
	_expect(
		_not_overlapping(stats_panel, mode_panel),
		"status cluster does not overlap the mode banner"
	)
	_expect(
		_not_overlapping(mode_panel, activity_rail),
		"mode banner does not overlap the activity rail"
	)
	_expect(
		_not_overlapping(activity_rail, support_panel),
		"activity rail does not overlap the support cluster"
	)
	_expect(
		_not_overlapping(support_panel, dock_panel),
		"support cluster does not overlap the action bar"
	)
	_expect(
		_not_overlapping(context_panel, dock_panel),
		"context strip remains above the action bar"
	)
	if support_panel != null:
		var viewport_rect: Rect2 = get_viewport().get_visible_rect()
		var support_rect: Rect2 = support_panel.get_global_rect()
		_expect(
			support_rect.position.x >= viewport_rect.position.x - 0.5,
			"support cluster starts inside the viewport"
		)
		_expect(
			support_rect.end.x <= viewport_rect.end.x + 0.5,
			"support cluster ends inside the viewport"
		)
	var grace_portrait: Control = hud.get("portrait") as Control
	if grace_portrait != null:
		_expect(
			grace_portrait.custom_minimum_size.x <= 100.0
			and grace_portrait.custom_minimum_size.y <= 100.0,
			"support portrait preserves its compact requested size"
		)


func _test_objective_prompt_and_activity() -> void:
	if hud == null or game_ui == null:
		return
	game_ui.call("set_objective", "Reach the proving lane")
	await _wait_frames(3)
	var mode_panel: Control = hud.get("mode_panel") as Control
	var mode_title: Label = hud.get("mode_title_label") as Label
	_expect(mode_panel != null and mode_panel.visible, "objective uses the mode banner")
	_expect(
		mode_title != null and mode_title.text == "Reach the proving lane",
		"mode banner displays the active objective"
	)
	var objective_label: Label = game_ui.get("objective_label") as Label
	_expect(objective_label != null and not objective_label.visible, "legacy objective label stays hidden")

	game_ui.call("show_prompt", "Record Spring")
	await _wait_frames(2)
	var context_panel: Control = hud.get("context_panel") as Control
	var context_title: Label = hud.get("context_title_label") as Label
	_expect(context_panel != null and context_panel.visible, "interaction uses the context strip")
	_expect(context_title != null and context_title.text == "Record Spring", "context strip names the interaction")
	var prompt_label: Label = game_ui.get("prompt_label") as Label
	_expect(prompt_label != null and not prompt_label.visible, "legacy prompt label stays hidden")
	game_ui.call("hide_prompt")

	game_ui.call("show_message", "Blueprint recorded")
	await _wait_frames(2)
	var shell_data: Dictionary = hud.call("get_unified_hud_debug_data") as Dictionary
	_expect(int(shell_data.get("activity_count", 0)) >= 1, "messages publish into the activity rail")
	var message_panel: Control = game_ui.get("message_panel") as Control
	_expect(
		message_panel != null and is_zero_approx(message_panel.modulate.a),
		"legacy center message is visually retired"
	)


func _test_active_ability_support() -> void:
	if player == null or active_ribbon == null or hud == null:
		return
	ribbon_provider = RibbonProvider.new()
	ribbon_provider.name = "RibbonProvider"
	player.add_child(ribbon_provider)
	active_ribbon.call("force_refresh")
	await _wait_frames(3)
	var shell_data: Dictionary = hud.call("get_unified_hud_debug_data") as Dictionary
	_expect(int(shell_data.get("active_ability_count", 0)) == 1, "persistent abilities publish into support cluster")
	var ribbon_panel: Control = active_ribbon.get("ribbon_panel") as Control
	_expect(ribbon_panel != null and not ribbon_panel.visible, "legacy active ability ribbon is retired")


func _test_placement_mode() -> void:
	if placement_controller == null or hud == null or player == null:
		return
	placement_provider = PlacementProvider.new()
	placement_provider.name = "PlacementProvider"
	player.add_child(placement_provider)
	var started: bool = bool(placement_controller.call(
		"begin_session",
		placement_provider,
		"fixture",
		null
	))
	_expect(started, "shared placement fixture starts")
	await _wait_frames(4)
	_expect(str(hud.call("get_hud_mode")) == "placement", "HUD enters placement mode")
	var activity_zone: Control = hud.call("get_hud_zone", "activity") as Control
	var support_zone: Control = hud.call("get_hud_zone", "support") as Control
	var context_panel: Control = hud.get("context_panel") as Control
	_expect(activity_zone != null and not activity_zone.visible, "placement suppresses activity rail")
	_expect(support_zone != null and not support_zone.visible, "placement suppresses support cluster")
	_expect(context_panel != null and context_panel.visible, "placement owns the context strip")
	var old_panel: Control = placement_controller.get("panel") as Control
	_expect(old_panel != null and is_zero_approx(old_panel.modulate.a), "legacy placement panel is visually retired")
	if quick_dock != null:
		var dock_panel: Control = quick_dock.get("dock_panel") as Control
		_expect(dock_panel != null and dock_panel.modulate.a < 0.5, "placement dims the command dock")
	placement_controller.call("cancel_placement")
	await _wait_frames(4)
	_expect(str(hud.call("get_hud_mode")) == "exploration", "cancel restores exploration HUD mode")


func _test_focus_mode() -> void:
	if caster == null or hud == null:
		return
	caster.call("open_focus_spell_menu")
	await _wait_frames(3)
	_expect(str(hud.call("get_hud_mode")) == "focus", "spell library enters focus HUD mode")
	var activity_zone: Control = hud.call("get_hud_zone", "activity") as Control
	var support_zone: Control = hud.call("get_hud_zone", "support") as Control
	_expect(activity_zone != null and not activity_zone.visible, "focus suppresses activity rail")
	_expect(support_zone != null and not support_zone.visible, "focus suppresses support cluster")
	caster.call("close_focus_spell_menu")
	await _wait_frames(3)
	_expect(str(hud.call("get_hud_mode")) == "exploration", "closing focus restores exploration mode")


func _count_visible_named_controls(parent: Node, node_name: String) -> int:
	if parent == null:
		return 0
	var count: int = 0
	for candidate: Node in parent.find_children(node_name, "", true, false):
		if not candidate is Control:
			continue
		var control: Control = candidate as Control
		if control.visible and control.modulate.a > 0.01:
			count += 1
	return count


func _not_overlapping(first: Control, second: Control) -> bool:
	if first == null or second == null:
		return false
	var first_rect: Rect2 = first.get_global_rect().grow(-1.0)
	var second_rect: Rect2 = second.get_global_rect().grow(-1.0)
	return not first_rect.intersects(second_rect)


func _wait_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _cleanup_and_finish() -> void:
	Engine.time_scale = 1.0
	if player != null and is_instance_valid(player):
		player.queue_free()
	if game_ui != null and is_instance_valid(game_ui):
		game_ui.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("UNIFIED_HUD_SHELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("UNIFIED_HUD_SHELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
