# Agent Handoff Contract

Every specialist should leave the next specialist enough grounded information to continue without repeating repository exploration or silently changing intent.

## Universal handoff

```text
Role completed:
Source request or issue:
Approved player-facing goal:
Scope boundary:
Repository evidence inspected:
Decisions made:
Assumptions:
Validation performed:
Validation not performed:
Risks or blockers:
Creative decisions still needed:
Recommended next role:
```

## Planner to Builder

The planner must provide:

- observable goal;
- relevant existing systems and paths;
- required behavior;
- acceptance criteria;
- explicit out-of-scope items;
- manual playtest flow;
- automated checks;
- approved creative direction;
- unresolved creative questions.

The builder must not begin while a required creative decision remains unresolved.

## Builder to QA

The builder must provide:

- branch and pull-request reference;
- complete changed-file list;
- behavior implemented;
- validation already run;
- exact scene or flow to test;
- known limitations;
- suspected fragile areas.

QA should test the claimed result, not invent a larger feature matrix.

## QA to Builder

A defect handoff must include:

- exact reproduction steps;
- expected and observed behavior;
- environment and save-state conditions;
- logs or visible evidence;
- likely fault boundary;
- smallest recommended fix;
- regression checks.

## Builder to Reviewer

The pull request must provide:

- linked issue;
- player-facing result;
- architecture reused;
- files and systems changed;
- CI results;
- manual test document;
- known limitations;
- creative-review questions;
- nearby behavior intentionally unchanged.

## Reviewer to Nick

The reviewer should reduce Nick's burden to:

- blockers or meaningful risks;
- whether the PR fulfills the approved goal;
- what must be judged through play rather than code inspection;
- a short, exact playtest path;
- a merge, revise, or reject recommendation.

## No invisible state

Do not rely on private assumptions, an earlier chat, or unwritten intent. Put material decisions in the issue, pull request, or repository documentation so the next agent and future Nick can recover the reasoning.
