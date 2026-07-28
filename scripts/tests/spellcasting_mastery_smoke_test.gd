extends Node

const AchievementCatalogScript = preload("res://scripts/progression/achievement_catalog.gd")
const AchievementServiceScript = preload("res://scripts/progression/achievement_service.gd")
const SpellcastingMasteryServiceScript = preload("res://scripts/progression/spellcasting_mastery_service.gd")
const SpellcastingTraditionCatalogScript = preload("res://scripts/progression/spellcasting_tradition_catalog.gd")
const SpellcastingTraditionResolverScript = preload("res://scripts/abilities/spellcasting_tradition_resolver.gd")
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")

var failures: Array[String] = []


func _ready() -> void:
	var previous_achievements: Dictionary = AchievementServiceScript.capture_state()
	AchievementServiceScript.clear_all()

	validate_catalogs()
	validate_sequential_mastery()
	validate_debug_mastery()
	validate_spell_compatibility()

	AchievementServiceScript.clear_all()
	AchievementServiceScript.restore_state(previous_achievements)

	if failures.is_empty():
		print("SPELLCASTING_MASTERY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("SPELLCASTING_MASTERY_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func validate_catalogs() -> void:
	for error_text: String in AchievementCatalogScript.validate_catalog():
		failures.append("catalog: " + error_text)

	if SpellcastingTraditionCatalogScript.TRADITION_IDS.size() != 8:
		failures.append("expected eight spellcasting traditions")
	if AchievementCatalogScript.get_definitions().size() != 32:
		failures.append("expected four mastery achievements for each of eight traditions")

	var warlock_capstone: Dictionary = SpellcastingTraditionCatalogScript.get_capstone("warlock")
	if str(warlock_capstone.get("id", "")) != "divine_incarnation":
		failures.append("Warlock mastery must reserve Divine Incarnation")


func validate_sequential_mastery() -> void:
	var skipped: Dictionary = SpellcastingMasteryServiceScript.unlock_stage(
		"warlock",
		"trial",
		{"fixture": "skip_attempt"}
	)
	if bool(skipped.get("ok", false)):
		failures.append("Warlock mastery allowed Trial before Initiation and Practice")

	for expected_stage: String in SpellcastingTraditionCatalogScript.STAGE_IDS:
		var result: Dictionary = SpellcastingMasteryServiceScript.advance(
			"warlock",
			{"fixture": "sequential_warlock", "expected_stage": expected_stage}
		)
		if not bool(result.get("ok", false)):
			failures.append("failed to advance Warlock to " + expected_stage)
			continue
		if str(result.get("stage_id", "")) != expected_stage:
			failures.append("Warlock advanced to the wrong stage; expected " + expected_stage)

	if SpellcastingMasteryServiceScript.get_rank("warlock") != 4:
		failures.append("Warlock mastery rank did not reach four")
	if not SpellcastingMasteryServiceScript.is_mastered("warlock"):
		failures.append("Warlock did not report mastered after all four stages")

	var mastery_achievement_id: String = SpellcastingTraditionCatalogScript.get_achievement_id(
		"warlock",
		"mastery"
	)
	var storage_id: String = AchievementServiceScript.get_storage_id(mastery_achievement_id)
	if not GameState.has_unlock(storage_id):
		failures.append("Warlock mastery was not stored in the persistent unlock ledger")

	var mastery_row: Dictionary = AchievementServiceScript.get_unlocked_row(mastery_achievement_id)
	if str(mastery_row.get("type", "")) != UnlockCatalogScript.TYPE_ACHIEVEMENT:
		failures.append("mastery ledger row did not use the achievement unlock type")
	var evidence: Dictionary = mastery_row.get("evidence", {}) as Dictionary
	if str(evidence.get("fixture", "")) != "sequential_warlock":
		failures.append("mastery ledger did not preserve achievement evidence")

	var progress: Dictionary = SpellcastingMasteryServiceScript.get_progress_row("warlock")
	if not bool(progress.get("capstone_ready", false)):
		failures.append("Warlock mastery did not expose its capstone hook")
	var capstone: Dictionary = progress.get("capstone", {}) as Dictionary
	if str(capstone.get("id", "")) != "divine_incarnation":
		failures.append("Warlock progress row exposed the wrong capstone")

	var duplicate: Dictionary = SpellcastingMasteryServiceScript.advance("warlock")
	if not bool(duplicate.get("ok", false)) or not bool(duplicate.get("already_complete", false)):
		failures.append("advancing an already mastered tradition was not idempotent")


func validate_debug_mastery() -> void:
	var result: Dictionary = SpellcastingMasteryServiceScript.master_all_for_debug()
	if not bool(result.get("ok", false)):
		failures.append("debug mastery did not master every tradition")
	if SpellcastingMasteryServiceScript.get_mastered_tradition_ids().size() != 8:
		failures.append("debug mastery did not report all eight mastered traditions")
	if AchievementServiceScript.get_unlocked_achievement_ids().size() != 32:
		failures.append("debug mastery did not unlock all 32 stage achievements")
	if not SpellcastingMasteryServiceScript.get_active_capstone_ids().has("divine_incarnation"):
		failures.append("debug mastery did not surface Divine Incarnation among active capstones")

	var revoked: int = SpellcastingMasteryServiceScript.reset_all()
	if revoked != 32:
		failures.append("mastery reset did not revoke all 32 stage achievements")
	if not AchievementServiceScript.get_unlocked_achievement_ids().is_empty():
		failures.append("mastery reset left achievement rows behind")


func validate_spell_compatibility() -> void:
	var fire_spell: AbilityDefinition = make_ability(
		"fixture_fire",
		"fire",
		AbilityDefinition.AbilityCategory.PROJECTILE,
		["damage"]
	)
	var fire_traditions: Array[String] = SpellcastingTraditionResolverScript.resolve(fire_spell)
	for expected_tradition: String in ["sorcery", "wizardry", "druidry", "warlock"]:
		if not fire_traditions.has(expected_tradition):
			failures.append("Fire spell did not resolve " + expected_tradition + " compatibility")

	var sound_spell: AbilityDefinition = make_ability(
		"fixture_sound",
		"sound",
		AbilityDefinition.AbilityCategory.INSTANT,
		["detection", "resonance"]
	)
	if not SpellcastingTraditionResolverScript.is_compatible(sound_spell, "bardic"):
		failures.append("Sound resonance spell did not resolve Bardic compatibility")

	var ward_spell: AbilityDefinition = make_ability(
		"fixture_ward",
		"life",
		AbilityDefinition.AbilityCategory.INSTANT,
		["ward", "protection"]
	)
	if not SpellcastingTraditionResolverScript.is_compatible(ward_spell, "theurgy"):
		failures.append("Life ward did not resolve Theurgy compatibility")

	var device_spell: AbilityDefinition = make_ability(
		"fixture_device",
		"metal",
		AbilityDefinition.AbilityCategory.UTILITY,
		["device", "gadget"]
	)
	if not SpellcastingTraditionResolverScript.is_compatible(device_spell, "artifice"):
		failures.append("Metal device spell did not resolve Artifice compatibility")

	var summon_spell: AbilityDefinition = make_ability(
		"fixture_summon",
		"soul",
		AbilityDefinition.AbilityCategory.SUMMON,
		["persistent"]
	)
	if not SpellcastingTraditionResolverScript.is_compatible(summon_spell, "ritualism"):
		failures.append("persistent summon did not resolve Ritualism compatibility")

	fire_spell.combo_tags = ["tradition_block:warlock"]
	if SpellcastingTraditionResolverScript.is_compatible(fire_spell, "warlock"):
		failures.append("explicit tradition block did not remove Warlock compatibility")

	fire_spell.combo_tags = ["tradition_only:ritualism"]
	var exclusive_traditions: Array[String] = SpellcastingTraditionResolverScript.resolve(fire_spell)
	if exclusive_traditions != ["ritualism"]:
		failures.append("exclusive tradition metadata did not override automatic compatibility")


func make_ability(
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