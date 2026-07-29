extends "res://scripts/tests/divine_specials_smoke_test.gd"


func _validate_catalog_and_charge(
	controller: PlayerDivineSpecialController
) -> void:
	var available: Array[DivineSpecialDefinition] = (
		controller.get_available_specials(true)
	)
	_expect(available.size() == 3, "Ruvia exposes three debug Divine Specials")
	_expect(
		controller.get_definition_by_id("ruvia_caldera_drop") != null,
		"Catalog contains Caldera Drop"
	)
	_expect(
		controller.get_definition_by_id("ruvia_wildfire_procession") != null,
		"Catalog contains Wildfire Procession"
	)
	_expect(
		controller.get_definition_by_id("ruvia_hearth_first_flame") != null,
		"Catalog contains Hearth of the First Flame"
	)
	controller.set_charge(0.0, "test_empty")
	var awarded: float = controller.award_charge(12.5, "test_award")
	_expect(is_equal_approx(awarded, 12.5), "Combat charge can be awarded")
	_expect(
		is_equal_approx(controller.divine_charge, 12.5),
		"Awarded Divine Charge is retained"
	)
	controller.force_full_charge("test_full")
	var selected: DivineSpecialDefinition = controller.get_selected_special(true)
	_expect(
		selected != null
		and controller.divine_charge + 0.001 >= selected.required_charge,
		"Full Divine Charge arms the forced-debug Special catalog"
	)


func _validate_caldera(
	controller: PlayerDivineSpecialController
) -> void:
	var hostile_projectile: GenericProjectile = GenericProjectile.new()
	hostile_projectile.name = "DivineSpecialHostileProjectile"
	hostile_projectile.position = Vector3(0.35, 1.0, -4.1)
	add_child(hostile_projectile)
	await get_tree().process_frame

	controller.force_full_charge("caldera_test")
	_expect(
		controller.select_special_by_id("ruvia_caldera_drop", true),
		"Caldera Drop can be selected"
	)
	_expect(
		controller.activate_selected_special(true),
		"Caldera Drop activates"
	)
	_expect(
		controller.divine_charge <= 0.01,
		"Caldera Drop consumes the shared Divine Charge"
	)
	await get_tree().create_timer(1.2).timeout
	var result: Dictionary = controller.last_effect_result
	_expect(
		str(result.get("special_id", "")) == "ruvia_caldera_drop",
		"Caldera Drop reports its identity"
	)
	_expect(
		bool(result.get("impact_completed", false)),
		"Caldera Drop reaches its impact"
	)
	_expect(
		bool(result.get("fire_field_spawned", false)),
		"Caldera Drop leaves a burning crater"
	)
	_expect(
		int(result.get("targets_hit", 0)) > 0,
		"Caldera Drop affects nearby hostile targets"
	)
	_expect(
		int(result.get("projectiles_cleared", 0)) >= 1,
		"Caldera Drop clears hostile projectiles in the blast"
	)
	_expect(
		not is_instance_valid(hostile_projectile)
		or hostile_projectile.is_queued_for_deletion(),
		"Cleared hostile projectile leaves the scene"
	)
