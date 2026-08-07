extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_lightning_flash_spell_trial_v1.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_flags: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_flags = GameState.flags.duplicate(true)
	_prepare_stats()

	var trial: PrototypeLightningFlashSpellTrial = (
		TrialScene.instantiate() as PrototypeLightningFlashSpellTrial
	)
	add_child(trial)
	for _frame: int in range(20):
		await get_tree().process_frame
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null("Player") as CharacterBody3D
	var first_gate: MechanismSlidingGate = trial.get_node_or_null(
		"ThunderlineActors/FirstContactGate"
	) as MechanismSlidingGate
	var chasm_gate: MechanismSlidingGate = trial.get_node_or_null(
		"ThunderlineActors/ChasmContactGate"
	) as MechanismSlidingGate
	var dividers: Node = trial.get_node_or_null("ThunderlineGateDividers")
	_expect(player != null, "Thunderline spawns Grace")
	_expect(first_gate != null, "Thunderline builds the first contact gate")
	_expect(chasm_gate != null, "Thunderline builds the chasm contact gate")
	_expect(dividers != null, "Thunderline seals both gate flanks")
	if player == null or first_gate == null or chasm_gate == null:
		_finish(trial)
		return

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var current_ability: AbilityDefinition = (
		caster.call("get_current_ability") as AbilityDefinition
		if caster != null and caster.has_method("get_current_ability")
		else null
	)
	_expect(
		current_ability != null and current_ability.get_spell_id() == "flash",
		"Thunderline automatically equips Flash"
	)
	if dividers != null and dividers.has_method("get_debug_data"):
		var divider_debug: Dictionary = dividers.call("get_debug_data") as Dictionary
		_expect(
			int(divider_debug.get("divider_count", 0)) == 4,
			"two closed gates receive four solid divider walls"
		)

	var serial: int = int(player.get_meta("lightning_flash_serial", 0))
	_publish_flash_result(
		player,
		serial + 1,
		Vector3(0.0, 1.0, -5.5),
		Vector3(0.0, 1.0, 9.2),
		Vector3(0.0, 0.0, 1.0),
		14.7,
		true,
		"FirstContactGate"
	)
	await get_tree().physics_frame
	var first_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(first_debug.get("stage", "")) == "chasm_line",
		"first solid contact advances the trial to the open circuit"
	)
	_expect(first_gate.is_mechanism_active(), "first Flash contact opens the first gate")

	_publish_flash_result(
		player,
		serial + 2,
		Vector3(0.0, 1.0, 14.0),
		Vector3(0.0, 21.0, 24.0),
		Vector3(0.0, 0.72, 0.69).normalized(),
		24.0,
		false,
		"none"
	)
	await get_tree().physics_frame
	var upward_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(upward_debug.get("stage", "")) == "chasm_line",
		"aiming upward does not counterfeit the chasm solution"
	)
	_expect(
		int(upward_debug.get("upward_mistakes", 0)) == 1,
		"Thunderline records the unsafe upward line"
	)
	_expect(not chasm_gate.is_mechanism_active(), "upward Flash leaves the far gate closed")

	_publish_flash_result(
		player,
		serial + 3,
		Vector3(0.0, 1.0, 14.0),
		Vector3(0.0, 1.0, 35.8),
		Vector3(0.0, 0.0, 1.0),
		21.8,
		true,
		"ChasmContactGate"
	)
	await get_tree().physics_frame
	var chasm_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(chasm_debug.get("stage", "")) == "mastery",
		"long first-contact Flash completes the open circuit"
	)
	_expect(chasm_gate.is_mechanism_active(), "valid chasm contact opens the far gate")

	trial.call("_on_mastery_area_body_entered", player)
	var complete_debug: Dictionary = trial.get_debug_data()
	_expect(bool(complete_debug.get("complete", false)), "mastery seal completes the Thunderline")
	_expect(
		GameState.get_flag("thunderline_flash_spell_trial_complete"),
		"Thunderline records its mastery flag"
	)

	trial.reset_trial()
	await get_tree().process_frame
	var reset_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(reset_debug.get("stage", "")) == "first_contact",
		"F8 reset returns the trial to First Contact"
	)
	_expect(not first_gate.is_mechanism_active(), "reset closes the first gate")
	_expect(not chasm_gate.is_mechanism_active(), "reset closes the chasm gate")
	_expect(
		not GameState.get_flag("thunderline_flash_spell_trial_complete"),
		"reset clears the temporary mastery flag"
	)
	_expect(
		GameState.get_stat("mana") == GameState.get_stat("max_mana"),
		"reset restores Mana for another Flash attempt"
	)

	_finish(trial)


func _publish_flash_result(
	player: CharacterBody3D,
	serial: int,
	origin: Vector3,
	destination: Vector3,
	direction: Vector3,
	distance: float,
	contacted: bool,
	contact_name: String
) -> void:
	player.set_meta("lightning_flash_serial", serial)
	player.set_meta("lightning_flash_origin", origin)
	player.set_meta("lightning_flash_destination", destination)
	player.set_meta("lightning_flash_direction", direction)
	player.set_meta("lightning_flash_distance", distance)
	player.set_meta("lightning_flash_contacted", contacted)
	player.set_meta("lightning_flash_contact_name", contact_name)
	player.global_position = destination


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
	push_error("LIGHTNING_FLASH_TRIAL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.flags = original_flags.duplicate(true)


func _finish(trial: Node) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if trial != null and is_instance_valid(trial):
		trial.queue_free()
	if failures.is_empty():
		print("LIGHTNING_FLASH_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LIGHTNING_FLASH_TRIAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
