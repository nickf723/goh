# Ruined Village Approach — First Production Adventure Slice v1 Manual Test

## Purpose

The Ruined Village Approach is now the **first production-adventure-slice entry point** for *Grace of Humanity*.

The goal is no longer to showcase as many systems as possible. The level should play as one coherent 10–15 minute miniature of the game:

```text
investigate
→ fight
→ choose an elemental route
→ optional discovery
→ checkpoint
→ enter the Church Trial
```

The scene still reuses the existing Ruined Village environment, combat encounter, Sound memory, elemental ravine routes, save point, Church Trial handoff, player, HUD, and world systems. `AdventureChunk` now provides the authored pacing spine instead of introducing another quest or level framework.

## Load the level

Run:

```text
res://scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn
```

The production slice should settle on this opening objective after initialization:

```text
Inspect the impact crater, the severed foundation, and the abandoned hearth.
```

The old spell-showcase launch behavior is intentionally suppressed here:

- Flight is **not** auto-unlocked;
- Flight is **not** auto-selected;
- Grace starts on the shared loadout's first spell;
- the ravine therefore remains a meaningful authored obstacle;
- large floating laboratory/solution labels are hidden from the canonical slice.

The separate Field Progression derivative remains a development showcase and does not activate this production Adventure Chunk graph.

---

# Adventure Chunk spine

The active graph is:

```text
Read the Vanished Village
        ↓
Clear the Village Square
        ↓
Cross the Collapsed Ravine
        ↓
Enter the Church of Angels
```

Beside the main route:

```text
Read the Vanished Village
        ↓
Recover the Buried Memory   (optional)
```

The five authored chunks are:

1. `ruined_village_investigation`
2. `ruined_village_square_combat`
3. `ruined_village_ravine_choice`
4. `ruined_village_sound_memory` — optional
5. `ruined_village_church_threshold`

The whole village leg persists through:

```text
first_production_adventure_slice_v1
```

The final threshold still changes directly into the existing Church Trial scene.

---

# Controller expectations

Use the player's configured actions rather than fixed physical-button labels:

```text
MOVE
INTERACT
LIGHT
HEAVY
FOCUS
CAST
DODGE
LOCK-ON
RESET (editor test only)
```

The level must not alter the user's controller mappings.

---

# 1. Opening investigation

- Confirm Grace begins inside the teleport-impact hollow facing toward the village route.
- Confirm the church remains visible as the distant destination.
- Confirm Flight is not automatically enabled as a laboratory shortcut.
- Inspect the **impact crater**.
- Follow the road and inspect the **severed/lifted foundation**.
- Inspect the **abandoned hearth**.
- Confirm the clues can be found in any order.
- Confirm each clue still gives its own environmental-story text.
- After all three have been read, confirm the objective changes to reaching/clearing the village square.

The scene should communicate impossible absence rather than ordinary collapse before combat becomes the focus.

---

# 2. Optional Sound memory

After the investigation chunk becomes complete:

- Enter the village square without using Sound first.
- Find the faint buried-memory interaction.
- Confirm interacting before reveal reports that the source is still hidden.
- Select Sound Pulse and reveal the wooden bird.
- Interact with the revealed memory.
- Confirm the optional Adventure Chunk completes.
- Confirm the main story objective does **not** get replaced by an optional objective.
- Confirm the level remains fully completable without finding the memory.

This beat is the slice's curiosity reward, not a progression lock.

---

# 3. Village square combat

- Enter the square and trigger the existing encounter.
- Confirm two Goblins and one Gremlin spawn from the existing encounter definition.
- Test Light/Heavy weapon branches.
- Use at least one spell or elemental interaction during the fight.
- Confirm lock-on sees active enemies.
- Defeat all three.
- Confirm the existing encounter reward still restores Mana.
- Confirm the broad scavenger barricade releases.
- Confirm the Adventure Chunk spine advances to the ravine objective.

The Adventure Chunk layer must not spawn a second encounter or duplicate encounter rewards.

---

# 4. Ravine route choice

Only **one** route is required.

## Right route: Fire

- Approach the root-choked stone bridge.
- Cast Fire at the debris.
- Confirm the debris clears immediately.
- Confirm the ravine Adventure Chunk completes.

## Right route: Ice + Heavy

On a reset/reload:

- Cast Ice at the debris.
- Confirm it freezes instead of opening immediately.
- Use a Heavy / force-tagged attack.
- Confirm the frozen obstruction shatters.
- Confirm the same ravine Adventure Chunk completes.

## Left route: Water → Ice

On a reset/reload:

- Approach the flooded crossing.
- Apply Water / Wet to the crossing.
- Apply Ice / Frozen.
- Confirm the path becomes visibly and physically traversable.
- Confirm the same ravine Adventure Chunk completes.

The Adventure Chunk uses **ANY requirement**, so solving one route must not demand the other route afterward.

---

# 5. Church approach and checkpoint

- Confirm either ravine solution converges below the church hill.
- Climb the stairs rather than bypassing the route with automatically unlocked Flight.
- Confirm the objective now asks Grace to enter the Church of Angels.
- Reach the church-ground camp.
- Rest and confirm Health, Mana, Stamina, and Stance restore.
- Save if desired.
- Confirm existing completed clues, combat, and route state survive a save/reload.

---

# 6. Death and recovery

- Save at the church-ground camp.
- Take lethal damage or use a controlled debug method.
- Confirm death retry reloads the current village scene.
- Confirm Grace returns to the saved camp position.
- Confirm existing world flags restore their corresponding physical state.
- Confirm the Adventure Chunk graph catches up from restored source properties instead of requiring repeated actions.

---

# 7. Church handoff

- Interact deliberately with the church entrance.
- Confirm `ruined_village_church_threshold` completes before the scene transition.
- Confirm the sequence persistence flag is set:

```text
first_production_adventure_slice_v1
```

- Confirm the scene changes to:

```text
res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

- Continue into the existing Church Trial and perform a short continuity check:
  - movement and camera still feel identical;
  - HUD state survives the transition cleanly;
  - Light/Heavy combat works;
  - spell selection/casting works;
  - the Church Trial objective owns presentation after transition;
  - save and boss startup still function.

The village sequence ending should feel like escalation into the next adventure space, not like returning to a development menu.

---

# 8. Pacing target

For a first blind-ish playthrough, measure from player control at the crater to crossing the church threshold.

Target:

```text
10–15 minutes
```

Do **not** tune toward the target by adding filler. Record where time is actually spent:

- navigation / getting lost;
- clue reading;
- combat;
- spell selection;
- understanding the ravine;
- optional memory;
- checkpoint interaction.

If the route is much shorter, the next question is whether one existing beat needs depth. If it is much longer, identify friction or confusion before adding/removing content.

---

# 9. Automated validation

Run:

```powershell
python scripts/ci/validate_feature_registry.py
python scripts/ci/validate_capability_inventory.py
python scripts/ci/run_feature_registry.py --godot godot
```

The existing registered smoke test remains:

```text
res://scenes/tests/ruined_village_approach_smoke_test.tscn
```

It now also verifies:

- the production Adventure Slice director activates only on the canonical village root;
- five chunks form a valid graph;
- investigation opens the graph;
- combat depends on investigation;
- ravine choice depends on combat;
- Sound memory stays optional;
- church threshold depends on the ravine;
- clues, debris, ice bridge, and memory expose lifecycle signals for sequencing;
- the production slice no longer auto-selects/unlocks Flight.

Existing regression coverage still verifies the environment, encounter definition, Fire route, Ice + Heavy route, Water + Ice bridge, Sound reveal, save-state restoration, checkpoint, and Church Trial transition path.

---

# Creative review

This playtest matters more than another subsystem checklist. Judge the slice on:

1. **Continuity:** Does each beat naturally create the reason to do the next one?
2. **Clarity:** Can you understand the next goal without floating developer signage?
3. **Agency:** Does the ravine feel like a choice rather than two chores?
4. **Sandbox value:** Do combat and elemental tools invite experimentation without requiring a tutorial popup?
5. **Optionality:** Does the Sound memory reward curiosity without hijacking the main objective?
6. **Pacing:** Where does the 10–15 minute route drag or rush?
7. **Escalation:** Does entering the Church Trial feel like the payoff to crossing the village?
8. **Game identity:** Does this feel more like playing *Grace of Humanity* than testing a collection of mechanics?

The result of this playtest should choose the next development target. Do not assume in advance that the answer is more content, more combat, more art, or more systems.

---

# Known limitations

- Terrain, ruins, vegetation, props, church architecture, enemies, animation, and audio remain prototype/replacement-ready.
- The playable footprint is compressed while implying a broader village region.
- Goblin and Gremlin actors still stand in for future location-specific opponents.
- The Water/Ice bridge remains latched until reset for dependable testing.
- The shared development loadout still exposes a very broad spell library; this pass only removes the explicit Flight showcase shortcut.
- The village Adventure Chunk spine currently ends at the Church threshold; the Church Trial retains its own existing progression logic.
- This milestone deliberately adds no new combat, puzzle, quest, progression, HUD, or environment framework.
