# Trial Chamber 002: Conductive Circuit v1 Manual Test

## Purpose

`Conductive Circuit` is the second compact Trial Chamber and the first counter-test of the accepted chamber format.

Trial 001 tested ordered transformations. Trial 002 asks a different question:

> Can the player reason about physical conductive topology using a small fixed toolset?

Scene:

```text
res://scenes/levels/prototypes/trial_chamber_002_conductive_circuit_v1.tscn
```

The room remains intentionally blockout-simple. Judge puzzle readability, placement feel, circuit behavior, spell interoperability, and the optional reward challenge rather than final art.

## Fixed loadout

Grace receives:

```text
Metal Tether
Water Jet
Lightning Spark
```

Automatic double jump, hover, and Flight are disabled.

Mana and Stamina regenerate for cheap experimentation.

## Electrical contract

These are not decorative puzzle wires.

The chamber uses the existing physical DC network:

- circuit terminals connect by world-space proximity;
- copper uses the shared conductive material profile;
- water uses the shared water conductivity/resistivity profile;
- movable copper links carry real `CircuitComponent` terminals;
- Metal Tether transfers tension into their rigid bodies;
- Lightning Spark excites transient circuit voltage sources;
- each receiver is powered only when the solver finds a closed conductive return path.

The required outcome is therefore **current reaches the receiver**, not a specific animation or button sequence.

## Puzzle I — Metal Link

The first room contains an open copper circuit and one loose copper link with a visible tether anchor.

- Observe that the receiver is dark.
- Pulse the violet input with Lightning before repairing the gap. The gate should remain closed.
- Select Metal Tether.
- Pull the loose copper link toward the missing section of the copper path.
- The contact radii are intentionally forgiving; the bar should not require millimeter placement.
- Once the physical terminals meet, switch to Lightning Spark.
- Pulse the violet input.
- Confirm the receiver energizes and Gate One opens permanently.

The useful realization should be:

```text
Metal is not a key.
Metal is a piece of the circuit.
```

If Grace physically pushes the bar into place without Metal Tether, that is a valid emergent placement solution. The important world state is a completed conductive topology.

## Puzzle II — Water Path

The second circuit contains a dry channel where one conductive segment is missing.

- Pulse Lightning while the channel is dry and confirm the gate remains closed.
- Cast Water Jet into the dark channel.
- Confirm the channel visibly fills with cyan water.
- Confirm the water remains latched for the puzzle instead of evaporating after the short `wet` status duration.
- Pulse the violet Lightning input.
- Confirm the water material participates in the same DC graph.
- Confirm the receiver energizes and Gate Two opens.

This room should communicate that Water is a **conductive medium**, not simply a blue switch.

## Optional cache — Side Circuit

After Puzzle II, a small side circuit and locked reward chest are available.

The cache is optional.

- Ignore it and verify the main synthesis chamber remains accessible.
- On another pass, inspect the compact open circuit.
- Reposition its copper link into the gap.
- Pulse its Lightning input.
- Confirm its receiver powers and the reward chest unlocks.
- Open the chest and choose one actual supply reward.
- Confirm the active main objective returns to Puzzle III afterward.
- Confirm powering or claiming the cache does not advance the main trial stage.

The optional circuit is deliberately a little tighter than Puzzle I. It should feel like a side challenge, not a second mandatory gate.

## Puzzle III — Synthesis

The final circuit contains **two different missing links**:

```text
one movable copper gap
+
one dry water channel
```

Test incomplete states first:

- position only the copper link and pulse Lightning;
- confirm the final receiver remains dark;
- fill only the water channel with the copper link displaced;
- confirm the final receiver remains dark.

Then solve the whole topology:

- position the copper link;
- fill the dry channel with Water Jet;
- pulse the violet input with Lightning Spark;
- confirm current reaches the receiver;
- confirm the final barrier opens.

Reach the gold completion seal.

The synthesis should feel like recombining two previously understood ideas, not learning a fourth rule at the finish line.

## Emergent behavior

Record alternative solutions rather than immediately patching them.

Examples worth observing:

- physically pushing a copper link instead of tethering it;
- using tether momentum to overshoot and then nudge the link back;
- energizing a source first and completing the topology while the pulse is still active;
- using player collision or another existing force to settle the conductor.

These are acceptable when the actual circuit still becomes physically complete.

An exploit becomes a problem when it powers a receiver with an open circuit, allows progression without the receiver ever energizing, or bypasses an unrelated required chamber.

## Reset

Use the normal development RESET action.

Confirm reset:

- returns Grace to the entrance;
- restores the exact three-spell loadout;
- releases any active Metal Tether;
- drains required water channels;
- returns movable copper links to their starting positions with zero velocity;
- closes all required gates;
- clears required trial completion;
- does not duplicate a reward already claimed from the optional cache.

## Creative review

Judge the chamber on these questions:

1. Can you tell that the copper bar belongs in the physical gap without a giant instruction label?
2. Is Metal Tether precise enough for forgiving circuit placement?
3. Does the terminal snap/contact tolerance feel generous rather than fiddly?
4. Does Water Jet visually read as filling a conductor rather than toggling a switch?
5. Is Lightning Spark's short range appropriate for deliberately energizing the input rods?
6. Do you understand why each failed circuit is open?
7. Does the final two-link circuit feel like a satisfying synthesis?
8. Is the optional side circuit tempting without looking mandatory?
9. Do the room and camera stay readable while pulling rigid bodies around?
10. What unplanned physical solution do you try?

## Automated regression

```text
res://scenes/tests/trial_chamber_002_conductive_circuit_smoke_test.tscn
```

The smoke test verifies:

- exact Metal Tether / Water Jet / Lightning Spark loadout;
- aerial bypasses disabled;
- real DC solvers exist per circuit;
- a disconnected copper gap stays open;
- physically aligning the copper link plus Lightning powers Puzzle I;
- Water Jet latches a shared water material component into Puzzle II's topology;
- Water + Lightning powers Puzzle II;
- the optional circuit unlocks a real reward chest without changing main stage;
- metal alone cannot solve the synthesis circuit;
- water + metal + Lightning powers the final receiver;
- reset restores required topology and player state.

## Art status

This remains a gameplay graybox.

The intentional visual grammar is limited to:

- copper/orange = conductive metal;
- cyan = water conductor;
- violet = Lightning input;
- cool blue = receiver/load;
- gold = reward/completion.

Do not expand the room into a production environment until its puzzle behavior survives playtesting.
