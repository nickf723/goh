extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_duplicate_spell_trial_v1.tscn"
)
const DuplicateControllerScript = preload(
	"res://scripts/soul/soul_duplicate_controller_ready.gd"
)
const COMPLETION_FLAG: String = "hall_of_two_souls_duplicate_trial_complete"

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_flag = GameState.get_flag(COMPLETION_FLAG)
	_prepare_stats()
	var trial: PrototypeDuplicateSpellTrial = TrialScene.instantiate() as PrototypeDuplicateSpellTrial
	add_child(trial)
	await _wait_frames(24)
	var player: CharacterBody3D = trial.get_node_or_null("Player") as CharacterBody3D
	var manager: Node = _ensure_manager(trial)
	_expect(player != null, "Hall of Two Souls spawns Grace")
	_expect(manager != null, "Hall of Two Souls resolves concentration")
	if player == null or manager == null:
		_finish(trial)
		return

	var duplicate_controller := DuplicateControllerScript.new() as SoulDuplicateControllerReady
	duplicate_controller.name = "SoulDuplicateControllerTestFixture"
	trial.add_child(duplicate_controller)
	duplicate_controller.bind_duplicate(player, manager)
	await _wait_frames(5)
	var duplicate: SoulDuplicateActorReady = get_tree().get_first_node_in_group("soul_duplicates") as SoulDuplicateActorReady
	_expect(duplicate != null, "trial fixture creates Soul Grace")
	if duplicate == null:
		_finish(trial)
		return

	trial.grace_plate.call("_on_body_entered", player)
	trial.soul_plate.call("_on_body_entered", duplicate)
	trial.evaluate_progression_now()
	await _wait_frames(2)
	_expect(trial.divergence_gate.is_mechanism_active(), "both bodies open the Divergence gate")
	_expect(not bool(trial.divergence_gate.get_debug_data().get("collision_enabled", true)), "Divergence gate removes blocking collision")
	_expect(str(trial.get_debug_data().get("stage", "")) == "double_strike", "Divergence advances exactly once")

	var grace_payload := DamagePayload.new()
	grace_payload.amount = 1
	grace_payload.source_name = "Grace Test Strike"
	var soul_payload := DamagePayload.new()
	soul_payload.amount = 1
	soul_payload.source_name = "Soul Test Strike"
	soul_payload.tags = ["soul", "duplicate", "live_clone"]
	trial.grace_strike_target.receive_damage_payload(grace_payload)
	trial.soul_strike_target.receive_damage_payload(soul_payload)
	trial.evaluate_progression_now()
	await _wait_frames(2)
	_expect(trial.strike_gate.is_mechanism_active(), "parallel attack state opens the Double Strike gate")
	_expect(not bool(trial.strike_gate.get_debug_data().get("collision_enabled", true)), "Double Strike gate removes blocking collision")
	_expect(str(trial.get_debug_data().get("stage", "")) == "mirrored_magic", "Double Strike advances to Mirrored Magic")

	trial.grace_magic_target.receive_damage_payload(grace_payload)
	trial.soul_magic_target.receive_damage_payload(soul_payload)
	trial.evaluate_progression_now()
	await _wait_frames(2)
	_expect(trial.magic_gate.is_mechanism_active(), "two live spell outcomes open the Mirrored Magic gate")
	_expect(not bool(trial.magic_gate.get_debug_data().get("collision_enabled", true)), "Mirrored Magic gate removes blocking collision")
	_expect(str(trial.get_debug_data().get("stage", "")) == "mastery", "Mirrored Magic advances to mastery")
	_expect(int(trial.get_debug_data().get("reliable_gate_opens", 0)) == 3, "all three Hall doors report one reliable opening")

	trial.call("_on_mastery_entered", player)
	_expect(GameState.get_flag(COMPLETION_FLAG), "mastery seal records Duplicate completion")
	trial.reset_trial()
	await _wait_frames(4)
	_expect(not trial.divergence_gate.is_mechanism_active(), "reset closes Divergence gate")
	_expect(not trial.strike_gate.is_mechanism_active(), "reset closes Double Strike gate")
	_expect(not trial.magic_gate.is_mechanism_active(), "reset closes Mirrored Magic gate")
	_expect(not GameState.get_flag(COMPLETION_FLAG), "reset clears temporary Duplicate mastery")
	_finish(trial)


func _ensure_manager(parent: Node) -> Node:
	var existing: Node = get_tree().get_first_node_in_group("concentration_manager")
	if existing != null:
		return existing
	var script: Script = load("res://scripts/concentration/concentration_manager.gd") as Script
	if script == null:
		return null
	var manager: Node = script.new()
	manager.name = "ConcentrationManager"
	manager.set("show_hud", false)
	parent.add_child(manager)
	return manager


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.append(label)
		push_error("DUPLICATE_SPELL_TRIAL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for key: Variant in GameState.stats.keys():
		GameState.stat_changed.emit(str(key), int(GameState.stats[key]))
	GameState.set_flag(COMPLETION_FLAG, original_flag)


func _finish(trial: Node) -> void:
	_restore_state()
	if trial != null and is_instance_valid(trial):
		trial.queue_free()
	if failures.is_empty():
		print("DUPLICATE_SPELL_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
