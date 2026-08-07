# Bubble and the Bubble Breakwater v1

## Purpose

Add Water's first one-hit defensive spell and prove that a persistent ward can remain visually readable without becoming another permanent processing swarm.

```text
Cast Bubble
    ↓
One incoming hit reaches Grace
    ↓
Health, stance, status-tick damage, and hit reaction are negated
    ↓
Bubble bursts once
    ↓
Nearby enemies, mobs, and loose objects are pushed outward
```

## Launch

Run:

```text
res://scenes/levels/prototypes/prototype_bubble_breakwater_spell_trial_v1.tscn
```

The development trial equips Bubble automatically, fills Mana on entry, and regenerates Mana at 2 points per second between attempts.

## Spell identity

Bubble costs 3 Mana and lasts for up to 12 seconds.

It is not extra health and it is not Guard:

- Bubble negates one complete incoming hit.
- The absorbed hit spends no health, stance, stamina, or Guard.
- Grace receives no hit stagger or recoil.
- The shield then ends immediately.
- Its burst deals 0 health damage and 0 stance damage.
- The burst applies outward knockback within a 4-meter radius.
- Boss knockback is strongly reduced.
- Recasting refreshes the existing ward instead of stacking multiple shields.
- Dodged attacks do not consume Bubble.
- Elemental-authority immunities resolve before Bubble and therefore preserve it.
- A damaging status tick can consume Bubble, preventing that tick.

Bubble sits outside ordinary Guard once an attack genuinely reaches defense resolution. If Grace is standing still and guarding with Bubble active, the ward is consumed before stamina or stance are charged.

## Performance contract

The player owns one permanent `PlayerBubbleShieldController`, but it sleeps while inactive.

```text
Inactive:
0 processing callbacks
0 visible shield meshes
0 persistent-spell count

Active:
1 controller
1 reused sphere mesh
30-Hz visual pulse
0 collision polling

Consumed:
1 bounded broadphase query
1 short reused burst animation
then sleep
```

There is no per-frame Area3D overlap scan and no newly spawned particle actor for each burst. F7 should show one additional persistent spell effect while Bubble is active and should return to the prior count after the shield is consumed or expires.

## Room I: One Clean Hit

1. Enter the first blue floor ring.
2. Cast Bubble.
3. Remain inside the ring while the pressure emitter charges.
4. Let the automatic pressure pulse strike the ward.
5. Confirm Bubble bursts.
6. Confirm Grace loses no health or stance and receives no stagger.
7. Confirm the first gate opens.

The pressure emitter only fires after it sees an active Bubble inside the ring, so the trial teaches the defense without repeatedly injuring Grace during setup.

## Room II: The Rebound

A training target begins just inside Bubble's burst radius.

1. Enter the second blue ring.
2. Position Grace so the target sits near the edge of the ward's burst.
3. Cast Bubble.
4. Let the second pressure pulse consume it.
5. Confirm the target is pushed outward without taking damage.
6. Push it beyond the authored outer distance to open the mastery gate.

The lesson is positional: Bubble protects Grace, but its follow-up value depends on where nearby bodies are when the hit arrives.

## Mastery

Enter the gold seal after the rebound gate opens.

Completion records:

```text
bubble_breakwater_spell_trial_complete
```

The mastery summary is:

```text
NEGATE • BURST • REPOSITION
```

## Reset behavior

F8 restores:

- Grace's starting transform, health, stance, Mana, and Bubble selection;
- the inactive shield state;
- the Rebound Target's transform, health, and forces;
- both gates;
- the trial stage and objective;
- the mastery flag; and
- all Bubble processing and persistent-effect group membership.

## F7 comparison

Because the reported 20 FPS and roughly 140 ms p95 were measured with F7 visible, the overlay itself received a second performance repair in this round.

The old visible overlay recursively walked the entire scene tree inside one half-second sample. That work now runs as an incremental census capped at 192 nodes per frame and refreshes every two seconds. The overlay displays `SCANNING` while the pass is incomplete.

Compare these cases after pulling main:

1. Bubble Breakwater with F7 hidden.
2. Bubble Breakwater with F7 visible and census `READY`.
3. Bubble active.
4. Bubble consumed and fully faded.

Record FPS, average frame time, p95, process time, physics time, draw calls, node count, and persistent spell count. This distinguishes a rendering bottleneck from an overlay-authored spike or a leaked spell effect.

## Automated regressions

Run:

```text
res://scenes/tests/bubble_breakwater_smoke_test.tscn
res://scenes/tests/runtime_performance_incremental_census_smoke_test.tscn
```

Coverage includes:

- spell library and icon integration;
- three-Mana cost;
- self-targeted one-hit-shield identity;
- recast refresh without duplicate controllers;
- complete health and stance negation;
- absence of hit reaction;
- outward force against nearby targets;
- zero burst damage;
- one-hit consumption;
- ordinary damage after the ward is gone;
- damaging status-tick interception;
- finite expiration and idle sleep;
- both Breakwater stages;
- mastery persistence and reset;
- fixed F7 census work per frame; and
- cancellation of unfinished diagnostic scans when the overlay closes.
