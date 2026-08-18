extends Node

const CombatPlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player_combat_v2.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	_snapshot_stats()
	await _validate_adaptive_hud()
	_restore_stats()
	_finish()


func _validate_adaptive_hud() -> void:
	_expect(CombatPlayerScene != null, "combat player scene preloads")
	if CombatPlayerScene == null:
		return
	var player: Node = CombatPlayerScene.instantiate()
	_expect(player != null, "combat player instantiates")
	if player == null:
		return
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var hud: Node = player.get_node_or_null("PlayerHUDV2")
	_expect(hud != null, "combat player exposes unified HUD")
	if hud == null:
		player.queue_free()
		return
	_expect(hud.has_method("get_debug_data"), "adaptive HUD exposes debug data")
	var data: Dictionary = hud.call("get_debug_data") as Dictionary
	_expect(bool(data.get("adaptive_quiet_hud", false)), "adaptive quiet HUD is live")
	_expect(not bool(data.get("information_removed", true)), "quiet HUD does not remove information")

	# Fully healthy exploration should be allowed to settle into the quiet state.
	_set_full_resources()
	hud.set("wake_remaining", 0.0)
	var action_state: PlayerActionState = player.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	if action_state != null:
		action_state.clear_action_locks()
	hud.call("_update_adaptive_prominence", 0.25)
	data = hud.call("get_debug_data") as Dictionary
	_expect(bool(data.get("quiet", false)), "healthy exploration settles into quiet HUD state")
	_expect(float(data.get("stats_target_alpha", 1.0)) < 0.7, "quiet exploration dims persistent stats")
	_expect(float(data.get("action_target_alpha", 1.0)) < 0.5, "quiet exploration dims command dock")
	_expect(float(data.get("support_target_alpha", 1.0)) < 0.4, "quiet exploration strongly recedes support cluster")

	# Resource pressure must wake critical information even without fresh input.
	var max_health: int = maxi(GameState.get_stat("max_health"), 1)
	GameState.set_stat("health", maxi(roundi(float(max_health) * 0.18), 1))
	hud.set("wake_remaining", 0.0)
	hud.call("_update_adaptive_prominence", 0.25)
	data = hud.call("get_debug_data") as Dictionary
	_expect(float(data.get("resource_pressure", 0.0)) > 0.25, "low health generates HUD resource pressure")
	_expect(float(data.get("stats_target_alpha", 0.0)) > 0.7, "low health wakes stat cluster")

	# Combat intent must fully wake the action layer.
	_set_full_resources()
	if action_state != null:
		action_state.is_attacking = true
	hud.set("wake_remaining", 0.0)
	hud.call("_update_adaptive_prominence", 0.25)
	data = hud.call("get_debug_data") as Dictionary
	_expect(not bool(data.get("quiet", true)), "combat exits quiet HUD state")
	_expect(float(data.get("action_target_alpha", 0.0)) >= 0.99, "combat fully wakes command dock")
	if action_state != null:
		action_state.is_attacking = false

	player.queue_free()


func _snapshot_stats() -> void:
	for stat_id: String in [
		"health", "max_health", "stamina", "max_stamina", "mana", "max_mana",
	]:
		original_stats[stat_id] = GameState.get_stat(stat_id)


func _restore_stats() -> void:
	for stat_id: String in original_stats.keys():
		GameState.set_stat(stat_id, int(original_stats[stat_id]))


func _set_full_resources() -> void:
	for pair: Array in [
		["health", "max_health"],
		["stamina", "max_stamina"],
		["mana", "max_mana"],
	]:
		var maximum: int = maxi(GameState.get_stat(str(pair[1])), 1)
		GameState.set_stat(str(pair[0]), maximum)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("PLAYER_HUD_ADAPTIVE_QUIET_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PLAYER_HUD_ADAPTIVE_QUIET_SMOKE_TEST: " + failure)
	get_tree().quit(1)
