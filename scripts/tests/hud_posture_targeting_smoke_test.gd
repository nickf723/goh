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
	player.name = "HUDPostureTargetingTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)

	for _frame: int in range(7):
		await get_tree().process_frame
	await get_tree().physics_frame

	var hud := player.get_node_or_null("PlayerHUDV2") as PlayerHUDV2
	var presentation := player.get_node_or_null(
		"PlayerHUDCombatPresentation"
	) as PlayerHUDCombatPresentation
	var stealth := player.get_node_or_null(
		"StealthController"
	) as PlayerStealthController
	var targeting := player.get_node_or_null(
		"CombatTargetingAssist"
	) as CombatTargetingAssist

	_expect(hud != null, "Player retains HUD v2")
	_expect(presentation != null, "Compact HUD presentation installs")
	_expect(stealth != null, "Stealth controller remains available")
	_expect(targeting != null, "Targeting assist remains available")
	if hud == null or presentation == null or stealth == null or targeting == null:
		_finish(player, floor, stealth)
		return

	presentation.call("_process", 0.25)
	var debug: Dictionary = presentation.get_debug_data()
	_expect(bool(debug.get("compact_stats", false)), "Developer stat copy is hidden")
	_expect(
		hud.avatar_title_label.text == "GRACE",
		"Top-left header keeps only the active avatar name"
	)
	_expect(
		hud.stats_panel.offset_bottom <= 203.0,
		"Top-left resource panel uses the compact height"
	)

	stealth.set_crouched(true)
	presentation.call("_process", 0.25)
	debug = presentation.get_debug_data()
	_expect(bool(debug.get("crouch_visible", false)), "Crouching reveals the compact posture chip")
	_expect(str(debug.get("crouch_state", "")) == "CROUCHED", "Posture chip names crouch state")

	stealth.concealed = true
	stealth.current_noise = 0.64
	presentation.call("_process", 0.1)
	debug = presentation.get_debug_data()
	_expect(str(debug.get("crouch_state", "")) == "CONCEALED", "Concealment upgrades the posture chip")
	_expect(
		presentation.crouch_noise_bar != null
		and is_equal_approx(presentation.crouch_noise_bar.value, 0.64),
		"Posture chip carries the restrained noise meter"
	)
	var legacy_layer_value: Variant = stealth.get("hud_layer")
	_expect(
		legacy_layer_value is CanvasLayer
		and not (legacy_layer_value as CanvasLayer).visible,
		"Legacy crouch debug panel is suppressed"
	)

	presentation.call("_process", 0.1)
	debug = presentation.get_debug_data()
	_expect(bool(debug.get("soft_reticle", false)), "Soft aim uses the bracket reticle")
	_expect(bool(debug.get("hard_reticle", false)), "Hard lock uses the bracket reticle")

	var dummy := Node3D.new()
	dummy.name = "ReticleTestTarget"
	dummy.add_to_group("enemy")
	dummy.position = Vector3(0.0, 0.0, -17.2)
	add_child(dummy)
	player.call("set_lock_on_target", dummy)
	player.call("update_lock_on_marker")
	presentation.call("_process", 0.1)
	debug = presentation.get_debug_data()
	_expect(
		float(debug.get("target_warning", 0.0)) > 0.0,
		"Hard lock warns before the target leaves range"
	)
	var hard_marker_value: Variant = player.get("lock_on_marker")
	_expect(
		hard_marker_value is MeshInstance3D
		and (hard_marker_value as MeshInstance3D).mesh == null,
		"Hard lock no longer renders as a glowing sphere"
	)

	player.call("clear_lock_on")
	dummy.queue_free()
	stealth.concealed = false
	stealth.set_crouched(false)
	presentation.call("_process", 0.25)
	_expect(
		not bool(presentation.get_debug_data().get("crouch_visible", true)),
		"Standing fades the posture chip away"
	)

	_finish(player, floor, stealth)


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
	floor.name = "HUDPostureTargetingTestFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
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
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _finish(
	player: Node,
	floor: Node,
	stealth: PlayerStealthController
) -> void:
	if stealth != null:
		stealth.concealed = false
		stealth.set_crouched(false)
	_restore_stats()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if failures.is_empty():
		print("HUD_POSTURE_TARGETING_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("HUD_POSTURE_TARGETING_SMOKE_TEST: " + failure)
	get_tree().quit(1)
