# Hazard Reactions v1 Test

Branch: `agent/hazard-reactions-v1`

## Goal

Make lingering spell hazards react to each other so Poison Cloud, Fire Field, and Wind Gust become a tiny sandbox grammar instead of isolated spell buttons.

## New reactions

### Poison Cloud + Fire Field

Reaction: **Toxic Ignition**

Expected:

- Poison Cloud detects overlapping Fire Field.
- The poison cloud briefly expands and pulses faster.
- A `Toxic Ignition!` message appears.
- Enemies in the cloud receive an extra reaction payload with poison/fire tags and burning.
- The ignited cloud burns out quickly after the flash.

### Wind Gust + Poison Cloud

Reaction: **Cloud Spread**

Expected:

- Wind Gust can now detect hazard areas, not only enemies.
- Gusting a Poison Cloud increases its radius and lifetime a bit.
- A `Cloud Spread!` message appears.
- The cloud can spread up to a small cap so it does not balloon forever.

### Wind Gust + Fire Field

Reaction: **Fanned Flames**

Expected:

- Gusting a Fire Field increases its radius and lifetime a bit.
- The field pulses taller/brighter for a short flare window.
- Burning applied during the flare is slightly stronger.
- A `Fanned Flames!` message appears.

## How to test

1. Pull branch `agent/hazard-reactions-v1`.
2. Run the usual dev scene.
3. Use `F9`/`F10` to select `Hazard Combo Lab`.
4. Press `F6` to spawn enemies.
5. Cast `Poison Cloud` near enemies.
6. Cast `Fire Field` overlapping the cloud.
7. Confirm Toxic Ignition triggers.
8. Cast a fresh Poison Cloud, then cast `Wind Gust` through it.
9. Confirm Cloud Spread triggers.
10. Cast Fire Field, then cast `Wind Gust` through it.
11. Confirm Fanned Flames triggers.

## Useful spell selector path

Hold focus with Left Shift or Right Mouse Button, then:

- Poison -> Poison Cloud
- Fire -> Fire Field
- Air -> Wind Gust

Confirm the highlighted spell, release focus, then press `Q` to cast.

## Expected debug signs

Console prints should include messages such as:

- `PoisonCloud reaction: Toxic Ignition`
- `PoisonCloud reaction: Cloud Spread`
- `FireField reaction: Fanned Flames`

The UI should also surface the reaction names when they occur.

## Known risks

- Hazard areas now use a prototype hazard collision layer value of `2` and mask `1 | 2`, while still detecting normal enemies on layer `1`.
- Reaction timing depends on Godot overlap updates, so if one reaction feels delayed, try casting the second hazard directly inside the first and waiting one tick.
- The visuals are intentionally small: pulsing/scale changes and UI messages first, fancier particles later.
