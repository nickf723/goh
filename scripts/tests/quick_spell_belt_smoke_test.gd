extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_quick_spell_loadouts: Dictionary = {}
var original_quick_spell_selected_slots: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_quick_spell_loadouts = GameState.quick_spell_loadouts.duplicate(true)
	original_quick_spell_selected_slots = (
		GameState.quick_spell_selected_slots.duplicate(true)
	)
	GameState.quick_spell_loadouts.clear()
	GameState.quick_spell_selected_slots.clear()
	_prepare_stats()

	var floor := _make_floor()
	add_child(floor)
	var player := PlayerScene.instantiate() as CharacterBody3D
	player.name = "QuickSpellBeltTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(6):
		await get_tree().process_frame
	await get_tree().physics_frame

	var router: Node = player.get_node_or_null("PlayerControlRouter")
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	var divine_router: Node = player.get_node_or_null("DivineSpecialInputRouter")
	var belt: QuickSpellBeltPresentation = player.get_node_or_null(
		"QuickSpellBeltPresentation"
	) as QuickSpellBeltPresentation

	_expect(router != null, "Ten-slot player control router installs")
	_expect(ability_caster != null, "Ability caster remains available")
	_expect(divine_router != null, "Divine Special input router remains available")
	_expect(belt != null, "Permanent D-pad command dock installs")
	if router == null or ability_caster == null or divine_router == null or belt == null:
		_finish(player, floor)
		return

	var loadout_value: Variant = ability_caster.get("loadout")
	var loadout: AbilityLoadout = (
		loadout_value as AbilityLoadout
		if loadout_value is AbilityLoadout
		else null
	)
	_expect(loadout != null, "Quickbar test player has an ability loadout")
	if loadout == null:
		_finish(player, floor)
		return
	_expect(loadout.get_quick_slot_count() == 10, "Ability loadouts expose ten quick slots")

	var rows: Array = router.call("get_quick_spell_slot_rows") as Array
	_expect(rows.size() == 10, "Quick spell belt exposes ten authoritative slots")
	_expect(
		(router.call("get_quick_spell_names") as Array).size() == 3,
		"Three-card window API remains available for compatibility"
	)
	if rows.size() != 10:
		_finish(player, floor)
		return

	var initial_dock_debug: Dictionary = belt.get_debug_data()
	_expect(bool(initial_dock_debug.get("permanent", false)), "Spell belt is permanent")
	_expect(bool(initial_dock_debug.get("visible", false)), "Permanent command dock is visible")
	_expect(bool(initial_dock_debug.get("item_tile", false)), "D-pad Up item wing exists")
	_expect(bool(initial_dock_debug.get("special_tile", false)), "D-pad Down Special wing exists")
	_expect(
		bool(initial_dock_debug.get("legacy_quick_concealed", false)),
		"Old bottom-left quick panel is visually concealed"
	)
	_expect(
		bool(initial_dock_debug.get("focus_aligned", false)),
		"Focus panel aligns directly above the command dock"
	)

	_expect(
		bool(router.call("select_quick_spell_slot", 9, "keyboard", false)),
		"Keyboard 0 selects quick spell slot ten"
	)
	var slot_ten: Dictionary = rows[9] as Dictionary
	_expect(
		int(ability_caster.get("current_ability_index"))
		== int(slot_ten.get("ability_index", -1)),
		"Slot ten selection updates the active cast spell"
	)
	_expect(
		int(router.call("get_selected_quick_spell_slot")) == 9,
		"Selected quick spell slot persists as ten"
	)

	_expect(
		bool(router.call("cycle_quick_spell", 1)),
		"D-pad Right wraps across the full quickbar"
	)
	_expect(
		int(router.call("get_selected_quick_spell_slot")) == 0,
		"Cycling after slot ten wraps to slot one"
	)
	_expect(
		bool(router.call("cycle_quick_spell", -1)),
		"D-pad Left wraps backward across the full quickbar"
	)
	_expect(
		int(router.call("get_selected_quick_spell_slot")) == 9,
		"Backward cycling from slot one returns to slot ten"
	)

	ability_caster.call("select_ability", 2, false)
	ability_caster.call("align_focus_menu_to_current_ability")
	var firebolt: AbilityDefinition = loadout.get_equipped_ability(2)
	var displaced: AbilityDefinition = loadout.get_equipped_ability(9)
	_expect(
		bool(router.call("assign_selected_focus_spell_to_slot", 9)),
		"Focus selection assigns through keyboard slot numbers"
	)
	var loadout_id: String = str(router.get("current_quickbar_loadout_id"))
	_expect(
		GameState.get_quick_spell_slot(loadout_id, 9) == firebolt.get_spell_id(),
		"Assigned Focus spell occupies slot ten by spell ID"
	)
	_expect(
		GameState.get_quick_spell_slot(loadout_id, 2) == displaced.get_spell_id(),
		"Assigning an existing spell swaps the displaced slot"
	)

	# The full equipment menu edits AbilityLoadout slots directly. Historically,
	# that left GameState pointing at the displaced spell ID, so the permanent
	# belt rendered the replacement as an invalid gray tile. Simulate that exact
	# path with a learned spell beyond the default ten.
	var original_slot_zero: AbilityDefinition = loadout.get_equipped_ability(0)
	var original_saved_slot_zero: String = GameState.get_quick_spell_slot(
		loadout_id,
		0
	)
	var bubble: AbilityDefinition = null
	for learned_ability: AbilityDefinition in loadout.get_learned_abilities():
		if (
			learned_ability != null
			and learned_ability.get_spell_id() == "bubble"
		):
			bubble = learned_ability
			break
	_expect(bubble != null, "Bubble exists in the learned spell library")
	if bubble != null:
		loadout.equip_ability(0, bubble)
		var replaced_rows: Array = router.call(
			"get_quick_spell_slot_rows"
		) as Array
		var replaced_row: Dictionary = (
			replaced_rows[0] as Dictionary
			if replaced_rows.size() > 0
			else {}
		)
		_expect(
			GameState.get_quick_spell_slot(loadout_id, 0) == "bubble",
			"full-menu loadout replacement updates the persistent quick-slot ID"
		)
		_expect(
			str(replaced_row.get("name", "")) == "Bubble",
			"replacement spell remains visible instead of becoming a gray empty tile"
		)
		_expect(
			int(replaced_row.get("ability_index", -1)) >= 0,
			"replacement quick slot resolves to a selectable runtime ability"
		)
		_expect(
			bool(router.call("select_quick_spell_slot", 0, "keyboard", false)),
			"replacement spell can be selected from the permanent quick belt"
		)
		_expect(
			ability_caster.call("get_current_ability") == bubble,
			"selecting the repaired slot equips the replacement spell"
		)

	# Restore the shared test loadout before the player leaves the tree.
	loadout.equip_ability(0, original_slot_zero)
	GameState.set_quick_spell_slot(
		loadout_id,
		0,
		original_saved_slot_zero
	)

	router.call("select_quick_spell_slot", 4, "keyboard", false)
	await get_tree().process_frame
	var belt_debug: Dictionary = belt.get_debug_data()
	_expect(int(belt_debug.get("slot_count", 0)) == 10, "Permanent HUD renders ten slots")
	_expect(
		float(belt_debug.get("reveal_remaining", 0.0)) > 0.0,
		"Keyboard selection still drives transient feedback"
	)

	_expect(
		bool(router.call("handle_focus_action", true)),
		"Focus opens through the unified controller router"
	)
	belt.call("_process", 0.016)
	belt_debug = belt.get_debug_data()
	_expect(
		bool(belt_debug.get("focus_assignment_visible", false)),
		"Permanent spell belt enters Focus assignment mode"
	)
	_expect(
		not bool(belt_debug.get("item_menu_visible", true))
		and not bool(belt_debug.get("special_menu_visible", true)),
		"Focus owns the D-pad without moving item or Special menus"
	)
	router.call("handle_focus_action", false)
	belt.call("_process", 0.016)

	router.call("handle_quick_item_button", 0, true)
	belt.call("_process", 0.016)
	_expect(
		bool(belt.get_debug_data().get("item_menu_visible", false)),
		"Holding D-pad Up opens the item belt wing"
	)
	router.call("handle_quick_item_button", 0, false)

	divine_router.set("force_debug_catalog_access", true)
	divine_router.call("handle_special_button", 0, true, 1000)
	divine_router.call("open_radial_for_device", 0)
	belt.call("_process", 0.016)
	_expect(
		bool(belt.get_debug_data().get("special_menu_visible", false)),
		"Holding D-pad Down opens the dock-aligned Special wing"
	)
	divine_router.call("cancel_active_gesture", 0, "command_dock_test_cleanup")

	var save_probe: Dictionary = {"version": 12}
	GameState.call("_append_player_records_to_save", save_probe)
	_expect(int(save_probe.get("version", 0)) == 13, "Quickbar save advances records version")
	_expect(
		save_probe.get("quick_spell_loadouts", null) is Dictionary,
		"Save record includes per-loadout spell belts"
	)
	var saved_slot_ten: String = GameState.get_quick_spell_slot(loadout_id, 9)
	GameState.set_quick_spell_slot(loadout_id, 9, "")
	GameState.call("_apply_player_records_from_save", save_probe)
	_expect(
		GameState.get_quick_spell_slot(loadout_id, 9) == saved_slot_ten,
		"Saved quick spell IDs restore without index drift"
	)
	_expect(
		GameState.get_selected_quick_spell_slot(loadout_id) == 4,
		"Saved selected quick spell slot restores"
	)

	_finish(player, floor)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "QuickSpellBeltTestFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.quick_spell_loadouts = original_quick_spell_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = (
		original_quick_spell_selected_slots.duplicate(true)
	)


func _finish(player: Node, floor: Node) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if failures.is_empty():
		print("QUICK_SPELL_BELT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("QUICK_SPELL_BELT_SMOKE_TEST: " + failure)
	get_tree().quit(1)