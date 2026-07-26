extends "res://scripts/tests/weapon_moveset_smoke_test.gd"


func _ready() -> void:
	failures.clear()
	validate_weapon(Sword, "sword", 9)
	validate_weapon(Hammer, "hammer", 7)
	validate_weapon(Spear, "lance", 7)
	validate_sword_branch_tree()
	validate_hammer_identity()
	validate_spear_identity()
	validate_payload_contracts()
	validate_critical_profiles()
	validate_stance_critical_loop()

	if failures.is_empty():
		print("WEAPON_MOVESET_CORE_DIAGNOSTIC: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("WEAPON_MOVESET_CORE_DIAGNOSTIC: " + failure)
	get_tree().quit(1)
