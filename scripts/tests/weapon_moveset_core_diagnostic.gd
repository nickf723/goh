extends "res://scripts/tests/weapon_moveset_smoke_test.gd"


func _ready() -> void:
	failures.clear()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() else "all"

	match mode:
		"graph":
			validate_weapon(Sword, "sword", 9)
			validate_weapon(Hammer, "hammer", 7)
			validate_weapon(Spear, "lance", 7)
		"sword":
			validate_sword_branch_tree()
		"hammer":
			validate_hammer_identity()
		"spear":
			validate_spear_identity()
		"payload":
			validate_payload_contracts()
		"critical":
			validate_critical_profiles()
		"stance":
			validate_stance_critical_loop()
		_:
			validate_weapon(Sword, "sword", 9)
			validate_weapon(Hammer, "hammer", 7)
			validate_weapon(Spear, "lance", 7)
			validate_sword_branch_tree()
			validate_hammer_identity()
			validate_spear_identity()
			validate_payload_contracts()
			validate_critical_profiles()
			validate_stance_critical_loop()

	var label: String = "WEAPON_MOVESET_CORE_DIAGNOSTIC_" + mode.to_upper()
	if failures.is_empty():
		print(label + ": PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error(label + ": " + failure)
	get_tree().quit(1)
