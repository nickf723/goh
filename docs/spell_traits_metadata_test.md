# Spell Traits / Metadata v1 Test

Branch: `agent/spell-traits-metadata-v1`

## Goal

Give every current prototype spell a reusable identity layer without changing how the spells cast or resolve.

This pass is architecture/data only. It should not rebalance the spells from the previous buff pass.

## What changed

### AbilityDefinition

`AbilityDefinition` now has metadata fields:

- `spell_id`
- `short_label`
- `icon_text`
- `roles`
- `targeting_style`
- `delivery_type`
- `combo_tags`
- `status_tags`
- `ui_tags`
- `debug_tags`
- `design_notes`

It also has helper methods:

- `get_spell_id()`
- `get_ui_label()`
- `get_identity_summary()`
- `has_role()`
- `has_combo_tag()`
- `has_status_tag()`
- `has_any_role()`
- `get_all_spell_tags()`
- `get_debug_data()`

### Current spell metadata identities

- `Arcane Spark`
  - Roles: damage, stance, force, starter
  - Delivery: projectile
  - Targeting: aimed
- `Space Blink`
  - Roles: movement, traversal, defense, positioning
  - Delivery: instant
  - Targeting: directional
- `Firebolt`
  - Roles: damage, burn, projectile, combo_starter
  - Delivery: projectile
  - Targeting: aimed
- `Ice Lance`
  - Roles: control, stance, slow, projectile, combo_starter
  - Delivery: projectile
  - Targeting: aimed
- `Lightning Spark`
  - Roles: interrupt, damage, projectile, combo_reactor
  - Delivery: projectile
  - Targeting: aimed
- `Sound Pulse`
  - Roles: detection, reveal, control, area, stagger
  - Delivery: pulse
  - Targeting: self_centered
- `Poison Cloud`
  - Roles: hazard, status, area, combo_starter, damage_over_time
  - Delivery: hazard_field
  - Targeting: ground_forward
- `Fire Field`
  - Roles: hazard, status, area, combo_reactor, damage_over_time
  - Delivery: hazard_field
  - Targeting: ground_forward
- `Wind Gust`
  - Roles: force, control, cone, combo_reactor, hazard_manipulation
  - Delivery: cone_burst
  - Targeting: directional_cone

## How to test

1. Pull branch `agent/spell-traits-metadata-v1`.
2. Open the project in Godot.
3. Confirm there are no parser errors from `ability_definition.gd`.
4. Run the usual dev scene.
5. Confirm the spell menu still opens.
6. Confirm quick-cast still works.
7. Cast every currently equipped spell:
   - Arcane Spark
   - Space Blink
   - Firebolt
   - Ice Lance
   - Lightning Spark
   - Sound Pulse
   - Poison Cloud
   - Fire Field
   - Wind Gust
8. Spawn Goblin, Gremlin, Zombie, and Mixed Wave.
9. Confirm all spells behave the same as the previous buff pass.

## Regression checks

- Spell resources load.
- No missing exported property warnings that block play.
- Current ability label still displays.
- Focus menu still groups spells by element.
- Cast cost payment still works.
- Projectiles still use their payloads.
- Fields and clouds still spawn.
- Sound Pulse still reveals/staggers.
- Toxic Ignition, Fanned Flames, and Cloud Spread still trigger.

## Notes

This metadata is not deeply wired into UI yet. The point is to make spell resources declare their identity now so future systems can ask questions like:

- Which spells are movement spells?
- Which spells are combo starters?
- Which spells apply burning?
- Which spells are hazards?
- Which spells should appear under a control filter?
- Which spells should teach a player about force reactions?

Future passes can use this for spell filtering, radial UI details, deck/card-style spell browsing, combo suggestions, debug panels, enemy AI counters, tutorials, and balance tools.
