extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()

	var floor := _make_floor()
	add_child(floor)
	var player := PlayerScene.instantiate() as CharacterBody3D
	player.name = "HUDIdleBudgetTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(10):
		await get_tree().process_frame
	await get_tree().physics_frame

	var hud: Node = player.get_node_or_null("PlayerHUDV2")
	var belt: Node = player.get_node_or_null("QuickSpellBeltPresentation")
	_expect(hud is PlayerHUDUnifiedBudgeted, "player scene uses the budgeted unified HUD")
	_expect(belt != null, "player installs the unified quick-spell belt")
	if hud == null or belt == null:
		_finish(player, floor)
		return

	hud.set_process(false)
	belt.set_process(false)

	# Warm caches and cadence counters before taking the stable idle snapshot.
	for _frame: int in range(30):
		hud.call("_process", 1.0 / 60.0)
		belt.call("_process", 1.0 / 60.0)

	var hud_before: Dictionary = hud.get_debug_data()
	var belt_before: Dictionary = belt.get_debug_data()
	var icon_cache_before: Dictionary = belt_before.get(
		"spell_icon_cache",
		{}
	) as Dictionary
	var updates_before: int = int(hud_before.get("unified_updates", 0))
	var panel_cache_before: int = int(hud_before.get("panel_style_cache", 0))
	var shell_cache_before: int = int(hud_before.get("shell_style_cache", 0))
	var sweeps_before: int = int(belt_before.get("duplicate_surface_sweeps", 0))
	var heavy_refreshes_before: int = int(belt_before.get("heavy_refreshes", 0))
	var fallback_polls_before: int = int(belt_before.get("fallback_polls", 0))
	var icon_probes_before: int = int(icon_cache_before.get("texture_path_probes", 0))
	var icon_styles_before: int = int(icon_cache_before.get("badge_style_creations", 0))

	for _frame: int in range(120):
		hud.call("_process", 1.0 / 60.0)
		belt.call("_process", 1.0 / 60.0)

	var hud_after: Dictionary = hud.get_debug_data()
	var belt_after: Dictionary = belt.get_debug_data()
	var icon_cache_after: Dictionary = belt_after.get(
		"spell_icon_cache",
		{}
	) as Dictionary
	var update_delta: int = int(hud_after.get("unified_updates", 0)) - updates_before

	_expect(
		bool(hud_after.get("budgeted_unified_hud", false)),
		"unified HUD exposes its bounded idle contract"
	)
	_expect(
		update_delta > 0 and update_delta <= 24,
		"two seconds of 60 FPS idle time produce at most 24 unified HUD updates"
	)
	_expect(
		int(hud_after.get("legacy_suppression_passes", 0)) == 1,
		"legacy HUD suppression performs one startup tree search"
	)
	_expect(
		int(hud_after.get("panel_style_cache", 0)) == panel_cache_before,
		"idle base-HUD refreshes reuse cached panel styles"
	)
	_expect(
		int(hud_after.get("shell_style_cache", 0)) == shell_cache_before,
		"idle unified-shell refreshes reuse cached shell styles"
	)
	_expect(
		not bool(hud_after.get("per_frame_style_allocation", true)),
		"unified HUD reports no per-frame style allocation"
	)
	_expect(
		int(belt_after.get("duplicate_surface_sweeps", -1)) == sweeps_before,
		"quick belt performs no recursive duplicate sweep during idle frames"
	)
	_expect(
		not bool(belt_after.get("per_frame_duplicate_tree_scan", true)),
		"quick belt reports event-driven duplicate retirement"
	)
	_expect(
		bool(belt_after.get("duplicate_surface_listener", false)),
		"quick belt listens for late generated surfaces without polling"
	)
	_expect(
		bool(belt_after.get("event_driven_slots", false)),
		"quick spell slots listen to caster, loadout, and persistent-slot events"
	)
	_expect(
		not bool(belt_after.get("fallback_polling_enabled", true)),
		"stable quick dock disables periodic safety polling"
	)
	_expect(
		int(belt_after.get("fallback_polls", -1)) == fallback_polls_before,
		"idle quick dock performs no fallback polls"
	)
	_expect(
		int(belt_after.get("heavy_refreshes", -1)) == heavy_refreshes_before,
		"idle quick dock performs no heavy presentation refreshes"
	)
	_expect(
		int(icon_cache_after.get("texture_path_probes", -1)) == icon_probes_before,
		"idle quick dock performs no repeated icon filesystem probes"
	)
	_expect(
		int(icon_cache_after.get("badge_style_creations", -1)) == icon_styles_before,
		"idle quick dock allocates no new spell badge styles"
	)

	_finish(player, floor)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "HUDIdleBudgetFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("HUD_IDLE_BUDGET_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _finish(player: Node, floor: Node) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if failures.is_empty():
		print("HUD_IDLE_BUDGET_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("HUD_IDLE_BUDGET_SMOKE_TEST: " + failure)
	get_tree().quit(1)
