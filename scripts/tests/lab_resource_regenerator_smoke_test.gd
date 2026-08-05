extends Node

const RegeneratorScript: Script = preload(
	"res://scripts/systems/lab_resource_regenerator.gd"
)
const InstallerScript: Script = preload(
	"res://scripts/systems/lab_resource_regenerator_installer.gd"
)
const GameUIScene: PackedScene = preload("res://scenes/ui/game_ui.tscn")

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	await _validate_identity_detection()
	await _validate_regeneration_behavior()
	await _validate_installer_deduplication()
	await _validate_shared_ui_wiring()
	_restore_stats()
	_finish()


func _validate_identity_detection() -> void:
	var installer := InstallerScript.new() as LabResourceRegeneratorInstaller
	installer.install_automatically = false
	add_child(installer)
	installer.set_process(false)
	_expect(
		installer.matches_lab_identity(
			"res://scenes/levels/prototypes/prototype_mechanism_network_lab_v1.tscn",
			"PrototypeMechanismNetworkLab"
		),
		"playable lab scene identities are recognized"
	)
	_expect(
		installer.matches_lab_identity(
			"res://scenes/levels/prototypes/prototype_training_yard_v1.tscn",
			"PrototypeTrainingYard",
			["familiar_training_lab"]
		),
		"conventional lab groups opt unusually named testing spaces into regeneration"
	)
	_expect(
		not installer.matches_lab_identity(
			"res://scenes/tests/mechanism_network_lab_smoke_test.tscn",
			"MechanismNetworkLabSmokeTest",
			["mechanism_network_labs"]
		),
		"test scenes do not receive background resource regeneration"
	)
	_expect(
		not installer.matches_lab_identity(
			"res://scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn",
			"PrototypeRuinedVillageApproach"
		),
		"ordinary production levels are not treated as labs"
	)
	installer.queue_free()
	await get_tree().process_frame


func _validate_regeneration_behavior() -> void:
	GameState.set_stat("max_mana", 12)
	GameState.set_stat("mana", 0)
	GameState.set_stat("max_stamina", 9)
	GameState.set_stat("stamina", 9)
	GameState.set_stat("max_focus", 6)
	GameState.set_stat("focus", 6)

	var regenerator := RegeneratorScript.new() as LabResourceRegenerator
	regenerator.name = "DeterministicRegenerator"
	regenerator.refill_on_ready = false
	regenerator.mana_per_second = 8.0
	regenerator.stamina_per_second = 0.0
	regenerator.focus_per_second = 0.0
	add_child(regenerator)
	regenerator.set_process(false)

	regenerator._process(0.5)
	_expect(GameState.get_stat("mana") == 4, "mana regenerates at the configured rate")
	regenerator._process(1.0)
	_expect(GameState.get_stat("mana") == 12, "mana regeneration clamps at maximum mana")

	regenerator._process(5.0)
	_expect(regenerator.mana_buffer == 0.0, "full mana cannot bank invisible regeneration credit")
	_expect(GameState.spend_mana(2), "test cast spends mana after the full-state wait")
	regenerator._process(0.125)
	_expect(
		GameState.get_stat("mana") == 11,
		"the next cast restores only newly earned mana rather than stored overflow"
	)

	GameState.set_stat("mana", 2)
	GameState.set_stat("stamina", 3)
	GameState.set_stat("focus", 1)
	regenerator.stamina_per_second = 10.0
	regenerator.focus_per_second = 8.0
	var refill: Dictionary = regenerator.refill_resources()
	_expect(GameState.get_stat("mana") == 12, "lab entry refill tops off mana")
	_expect(GameState.get_stat("stamina") == 9, "lab entry refill tops off stamina")
	_expect(GameState.get_stat("focus") == 6, "lab entry refill tops off Focus")
	_expect(int(refill.get("mana", 0)) == 10, "entry refill reports restored mana")

	regenerator.queue_free()
	await get_tree().process_frame


func _validate_installer_deduplication() -> void:
	var lab_root := Node3D.new()
	lab_root.name = "SyntheticLab"
	lab_root.add_to_group("lab_resource_regeneration")
	add_child(lab_root)

	var installer := InstallerScript.new() as LabResourceRegeneratorInstaller
	installer.name = "Installer"
	installer.install_automatically = false
	lab_root.add_child(installer)
	installer.set_process(false)

	var installed: LabResourceRegenerator = installer.install_for_scene(lab_root)
	_expect(installed != null, "installer creates regeneration for an opted-in lab")
	_expect(installed.get_parent() == lab_root, "automatic regeneration belongs to the lab root")
	var reused: LabResourceRegenerator = installer.install_for_scene(lab_root)
	_expect(reused == installed, "repeated installation reuses the existing service")

	var scoped_count: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("lab_resource_regenerators"):
		if candidate == lab_root or lab_root.is_ancestor_of(candidate):
			scoped_count += 1
	_expect(scoped_count == 1, "a lab never receives duplicate regenerators")
	_expect(installer.install_count == 1, "installer records one creation")
	_expect(installer.reused_count >= 1, "installer records service reuse")

	lab_root.queue_free()
	await get_tree().process_frame


func _validate_shared_ui_wiring() -> void:
	var ui: Node = GameUIScene.instantiate()
	ui.name = "GameUIFixture"
	add_child(ui)
	await get_tree().process_frame
	_expect(
		ui.get_node_or_null("LabResourceRegeneratorInstaller") is LabResourceRegeneratorInstaller,
		"shared GameUI carries the lab resource installer"
	)
	ui.queue_free()
	await get_tree().process_frame


func _restore_stats() -> void:
	for stat_value: Variant in original_stats.keys():
		var stat_id: String = str(stat_value)
		GameState.set_stat(stat_id, int(original_stats[stat_value]))


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("LAB_RESOURCE_REGENERATOR_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("LAB_RESOURCE_REGENERATOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LAB_RESOURCE_REGENERATOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
