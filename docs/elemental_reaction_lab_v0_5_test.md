# Elemental Reaction Laboratory + Visual Refresh v0.5 QA

## Goal

Verify that the existing payload/receiver/combo grammar now supports a readable, resettable five-element laboratory without breaking the Church Trial.

The player-facing recipes are:

```text
Fire + Oil → IGNITE
Water + Lightning → CONDUCT
Water + Ice → FREEZE
Frozen + Sword/Force → SHATTER
Frozen + Fire → STEAM
Sound + Hidden → REVEAL
```

## Dependency

This branch is stacked on PR #69 and expects the Goblin and Gremlin visual wrappers from that pass.

Merge PR #69 first. Then retarget this PR to `main` if GitHub does not do so automatically.

## Scene

Run:

```text
scenes/levels/prototypes/prototype_elemental_reaction_lab_v1.tscn
```

The lab should start with:

- Grace near the entry wall;
- a violet reset console on the left;
- a mana shrine on the right;
- three front stations: Ignite, Conduct, Freeze;
- two rear stations: Shatter, Steam;
- one final Sound Reveal station;
- station labels readable from the normal gameplay camera.

## Focused spell loadout

Confirm the lab equips exactly these five spells in this order:

1. Firebolt
2. Water Jet
3. Ice Lance
4. Lightning Spark
5. Sound Pulse

The practice sword remains available and supplies the `force` tag for Shatter.

The lab should refill Grace's mana, stamina, and focus at startup and after every reset.

## Element visual identity

### Fire

Confirm Firebolt reads as:

- a hot ember core;
- a brighter inner center;
- layered orange/red flame tails;
- a warm point light;
- a flickering trail;
- an orange-red impact flare.

### Water

Confirm Water Jet reads as:

- a stretched flowing body rather than a sphere;
- cyan flow rings;
- detached droplets;
- a softer blue trail and impact ripple.

### Ice

Confirm Ice Lance reads as:

- an angular crystal lance;
- separate side shards;
- pale cyan frost halo;
- a rigid rotating trail and crystalline impact.

### Lightning

Confirm Lightning Spark reads as:

- a bright white core;
- multiple jagged arc pieces;
- violet-blue charge ring;
- rapid flicker/jitter;
- a sharp electric impact.

### Sound

Confirm Sound Pulse is not a projectile.

It should create:

- three expanding horizontal rings;
- two crossing vertical resonance rings;
- pink Sound coloring;
- a clear radius that reaches the hidden resonator when Grace is nearby.

The five elements should be distinguishable before reading the spell label.

## Station anatomy

Each surface station contains two valid targets:

- the Goblin or Gremlin in the center for status/reaction testing;
- the smaller glowing `SURFACE` catalyst beside it for changing the puddle itself.

Confirm projectiles aimed at the creature hit the creature rather than being stolen by the surface catalyst.

Confirm projectiles aimed at the side catalyst trigger the puddle's reaction state.

The catalyst is an Area3D and must not block Grace, the camera, enemies, or projectiles physically.

## IGNITE station

### Target reaction

1. Approach the Goblin standing in oil.
2. Confirm the oil patch gives it the `oily` status visual.
3. Cast Firebolt at the Goblin.
4. Confirm:
   - `IGNITE` appears;
   - an orange-red reaction burst appears;
   - the Goblin gains persistent burning visuals;
   - normal Firebolt damage still applies;
   - burning continues to tick normally.

### Surface reaction

1. Reset the lab.
2. Cast Firebolt at the station's side `SURFACE` catalyst.
3. Confirm the oil patch visibly ignites with multiple flame markers.
4. Step into the burning oil.
5. Confirm targets inside sustain burning.
6. Wait for the configured state duration and confirm the oil returns to its glossy baseline.

## CONDUCT station

### Target reaction

1. Confirm the Gremlin standing in water gains `wet` visuals.
2. Cast Lightning Spark at the Gremlin.
3. Confirm:
   - `CONDUCT` appears;
   - the reaction burst is violet-blue;
   - the Gremlin gains persistent electric/stunned visuals;
   - its action/movement block follows existing stunned behavior;
   - normal Lightning Spark damage still applies.

### Surface reaction

1. Reset the lab.
2. Cast Lightning Spark at the station's side `SURFACE` catalyst.
3. Confirm the water becomes electrified with visible arc pieces.
4. Step into the electrified water.
5. Confirm targets inside sustain short stun pulses while the state lasts.
6. Confirm the water returns to normal afterward.

## FREEZE station

### Target reaction

1. Confirm the Goblin is wet from the water patch.
2. Cast Ice Lance at the Goblin.
3. Confirm:
   - `FREEZE` appears;
   - the burst is pale cyan;
   - the Goblin receives a visible ice shell/shards;
   - frozen blocks movement/actions according to the existing status system;
   - normal Ice Lance damage and stance pressure still apply.

### Surface reaction

1. Reset the lab.
2. Cast Ice Lance at the station's side `SURFACE` catalyst.
3. Confirm the water gains a crystalline frozen surface state.
4. Confirm targets inside sustain frozen while the state remains active.
5. Confirm the patch returns to water after its duration.

## SHATTER station

### Target reaction

1. Cast Ice Lance at the wet Gremlin to produce `FREEZE`.
2. Move into sword range.
3. Strike the frozen Gremlin with the practice sword.
4. Confirm:
   - `SHATTER` appears;
   - the reaction produces an outward crystal-shard burst;
   - frozen is removed;
   - reaction health/stance damage applies;
   - the normal sword payload still applies once;
   - the target remains available for further tests unless its large test health is depleted.

### Surface reaction

1. Reset the lab.
2. Cast Ice Lance at the side `SURFACE` catalyst to freeze the water.
3. Strike the nearby catalyst with the practice sword.
4. Confirm the surface produces a Shatter burst and returns to water.

## STEAM station

### Target reaction

1. Cast Ice Lance at the wet Goblin to produce `FREEZE`.
2. Cast Firebolt at the same target.
3. Confirm:
   - `STEAM BURST` appears;
   - a pale expanding steam-cloud reaction appears;
   - frozen, chill, and direct burning are removed by the recipe;
   - the short `steamed` visual/status remains;
   - Firebolt direct damage still applies.

### Surface reaction

1. Reset the lab.
2. Cast Ice Lance at the side `SURFACE` catalyst.
3. Cast Firebolt at the frozen catalyst.
4. Confirm the water becomes a temporary steam-cloud state and later returns to water.

## REVEAL station

1. Approach the empty gold marker at the rear station.
2. Confirm the resonance instrument starts hidden and non-colliding.
3. Cast Sound Pulse nearby.
4. Confirm:
   - the expanding Sound rings are visible;
   - `REVEAL` appears in pink;
   - the hidden ring instrument becomes visible;
   - its collision is enabled only while revealed;
   - pink crossing resonance rings mark the revealed state;
   - it hides again after the configured reveal duration.

## Persistent status readability

On the reaction targets, verify the following can be recognized without relying on UI text:

- Wet: orbiting/droplet shapes
- Oily: dark-violet sheen ring
- Burning: multiple orange flames
- Frozen: translucent ice shell and shards
- Stunned: jagged electric arcs
- Steamed: pale vapor clouds
- Revealed: pink resonance rings

Confirm status visuals follow the target and do not add collision.

## Reset console

After changing every station:

1. Interact with the violet reset console.
2. Confirm:
   - oil and water patches return to normal;
   - reaction timers clear;
   - target health and stance refill;
   - all target statuses clear;
   - the hidden Sound instrument hides again;
   - Grace's resources refill;
   - the five-spell lab loadout remains selected;
   - no scene reload is required.

In editor builds, press F8 and confirm it performs the same laboratory reset.

## Debug contract

Inspect debug output/overlay and confirm:

- the lab reports the registered rule count;
- each surface reports profile, active target count, reaction state, timer, last reaction, and hazard tags;
- each test target reports statuses and its last reaction;
- `PayloadReceiver` reports the last incoming payload, reaction ID, and reaction visual style;
- the combo matrix includes visual styles for Ignite, Conduct, Freeze, Shatter, and Steam.

## Church Trial regression

Run:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Complete:

```text
entry/save → Goblin + Gremlin combat → Fire/Water lock → Sound Reveal bridge → Animated Armor → sigil → exit
```

Confirm:

- Firebolt, Water Jet, Ice Lance, Lightning Spark, and Sound Pulse still cast normally;
- free aim and lock-on remain correct;
- projectiles retain their original collision and payload behavior;
- Goblin and Gremlin AI, telegraphs, health, damage, status reactions, and defeat remain correct;
- water/oil patches do not unexpectedly block movement or projectiles;
- Sound still reveals the bridge;
- saves, retry, boss, reward, Inventory, and exit remain functional.

## Automated validation

The exact PR head must pass:

- custom agent validation;
- Godot 4.6 import;
- title-screen startup;
- Church Trial startup;
- Elemental Reaction Lab startup;
- automated recipe smoke test for Ignite, Conduct, Freeze, Shatter, Steam, and the debug matrix;
- Windows release export;
- artifact upload.

## Windows artifact

Launch the generated Windows artifact and repeat:

- one full pass through all six lab reactions;
- reset console verification;
- at least the common-enemy and Sound portions of the Church Trial.

## Known limitations

- Visuals are procedural and replacement-ready rather than final authored particle systems.
- Only Fire, Water, Ice, Lightning, and Sound receive this pass.
- Lab targets are static presentation targets using the Goblin and Gremlin wrappers, not active AI encounters.
- Reaction damage/ranges remain prototype values.
- No new audio, authored UV textures, cinematics, skeletal animation, or post-processing is included.
