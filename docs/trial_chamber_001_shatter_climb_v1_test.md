# Trial Chamber 001: Shatter & Climb — Consecutive Puzzle Pass

## Purpose

`Shatter & Climb` is the first compact trial in the isolated-puzzle development format.

The first pass proved that a fixed loadout and a small chamber feel good. This pass changes the structure from **choose one branch** to **solve a short sequence**:

```text
Puzzle I: Freeze
        ↓
Puzzle II: Shatter
        ↓
Optional Cache ── reward only
        ↓
Puzzle III: Synthesis
        ↓
Upper Seal
```

Scene:

```text
res://scenes/levels/prototypes/trial_chamber_001_shatter_climb_v1.tscn
```

The chamber is intentionally placeholder-simple. Judge puzzle readability, tool expression, sequencing, movement, camera behavior, optional-reward temptation, and solution satisfaction rather than final art.

## Fixed trial loadout

Grace receives only:

```text
Weapon: Training Hammer
Spell 1: Water Jet
Spell 2: Ice Lance
```

Double jump, hover, and Flight are disabled so old development progression cannot bypass the authored sequence. Mana and Stamina regenerate so experimentation is cheap.

## Trial philosophy

The **required sequence is spatial**, not a password check.

Each puzzle asks Grace to produce a world-state outcome and physically move beyond it. If the supplied tools create an unexpected but coherent way to cross a gap or reach a checkpoint, accept it. What the player may not do is solve Puzzle I and skip directly to the end while ignoring the rest of the chamber.

Required puzzles teach and test the core vocabulary. Optional puzzles reward curiosity with items but never advance the main trial.

---

## Puzzle I — Freeze

Goal: cross the flooded span.

Intended discovery:

```text
Water Jet → Wet
Ice Lance → Wet Freeze
Wet Freeze → solid crossing
```

Playtest:

- Confirm the entrance leads directly to one obvious flooded gap.
- Confirm there is no authored stair route around it.
- Cast Water Jet onto the crossing.
- Cast Ice Lance onto the wet crossing.
- Confirm it becomes visible solid ice with traversal collision.
- Cross to the far side.
- Confirm reaching the far side advances the objective to Puzzle II.

The checkpoint beyond the gap is the progression condition. A coherent emergent crossing is allowed, but Puzzle II still follows.

---

## Puzzle II — Shatter

Goal: pass the fractured masonry seal.

Intended discovery:

```text
ordinary Hammer hit → stone holds
Ice Lance → masonry becomes brittle
Light Hammer hit → still holds
Heavy Hammer hit → shatter
```

This pass tightens the shared brittle-gate contract for this room: the trial opts into **Heavy-required shattering**. Existing village gates retain their more forgiving default behavior.

Playtest:

- Hit the seal before freezing it and confirm it remains closed.
- Freeze it with Ice Lance.
- Try a Light Hammer hit and confirm the frozen seal still holds.
- Use Heavy.
- Confirm the seal breaks/withdraws.
- Walk through it.
- Confirm the objective advances to Puzzle III.

---

## Optional Cache — reward, not progression

Between Puzzles II and III, a gold reward cache sits on a raised side shelf.

It is deliberately too high for an ordinary jump and has **no progression flag attached to it**.

The supplied tools already suggest several experiments:

- lodge Ice Lances into hard surfaces as temporary footholds;
- use Water Jet recoil to gain height;
- combine both;
- discover something stranger.

Reach the shelf and open the cache. It uses the existing reward-choice chest and offers ordinary supplies. Claiming it must not alter the active main-trial stage.

Resetting the main puzzle sequence does not reseal or respawn an already opened cache, preventing the optional reward from becoming a reset-farming loop during the same scene instance.

This is the model for future optional trial content:

```text
harder / stranger side problem → item, material, technique, lore, or other reward
```

---

## Puzzle III — Synthesis

Goal: reach the upper seal using both ideas learned earlier.

The final chamber contains:

1. a steep flooded chute;
2. an upper fractured crown seal;
3. the glowing goal beyond it.

Intended sequence:

```text
Water Jet + Ice Lance
        ↓
freeze the chute into a walkable ramp
        ↓
Ice Lance + Heavy Hammer
        ↓
shatter the crown seal
        ↓
Upper Seal
```

This is the first **remix** beat. The chamber no longer teaches either interaction separately here. It asks the player to recognize and reuse both.

Creative ascent methods remain welcome. If Water Jet recoil or Ice Lance footholds replace the frozen ramp, that is a valid solution to the ascent portion. The player still has to continue through the final chamber and reach the seal.

---

## Geometry / presentation target

This pass intentionally removes the previous branching stair runs. The room should read as three broad consecutive spaces inside one simple shell:

- generous ceiling height;
- broad flat landings;
- one flooded horizontal span;
- one masonry threshold;
- one flooded inclined ascent;
- one final masonry threshold;
- one small raised optional shelf.

The goal is not final architecture. It is a cleaner graybox that does not create accidental visual puzzles such as stairs disappearing into ceilings.

Color hierarchy is restrained:

- cyan = water / freeze opportunity;
- fractured gray = shatter opportunity;
- gold = optional cache or final goal.

---

## Reset behavior

Use the existing `RESET` / `restart_scene` development action.

Confirm reset:

- returns Grace to the entrance;
- returns progression to Puzzle I;
- restores Health, Mana, Stamina, and Stance;
- melts both authored frozen surfaces;
- restores both masonry seals;
- clears trial completion;
- keeps the fixed Water / Ice / Hammer loadout;
- does not duplicate the optional cache reward within the same scene instance.

Falling below the chamber also returns Grace to the entrance.

---

## Creative review

Judge the pass on these questions:

1. Does solving three small problems feel more satisfying than choosing one branch?
2. Does Puzzle I teach Water → Ice clearly without a tutorial placard?
3. Does Puzzle II make Ice → Heavy feel physically legible?
4. Does requiring Heavy improve the shatter interaction?
5. Does Puzzle III feel like a genuine remix rather than the same two puzzles pasted together?
6. Does the raised cache tempt you away from the main route without confusing the objective?
7. Is the optional reward worth the extra experimentation?
8. Does the fixed loadout still make experimentation feel focused rather than restrictive?
9. Does the no-stair graybox feel cleaner with the camera?
10. Which unintended solution do you discover?

Unexpected solutions remain valuable. Patch one out only when it trivializes the broader trial format, not merely because it was unplanned.

---

## Automated regression

```text
res://scenes/tests/trial_chamber_001_shatter_climb_smoke_test.tscn
```

The regression checks:

- one continuous compact shell with no authored stair-run nodes;
- exact Water Jet + Ice Lance loadout;
- Training Hammer assignment;
- aerial bypasses disabled;
- optional reward cache starts available and does not advance progression;
- Puzzle I uses actual Water Jet and Ice Lance payloads;
- reaching the far side advances to Puzzle II;
- Puzzle II rejects a Light force hit after freezing;
- Puzzle II accepts Heavy after freezing;
- passing the seal advances to Puzzle III;
- Puzzle III freezes the inclined ascent and shatters the crown seal;
- only the final goal completes the trial;
- reset restores all four required mechanisms and returns to Puzzle I.

## Promotion status

Trial Chamber 001 remains experimental authored content rather than a new general framework. If this consecutive-plus-optional structure feels good manually, promote the chamber and use this grammar as the starting point for Trial 002.
