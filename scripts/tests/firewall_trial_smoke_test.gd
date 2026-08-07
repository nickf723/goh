extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_firewall_spell_trial_v1.tscn"
)
const COMPLETION_FLAG: String = "ember_scriptorium_firewall_trial_complete"

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_completion_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_completion_flag = GameState.get_flag(COMPLETION_FLAG)
	_prepare_stats()

	var trial: PrototypeFirewallSpellTrial = (
		TrialScene.instantiate() as PrototypeFirewallSpellTrial
	)
	add_child(trial)
	for _frame: int in range(20):
		await get_tree().process_frame
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null("Player") as CharacterBody3D
	var floor_gate: MechanismSlidingGate = trial.get_node_or_null(
		"EmberScriptoriumActors/FloorScriptGate"
	) as MechanismSlidingGate
	var corner_gate: MechanismSlidingGate = trial.get_node_or_null(
		"EmberScriptoriumActors/CornerScriptGate"
	) as MechanismSlidingGate
	_expect(player != null, "Ember Scriptorium spawns Grace")
	_expect(floor_gate != null, "Ember Scriptorium builds the floor gate")
	_expect(corner_gate != null, "Ember Scriptorium builds the corner gate")
	if player == null or floor_gate == null or corner_gate == null:
		_finish(trial)
		return

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var current_ability: AbilityDefinition = (
		caster.call("get_current_ability") as AbilityDefinition
		if caster != null and caster.has_method("get_current_ability")
		else null
	)
	_expect(
		current_ability != null and current_ability.get_spell_id() == "firewall",
		"Ember Scriptorium automatically equips Firewall"
	)

	var serial: int = int(player.get_meta("firewall_serial", 0))
	_publish_firewall_path(
		player,
		serial + 1,
		[
			Vector3(-3.0, 0.0, 2.0),
			Vector3(-1.5, 0.0, 3.5),
			Vector3(0.0, 0.0, 5.0),
			Vector3(1.5, 0.0, 6.5),
			Vector3(3.0, 0.0, 8.0),
		],
		[
			Vector3.UP,
			Vector3.UP,
			Vector3.UP,
			Vector3.UP,
			Vector3.UP,
		],
		["floor"],
		8.5,
		0,
		"released"
	)
	await get_tree().physics_frame
	var floor_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(floor_debug.get("stage", "")) == "corner_script",
		"long floor trace advances the trial to the turned script"
	)
	_expect(floor_gate.is_mechanism_active(), "valid floor trace opens the first gate")
	_expect(not corner_gate.is_mechanism_active(), "corner gate remains closed after stage one")

	_publish_firewall_path(
		player,
		serial + 2,
		[
			Vector3(0.0, 0.0, 20.0),
			Vector3(0.0, 0.0, 22.8),
			Vector3(0.0, 1.5, 24.6),
			Vector3(0.0, 3.7, 24.6),
			Vector3(0.0, 4.66, 23.8),
			Vector3(0.0, 4.66, 21.0),
		],
		[
			Vector3.UP,
			Vector3.UP,
			Vector3.BACK,
			Vector3.BACK,
			Vector3.DOWN,
			Vector3.DOWN,
		],
		["floor", "wall", "ceiling"],
		9.8,
		2,
		"released"
	)
	await get_tree().physics_frame
	var corner_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(corner_debug.get("stage", "")) == "mastery",
		"ordered floor-wall-ceiling trace completes the turned script"
	)
	_expect(corner_gate.is_mechanism_active(), "valid corner trace opens the second gate")
	_expect(
		int(corner_debug.get("last_transition_count", 0)) == 2,
		"trial retains the two authored surface transitions"
	)

	trial.call("_on_mastery_area_body_entered", player)
	var complete_debug: Dictionary = trial.get_debug_data()
	_expect(bool(complete_debug.get("complete", false)), "mastery seal completes the trial")
	_expect(GameState.get_flag(COMPLETION_FLAG), "trial records the Firewall mastery flag")

	trial.reset_trial()
	await get_tree().process_frame
	var reset_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(reset_debug.get("stage", "")) == "floor_script",
		"F8 reset returns the trial to the flat script"
	)
	_expect(not floor_gate.is_mechanism_active(), "reset closes the floor gate")
	_expect(not corner_gate.is_mechanism_active(), "reset closes the corner gate")
	_expect(not GameState.get_flag(COMPLETION_FLAG), "reset clears the temporary mastery flag")
	_expect(
		GameState.get_stat("mana") == GameState.get_stat("max_mana"),
		"reset restores Mana for another drawing attempt"
	)

	_finish(trial)


func _publish_firewall_path(
	player: CharacterBody3D,
	serial: int,
	points: Array[Vector3],
	normals: Array[Vector3],
	surface_sequence: Array[String],
	path_length: float,
	transitions: int,
	reason: String
) -> void:
	player.set_meta("firewall_serial", serial)
	player.set_meta("firewall_path_points", points)
	player.set_meta("firewall_path_normals", normals)
	player.set_meta("firewall_surface_sequence", surface_sequence)
	player.set_meta("firewall_path_length", path_length)
	player.set_meta("firewall_surface_transitions", transitions)
	player.set_meta("firewall_draw_reason", reason)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("FIREWALL_TRIAL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.set_flag(COMPLETION_FLAG, original_completion_flag)


func _finish(trial: Node) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if trial != null and is_instance_valid(trial):
		trial.queue_free()
	if failures.is_empty():
		print("FIREWALL_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FIREWALL_TRIAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
