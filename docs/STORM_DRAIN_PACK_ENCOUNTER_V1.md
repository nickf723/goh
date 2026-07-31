# Storm Drain Pack Encounter v1

## Purpose

The Storm Drain Pack is the first dedicated playable encounter built to exercise reaction-aware tactical AI, squad reservations, complementary squad roles, threat response, engagement lanes, cover requests, elemental surfaces, and the tactical flight recorder in one fight.

Scene:

```text
res://scenes/levels/prototypes/prototype_storm_drain_pack_encounter_v1.tscn
```

## Pack composition

### Mire Gremlin

- Squad role: `primer`
- Personality: `cautious`
- Signature action: **Mire Spit**
- Fires a Water projectile that applies Wet and advertises Conduct setup.

### Spark Gremlin

- Squad role: `payoff_specialist`
- Personality: `bold`
- Signature action: **Spark Pounce**
- Commits to a Lightning lunge and receives extra tactical value against Wet targets.

### Shield Gremlin

- Squad role: `protector`
- Personality: `brute`
- Signature action: **Guard Screech**
- Restores stance to nearby pack members and applies a short guarded status.

### Runner Gremlin

- Squad role: `skirmisher`
- Personality: `skittish`
- Signature action: **Hookstep**
- Uses a fast lateral retreat that opens engagement space and broadcasts a cover request.

## Arena

The arena contains:

- a long reactive Water channel through the center
- side walkways and four cover pillars
- enough distance for ranged setup and committed pounces
- a reset console
- Mana, Stamina, and Focus regeneration
- a Ruvia testing ring
- a tactical decision overlay
- a compact pack-status panel

Grace can cross the channel, avoid it, freeze it, cleanse statuses, interrupt Spark during windup, launch Shield away from the formation, or consume the pack's setup herself.

## Controls

- Standard movement, weapons, spells, Focus, and Divine Incarnation controls
- `F2`: show or hide tactical telemetry
- `Tab`: observe the next surviving pack member
- `,` or Left: previous recorded decision
- `.` or Right: next recorded decision
- `F8` in the editor: reset the encounter
- Interact with the violet console to reset in any build

## First manual test

1. Enter without immediately attacking.
2. Watch whether Mire prefers range and attempts Mire Spit.
3. Let Mire apply Wet once.
4. Observe whether Spark's telemetry recognizes a reaction payoff.
5. Damage one pack member's stance and watch for Guard Screech.
6. Pressure Runner in melee and watch for Hookstep and a cover request.
7. Freeze the central channel and confirm only actors standing in it receive Frozen.
8. Defeat one specialist and watch whether the remaining formation continues without duplicated reservations.
9. Summon Ruvia and observe whether she respects the pack's claimed reactions and protected states.
10. Reset and repeat with a different opening spell.

## Expected tactical rhythm

```text
Mire Spit applies Wet
-> Spark reserves Conduct payoff
-> Shield repairs or covers the formation
-> Runner vacates a crowded lane
-> another pack member answers the opening
```

The sequence is opportunistic rather than scripted. Interrupts, hazards, distance, cooldowns, player actions, and personality may change the order.

## Automated test

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/storm_drain_pack_encounter_smoke_test.tscn
```

Expected:

```text
STORM_DRAIN_PACK_ENCOUNTER_SMOKE_TEST: PASS
```

The regression verifies scene construction, four-member spawning, explicit roles and personalities, action libraries, projectile delivery, Guard Screech stance restoration, water and telemetry infrastructure, resource regeneration, and encounter reset.

## Known limitations

- Mire Spit uses procedural projectile visuals.
- Guard Screech restores stance but does not yet provide a complete damage-mitigation shield model.
- Hookstep currently commits to one authored lateral direction.
- The tactical overlay observes one actor at a time.
- Final sound, animation, creature silhouettes, and environment art remain replacement-ready.
