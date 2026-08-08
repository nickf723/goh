extends RefCounted
class_name SpellCloneReplayPolicy

const Semantics = preload(
	"res://scripts/abilities/spell_clone_semantics.gd"
)

# Compatibility wrapper for older tests and callers. New code should use
# SpellCloneSemantics because Repeat and Soul Duplicate intentionally have
# different behavior.

const MODE_REPLAY: String = "replay"
const MODE_SUPPRESS: String = "suppress"


static func get_policy(ability: AbilityDefinition) -> Dictionary:
	if ability == null:
		return _suppressed("missing ability")
	var repeat_mode: String = Semantics.get_repeat_mode(ability)
	if repeat_mode == Semantics.REPEAT_SUPPRESS:
		return _suppressed("ownership spell is not repeatable", ability.get_spell_id())
	if repeat_mode == Semantics.REPEAT_WORLD_STATE:
		return _suppressed("world-state spell intentionally no-ops in Repeat", ability.get_spell_id())
	return {
		"mode": MODE_REPLAY,
		"spell_id": ability.get_spell_id(),
		"reason": "handled by " + repeat_mode,
		"copies_result": false,
		"fresh_world_interaction": repeat_mode != Semantics.REPEAT_TRAJECTORY,
		"copies_motion_timeline": repeat_mode == Semantics.REPEAT_TRAJECTORY,
		"repeat_mode": repeat_mode,
		"duplicate_mode": Semantics.get_duplicate_mode(ability),
	}


static func can_replay(ability: AbilityDefinition) -> bool:
	return str(get_policy(ability).get("mode", MODE_SUPPRESS)) == MODE_REPLAY


static func _suppressed(reason: String, spell_id: String = "") -> Dictionary:
	return {
		"mode": MODE_SUPPRESS,
		"spell_id": spell_id,
		"reason": reason,
		"copies_result": false,
		"fresh_world_interaction": false,
	}
