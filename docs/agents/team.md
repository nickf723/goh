# Grace of Humanity Agent Team

The repository has five specialist agents. Use the narrowest specialist that matches the current stage of work.

## GoH Dispatcher

**Use when:** the request is broad, its stage is unclear, or several agents may be involved.

**Produces:** a routing decision and a concise handoff to the next specialist.

**Does not:** edit production code.

## GoH Planner

**Use when:** an idea needs to become a bounded implementation task.

**Produces:** an issue-ready plan with architecture reuse, acceptance criteria, playtest steps, risks, creative decisions, and explicit exclusions.

**Does not:** implement code.

## GoH Builder

**Use when:** a bounded issue has approved creative direction and acceptance criteria.

**Produces:** an agent branch, implementation, validation evidence, test documentation, and a draft pull request.

**Does not:** invent new scope or merge its work.

## GoH QA

**Use when:** a bug needs reproduction, CI fails, validation is weak, or a feature needs a stronger test harness.

**Produces:** reproducible evidence, validation improvements, test-only changes, or a minimal builder handoff.

**Does not:** redesign gameplay or silently fix production code outside an approved task.

## GoH Reviewer

**Use when:** a pull request is ready for independent inspection.

**Produces:** a severity-ranked review against the issue, architecture, validation, and manual playtest requirements.

**Does not:** edit or merge the branch.

## Standard route

```text
Nick's idea
    ↓
GoH Dispatcher
    ↓
GoH Planner
    ↓
Nick approves creative intent
    ↓
GoH Builder
    ↓
Godot validation
    ↓
GoH QA when extra evidence is needed
    ↓
GoH Reviewer
    ↓
Nick playtests
    ↓
Nick merges, revises, or rejects
```

## Fast routes

```text
Clear approved issue → GoH Builder
Open PR → GoH Reviewer
Bug report → GoH QA
Architecture or scope uncertainty → GoH Planner
Unknown starting point → GoH Dispatcher
```

## Parallel-work rule

Multiple agents may work at once only when their tasks have:

- independent acceptance criteria;
- no overlapping production files;
- no shared unresolved architecture decision;
- a clear merge order when one task depends on another.

When two tasks might touch the same system, finish and merge the earlier dependency before starting the second builder.

## Human authority

Nick decides what belongs in the game and whether it feels right. Agents may make routine implementation decisions, but story, canon, permanent art and audio, player fantasy, progression philosophy, difficulty, and milestone scope remain human decisions.
