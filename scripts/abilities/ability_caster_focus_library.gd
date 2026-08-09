extends "res://scripts/abilities/ability_caster_spell_presentation.gd"
class_name AbilityCasterFocusLibrary

# Compatibility entry point retained for every existing player/lab scene.
# Focus navigation lives in AbilityCasterFocusGrid; plant placement layers on top,
# and SpellPresentation now adds shared prepare/release/manifest lifecycle feedback
# without forcing scene migrations.
