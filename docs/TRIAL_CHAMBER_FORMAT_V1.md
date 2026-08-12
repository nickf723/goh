# Grace of Humanity — Trial Chamber Format v1

## Status

Accepted development format.

`Trial Chamber 001: Shatter & Climb` is the first reference implementation. `Trial Chamber 002: Conductive Circuit` is the first counter-test using a different systems vocabulary.

## Purpose

Trial Chambers are compact authored spaces for testing whether Grace's existing tools create understandable, satisfying, systemic puzzles without the noise of a large open environment.

They are not a replacement for dungeons or exploration regions. They are a controlled crucible for puzzle design, sandbox interactions, player readability, movement, camera behavior, and small-scale environment composition.

## Core grammar

A standard chamber should usually follow:

```text
Fixed loadout
→ Puzzle I: teach / establish
→ Puzzle II: apply / transform
→ Optional challenge → reward
→ Puzzle III: synthesis / remix
→ completion seal
```

A chamber may vary the number of stages when the idea demands it, but it should remain short enough to replay and understand as one experiment.

## Required-route rule

Required puzzles are consecutive rather than mutually exclusive branches.

The player should leave a completed chamber having engaged with the important ideas the chamber was built to test. Alternate methods may solve an individual puzzle, but creativity should not normally erase the rest of the required sequence.

## Outcome-first validation

A puzzle defines the world state that must be achieved, not a single approved input sequence.

Examples:

- a crossing becomes traversable;
- a brittle obstruction is physically cleared;
- a circuit carries current to its receiver;
- a gate reaches its open state;
- Grace reaches a valid destination.

If the supplied tools produce another coherent way to reach that state, record it as an emergent solution before treating it as a defect.

Patch an emergent solution only when it trivializes the chamber family, bypasses unrelated required outcomes, depends on an obvious technical exploit, or destroys useful game constraints.

## Optional challenges

Optional puzzles are allowed to branch from the required route because their purpose is reward rather than proof of completion.

They should:

- be visibly tempting but clearly nonmandatory;
- generally ask for deeper, less-instructed, or more precise use of the same vocabulary;
- never own main-progression state;
- never overwrite the active main objective after the reward interaction finishes;
- award real items, materials, techniques, lore, or other useful rewards when practical;
- avoid trivial farming when the chamber is reset during development.

## Fixed loadouts

Each chamber explicitly defines Grace's available puzzle vocabulary.

The fixed loadout should be small enough that experimentation is inviting rather than menu-heavy. A typical trial uses two to five meaningful tools. Development-only progression shortcuts such as automatic Flight should be disabled unless Flight is one of the chamber's intended verbs.

Mana and other expendable resources may regenerate during development trials when resource starvation would only slow iteration rather than test an intended constraint.

## Environment rules

Trial art remains deliberately quiet while gameplay is being proven.

- broad floors and walls before decoration;
- generous camera volume;
- few or no unnecessary stairs;
- no giant solution text;
- color and material cues may distinguish puzzle concepts;
- one readable completion landmark;
- optional rewards may use a separate accent;
- primitive blockout geometry is acceptable until the puzzle survives playtesting.

A chamber that only works because the scenery explains the answer is not yet a strong systemic puzzle.

## Reset contract

Development reset should restore:

- Grace's start position;
- the fixed loadout;
- Health, Mana, Stamina, and Stance as appropriate;
- required puzzle mechanisms;
- required completion flags;
- physical puzzle pieces and their velocities.

Optional rewards should not become an infinite farming source merely because the main puzzle is reset.

## Reference chamber 001 — Shatter & Climb

Vocabulary:

```text
Training Hammer
Water Jet
Ice Lance
```

Required arc:

```text
Water → Ice crossing
→ Ice → Heavy brittle seal
→ frozen ascent + brittle crown synthesis
→ upper seal
```

Optional challenge:

```text
Reach a raised reward cache using the supplied movement/terrain possibilities.
```

Primary lesson: ordered material transformations and compound physical reactions.

## Counter-test chamber 002 — Conductive Circuit

Vocabulary:

```text
Metal Tether
Water Jet
Lightning Spark
```

Required arc:

```text
place conductive metal into a physical circuit gap + Lightning
→ turn a dry channel into a conductive water path + Lightning
→ complete one circuit containing both missing metal and water links + Lightning
→ completion seal
```

Optional challenge:

```text
Power a separate side circuit to unlock a reward cache.
```

Primary lesson: topology, physical placement, conductive materials, and transient electrical power.

## Promotion rule for future chambers

Do not mass-produce trials from this document.

Author one chamber, play it, record what was fun or confusing, and let the next chamber deliberately test a different class of reasoning. Shared infrastructure should only be extracted after repeated authored examples prove that the abstraction is real.
