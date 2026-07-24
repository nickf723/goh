extends Node

const PlayerDefenseControllerScript: Script = preload("res://scripts/player/player_defense_controller.gd")
const PlayerActionStateScript: Script = preload("res://scripts/player/player_action_state.gd")
const HitReceiverScript: Script = preload("res://scripts/combat/hit_receiver.gd")
const StatusReceiverScript: Script = preload("res://scripts/combat/status_receiver.gd")
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")

var failures: Array[String] = []
var original_snapshot: Dictionary
var original_invulnerable: bool
var original_invulnerability_timer: float


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_snapshot = GameState.get_stat_snapshot()
	original_invulnerable = GameState.player_invulnerable
	original_invulnerability_timer = GameState.player_invulnerability_timer

	var actor: CharacterBody3D = CharacterBody3D.new()
	actor.name = "DefenseTestPlayer"
	add_child(actor)

	var action_state: PlayerActionState = PlayerActionStateScript.new() as PlayerActionState
	action_state.name = "PlayerActionState"
	actor.add_child(action_state)
	action_state.set_process(false)

	var defense: PlayerDefenseController = PlayerDefenseControllerScript.new() as PlayerDefenseController
	defense.name = "PlayerDefenseController"
	actor.add_child(defense)
	defense.set_process(false)

	var attacker: CharacterBody3D = CharacterBody3D.new()
	attacker.name = "DefenseTestAttacker"
	add_child(attacker)

	var status_receiver: Node = StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	attacker.add_child(status_receiver)
	status_receiver.set_process(false)

	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", "Defense Test Attacker")
	hit_receiver.set("hit_mode", 3)
	hit_receiver.set("max_health", 4)
	hit_receiver.set("current_health", 4)
	hit_receiver.set("max_stance", 3)
	hit_receiver.set("current_stance", 3)
	hit_receiver.set("disappears_when_defeated", false)
	attacker.add_child(hit_receiver)
	hit_receiver.set_process(false)

	var payload: DamagePayload = DamagePayload.new()
	payload.amount = 1
	payload.stance_damage = 1
	payload.element = "neutral"
	payload.source_name = "Test Claw"
	payload.hit_type = "melee"
	payload.tags = ["enemy_attack", "physical", "melee"]

	attacker.position = Vector3(0.0, 0.0, -2.0)
	reset_resources()
	var hit_result: Dictionary = defense.resolve_incoming_attack(payload, attacker)
	assert_equal(hit_result.get("outcome"), "hit", "unguarded attack hits")
	assert_equal(GameState.get_stat("health"), 4, "unguarded attack damages health")
	assert_equal(GameState.get_stat("stance"), 4, "unguarded attack damages stance")
	assert_true(action_state.is_staggered, "unguarded attack starts a hit reaction lock")

	reset_actor_state(action_state, defense)
	reset_resources()
	attacker.position = Vector3(0.0, 0.0, -2.0)
	assert_true(defense.begin_guard(), "guard begins from ready state")
	var perfect_result: Dictionary = defense.resolve_incoming_attack(payload, attacker)
	assert_equal(perfect_result.get("outcome"), "perfect_guard", "fresh guard deflects attack")
	assert_equal(GameState.get_stat("health"), 5, "perfect guard protects health")
	assert_equal(GameState.get_stat("stamina"), 5, "perfect guard spends no stamina")
	assert_equal(GameState.get_stat("stance"), 5, "perfect guard spends no player stance")
	assert_equal(int(hit_receiver.get("current_stance")), 1, "perfect guard damages attacker stance")
	assert_true(bool(status_receiver.call("has_status", "staggered")), "perfect guard staggers attacker")

	reset_actor_state(action_state, defense)
	reset_resources()
	hit_receiver.set("current_stance", 3)
	status_receiver.call("clear_all_statuses")
	assert_true(defense.begin_guard(), "guard begins for held block")
	defense.perfect_guard_remaining = 0.0
	var block_result: Dictionary = defense.resolve_incoming_attack(payload, attacker)
	assert_equal(block_result.get("outcome"), "blocked", "held guard blocks frontal attack")
	assert_equal(GameState.get_stat("health"), 5, "held guard protects health")
	assert_equal(GameState.get_stat("stamina"), 4, "held guard spends stamina")
	assert_equal(GameState.get_stat("stance"), 4, "held guard spends stance")

	reset_actor_state(action_state, defense)
	reset_resources()
	GameState.set_stat("stamina", 0)
	GameState.set_stat("stance", 2)
	assert_true(defense.begin_guard(), "zero-stamina guard can enter but is fragile")
	defense.perfect_guard_remaining = 0.0
	var break_result: Dictionary = defense.resolve_incoming_attack(payload, attacker)
	assert_equal(break_result.get("outcome"), "guard_broken", "empty stamina breaks guard")
	assert_equal(GameState.get_stat("stance"), 0, "guard break empties stance")
	assert_true(action_state.is_staggered, "guard break staggers player")
	assert_true(not defense.is_guarding, "guard break ends guard")

	reset_actor_state(action_state, defense)
	reset_resources()
	attacker.position = Vector3(0.0, 0.0, 2.0)
	assert_true(defense.begin_guard(), "guard begins before rear test")
	defense.perfect_guard_remaining = 0.0
	var rear_result: Dictionary = defense.resolve_incoming_attack(payload, attacker)
	assert_equal(rear_result.get("outcome"), "hit", "rear attack bypasses directional guard")
	assert_equal(GameState.get_stat("health"), 4, "rear attack damages health")

	reset_actor_state(action_state, defense)
	reset_resources()
	attacker.position = Vector3(0.0, 0.0, -2.0)
	GameState.begin_player_invulnerability(0.2)
	var dodge_result: Dictionary = defense.resolve_incoming_attack(payload, attacker)
	assert_equal(dodge_result.get("outcome"), "dodged", "invulnerability resolves before guard")
	assert_equal(GameState.get_stat("health"), 5, "dodge protects health")

	assert_player_scene_contract()
	assert_guard_bindings()

	actor.queue_free()
	attacker.queue_free()
	restore_state()

	if failures.is_empty():
		print("PLAYER_DEFENSE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("PLAYER_DEFENSE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func reset_resources() -> void:
	GameState.set_stat("max_health", 5)
	GameState.set_stat("health", 5)
	GameState.set_stat("max_stamina", 5)
	GameState.set_stat("stamina", 5)
	GameState.set_stat("max_stance", 5)
	GameState.set_stat("stance", 5)
	GameState.player_invulnerable = false
	GameState.player_invulnerability_timer = 0.0


func reset_actor_state(action_state: PlayerActionState, defense: PlayerDefenseController) -> void:
	action_state.reset_for_respawn()
	defense.reset_defense()


func assert_player_scene_contract() -> void:
	var player: Node = PlayerScene.instantiate()
	if player.get_node_or_null("PlayerDefenseController") == null:
		failures.append("reusable Player scene is missing PlayerDefenseController")
	player.queue_free()


func assert_guard_bindings() -> void:
	assert_true(InputMap.has_action("guard"), "guard input action exists")
	assert_true(action_has_key("guard", KEY_F), "guard includes keyboard F")
	assert_true(action_has_mouse_button("guard", MOUSE_BUTTON_XBUTTON2), "guard includes Mouse 5")
	assert_true(action_has_joy_button("guard", 2), "guard includes controller face X")
	assert_true(not action_has_joy_button("weapon_light_attack", 2), "controller face X is exclusive to guard")


func action_has_key(action_name: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == keycode or key_event.physical_keycode == keycode:
				return true
	return false


func action_has_mouse_button(action_name: StringName, button: MouseButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func action_has_joy_button(action_name: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func restore_state() -> void:
	GameState.stats = original_snapshot.duplicate(true)
	for stat_variant: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_variant)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_variant]))
	GameState.player_invulnerable = original_invulnerable
	GameState.player_invulnerability_timer = original_invulnerability_timer


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")
