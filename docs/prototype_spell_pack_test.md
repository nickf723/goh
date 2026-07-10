# Prototype Spell Pack Test

## Goal

Add a first wave of new prototype spells so the full menu, focus spell selector, and spell metadata system have more content to organize.

This is intentionally mostly data-driven. The new spells use the existing `generic_projectile.tscn`, `DamagePayload`, and ability metadata/trait profiles.

## New spells

| Element | Spell | Role | Current behavior |
|---|---|---|---|
| Water | Water Jet | Setup/control | Wets targets for ice/lightning follow-ups. |
| Earth | Earth Spike | Stance/control | Chunky stance pressure with knockback. |
| Metal | Metal Needle | Direct damage | Simple sharp projectile. |
| Life | Life Thorn | Damage/growth placeholder | Small thorn projectile until healing/growth systems exist. |
| Death | Death Hex | Damage over time/debuff | Applies poisoned through the existing status system. |
| Body | Body Burst | Force/control | Knockback projectile that carries the `force` tag and can trigger frozen shatter. |
| Soul | Soul Thread | Interrupt/control | Brief stun. |
| Dreams | Dream Snare | Illusion/control | Brief stagger. |
| Time | Time Snare | Slow/control | Applies chill as the current slow carrier. |

## Files added

### Ability resources

- `data/abilities/water_jet_ability.tres`
- `data/abilities/earth_spike_ability.tres`
- `data/abilities/metal_needle_ability.tres`
- `data/abilities/life_thorn_ability.tres`
- `data/abilities/death_hex_ability.tres`
- `data/abilities/body_burst_ability.tres`
- `data/abilities/soul_thread_ability.tres`
- `data/abilities/dream_snare_ability.tres`
- `data/abilities/time_snare_ability.tres`

### Payload resources

- `data/damage_payloads/water_jet_payload.tres`
- `data/damage_payloads/earth_spike_payload.tres`
- `data/damage_payloads/metal_needle_payload.tres`
- `data/damage_payloads/life_thorn_payload.tres`
- `data/damage_payloads/death_hex_payload.tres`
- `data/damage_payloads/body_burst_payload.tres`
- `data/damage_payloads/soul_thread_payload.tres`
- `data/damage_payloads/dream_snare_payload.tres`
- `data/damage_payloads/time_snare_payload.tres`

## Test branch

```text
agent/prototype-spell-pack-v1
```

## Parser/load test

1. Open Godot.
2. Confirm no resource load errors from the new ability or payload `.tres` files.
3. Run the usual dev scene.
4. Confirm the player still starts normally.

## Menu checks

1. Open the full menu with `Tab` or `M`.
2. Go to Loadout.
3. Confirm the new spells appear as cards.
4. Confirm their metadata is visible:
   - element
   - profile
   - roles
   - combo tags
   - status tags
   - design notes
5. Open the focus spell selector.
6. Move through elements and confirm each new element shelf has a spell.

## Gameplay checks

Use the focus spell selector to cast each spell against a dummy or enemy.

Expected:

- Water Jet applies `wet`.
- Earth Spike deals stance pressure.
- Metal Needle deals direct damage.
- Life Thorn deals small direct damage.
- Death Hex applies `poisoned`.
- Body Burst applies knockback/force and should trigger force + frozen shatter when used on frozen targets.
- Soul Thread briefly stuns.
- Dream Snare briefly staggers.
- Time Snare applies chill/slow.

## Combo checks

- Water Jet -> Lightning Spark should trigger wet conduction.
- Water Jet -> Ice Lance should trigger wet freeze.
- Ice Lance or Wet Freeze -> Body Burst should trigger frozen shatter because Body Burst carries the `force` tag.

## Known limitations

- These are prototype spells, not final fantasy-tuned designs.
- Life Thorn is a placeholder until healing/growth receiver logic exists.
- Time Snare currently uses `chill` because there is not yet a dedicated time-slow status.
- Dream Snare currently uses `staggered` because there is not yet an illusion/perception system.
- New spells share the generic projectile visuals for now.
