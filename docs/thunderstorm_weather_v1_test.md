# Thunderstorm Weather v1

## Run

Open:

`scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn`

Equip **Thunderstorm** from the Lightning element page and cast it.

## Expected behavior

- Thunderstorm replaces Flight, Rain, or Snowfall as the active concentration effect.
- The sky transitions to a dark blue-black storm profile and rain begins around Grace.
- Fifty-five percent of maximum mana is reserved.
- Lightning spells are free while the storm remains active.
- Exposed targets repeatedly receive Wet.
- A blue ground ring and rising leaders telegraph every environmental strike for about 1.15 seconds.
- Grace is never selected as a strike target.
- Wet, metallic, conductive, and elevated targets receive strong priority.
- The procedural main bolt branches from the sky and can chain through up to three nearby conductors.
- Conductive water receives an ordinary Lightning payload and becomes electrified through its existing system.
- The cinematic lighting rig produces a brief double flash at impact.
- Thunder arrives after `distance / 343 m/s`, plays a procedural rumble, and emits a perception stimulus that enemies can investigate.
- Casting Thunderstorm again dismisses it and restores the clear sunset lighting.

## Village route

Three pairs of copper storm rods have been added along the arrival road, village square, and church approach. Stand near each pair and watch the storm prefer their elevated crowns, then jump visibly between close conductors.

The telegraph contracts inward as charge rises. The full strike is deliberately dangerous to enemies and world targets but does not directly target Grace.

## Smoke test

Run:

`scenes/tests/thunderstorm_weather_smoke_test.tscn`

It forces a strike into one wet copper rod and verifies the primary payload, conductive chain, and procedural arc count.
