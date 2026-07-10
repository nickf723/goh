# Spell Trait Profiles Test

## Goal

Verify that spell metadata can now inherit shared taxonomy from reusable trait profiles while keeping each spell's unique identity.

This is an architecture pass. Spell behavior should remain the same as the previous buff pass.

## Branch

`agent/spell-trait-profiles-v1`

## What changed

- Added `scripts/abilities/ability_trait_profile.gd`.
- Added reusable profile resources in `data/ability_trait_profiles/`:
  - `damage_projectile_profile.tres`
  - `control_projectile_profile.tres`
  - `movement_utility_profile.tres`
  - `detection_pulse_profile.tres`
  - `lingering_hazard_profile.tres`
  - `cone_force_profile.tres`
- `AbilityDefinition` now supports:
  - `trait_profile`
  - `use_trait_profile`
  - profile-aware metadata getters.
- Current spells now reference trait profiles.

## Current spell profile assignments

| Spell | Profile | Local identity |
|---|---|---|
| Arcane Spark | Damage Projectile | neutral stance pressure, force |
| Firebolt | Damage Projectile | fire burn, toxic ignition trigger |
| Ice Lance | Control Projectile | chill, stance damage, freeze setup |
| Lightning Spark | Control Projectile | quick interrupt, shock tag |
| Space Blink | Movement Utility | defensive repositioning |
| Sound Pulse | Detection Pulse | reveal, echo, stagger |
| Poison Cloud | Lingering Hazard | poison gas, toxic ignition, cloud spread |
| Fire Field | Lingering Hazard | burning field, fanned flames, hazard reactor |
| Wind Gust | Cone Force | push, hazard manipulation |

## Test steps

1. Open the project in Godot.
2. Confirm there are no parser errors from:
   - `ability_definition.gd`
   - `ability_trait_profile.gd`
3. Run the dev scene.
4. Open the spell menu.
5. Cast every currently equipped spell.
6. Spawn:
   - Goblin Duel
   - Gremlin Duel
   - Zombie Duel
   - Mixed Wave
7. Confirm every spell still behaves exactly like the previous spell buff pass.

## Regression checks

- Spell resources load.
- Focus menu still groups spells by `element`.
- Quick-cast still works.
- Projectiles still use payloads.
- Space Blink still teleports Grace.
- Sound Pulse still reveals and staggers.
- Fire Field, Poison Cloud, and Wind Gust still spawn.
- Toxic Ignition still works.
- Fanned Flames still works.
- Cloud Spread still works.

## Dev/debug checks

If you inspect an ability resource or call its debug helpers later:

- `get_identity_summary()` should include the profile id.
- `get_roles()` should include profile roles plus local roles.
- `get_combo_tags()` should include profile combo tags plus local combo tags.
- `get_all_spell_tags()` should include profile tags, spell tags, element, targeting, delivery, and profile id.

## Why this matters

Before this pass, every spell carried all metadata directly.

After this pass, future spells can inherit from reusable buckets like:

- Damage Projectile
- Control Projectile
- Movement Utility
- Detection Pulse
- Lingering Hazard
- Cone Force

Then each spell only needs to declare what makes it special. This makes future spell creation less copy-paste heavy and gives UI/combo/tutorial systems a cleaner taxonomy to query.

## Known risks

- Godot may want to resave `.tres` resources after loading new exported fields.
- The trait profile reference is intentionally typed as `Resource` in `AbilityDefinition` to avoid parser load-order issues.
- This PR should not change gameplay behavior, but it changes how metadata getters compute their answers.
