extends RefCounted
class_name SpellcastingMasteryTestFixture

const AchievementCatalogScript = preload("res://scripts/progression/achievement_catalog.gd")
const AchievementServiceScript = preload("res://scripts/progression/achievement_service.gd")
const MasteryScript = preload("res://scripts/progression/spellcasting_mastery_service.gd")
const TraditionCatalogScript = preload("res://scripts/progression/spellcasting_tradition_catalog.gd")
const TraditionResolverScript = preload("res://scripts/abilities/spellcasting_tradition_resolver.gd")
const MasteryShellScript = preload("res://scripts/ui/full_menu_shell_mastery.gd")
const RuviaAvatar: PlayableAvatarDefinition = preload(
	"res://data/avatars/ruvia_incarnation_prototype.tres"
)
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")

const UNRELATED_UNLOCK_ID: String = "spellcasting_mastery_fixture_permission"


static func run(manager: PlayerAvatarManager) -> Array[String]:
	var failures: Array[String] = []
	var previous_achievements: Dictionary = AchievementServiceScript.capture_state()
	var previous_unrelated: Variant = GameState.get_unlock_snapshot().get(
		UNRELATED_UNLOCK_ID,
		null
	)

	AchievementServiceScript.clear_all()
	GameState.grant_unlock(UNRELATED_UNLOCK_ID, {
		"type": UnlockCatalogScript.TYPE_PERMISSION,
		"display_name": "Unrelated Fixture Permission",
	})

	_validate_catalog_and_baseline(failures)
	_validate_warlock_gateway(manager, failures)
	_validate_compatibility(failures)
	_validate_menu(manager, failures)
	_validate_debug_reset(failures)

	AchievementServiceScript.clear_all()
	AchievementServiceScript.restore_state(previous_achievements)
	if previous_unrelated is Dictionary:
		GameState.grant_unlock(
			UNRELATED_UNLOCK_ID,
			(previous_unrelated as Dictionary).duplicate(true)
		)
	elif bool(previous_unrelated):
		GameState.grant_unlock(UNRELATED_UNLOCK_ID)
	else:
		GameState.revoke_unlock(UNRELATED_UNLOCK_ID)
	MasteryScript.ensure_story_baseline()
	return failures


static func _validate_catalog_and_baseline(failures: Array[String]) -> void:
	for error_text: String in AchievementCatalogScript.validate_catalog():
		_fail(failures, "catalog: " + error_text)
	_check(TraditionCatalogScript.TRADITION_IDS.size() == 8, "eight traditions", failures)
	_check(AchievementCatalogScript.get_total_count() == 32, "32 milestones", failures)
	_check(
		AchievementServiceScript.get_persistence_scope() == "save_slot",
		"save-slot achievement scope",
		failures
	)
	MasteryScript.ensure_story_baseline()
	_check(MasteryScript.get_rank("sorcery") == 1, "Sorcery story baseline", failures)
	_check(MasteryScript.get_rank("wizardry") == 1, "Wizardry story baseline", failures)
	_check(MasteryScript.get_rank("warlock") == 0, "Warlock begins locked", failures)
	_check(
		AchievementServiceScript.get_unlocked_achievement_ids().size() == 2,
		"baseline contains exactly two milestones",
		failures
	)


static func _validate_warlock_gateway(
	manager: PlayerAvatarManager,
	failures: Array[String]
) -> void:
	var production_ruvia: PlayableAvatarDefinition = (
		RuviaAvatar.duplicate(true) as PlayableAvatarDefinition
	)
	production_ruvia.debug_available = false
	_check(
		not manager.is_avatar_unlocked(production_ruvia),
		"Ruvia locked before Warlock Mastery",
		failures
	)
	var skipped: Dictionary = MasteryScript.unlock_stage(
		"warlock",
		"trial",
		{"silent": true}
	)
	_check(not bool(skipped.get("ok", false)), "Warlock cannot skip stages", failures)

	for expected_stage: String in TraditionCatalogScript.STAGE_IDS:
		var result: Dictionary = MasteryScript.advance(
			"warlock",
			{"fixture": "sequential_warlock", "silent": true}
		)
		_check(bool(result.get("ok", false)), "advance Warlock", failures)
		_check(
			str(result.get("stage_id", "")) == expected_stage,
			"Warlock stage " + expected_stage,
			failures
		)

	_check(MasteryScript.is_mastered("warlock"), "Warlock mastered", failures)
	_check(
		GameState.has_unlock("spellcasting.warlock.mastery"),
		"semantic mastery requirement resolves",
		failures
	)
	_check(
		manager.is_avatar_unlocked(production_ruvia),
		"Warlock Mastery unlocks Ruvia",
		failures
	)
	_check(
		MasteryScript.has_active_capstone("divine_incarnation"),
		"Divine Incarnation capstone active",
		failures
	)

	var mastery_id: String = TraditionCatalogScript.get_achievement_id(
		"warlock",
		"mastery"
	)
	var mastery_row: Dictionary = AchievementServiceScript.get_unlocked_row(mastery_id)
	_check(
		str(mastery_row.get("type", "")) == UnlockCatalogScript.TYPE_ACHIEVEMENT,
		"mastery stored as achievement",
		failures
	)
	_check(
		str(mastery_row.get("persistence_scope", "")) == "save_slot",
		"mastery row keeps save-slot scope",
		failures
	)

	var snapshot: Dictionary = AchievementServiceScript.capture_state()
	_check(AchievementServiceScript.clear_all() == 6, "capture contains six milestones", failures)
	_check(GameState.has_unlock(UNRELATED_UNLOCK_ID), "cleanup preserves unrelated unlock", failures)
	AchievementServiceScript.restore_state(snapshot)
	_check(MasteryScript.is_mastered("warlock"), "mastery snapshot restores", failures)


static func _validate_compatibility(failures: Array[String]) -> void:
	var fire: AbilityDefinition = _ability(
		"fixture_fire",
		"fire",
		AbilityDefinition.AbilityCategory.PROJECTILE,
		["damage"]
	)
	var resolved: Array[String] = TraditionResolverScript.resolve(fire)
	for expected: String in ["sorcery", "wizardry", "druidry", "warlock"]:
		_check(resolved.has(expected), "Fire supports " + expected, failures)

	var sound: AbilityDefinition = _ability(
		"fixture_sound",
		"sound",
		AbilityDefinition.AbilityCategory.INSTANT,
		["resonance"]
	)
	_check(TraditionResolverScript.is_compatible(sound, "bardic"), "Bardic Sound", failures)
	var device: AbilityDefinition = _ability(
		"fixture_device",
		"metal",
		AbilityDefinition.AbilityCategory.UTILITY,
		["device"]
	)
	_check(TraditionResolverScript.is_compatible(device, "artifice"), "Artifice device", failures)

	fire.combo_tags = ["tradition_block:warlock"]
	_check(not TraditionResolverScript.is_compatible(fire, "warlock"), "Warlock block tag", failures)
	fire.combo_tags = ["tradition_only:ritualism"]
	_check(TraditionResolverScript.resolve(fire) == ["ritualism"], "exclusive tradition tag", failures)


static func _validate_menu(
	manager: PlayerAvatarManager,
	failures: Array[String]
) -> void:
	var shell: Control = MasteryShellScript.new()
	manager.add_child(shell)
	shell.call("show_menu", FullMenuDirector.build_menu_data())
	shell.call("select_tab", int(shell.call("get_tab_index", "magic")))
	var text: String = _collect_text(shell)
	_check(text.contains("SPELLCASTING TRADITIONS"), "Magic tab tradition section", failures)
	_check(text.contains("Sorcery") and text.contains("Wizardry"), "baseline cards", failures)
	_check(text.contains("Warlock") and text.contains("Divine Incarnation"), "Warlock card", failures)
	_check(text.contains("Milestones"), "milestone track", failures)
	shell.queue_free()


static func _validate_debug_reset(failures: Array[String]) -> void:
	_check(bool(MasteryScript.master_all_for_debug().get("ok", false)), "debug master all", failures)
	_check(
		AchievementServiceScript.get_unlocked_achievement_ids().size() == 32,
		"all milestones unlocked",
		failures
	)
	_check(MasteryScript.reset_all(true) == 32, "reset revokes 32 milestones", failures)
	_check(
		MasteryScript.get_rank("sorcery") == 1
		and MasteryScript.get_rank("wizardry") == 1,
		"reset restores story baseline",
		failures
	)
	_check(MasteryScript.get_rank("warlock") == 0, "reset relocks Warlock", failures)
	_check(GameState.has_unlock(UNRELATED_UNLOCK_ID), "reset preserves unrelated unlock", failures)


static func _ability(
	spell_id: String,
	element: String,
	category: AbilityDefinition.AbilityCategory,
	roles: Array[String]
) -> AbilityDefinition:
	var ability: AbilityDefinition = AbilityDefinition.new()
	ability.spell_id = spell_id
	ability.display_name = spell_id.capitalize()
	ability.element = element
	ability.category = category
	ability.roles = roles.duplicate()
	ability.delivery_type = "instant" if category == AbilityDefinition.AbilityCategory.INSTANT else "projectile"
	return ability


static func _collect_text(root: Node) -> String:
	var lines: Array[String] = []
	_collect_text_recursive(root, lines)
	return "\n".join(lines)


static func _collect_text_recursive(node: Node, lines: Array[String]) -> void:
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_text_recursive(child, lines)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		_fail(failures, message)


static func _fail(failures: Array[String], message: String) -> void:
	failures.append(message)
