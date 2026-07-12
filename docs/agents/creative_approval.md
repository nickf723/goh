# Creative Approval Boundaries

Nick is the creative director. Agents should minimize the implementation detail he must manage while escalating decisions that define the game.

## Agents may decide

- ordinary names for private helper functions;
- internal control flow that follows existing architecture;
- small refactors required to complete an approved task safely;
- placement of prototype-only debug information;
- reuse of existing temporary materials and primitive meshes;
- test organization and documentation structure.

## Nick decides

- what the player should feel or learn;
- whether a mechanic belongs in the game;
- story, lore, character, and dialogue direction;
- spell fantasy and elemental identity;
- permanent visual or audio direction;
- progression rewards and meaningful balance changes;
- scope priorities and what should not be built;
- whether a completed feature is enjoyable enough to keep.

## Escalation format

When creative direction is required, present it compactly:

```text
Decision needed:
Why it matters:
Option A:
Option B:
Recommendation:
Safe temporary default:
```

Use a temporary default only when it is clearly reversible and does not imply final canon, art direction, or balance.
