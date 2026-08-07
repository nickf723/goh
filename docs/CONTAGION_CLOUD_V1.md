# Contagion Cloud v1

Contagion Cloud is a large, slow-moving Poison field. It travels through living targets and movable props, sustains Poisoned on anything inside its volume, and expires on a timer rather than on impact.

## Player contract

```text
Mana cost:          3 upfront
Cloud radius:       3.25 meters
Travel speed:       2.35 m/s
Lifetime:           8.5 seconds
Exposure scan:      every 0.2 seconds
Poison sustain:     1.6 seconds per refresh
Impact damage:      0
Stance damage:      0
```

Grace's ordinary run speed is 5 m/s, so she can catch and pass the cloud after casting it.

```text
Cast forward
    ↓
Large gas globe forms ahead of Grace
    ↓
Cloud advances slowly through targets
    ↓
Targets entering the radius become Poisoned
    ↓
Solid architecture stops movement
    ↓
Cloud remains until its timer expires
```

Recasting replaces Grace's previous Contagion Cloud. This keeps the base spell to one persistent moving volume per caster and protects the frame-time budget. Future upgrades may intentionally allow multiple clouds.

## Contact rules

Contagion Cloud is not a projectile with an impact callback.

It passes through:

- enemies;
- ordinary character mobs;
- rigid-body props;
- status and payload receiver areas;
- nodes tagged `contagion_cloud_pass_through`.

It stops against:

- `StaticBody3D` architecture;
- `AnimatableBody3D` machinery;
- `GridMap` and `CSGShape3D` geometry;
- nodes tagged `contagion_cloud_blocker`.

The cloud uses a forward contact ray based on a reduced movement radius. When architecture is reached, its center is placed outside the surface, movement is disabled, and lifetime continues decreasing normally. Touching a target never changes remaining lifetime.

## Poison exposure

Every bounded exposure scan uses one reused `SphereShape3D` query. Valid targets have `Poisoned` sustained through their existing `StatusReceiver`.

```text
Inside cloud
    → Poisoned duration is refreshed

Leave cloud
    → Existing Poisoned duration counts down normally

Re-enter cloud
    → Poisoned is refreshed again
```

The cloud itself deals no immediate impact damage. Poison damage comes from the shared status system at its ordinary status cadence.

Each infected target records:

```text
contagion_cloud_last_serial
contagion_cloud_last_source_id
contagion_cloud_last_tick_msec
```

These metadata values let authored encounters verify that several targets were infected by the same moving cloud without coupling those encounters to the cloud's internal node layout.

## Shared gas integration

Contagion Cloud registers in `gas_volumes` with the existing Poison Gas definition.

It implements:

```text
sample_density(world_position)
get_total_density_mass()
gas_id = poison
gas_definition = Poison Gas
```

A `GasManager` can therefore sample the cloud alongside other atmospheric volumes. Density is strongest in the core and smoothly falls to zero at the authored radius.

The cloud also samples the existing airflow manager when one is present. Ordinary movement remains dominant, while Wind Well, Gust fields, or future atmospheric systems can bend the gas through the shared airflow contract.

## Reactions

Contagion Cloud remains a `hazard_reactive` gas volume.

- Air or force payloads widen it slightly and add drift without extending its lifetime.
- Fire triggers Toxic Ignition, applies a short reaction burst to current occupants, and consumes the cloud after a brief flash.

These are explicit reactions. Ordinary target and wall contact never consumes it.

## Presentation and performance

```text
1 ContagionCloud controller
1 translucent core mesh
1 puff MultiMesh
26 puff instances
0 per-puff nodes
1 reused sphere contact query at 5 Hz
1 forward movement ray per physics frame while moving
20 visual updates per second
1 persistent spell effect
```

The cloud uses deterministic low-poly gas puffs with slow local swirling. F7 should show one additional `SPELL FX` and one additional `PERSISTENT` while the cloud exists. Both return to baseline after expiration or replacement.

## The Pestilent Procession

Launch:

```text
res://scenes/levels/prototypes/prototype_contagion_cloud_spell_trial_v1.tscn
```

The development trial restores Mana on entry and regenerates 2 Mana per second between casts.

### I. The Unbroken Front

Three witnesses stand along one marked lane.

Cast one Contagion Cloud through all three. The gate opens only when every witness records the same cloud serial.

This proves that:

- the cloud moves;
- it poisons new entrants over time;
- it does not disappear after the first target;
- one persistent volume can affect separated targets sequentially.

### II. Outpace the Plume

Cast a fresh cloud forward from the green start mark, then run to the gold finish line.

The finish verifies:

- a new active Contagion Cloud exists;
- it is aligned with the marked lane;
- it has travelled at least 3 meters;
- Grace reaches the finish while the cloud center remains behind it.

The cloud is not destroyed when the race succeeds. It continues on its own timer behind Grace.

### Mastery

Enter the final gold seal:

```text
CAST • CONTAMINATE • OUTPACE
```

Completion records:

```text
pestilent_procession_contagion_cloud_trial_complete
```

## Reset

F8 restores:

- Grace's transform, velocity, resources, and Contagion Cloud selection;
- all witness health and status state;
- infection metadata and cast serials;
- both gates;
- race progression and mastery state;
- every active Contagion Cloud and gas-volume registration.

## Focused playtest

1. Open the Pestilent Procession.
2. Confirm Contagion Cloud appears under Poison with the `☣>` symbol.
3. Cast down the first lane and watch the cloud move more slowly than Grace can run.
4. Confirm all three witnesses become Poisoned as the same cloud reaches them.
5. Confirm the cloud does not disappear on any witness.
6. Let it reach the closed gate and confirm it stops but continues swirling.
7. Wait for its timer and confirm it fades only when time expires.
8. Enter the second lane and cast from the green mark.
9. Run past the cloud to the gold line.
10. Confirm the cloud continues moving behind Grace after the gate opens.
11. Test Wind Gust or Wind Well against a cloud and observe the shared gas drift.
12. Test Fire against a cloud and confirm Toxic Ignition remains available.
13. Watch F7 through casting, target contact, wall contact, expiration, and recasting.
14. Complete the mastery seal and press F8 to verify the full reset.
