extends Node

const ConcentrationManagerScript = preload(
	"res://scripts/concentration/concentration_manager.gd"
)
const RepeatDefinition: Resource = preload(
	"res://data/concentration/repeat_concentration.tres"
)
const RainDefinition: Resource = preload(
	"res://data/weather/rain_weather.tres"
)
const BoulderAbility: AbilityDefinition = preload(
	"res://data/abilities/boulder_ability.tres"
)
const StableTrajectoryScript = preload(
	"res://scripts/time/repeat_trajectory_echo_stable.gd"
)
const TimeMemoryControllerScript = preload(
	"res://scripts/time/repeat_echo_controller_time_memory.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	await _test_concentration_budget()
	await _test_repeat_shell_recursion_guard()
	_finish()


func _test_concentration_budget() -> void:
	var manager := ConcentrationManagerScript.new() as ConcentrationManager
	manager.name = "BudgetTestManager"
	manager.show_hud = false
	add_child(manager)
	await get_tree().process_frame

	_expect(
		manager.activate_effect(RepeatDefinition, null),
		"Repeat activates inside an empty concentration budget"
	)
	_expect(
		manager.activate_effect(RainDefinition, null),
		"Rain activates without evicting Repeat"
	)
	_expect(
		manager.has_effect("repeat_concentration")
		and manager.has_effect("rain_weather"),
		"Rain and Repeat coexist in the active concentration set"
	)
	_expect(
		manager.get_active_effect_count() == 2,
		"the manager reports two simultaneous concentration effects"
	)
	_expect(
		manager.get_reservation_percent() == 60,
		"Repeat 20% plus Rain 40% reserves exactly 60%"
	)
	_expect(
		manager.get_usable_mana_cap() == 40,
		"the combined concentration budget leaves 40% Mana usable"
	)
	_expect(
		manager.is_element_free("water"),
		"Rain's free-Water rule remains active while Repeat coexists"
	)

	manager.deactivate_effect_by_id("rain_weather", false)
	_expect(
		manager.has_effect("repeat_concentration")
		and not manager.has_effect("rain_weather"),
		"dismissing Rain releases only Rain"
	)
	_expect(
		manager.get_reservation_percent() == 20,
		"Repeat's 20% reservation survives Rain dismissal"
	)

	manager.activate_effect(RainDefinition, null)
	manager.deactivate_effect_by_id("repeat_concentration", false)
	_expect(
		manager.has_effect("rain_weather")
		and not manager.has_effect("repeat_concentration"),
		"releasing Repeat leaves Rain intact"
	)
	_expect(
		manager.get_reservation_percent() == 40,
		"Rain's 40% reservation survives Repeat dismissal"
	)
	manager.deactivate_all_effects(false)
	manager.queue_free()
	await get_tree().process_frame


func _test_repeat_shell_recursion_guard() -> void:
	var proxy := Node3D.new()
	proxy.name = "RepeatProxy"
	add_child(proxy)
	var echo := StableTrajectoryScript.new() as RepeatTrajectoryEchoStable
	echo.name = "RememberedBoulderTest"
	add_child(echo)
	echo.configure(
		BoulderAbility,
		proxy,
		BoulderAbility.get_action_payload()
	)
	await get_tree().process_frame
	var shell: Node = echo.visual_shell
	_expect(shell != null, "the remembered Boulder constructs one visual shell")
	_expect(
		shell != null and bool(shell.get_meta("clone_spell_replay", false)),
		"the remembered Boulder shell is clone-tagged before observation"
	)
	_expect(
		shell != null and bool(shell.get_meta("repeat_memory_visual", false)),
		"the shell explicitly identifies itself as a Repeat memory visual"
	)
	var observer := TimeMemoryControllerScript.new() as RepeatEchoControllerTimeMemory
	add_child(observer)
	_expect(
		shell != null and bool(observer.call("_belongs_to_clone_memory", shell)),
		"Repeat's scene observer rejects its own remembered Boulder subtree"
	)
	var shell_debug: Dictionary = echo.get_debug_data()
	_expect(
		bool(shell_debug.get("visual_shell_clone_tagged", false)),
		"trajectory debug data exposes the recursion guard"
	)
	observer.queue_free()
	echo.finish_replay()
	proxy.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("REPEAT_CONCENTRATION_BUDGET_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for key_value: Variant in GameState.stats.keys():
		var key: String = str(key_value)
		GameState.stat_changed.emit(key, int(GameState.stats[key_value]))


func _finish() -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if failures.is_empty():
		print("REPEAT_CONCENTRATION_BUDGET_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("REPEAT_CONCENTRATION_BUDGET_SMOKE_TEST: " + failure)
	get_tree().quit(1)
