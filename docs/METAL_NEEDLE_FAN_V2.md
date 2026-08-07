# Metal Needle Fan v2

Metal Needle is now a rapid fan volley instead of a generic single projectile.

## Player contract

```text
Mana cost:             2
Needles:               9
Full fan angle:        54 degrees
Launch interval:       0.018 seconds
Needle speed:          36 m/s
Maximum range:         17 meters
Damage per needle:     1
Stance per needle:     1
Per-target cast cap:   3 needles
```

One button press creates the complete salvo. The center needle launches first, then the surrounding punctures leave in an alternating center-out sequence across roughly 0.15 seconds.

```text
Long range
    → fan separates
    → several enemies can each catch one needle

Close range
    → fan has not separated yet
    → up to three needles can converge on one target
```

The three-hit cap applies per target and per cast. Needles beyond that cap still collide and end normally, but they do not multiply damage without limit against oversized or point-blank targets.

## Collision and force

Every needle owns its own swept ray from its previous position to its next position. It stops at the first valid target or solid surface.

Each puncture carries:

```text
1 Metal health damage
1 stance damage
small directional knockback
metal / pierce / sharp / projectile / fan / volley tags
```

The knockback direction follows that individual needle rather than pushing radially away from Grace.

Targets record:

```text
metal_needle_fan_last_serial
metal_needle_fan_hits_from_serial
metal_needle_fan_last_needle_index
```

These values allow rooms and encounters to distinguish a wide one-volley fan from repeated unrelated casts and to verify close-range multihits without reading the spell node directly.

## Presentation and performance

```text
1 MetalNeedleFan controller
1 MultiMeshInstance3D
9 needle instances
0 per-needle nodes
0 per-needle process callbacks
9 bounded ray sweeps per physics step at most
1 short unshadowed launch light
0 persistent effects
```

F7 should briefly show one additional `SPELL FX`. `PERSISTENT` remains unchanged. When every needle hits or reaches maximum range, the controller removes itself and the temporary effect count returns to baseline.

## Complete Focus library

Grace's development loadout now includes every `AbilityDefinition` resource currently authored in `res://data/abilities`, for a total of forty-two spells at this revision.

The final seven restored entries are:

```text
Sound      Echolocation
Sound      Resonant Pulse
Air        Gust
Water      Rain
Ice        Snowfall
Lightning  Thunderstorm
Air        Flight
```

This restores both the concentration spells and the older laboratory spells that had never been copied into Grace's main Focus library. `Wind Gust` and `Gust` are intentionally separate entries: Wind Gust is the immediate combat shove, while Gust is the moving analytic airflow field.

All forty-two resources are stored in `learned_abilities`, so they appear in their ordinary elemental Focus pages and can be assigned to any of the ten quick slots without replacing or corrupting other Focus entries.

The same resources are retained in the runtime casting array, allowing immediate selection and casting from Focus during development. The regression scans the full `data/abilities` directory and requires every discovered spell ID to exist in both collections, so newly authored spells cannot quietly fall behind the Focus menu again.

### Runtime concentration service

Most Spell Trial scenes did not contain the old weather-laboratory concentration nodes. Weather and Flight can now establish one shared `ConcentrationManager` lazily when first cast.

Only one concentration effect can remain active:

```text
Rain
  ↓ cast Snowfall
Rain releases, Snowfall reserves Mana
  ↓ cast Thunderstorm
Snowfall releases, Thunderstorm reserves Mana
  ↓ cast Flight
Thunderstorm releases, Flight takes concentration
```

The lazily created manager leaves the older concentration HUD disabled. Resource presentation stays inside the optimized unified HUD rather than reviving another continuously refreshing interface.

### Runtime weather service

Rain, Snowfall, and Thunderstorm still prefer an authored weather controller when the scene provides one. In an ordinary gameplay or Spell Trial scene, the spell creates the matching controller on demand.

At most one generated weather controller remains at a time. Replacing or dismissing weather stops and removes the previous generated controller, including when authority passes to an authored scene controller. This prevents the complete spell library from preloading or accumulating several hundred inactive rain, snow, and storm presentation nodes.

Flight similarly enables its existing aerial locomotion state when the learned spell is present. The progression layer can later withhold the Flight ability resource until its intended unlock point.

## The Needle Loom

Launch:

```text
res://scenes/levels/prototypes/prototype_metal_needle_fan_spell_trial_v1.tscn
```

The trial equips Metal Needle automatically and regenerates 2 Mana per second between volleys.

### I. The Broad Fan

Five marks are arranged along the authored 54-degree spread.

Stand on the first metal casting mark, aim through the middle target, and fire once. The gate opens only when every target records the same fan serial.

This verifies:

- nine distinct needles launch;
- the fan opens across distance;
- several targets can be struck by one cast;
- the spell is not a cone-shaped instant hit disguised as projectiles.

### II. The Close Press

A larger target stands only a few meters from the second casting mark.

Fire from close range. The second gate requires at least three needles from one new volley. The per-target cap prevents the remaining six needles from turning proximity into an unrestricted nine-hit burst.

### Mastery

Enter the gold seal:

```text
SPREAD • SALVO • PUNCTURE
```

Completion records:

```text
needle_loom_metal_needle_trial_complete
```

## Reset

F8 restores:

- Grace's transform, velocity, resources, and Metal Needle selection;
- every fan and close target;
- target hit metadata and cast serials;
- both progression gates;
- the mastery flag;
- every active Metal Needle fan controller.

## Focused playtest

1. Open the Needle Loom and confirm Metal Needle uses the `>>` badge under Metal.
2. Fire into open space and confirm nine visible needles bloom rapidly from the center of the fan.
3. Stand on the first mark, aim through the center target, and strike all five marks with one volley.
4. Move closer to an isolated target and confirm several needles converge.
5. Confirm one target receives no more than three damaging punctures from one cast.
6. Fire beside a wall and confirm individual fan needles stop at different contact points.
7. Inspect Sound and confirm Sound Pulse, Echolocation, and Resonant Pulse are all present.
8. Inspect Air and confirm Wind Gust, Gust, Wind Well, and Flight are all present.
9. Assign Metal Needle, Rain, Snowfall, Thunderstorm, and Flight to different quick slots and verify their Focus entries remain intact.
10. Cast Rain in the Needle Loom, then Snowfall, then Thunderstorm. Confirm each weather replaces the previous concentration.
11. Cast Flight and confirm the active weather releases before Grace takes flight.
12. Watch F7 during repeated volleys and weather switching. Metal Needle should never add a persistent effect, and generated weather controllers should not accumulate.
13. Complete the mastery seal and press F8 to verify the trial reset.
