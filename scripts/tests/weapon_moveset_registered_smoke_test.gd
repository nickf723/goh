extends Node

const WeaponMovesetSuiteScript: Script = preload("res://scripts/tests/weapon_moveset_smoke_test.gd")
const Sword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const Hammer: WeaponDefinition = preload("res://data/weapons/training_hammer.tres")
const Spear: WeaponDefinition = preload("res://data/weapons/training_spear.tres")


func _ready() -> void:
	var suite: Node = WeaponMovesetSuiteScript.new()
	var suite_failures: Array = suite.get("failures") as Array
	suite_failures.clear()

	# Validate the global progression sandbox before local combat fixtures exist.
	suite.call("validate_combat_arena_sandbox")

	suite.call("validate_weapon", Sword, "sword", 9)
	suite.call("validate_weapon", Hammer, "hammer", 7)
	suite.call("validate_weapon", Spear, "lance", 7)
	suite.call("validate_sword_branch_tree")
	suite.call("validate_hammer_identity")
	suite.call("validate_spear_identity")
	suite.call("validate_payload_contracts")
	suite.call("validate_critical_profiles")
	suite.call("validate_stance_critical_loop")

	var failures: Array[String] = []
	for failure: Variant in suite.get("failures") as Array:
		failures.append(str(failure))
	suite.free()

	if failures.is_empty():
		print("WEAPON_MOVESET_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("WEAPON_MOVESET_SMOKE_TEST: " + failure)
	get_tree().quit(1)
