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

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "PlayerHUDV2TestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var hud: PlayerHUDV2 = player.get_node_or_null(
		"PlayerHUDV2"
	) as PlayerHUDV2
	var status_receiver: PlayerStatusReceiver = player.get_node_or_null(
		"StatusReceiver"
	) as PlayerStatusReceiver
	var control_router: Node = player.get_node_or_null("PlayerControlRouter")

	_expect(hud != null, "Shared player installs PlayerHUDV2")
	_expect(status_receiver != null, "HUD test player retains status receiver")
	_expect(control_router != null, "HUD test player retains unified controls")
	if hud == null or status_receiver == null or control_router == null:
		_finish(player, floor, status_receiver)
		return

	hud.refresh_data(true)
	var debug: Dictionary = hud.get_debug_data()
	_expect(bool(debug.get("stats_panel", false)), "Top-left stats panel is visible")
	_expect(bool(debug.get("quick_panel", false)), "Bottom-left quick panel is visible")
	_expect(bool(debug.get("portrait", false)), "Bottom-right Grace portrait exists")
	_expect(
		bool(debug.get("legacy_suppressed", false)),
		"Legacy gameplay HUD presentation is suppressed"
	)
	_expect(
		not (player.get_node("DivineSpecialHUD") as CanvasLayer).visible,
		"Legacy Divine Special HUD is hidden"
	)
	_expect(
		not (player.get_node("QuickItemBeltUI") as CanvasLayer).visible,
		"Legacy quick-item belt is hidden"
	)

	GameState.set_stat("health", 37)
	hud.refresh_data(true)
	var health_row: Dictionary = hud.stat_rows.get("health", {}) as Dictionary
	var health_bar: ProgressBar = health_row.get("bar") as ProgressBar
	var health_value: Label = health_row.get("value") as Label
	_expect(
		health_bar != null and is_equal_approx(health_bar.value, 37.0),
		"Health bar reflects live GameState data"
	)
	_expect(
		health_value != null and health_value.text == "37 / 100",
		"Health copy reflects live values"
	)

	status_receiver.apply_status("burning", 4.0, 1.0, "hud_v2_test")
	hud.refresh_data(true)
	debug = hud.get_debug_data()
	_expect(
		str(debug.get("expression", "")) == "burning",
		"Grace portrait reacts to Burning"
	)
	_expect(
		int(debug.get("status_count", 0)) >= 1,
		"Status effects appear above Grace's portrait"
	)

	status_receiver.clear_all_statuses()
	GameState.set_stat("health", 20)
	hud.refresh_data(true)
	debug = hud.get_debug_data()
	_expect(
		str(debug.get("expression", "")) == "low_health",
		"Grace portrait reacts to low health"
	)

	hud.show_dialogue_preview({
		"speaker": "Wayfarer",
		"title": "Roadside Traveler",
		"name": "Wayfarer",
		"text": "The first flame still burns in the wilds.",
		"choice": "◆  I will prove myself.",
		"accent": Color(0.35, 0.58, 0.82, 1.0),
	})
	debug = hud.get_debug_data()
	_expect(
		bool(debug.get("dialogue_visible", false)),
		"Dialogue strip extends left from Grace's portrait"
	)
	_expect(
		hud.dialogue_speaker_label.text == "WAYFARER",
		"Dialogue strip presents the NPC speaker"
	)
	hud.hide_dialogue_preview()
	_expect(
		not bool(hud.get_debug_data().get("dialogue_visible", true)),
		"Dialogue strip collapses cleanly"
	)

	var quick_names_result: Variant = control_router.call("get_quick_spell_names")
	_expect(
		quick_names_result is Array and (quick_names_result as Array).size() == 3,
		"Bottom-left HUD reads the three-spell quick ribbon"
	)

	_finish(player, floor, status_receiver)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	GameState.set_stat("focus", 5)
	GameState.set_stat("power", 1)
	GameState.set_stat("arcana", 1)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "PlayerHUDV2TestFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _restore_stats() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(
			stat_id,
			int(GameState.stats[stat_value])
		)


func _finish(
	player: Node,
	floor: Node,
	status_receiver: PlayerStatusReceiver
) -> void:
	if status_receiver != null:
		status_receiver.clear_all_statuses()
	_restore_stats()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if failures.is_empty():
		print("PLAYER_HUD_V2_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PLAYER_HUD_V2_SMOKE_TEST: " + failure)
	get_tree().quit(1)
