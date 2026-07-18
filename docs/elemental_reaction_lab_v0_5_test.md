# Elemental Reaction Laboratory + Steam Burst v1 QA

## Goal

Verify that the existing payload, receiver, status, force, and combo-rule grammar supports a visible multi-target elemental reaction:

```text
Water → Ice → Fire → STEAM BURST
```

The Steam Burst should transform the frozen surface, create a readable cloud burst, and apply a reusable radial consequence to nearby actors.

The broader laboratory still supports:

```text
Fire + Oil → IGNITE
Water + Lightning → CONDUCT
Water + Ice → FREEZE
Frozen + Sword/Force → SHATTER
Frozen + Fire → STEAM BURST
Sound + Hidden → REVEAL
```

## Scene

Run:

```text
scenes/levels/prototypes/prototype_elemental_reaction_lab_v1.tscn
```

The laboratory should contain:

- Grace near the entry wall;
- a violet reset console on the left;
- a mana shrine on the right;
- Ignite, Conduct, and Freeze stations at the front;
- Shatter and Steam stations behind them;
- the Sound Reveal station at the rear;
- live surface-state readouts at the reaction stations.

The Steam station should additionally contain:

- a water surface and side `SURFACE` catalyst;
- three reaction targets arranged around the surface;
- a pale circular guide labeled `STEAM BURST • 2.65m`;
- a readout showing state, last reaction, burst target count, and target names.

## Focused loadout

The lab equips these five spells:

1. Firebolt
2. Water Jet
3. Ice Lance
4. Lightning Spark
5. Sound Pulse

The practice sword remains available for Force and Shatter testing.

Grace's mana, stamina, and focus should refill when the scene starts and whenever the lab resets.

## Station targeting

Each surface station exposes a glowing side catalyst labeled `SURFACE`.

- Aim at the creature to test status combinations on a normal target.
- Aim at the side catalyst to change the puddle or hazard itself.
- The catalyst must not physically block Grace, the camera, enemies, or projectiles.

## Steam Burst arena

### Surface sequence

1. Go to the Steam station.
2. Note that the readout begins at `STATE: NORMAL` and `LAST: NONE`.
3. Cast Ice Lance at the side `SURFACE` catalyst.
4. Confirm the water becomes visibly frozen.
5. Confirm the readout changes to `STATE: FROZEN` and reports the Freeze reaction.
6. Cast Firebolt at the same frozen catalyst.
7. Confirm `STEAM BURST` appears over the surface.
8. Confirm the surface changes to a temporary steaming state.
9. Confirm a pale expanding cloud and reaction rings clearly reach toward the radius guide.
10. Confirm the readout changes to `STATE: STEAMING`, `LAST: STEAM_BURST`, and reports nearby targets.

### Radial consequence

The Steam Burst uses a `2.65m` sphere centered on the reacting surface.

For targets inside that radius, confirm:

- they gain the short `steamed` status;
- they receive one point of stance pressure;
- they receive a modest outward impulse;
- their force/debug summary identifies Steam Burst;
- the surface readout includes their names and the total number caught.

The push should be visible but restrained. It should scatter the test arrangement slightly rather than launch targets across the laboratory.

A target beyond the pale radius guide should not receive the radial result.

### Primary reaction behavior

Confirm the frozen surface itself:

- loses its frozen state;
- enters the temporary steaming state;
- continues applying short steamed pulses to actors standing inside it;
- returns to ordinary water after its configured duration.

The radial burst should occur once when the recipe resolves. The lingering steaming surface should not repeatedly reapply the one-point burst stance damage or burst impulse.

### Direct target reaction

1. Reset the lab.
2. Let a reaction target become wet.
3. Cast Ice Lance directly at it to produce Freeze.
4. Cast Firebolt directly at the same target.
5. Confirm:
   - `STEAM BURST` appears;
   - frozen, chill, and direct burning are removed;
   - the target keeps the short steamed status;
   - Firebolt's normal direct payload still resolves;
   - nearby receiver-equipped targets can still receive the radial consequence.

## Live station readouts

The Ignite, Conduct, Freeze, Shatter, and Steam stations should display:

```text
STATE: <current surface state>
LAST: <most recent reaction>
BURST: <area target count> | <target names>
```

Confirm:

- the text is readable from the ordinary gameplay camera;
- its color follows the current elemental state;
- non-area recipes report a burst count of zero;
- Steam Burst reports the actual deduplicated targets caught;
- the panel updates after reset without reloading the scene.

## Other reaction regressions

### Ignite

1. Cast Firebolt at an oily target or Oil `SURFACE` catalyst.
2. Confirm Ignite feedback and persistent burning.
3. Confirm the oil surface eventually returns to baseline.

### Conduct

1. Cast Lightning Spark at a wet target or Water `SURFACE` catalyst.
2. Confirm Conduct feedback and electric/stun behavior.
3. Confirm the surface eventually returns to water.

### Freeze

1. Cast Ice Lance at a wet target or Water `SURFACE` catalyst.
2. Confirm Freeze feedback and frozen movement/action blocking.
3. Confirm the surface gains its crystalline state.

### Shatter

1. Freeze a target or surface.
2. Apply the practice sword's Force-tagged attack.
3. Confirm Shatter removes frozen and applies the existing reaction payload.

### Reveal

1. Approach the empty gold marker at the rear station.
2. Cast Sound Pulse nearby.
3. Confirm the hidden resonator becomes visible and collidable for the reveal duration.

## Reset contract

After triggering Steam Burst and moving the targets:

1. Use the violet reset console or press F8 in an editor build.
2. Confirm:
   - every surface returns to normal;
   - reaction timers and burst histories clear;
   - each target returns to its staged Steam-arena position;
   - target health and stance refill;
   - all statuses clear;
   - stored external force clears;
   - the readout returns to `NORMAL`, `NONE`, and zero targets;
   - Grace's resources refill;
   - the five-spell laboratory loadout remains active.

No scene reload should be required.

## Debug contract

Confirm debug data exposes:

- laboratory version `elemental_reaction_v1`;
- registered combo-rule count;
- surface state and remaining reaction time;
- last reaction ID;
- radial target count and names;
- current hazard tags;
- target statuses and force summaries;
- Steam Burst's area radius and area status in the combo matrix.

## Automated validation

The exact branch head must pass:

- feature-registry validation;
- Godot 4.6 import;
- project startup;
- registered feature scenes and tests;
- elemental reaction smoke tests for Ignite, Conduct, Freeze, Shatter, and Steam;
- explicit Steam Burst tests for radial steamed status, one stance damage, and force;
- Windows release export;
- artifact upload.

## Creative review

Judge these qualities during the manual pass:

- Does Ice followed by Fire read as one compounded magical event?
- Is the Steam Burst large enough to reward setup without feeling detached from the surface?
- Is the cloud visible without obscuring the entire station?
- Is the outward push noticeable but controlled?
- Does the live readout help diagnose the reaction without becoming visual wallpaper?
- Does the three-step Water → Ice → Fire chain feel worth performing?

## Known limitations

- The radial query is a simple sphere and does not test line of sight or cover.
- Steam currently applies status, stance pressure, and force, but no dedicated concealment gameplay.
- The surface and reaction visuals are procedural and replacement-ready.
- Laboratory targets are deterministic test actors rather than active encounter AI.
- Reaction tuning remains prototype balance.
- Only a subset of the sixteen core elements is represented in this laboratory pass.
