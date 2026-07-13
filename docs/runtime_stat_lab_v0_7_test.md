# Runtime Stat Laboratory + Resource Overcharge v0.7 QA

## Goal

Verify that the permanent Runtime Stat Laboratory safely exposes Grace's current stat architecture, supports uninterrupted combat and spell testing, distinguishes live formulas from metadata, and restores the exact entry state without writing laboratory values into the save slot.

## Scene

Run:

```text
scenes/levels/prototypes/prototype_runtime_stat_lab_v1.tscn
```

The room should open with:

- Grace on the front dais;
- Stamina controls and Sword/Hammer/Spear racks on the left;
- Mana controls and a cast target on the right;
- Health and Stance controls across the middle;
- Focus presets and a moving three-orb clock in the rear;
- a universal stat selector near the rear-right;
- LIVE/PARTIAL/DORMANT stat-gallery panels along the back wall;
- RESET ALL on the front-left;
- EXIT LAB on the front-right;
- a telemetry panel in the upper-left.

## Controller-first actions

The room intentionally describes actions rather than hard-coded buttons:

```text
INTERACT
LIGHT
HEAVY
FOCUS
CAST
DODGE
RESET
```

Confirm the game preserves the input actions configured in `project.godot`.

For Nick's current controller layout, the expected physical mapping is:

```text
L   LIGHT
R   HEAVY
ZL  FOCUS / spell menu
ZR  CAST
```

The laboratory and Weapon Combat Arena must not add an extra Heavy controller binding when `weapon_heavy_attack` already has one.

Keyboard fallback may remain available, but in-world instructions must not claim that one physical key or controller button is universal.

## Entry snapshot safety

Before touching a station:

1. Note Health, Stamina, Mana, Stance, Focus, and one dormant stat such as Defense.
2. Optionally change those values through an earlier development scene before opening the laboratory.
3. Enter the laboratory directly.
4. Confirm the HUD matches the values present at entry.
5. Confirm no save notification appears when the laboratory starts.

The laboratory captures a runtime snapshot only. It must not call the save-bed or save-slot writing flow.

## Stamina wing

### Baseline

1. Activate `STAMINA BASE`.
2. Confirm both current and maximum Stamina return to the values captured at laboratory entry.
3. Confirm Infinite Stamina is disabled if it was active.

### Overcharge

1. Activate `STAMINA 1000`.
2. Confirm the HUD shows:

```text
STAMINA 1000 / 1000
```

3. Equip Practice Sword.
4. Perform neutral Heavy and every available Light-to-Heavy branch.
5. Equip Training Hammer and repeat its Light and Heavy branches.
6. Equip Training Spear and repeat its Light and Heavy branches.
7. Confirm Stamina decreases according to attack costs.
8. Confirm the telemetry increments:
   - attack count;
   - declared weapon Stamina cost;
   - observed Stamina spent;
   - last/current attack information.

### Infinite Stamina

1. Activate `STAMINA ∞`.
2. Confirm the station and HUD display the Infinite state.
3. Repeatedly perform the most expensive Hammer and Sword Heavy sequences.
4. Confirm attacks never fail with `Not enough stamina`.
5. Confirm Stamina refills to at least `1000 / 1000` after spending.
6. Confirm attack and cost counters continue increasing even though the resource is refilled.
7. Toggle `STAMINA ∞` again.
8. Confirm Infinite mode turns off while the current overcharged pool remains until another preset or reset is used.

## Mana wing

### Overcharge

1. Activate `MANA 1000`.
2. Confirm the HUD shows:

```text
MANA 1000 / 1000
```

3. Aim at the Mana Cast Target.
4. CAST several spells with different costs.
5. Confirm Mana decreases normally.
6. Confirm the telemetry increments:
   - cast count;
   - selected spell name;
   - displayed Mana cost;
   - observed Mana spent.

### Infinite Mana

1. Activate `MANA ∞`.
2. Repeatedly CAST until the normal pool would have emptied.
3. Confirm spells continue casting and Mana refills.
4. Confirm spell telemetry remains meaningful while Infinite mode is active.
5. Toggle Infinite Mana off and confirm the station updates.
6. Activate `MANA BASE` and confirm current and maximum Mana return to the entry snapshot.

## Health wing

### Minimum Health

1. Activate `HEALTH 1`.
2. Confirm current Health becomes `1` without changing maximum Health.
3. Confirm Grace is not defeated and the scene does not restart.

### Controlled damage

1. Activate `HEALTH 1000`.
2. Confirm current and maximum Health become `1000 / 1000`.
3. Activate `PHYSICAL HIT`.
4. Confirm Health decreases by the displayed controlled amount.
5. Activate `MAGICAL HIT`.
6. Confirm Health decreases again.
7. Repeat until near 1 Health.
8. Confirm laboratory damage never reduces Health below 1 or emits the player-defeated flow.

The two labels are demonstration categories only. Defense and Resilience formulas are not active in this sprint, so both controlled hits currently subtract the configured amount directly.

### Full heal and baseline

1. Activate `FULL HEAL`.
2. Confirm current Health returns to the current maximum.
3. Activate `HEALTH 1000`, then `HEALTH BASE` through the universal selector if Health is selected.
4. Confirm both Health values return to the entry snapshot.

## Stance wing

1. Activate `STANCE 1`.
2. Confirm current Stance becomes 1 while maximum Stance remains unchanged.
3. Activate `STANCE HIT`.
4. Confirm Stance can reach 0 without affecting Health or causing player defeat.
5. Activate `FULL STANCE` and confirm current Stance returns to the current maximum.
6. Activate `STANCE 1000` and confirm both current and maximum Stance become `1000 / 1000`.
7. Use RESET ALL later and verify the original Stance pair returns.

## Focus wing

The moving three-orb clock uses ordinary frame processing and therefore visibly follows `Engine.time_scale`.

### Focus 0

1. Activate `FOCUS 0`.
2. Hold FOCUS.
3. Confirm the telemetry reports world speed near `1.0`.
4. Confirm the orbit clock continues at full speed.

### Focus 5

1. Activate `FOCUS 5`.
2. Hold FOCUS.
3. Confirm the world slows to an intermediate speed.
4. Release FOCUS and confirm world speed returns to `1.0`.

### Focus 10

1. Activate `FOCUS 10`.
2. Hold FOCUS.
3. Confirm the telemetry reports approximately `0.12` world speed.
4. Confirm the orbit clock moves much more slowly.

### Focus 1000

1. Activate `FOCUS 1000`.
2. Hold FOCUS.
3. Confirm the world does not slow below the configured minimum of approximately `0.12`.
4. Release FOCUS.
5. Confirm time scale returns to `1.0`.

This verifies the current clamped Focus formula rather than inventing a new overcharge curve.

## Universal stat selector

The selector cycles through:

- all 16 base-stat ids;
- all 16 core elemental affinities;
- Light, Darkness, and Void.

Use `PREVIOUS STAT` and `NEXT STAT` to change the selection. The HUD must show:

```text
SELECTED STAT
implementation classification
current value
classification explanation
```

For each class, test at least one example.

### LIVE example

1. Select Stamina or Focus.
2. Activate `SELECT 10`.
3. Confirm the value changes and the corresponding active system reads it.
4. Activate `SELECT BASE` and confirm the entry value returns.

### PARTIAL example

1. Select Power, Arcana, or Fire.
2. Confirm it is marked `PARTIAL`.
3. Activate `SELECT 1000`.
4. Confirm the stat value and gallery update.
5. Confirm existing damage does not suddenly scale, because production formulas remain intentionally inactive.
6. Activate `SELECT BASE`.

### DORMANT example

1. Select Defense, Charisma, Skill, or Luck.
2. Confirm it is marked `DORMANT`.
3. Activate `SELECT 10` and then `SELECT 1000`.
4. Confirm the value changes visibly.
5. Confirm gameplay does not pretend that an unimplemented formula exists.
6. Activate `SELECT BASE`.

## Stat gallery

Inspect all rear-wall panels.

Expected broad classifications:

```text
LIVE
Health, Stamina, Mana, Stance, Focus

PARTIAL
Power, Dexterity, Arcana, Intelligence
Elemental affinity ids

DORMANT
Defense, Resilience, Constitution, Evasion
Charisma, Skill, Luck
```

Confirm every displayed value updates after the universal selector mutates that stat.

Confirm the legend clearly explains:

```text
LIVE     active formula
PARTIAL  metadata hook
DORMANT  catalog only
```

## Telemetry checks

The HUD should remain readable during ordinary gameplay and display:

- current/max action resources;
- Infinite markers;
- equipped weapon;
- current attack;
- attack count;
- declared weapon Stamina cost;
- observed Stamina spent;
- selected spell and its Mana cost;
- cast count;
- observed Mana spent;
- Focus value;
- observed Focus spent;
- current world speed;
- last laboratory mutation;
- selected universal stat and implementation status.

Small timing differences are acceptable. Negative counters, impossible resource values, or counters changing from station setup mutations are not acceptable.

## Reset All

Before resetting, create a noisy laboratory state:

1. Enable Infinite Stamina and Infinite Mana.
2. Set Health and Stance to 1000.
3. Set Focus to 0 or 1000.
4. Change a Partial stat and a Dormant stat.
5. Equip Hammer or Spear.
6. Attack and cast several times.
7. Enter Focus mode briefly.

Then activate `RESET ALL` or use editor F8.

Confirm:

- every stat exactly matches the entry snapshot;
- current/max resource pairs are exact;
- all Infinite modes are off;
- `Engine.time_scale` is `1.0`;
- Focus menu and action locks are clear;
- invulnerability is clear;
- lock-on and combat motion are clear;
- Practice Sword is restored;
- training targets return to their initial transforms and receiver values;
- the Focus clock resets;
- telemetry counters return to zero;
- no save notification appears.

## Safe exit

1. Mutate several stats again.
2. Enable Infinite Stamina.
3. Activate `EXIT LAB`.
4. Confirm the room restores the entry snapshot before changing scene.
5. In the destination scene, inspect the Stats menu or resource HUD.
6. Confirm no laboratory value followed Grace out of the room.
7. Restart the game or use Continue.
8. Confirm the persistent save was not modified by laboratory activity.

Closing the running scene directly should also restore the runtime snapshot through the session's tree-exit cleanup.

## Controller mapping regression

1. Open the Input Map after importing the branch.
2. Confirm the user's existing controller binding for `weapon_heavy_attack` remains intact.
3. Run both the Runtime Stat Laboratory and Weapon Combat Arena.
4. Confirm the configured LIGHT and HEAVY controls work.
5. Confirm the old runtime Heavy fallback did not silently add another controller button when a joypad binding already existed.
6. Confirm FOCUS and CAST remain on the configured actions.

## Existing-scene regressions

### Weapon Combat Arena

Run:

```text
scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn
```

Confirm:

- Light/Heavy combo behavior is unchanged;
- all three weapon racks work;
- semantic action instructions replace stale fixed-button prose;
- resource costs remain unchanged;
- target reset and enemy spawns work.

### Elemental Reaction Laboratory

Run:

```text
scenes/levels/prototypes/prototype_elemental_reaction_lab_v1.tscn
```

Confirm all reactions, surfaces, reset behavior, spells, and visuals remain functional.

### Church Trial

Run:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Complete the route and confirm:

- normal resource limits apply;
- no Infinite laboratory mode leaked;
- weapon and spell controls work;
- saves, transitions, puzzles, enemies, boss, reward, and exit remain functional.

## Automated validation

CI must pass:

```text
custom agent validation
Godot 4.6 import
main startup
Church Trial startup
Elemental Reaction Laboratory startup
reaction recipe test
Weapon Combat Arena startup
weapon moveset test
Runtime Stat Laboratory startup
runtime stat-session test
Windows export
artifact upload
```

The automated stat test covers:

- controlled entry snapshot;
- Stamina current/max overcharge to 1000;
- spending and Infinite refill;
- Mana current/max overcharge;
- nonlethal Health minimum and full restore;
- Focus 0, 10, and 1000 time-scale behavior;
- LIVE/PARTIAL/DORMANT classifications;
- exact snapshot restoration;
- Infinite-mode cleanup;
- world-time cleanup;
- exit restoration.

## Windows artifact

Launch the exported Windows artifact and repeat the critical route:

1. Open the Runtime Stat Laboratory scene through the development workflow available for the artifact.
2. Test Stamina 1000 and Infinite Stamina.
3. Test Infinite Mana.
4. Test Focus 0 and Focus 10.
5. RESET ALL.
6. EXIT LAB.
7. Confirm ordinary gameplay values return.

## Known limitations

- The laboratory is a development scene, not a production character-building menu.
- Only Health, Stamina, Mana, Stance, and Focus have direct demonstrations of active runtime behavior.
- Power, Dexterity, Arcana, Intelligence, and elemental affinities expose metadata hooks, not active scaling formulas.
- Defense, Resilience, Constitution, Evasion, Charisma, Skill, and Luck remain dormant.
- Physical and magical Health buttons demonstrate labeled controlled damage, not active Defense/Resilience calculations.
- Infinite resources use continuous refill rather than bypassing cost functions, preserving useful spend telemetry.
- Procedural room art, labels, and moving Focus clock are replacement-ready prototypes.
- No permanent cheats, allocation, leveling, respec, XP, equipment bonuses, or save-schema changes are included.

## Creative review

Judge whether the chamber feels like a useful RPG systems cockpit rather than a wall of arbitrary cheats. In particular, judge:

- whether Stamina overcharge makes complete weapon-combo testing frictionless;
- whether Infinite modes are obvious and trustworthy;
- whether the five active demonstrations teach what their stats currently do;
- whether the LIVE/PARTIAL/DORMANT distinction prevents false promises;
- whether the universal selector is understandable from the gameplay camera;
- whether the controller-first language remains useful after remapping inputs;
- whether the HUD contains enough information without swallowing the room.
