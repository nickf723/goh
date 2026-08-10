extends "res://scripts/levels/prototype_ruined_village_approach.gd"
class_name PrototypeRuinedVillageProductionSlice


# The original Ruined Village root doubles as a mechanics showcase for derivative
# development scenes. The canonical story launch should not auto-select Flight,
# unlock traversal cheats, boost stats, or announce a spell showcase before the
# Adventure Slice director takes over authored pacing. Derivative lab scenes
# override the root script and therefore retain the original showcase behavior.
func configure_player_showcase() -> void:
	GameState.restore_rest_resources()
	set_meta("production_slice_player_start", true)
	set_meta("showcase_shortcuts_suppressed", true)
