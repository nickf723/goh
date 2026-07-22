# Echolocation Chamber v1 Manual Test

## Scene

```txt
res://scenes/levels/prototypes/prototype_echolocation_chamber_v1.tscn
```

## Purpose

Validate that Echolocation functions as a controller-friendly exploration spell in complete darkness. The pulse should have visible travel time, reveal nearby architecture only when it reaches each object, and let the player navigate by refreshing a fading mental map.

## Controls

```txt
MOVE                 Left stick
AIM                  Right stick
CAST ECHOLOCATION    RT
RESET                 F8
```

## Intended route

1. Start in total darkness with only Grace's faint Sound anchor visible.
2. Cast Echolocation and watch nearby floor tiles, walls, and pillars appear progressively as the wave reaches them.
3. Follow the first opening on the right side of the chamber.
4. Recast as revealed geometry fades.
5. Weave left, right, then left through the silent zigzag corridor.
6. Locate the gold resonant beacon behind the final arch.
7. Enter the beacon area and confirm puzzle completion feedback.
8. Press F8 and confirm Grace returns to the entrance and all revealed geometry becomes hidden again.

## Expected behavior

- The environment background and ambient illumination are black.
- Ordinary room geometry is physically solid even while invisible.
- Echolocation uses a traveling pulse rather than revealing every target instantly.
- Nearby objects reveal in distance order as the pulse expands.
- Architecture remains visible for about three seconds, then fades back into darkness.
- The beacon remains visible slightly longer and produces its own message when reached by the pulse.
- Repeated casts overlap safely and refresh reveal timers.
- Echolocation is the only equipped spell in this room and costs no mana for uninterrupted feel testing.
- The player cannot walk through hidden walls simply because their visuals have faded.

## Known v1 limitations

- Echoes display luminous proxy surfaces rather than final outline shaders.
- The chamber uses a fixed authored zigzag instead of acoustic propagation or reflection simulation.
- Sound currently passes through geometry when selecting detectable targets within radius.
- The player-facing spell will eventually need final mana, cooldown, audio, animation, and accessibility tuning.
