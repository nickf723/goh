# Agent Workflow

This workflow turns creative direction into reviewable repository changes while keeping Nick in control of scope and feel.

## Flow

```text
Idea
  ↓
Plan issue
  ↓
Creative approval
  ↓
Build on agent branch
  ↓
Automated validation
  ↓
Draft pull request
  ↓
Independent review
  ↓
Nick playtests
  ↓
Revise, merge, or reject
```

## 1. Idea capture

Nick describes the desired player experience in ordinary language. The first response should preserve that intent rather than immediately translating it into code details.

## 2. Planning

The planning pass finds existing systems, proposes the smallest useful vertical slice, and writes observable acceptance criteria. It must identify creative questions separately from implementation questions.

## 3. Approval

Nick approves the player-facing goal and any creative decisions. Routine implementation choices do not require a meeting.

## 4. Building

The builder works from the approved issue on `agent/<short-description>`. It may update the issue when repository discoveries make an acceptance criterion impossible, but it may not silently substitute a different feature.

## 5. Validation

Automated checks catch import, parse, and startup failures. The builder also adds manual playtest steps for anything the player can see, hear, control, or trigger.

## 6. Review

A separate review pass checks:

- acceptance criteria;
- architectural reuse;
- scope discipline;
- likely regressions;
- debug visibility;
- manual test quality;
- unresolved creative decisions.

## 7. Playtest

Nick tests feel, readability, pacing, and whether the feature belongs in the game. A technically correct feature can still be rejected.

## 8. Merge

Merge only after checks pass and the playtest is satisfactory. Prefer squash merges for a compact project history unless preserving individual commits is useful.

## Autonomy ladder

### Level 1: supervised

The agent plans and builds a draft PR. Nick reviews every change and merges manually.

### Level 2: delegated

The agent may repair its branch from CI or review feedback without renewed approval when the player-facing goal remains unchanged.

### Level 3: trusted low-risk work

Documentation, tests, validators, and narrowly scoped tooling may be eligible for auto-merge after consistently reliable results. Gameplay, progression, architecture, story, and final assets remain review-gated.

The project starts at Level 1.
