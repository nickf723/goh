# Steam Burst v1 Architecture

## Interaction sentence

```text
Fire payload → Frozen target or surface → Combo rule → Steam Burst → Radial receivers → Status, stance, and force consequences
```

## Reused systems

- `DamagePayload` supplies incoming elemental and delivery tags.
- `ComboRuleRegistry` decides whether Fire matches a Frozen target or hazard.
- `StatusSurface` owns the frozen-to-steaming state transition.
- `StatusReceiver`, `HitReceiver`, and `ForceReceiver` consume radial consequences.
- `CombatFeedback` and `ElementVisuals` present the reaction.

## New reusable seam

`ReactionBurstResolver` reads optional area-effect fields from any `ComboRule` and applies them through existing receivers. The resolver does not know about Steam, Ice, Fire, laboratory targets, or specific species.

This seam can later support:

- oil explosions;
- lightning conduction pulses;
- frozen shatter shockwaves;
- Sound resonance breaks;
- toxic ignition clouds;
- boss-generated elemental detonations.

## Steam Burst v1 tuning

- Radius: `2.65m`
- Status: `steamed` for `1.8s`
- Stance pressure: `1`
- Outward force: `1.5`
- Upward force: `0.35`
- Health damage: `0`

The primary frozen surface becomes a temporary steaming surface. The radial consequence occurs once when the combo resolves.

## Current boundaries

- Sphere overlap only, with no line-of-sight or cover test.
- No dedicated concealment or vision penalty for Steam yet.
- Radial results only affect targets exposing compatible receiver children.
- Final VFX, sound, animation, and balance remain replacement-ready.
